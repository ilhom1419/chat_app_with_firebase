import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import '../datasources/secure_signal_protocol_store.dart';

class SecretChatCryptoService {
  final FirebaseFirestore _firestore;
  final SecureSignalProtocolStore _protocolStore;

  SecretChatCryptoService({
    FirebaseFirestore? firestore,
    required SecureSignalProtocolStore protocolStore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _protocolStore = protocolStore;

  SecureSignalProtocolStore get protocolStore => _protocolStore;

  /// Deterministically maps a string deviceId to a 32-bit positive integer deviceId
  int toSignalDeviceId(String deviceId) {
    return (deviceId.hashCode.abs() % 100000) + 1;
  }

  SignalProtocolAddress getAddress(String uid, String deviceId) {
    return SignalProtocolAddress(uid, toSignalDeviceId(deviceId));
  }

  /// Ensures a Signal Protocol session exists for the recipient, initializing X3DH if needed
  Future<void> ensureSessionEstablished({
    required String remoteUid,
    required String remoteDeviceId,
  }) async {
    final remoteAddress = getAddress(remoteUid, remoteDeviceId);
    final hasSession = await _protocolStore.containsSession(remoteAddress);

    if (hasSession) {
      return;
    }

    // 1. Fetch remote device document from Firestore
    final deviceDocRef = _firestore
        .collection('users')
        .doc(remoteUid)
        .collection('devices')
        .doc(remoteDeviceId);

    final deviceSnap = await deviceDocRef.get();
    if (!deviceSnap.exists) {
      throw Exception('Qarshi tomon qurilmasi topilmadi');
    }

    final deviceData = deviceSnap.data()!;
    if (deviceData['revoked'] == true) {
      throw Exception('Qarshi tomon qurilmasi bekor qilingan (revoked)');
    }

    final int registrationId = deviceData['registrationId'] as int;
    final String identityPubBase64 = deviceData['identityPublicKey'] as String;
    final Map<String, dynamic> signedPreKeyData =
        deviceData['signedPreKey'] as Map<String, dynamic>;

    final identityKey =
        IdentityKey.fromBytes(base64Decode(identityPubBase64), 0);
    final int signedPreKeyId = signedPreKeyData['keyId'] as int;
    final signedPreKeyPublic =
        Curve.decodePoint(base64Decode(signedPreKeyData['publicKey'] as String), 0);
    final signedPreKeySignature =
        base64Decode(signedPreKeyData['signature'] as String);

    // 2. Atomically claim an unused One-Time PreKey (OPK) if available
    int? opkId;
    ECPublicKey? opkPublic;

    final prekeysColl = deviceDocRef.collection('prekeys');
    final opkQuery = await prekeysColl
        .where('consumed', isEqualTo: false)
        .limit(1)
        .get();

    if (opkQuery.docs.isNotEmpty) {
      final opkDoc = opkQuery.docs.first;
      opkId = opkDoc.data()['keyId'] as int?;
      final opkBase64 = opkDoc.data()['publicKey'] as String?;
      if (opkBase64 != null && opkBase64.isNotEmpty) {
        opkPublic = Curve.decodePoint(base64Decode(opkBase64), 0);
        // Mark OPK as consumed
        await opkDoc.reference.update({
          'consumed': true,
          'consumedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // 3. Assemble PreKeyBundle
    final bundle = PreKeyBundle(
      registrationId,
      toSignalDeviceId(remoteDeviceId),
      opkId,
      opkPublic,
      signedPreKeyId,
      signedPreKeyPublic,
      signedPreKeySignature,
      identityKey,
    );

    // 4. Build session using SessionBuilder
    final builder =
        SessionBuilder.fromSignalStore(_protocolStore, remoteAddress);
    await builder.processPreKeyBundle(bundle);
  }

  /// Encrypts plaintext message locally using SessionCipher
  /// Returns a map containing serialized Base64 payload and envelopeType (1: PreKeySignalMessage, 2: SignalMessage)
  Future<Map<String, dynamic>> encryptMessage({
    required String remoteUid,
    required String remoteDeviceId,
    required String plaintext,
  }) async {
    final remoteAddress = getAddress(remoteUid, remoteDeviceId);

    // Ensure session is established
    await ensureSessionEstablished(
      remoteUid: remoteUid,
      remoteDeviceId: remoteDeviceId,
    );

    final cipher = SessionCipher.fromStore(_protocolStore, remoteAddress);
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final ciphertextMessage = await cipher.encrypt(plaintextBytes);

    final int envelopeType =
        ciphertextMessage.getType() == CiphertextMessage.prekeyType ? 1 : 2;
    final String payload = base64Encode(ciphertextMessage.serialize());

    return {
      'payload': payload,
      'envelopeType': envelopeType,
    };
  }

  /// Decrypts encrypted message locally using SessionCipher
  Future<String> decryptMessage({
    required String remoteUid,
    required String remoteDeviceId,
    required String payload,
    required int envelopeType,
  }) async {
    final remoteAddress = getAddress(remoteUid, remoteDeviceId);
    final bytes = base64Decode(payload);
    final cipher = SessionCipher.fromStore(_protocolStore, remoteAddress);

    Uint8List decryptedBytes;

    if (envelopeType == 1) {
      // PreKeySignalMessage (initiates or continues session)
      final preKeyMessage = PreKeySignalMessage(bytes);
      decryptedBytes = await cipher.decrypt(preKeyMessage);
    } else {
      // Standard SignalMessage (WhisperMessage)
      final signalMessage = SignalMessage.fromSerialized(bytes);
      decryptedBytes = await cipher.decryptFromSignal(signalMessage);
    }

    return utf8.decode(decryptedBytes);
  }

  /// Generates the standard 60-digit Signal Protocol Safety Number (Fingerprint)
  Future<String> generateSafetyNumber({
    required String myUid,
    required String remoteUid,
    required String remoteDeviceId,
  }) async {
    final remoteAddress = getAddress(remoteUid, remoteDeviceId);
    final myIdentity = await _protocolStore.getIdentityKeyPair();
    var remoteIdentity = await _protocolStore.getIdentity(remoteAddress);

    if (remoteIdentity == null) {
      // Fetch remote identity key from Firestore if not yet stored in session
      final doc = await _firestore
          .collection('users')
          .doc(remoteUid)
          .collection('devices')
          .doc(remoteDeviceId)
          .get();
      if (!doc.exists) {
        throw Exception('Qarshi tomon identifikatori topilmadi');
      }
      final pubKeyBase64 = doc.data()!['identityPublicKey'] as String;
      remoteIdentity = IdentityKey.fromBytes(base64Decode(pubKeyBase64), 0);
      await _protocolStore.saveIdentity(remoteAddress, remoteIdentity);
    }

    final generator = NumericFingerprintGenerator(5200);
    final fingerprint = generator.createFor(
      1,
      Uint8List.fromList(utf8.encode(myUid)),
      myIdentity.getPublicKey(),
      Uint8List.fromList(utf8.encode(remoteUid)),
      remoteIdentity,
    );

    return fingerprint.displayableFingerprint.getDisplayText();
  }
}
