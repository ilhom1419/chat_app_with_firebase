import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/device_identity.dart';
import '../datasources/secure_signal_protocol_store.dart';

class SecretChatKeyService {
  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _secureStorage;
  final SecureSignalProtocolStore _protocolStore;

  SecretChatKeyService({
    FirebaseFirestore? firestore,
    FlutterSecureStorage? secureStorage,
    SecureSignalProtocolStore? protocolStore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _protocolStore = protocolStore ??
            SecureSignalProtocolStore(
                secureStorage ?? const FlutterSecureStorage());

  SecureSignalProtocolStore get protocolStore => _protocolStore;
  FlutterSecureStorage get secureStorage => _secureStorage;

  static const String _deviceIdStorageKey = 'secret_chat_device_id';

  /// Obtains current device ID or generates a permanent UUID for this installation
  Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _secureStorage.read(key: _deviceIdStorageKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _secureStorage.write(key: _deviceIdStorageKey, value: deviceId);
    }
    return deviceId;
  }

  /// Ensures current device has initialized its Signal keys and published public keys to Firestore
  Future<DeviceIdentity> initializeDeviceKeys(String userId) async {
    final deviceId = await getOrCreateDeviceId();
    final deviceDocRef =
        _firestore.collection('users').doc(userId).collection('devices').doc(deviceId);

    final docSnap = await deviceDocRef.get();
    bool needsGeneration = false;

    try {
      await _protocolStore.getIdentityKeyPair();
      await _protocolStore.getLocalRegistrationId();
    } catch (_) {
      needsGeneration = true;
    }

    if (needsGeneration || !docSnap.exists) {
      // 1. Generate Signal cryptographic material
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);
      final signedPreKey = generateSignedPreKey(identityKeyPair, 1);
      final preKeys = generatePreKeys(1, 50);

      // 2. Persist private material in Secure Storage
      await _protocolStore.saveLocalIdentityKeyPair(identityKeyPair);
      await _protocolStore.saveLocalRegistrationId(registrationId);
      await _protocolStore.storeSignedPreKey(signedPreKey.id, signedPreKey);
      for (final pk in preKeys) {
        await _protocolStore.storePreKey(pk.id, pk);
      }

      // 3. Publish public metadata to Firestore
      final identityPubKeyBytes = identityKeyPair.getPublicKey().serialize();
      final signedPubKeyBytes =
          signedPreKey.getKeyPair().publicKey.serialize();

      await deviceDocRef.set({
        'registrationId': registrationId,
        'identityPublicKey': base64Encode(identityPubKeyBytes),
        'signedPreKey': {
          'keyId': signedPreKey.id,
          'publicKey': base64Encode(signedPubKeyBytes),
          'signature': base64Encode(signedPreKey.signature),
          'createdAt': FieldValue.serverTimestamp(),
        },
        'revoked': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      // 4. Batch publish One-Time PreKeys (consumed: false)
      final batch = _firestore.batch();
      for (final pk in preKeys) {
        final pkRef = deviceDocRef.collection('prekeys').doc(pk.id.toString());
        batch.set(pkRef, {
          'keyId': pk.id,
          'publicKey': base64Encode(pk.getKeyPair().publicKey.serialize()),
          'consumed': false,
          'consumedBy': null,
          'consumedAt': null,
        });
      }
      await batch.commit();

      return DeviceIdentity(
        deviceId: deviceId,
        registrationId: registrationId,
        identityPublicKey: base64Encode(identityPubKeyBytes),
        createdAt: DateTime.now(),
        revoked: false,
      );
    } else {
      // Existing device document
      final data = docSnap.data()!;
      return DeviceIdentity.fromFirestore(data, deviceId);
    }
  }

  /// Mark current device as revoked
  Future<void> revokeCurrentDevice(String userId) async {
    final deviceId = await getOrCreateDeviceId();
    final deviceDocRef =
        _firestore.collection('users').doc(userId).collection('devices').doc(deviceId);
    await deviceDocRef.update({'revoked': true});
  }
}
