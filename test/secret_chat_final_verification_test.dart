import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_message.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_media_payload.dart';
import 'package:chat_app/features/secret_chat/data/datasources/secure_signal_protocol_store.dart';
import 'package:chat_app/features/secret_chat/data/services/secret_media_crypto_service.dart';
import 'package:chat_app/core/security/screen_protector_service.dart';
import 'package:chat_app/core/localization/localization_service.dart';

class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    _data.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PHASE G — Section 1 & 10: Security Rules & No-Leak Verification', () {
    test('1. Secret message envelope in Firestore strictly excludes plaintext and media keys', () {
      final now = DateTime.now();
      final msg = SecretMessage(
        messageId: 'msg_audit_001',
        chatId: 'secret_chat_audit',
        senderId: 'alice_uid',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'V3aF8x2SignalEncryptedPayloadBase64==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now,
        isRead: false,
      );

      final map = msg.toFirestore();

      // No plaintext leakage
      expect(map.containsKey('text'), isFalse);
      expect(map.containsKey('plaintext'), isFalse);
      expect(map.containsKey('decryptedText'), isFalse);
      expect(map.containsKey('mediaKey'), isFalse);
      expect(map.containsKey('keyBase64'), isFalse);
      expect(map.containsKey('nonceBase64'), isFalse);

      // Only authorized protocol fields
      expect(map['messageId'], equals('msg_audit_001'));
      expect(map['chatId'], equals('secret_chat_audit'));
      expect(map['senderId'], equals('alice_uid'));
      expect(map['senderDeviceId'], equals('dev_alice_1'));
      expect(map['recipientDeviceId'], equals('dev_bob_1'));
      expect(map['payload'], equals('V3aF8x2SignalEncryptedPayloadBase64=='));
      expect(map['protocolVersion'], equals(1));
      expect(map['envelopeType'], equals(1));
      expect(map['selfDestructDuration'], equals(5));
      expect(map['isRead'], isFalse);
    });
  });

  group('PHASE G — Section 2 & 3: Signal Protocol E2EE Two-Party Simulation', () {
    late MockSecureStorage aliceStorage;
    late MockSecureStorage bobStorage;
    late SecureSignalProtocolStore aliceStore;
    late SecureSignalProtocolStore bobStore;

    const aliceUid = 'alice_user';
    const bobUid = 'bob_user';
    const aliceDeviceIdInt = 101;
    const bobDeviceIdInt = 202;

    late SignalProtocolAddress aliceAddress;
    late SignalProtocolAddress bobAddress;

    late IdentityKeyPair aliceIdentity;
    late IdentityKeyPair bobIdentity;
    late int aliceRegId;
    late int bobRegId;
    late SignedPreKeyRecord bobSignedPreKey;
    late List<PreKeyRecord> bobPreKeys;

    setUp(() async {
      aliceStorage = MockSecureStorage();
      bobStorage = MockSecureStorage();
      aliceStore = SecureSignalProtocolStore(aliceStorage, prefix: 'alice_');
      bobStore = SecureSignalProtocolStore(bobStorage, prefix: 'bob_');

      aliceAddress = SignalProtocolAddress(aliceUid, aliceDeviceIdInt);
      bobAddress = SignalProtocolAddress(bobUid, bobDeviceIdInt);

      aliceIdentity = generateIdentityKeyPair();
      aliceRegId = generateRegistrationId(false);
      await aliceStore.saveLocalIdentityKeyPair(aliceIdentity);
      await aliceStore.saveLocalRegistrationId(aliceRegId);

      bobIdentity = generateIdentityKeyPair();
      bobRegId = generateRegistrationId(false);
      await bobStore.saveLocalIdentityKeyPair(bobIdentity);
      await bobStore.saveLocalRegistrationId(bobRegId);

      bobSignedPreKey = generateSignedPreKey(bobIdentity, 1);
      await bobStore.storeSignedPreKey(bobSignedPreKey.id, bobSignedPreKey);

      bobPreKeys = generatePreKeys(1, 5);
      for (final pk in bobPreKeys) {
        await bobStore.storePreKey(pk.id, pk);
      }
    });

    test('2. Two-client X3DH session establishment & bi-directional Double Ratchet exchange', () async {
      // Bob PreKeyBundle
      final bobBundle = PreKeyBundle(
        bobRegId,
        bobDeviceIdInt,
        bobPreKeys.first.id,
        bobPreKeys.first.getKeyPair().publicKey,
        bobSignedPreKey.id,
        bobSignedPreKey.getKeyPair().publicKey,
        bobSignedPreKey.signature,
        bobIdentity.getPublicKey(),
      );

      // Alice processes Bob's PreKeyBundle
      final aliceSessionBuilder = SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      expect(await aliceStore.containsSession(bobAddress), isTrue);

      // Alice sends message to Bob
      const aliceOriginalText = 'Salom Bob, bu maxfiy xabar!';
      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final ciphertextFromAlice = await aliceCipher.encrypt(Uint8List.fromList(utf8.encode(aliceOriginalText)));

      expect(ciphertextFromAlice.getType(), equals(CiphertextMessage.prekeyType));
      final serializedPayload = base64Encode(ciphertextFromAlice.serialize());

      // Bob decrypts
      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      final decryptedBytesBob = await bobCipher.decrypt(PreKeySignalMessage(base64Decode(serializedPayload)));
      expect(utf8.decode(decryptedBytesBob), equals(aliceOriginalText));

      // Bob replies to Alice (Ratchet step)
      const bobOriginalReply = 'Salom Alice, javob qaytaryapman!';
      final replyFromBob = await bobCipher.encrypt(Uint8List.fromList(utf8.encode(bobOriginalReply)));

      // Alice decrypts Bob's reply
      final decryptedBytesAlice = await aliceCipher.decryptFromSignal(SignalMessage.fromSerialized(replyFromBob.serialize()));
      expect(utf8.decode(decryptedBytesAlice), equals(bobOriginalReply));

      // Verify Safety Number (Fingerprint) calculation
      final generator = NumericFingerprintGenerator(5200);
      final fingerprint = generator.createFor(
        1,
        Uint8List.fromList(utf8.encode(aliceUid)),
        aliceIdentity.getPublicKey(),
        Uint8List.fromList(utf8.encode(bobUid)),
        bobIdentity.getPublicKey(),
      );
      expect(fingerprint.displayableFingerprint.getDisplayText(), isNotEmpty);
    });

    test('3. Corrupted or tampered ciphertext is strictly rejected with no plaintext fallback', () async {
      final bobBundle = PreKeyBundle(
        bobRegId,
        bobDeviceIdInt,
        bobPreKeys.last.id,
        bobPreKeys.last.getKeyPair().publicKey,
        bobSignedPreKey.id,
        bobSignedPreKey.getKeyPair().publicKey,
        bobSignedPreKey.signature,
        bobIdentity.getPublicKey(),
      );

      final aliceSessionBuilder = SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final msg = await aliceCipher.encrypt(Uint8List.fromList(utf8.encode('Top Secret Message')));
      final serialized = msg.serialize();

      // Tamper byte
      final tampered = Uint8List.fromList(serialized);
      tampered[tampered.length - 5] ^= 0xFF;

      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      expect(
        () async => await bobCipher.decrypt(PreKeySignalMessage(tampered)),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('PHASE G — Section 4: Disappearing Messages Verification', () {
    test('4. All timer options (Off, 5s, 1m, 1h) behave deterministically', () {
      final now = DateTime.now();

      // Mode 1: Off (duration = 0) -> never expires
      final msgOff = SecretMessage(
        messageId: 'msg_off',
        chatId: 'c1',
        senderId: 'a',
        senderDeviceId: 'da',
        recipientDeviceId: 'db',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 0,
        createdAt: now.subtract(const Duration(days: 7)),
        isRead: true,
        readAt: now.subtract(const Duration(days: 7)),
      );
      expect(msgOff.isCountdownActive, isFalse);
      expect(msgOff.isExpired, isFalse);
      expect(msgOff.remainingTime, isNull);

      // Mode 2: 5 seconds -> active at 2s, expires at 6s
      final msg5sActive = SecretMessage(
        messageId: 'msg_5s',
        chatId: 'c1',
        senderId: 'a',
        senderDeviceId: 'da',
        recipientDeviceId: 'db',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now.subtract(const Duration(seconds: 10)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 2)),
      );
      expect(msg5sActive.isCountdownActive, isTrue);
      expect(msg5sActive.isExpired, isFalse);
      expect(msg5sActive.remainingTime!.inSeconds, inInclusiveRange(2, 3));

      final msg5sExpired = msg5sActive.copyWith(readAt: now.subtract(const Duration(seconds: 6)));
      expect(msg5sExpired.isExpired, isTrue);
      expect(msg5sExpired.remainingTime, equals(Duration.zero));

      // Mode 3: 1 minute (60s) -> active at 30s, expires at 61s
      final msg60sActive = SecretMessage(
        messageId: 'msg_60s',
        chatId: 'c1',
        senderId: 'a',
        senderDeviceId: 'da',
        recipientDeviceId: 'db',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 60,
        createdAt: now.subtract(const Duration(minutes: 2)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 30)),
      );
      expect(msg60sActive.isCountdownActive, isTrue);
      expect(msg60sActive.isExpired, isFalse);

      final msg60sExpired = msg60sActive.copyWith(readAt: now.subtract(const Duration(seconds: 61)));
      expect(msg60sExpired.isExpired, isTrue);

      // Mode 4: 1 hour (3600s) -> active at 1800s, expires at 3601s
      final msg1hActive = SecretMessage(
        messageId: 'msg_1h',
        chatId: 'c1',
        senderId: 'a',
        senderDeviceId: 'da',
        recipientDeviceId: 'db',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 3600,
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 1800)),
      );
      expect(msg1hActive.isCountdownActive, isTrue);
      expect(msg1hActive.isExpired, isFalse);

      final msg1hExpired = msg1hActive.copyWith(readAt: now.subtract(const Duration(seconds: 3601)));
      expect(msg1hExpired.isExpired, isTrue);
    });
  });

  group('PHASE G — Section 5: Screenshot Protection Architecture', () {
    test('5. ScreenProtectorService reference counting handles nested views safely', () async {
      ScreenProtectorService.resetForTesting();
      expect(ScreenProtectorService.isSecureActive, isFalse);

      // 1. Enter secret chat
      await ScreenProtectorService.enableSecure();
      expect(ScreenProtectorService.isSecureActive, isTrue);
      expect(ScreenProtectorService.activeSecureCount, equals(1));

      // 2. Open fullscreen media viewer or Safety Number dialog
      await ScreenProtectorService.enableSecure();
      expect(ScreenProtectorService.isSecureActive, isTrue);
      expect(ScreenProtectorService.activeSecureCount, equals(2));

      // 3. Close dialog -> Secret chat remains protected
      await ScreenProtectorService.disableSecure();
      expect(ScreenProtectorService.isSecureActive, isTrue);
      expect(ScreenProtectorService.activeSecureCount, equals(1));

      // 4. Leave secret chat -> Protection cleared
      await ScreenProtectorService.disableSecure();
      expect(ScreenProtectorService.isSecureActive, isFalse);
      expect(ScreenProtectorService.activeSecureCount, equals(0));

      ScreenProtectorService.resetForTesting();
    });
  });

  group('PHASE G — Section 6 & 7: Encrypted Media Authenticity & In-Memory Privacy', () {
    test('6. Encrypted media maintains 128-bit AEAD tag and refuses corrupted ciphertext', () {
      final plainData = Uint8List.fromList(utf8.encode('Secret media bytes content test'));
      final key = SecretMediaCryptoService.generateKey();
      final nonce = SecretMediaCryptoService.generateNonce();
      final aad = Uint8List.fromList(utf8.encode('media_aad_001'));

      final ciphertext = SecretMediaCryptoService.encryptMedia(
        plaintextBytes: plainData,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );

      // Ciphertext length = plaintext length + 16 bytes auth tag
      expect(ciphertext.length, equals(plainData.length + 16));

      // Successful decryption
      final decrypted = SecretMediaCryptoService.decryptMedia(
        ciphertextAndTag: ciphertext,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );
      expect(decrypted, equals(plainData));

      // Tampered tag must fail
      final corruptedTag = Uint8List.fromList(ciphertext);
      corruptedTag[corruptedTag.length - 1] ^= 0x01;
      expect(
        () => SecretMediaCryptoService.decryptMedia(
          ciphertextAndTag: corruptedTag,
          key: key,
          nonce: nonce,
          associatedData: aad,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('7. In-memory decrypted media is not retained in persistent plain storage', () {
      final payload = SecretMediaPayload(
        type: SecretMediaType.voice,
        mediaId: 'voice_mem_test',
        storagePath: 'secret_chats/c1/media/voice_mem_test',
        mediaUrl: 'https://...',
        keyBase64: base64Encode(List.filled(32, 9)),
        nonceBase64: base64Encode(List.filled(12, 10)),
        durationSeconds: 12,
        size: 48000,
        mimeType: 'audio/m4a',
      );

      // Serialization to JSON (transmitted via Signal envelope) contains no raw bytes
      final jsonMap = payload.toJson();
      expect(jsonMap.containsKey('decryptedBytes'), isFalse);
      expect(jsonMap.containsKey('localFilePath'), isFalse);
      expect(jsonMap['mediaId'], equals('voice_mem_test'));
    });
  });

  group('PHASE G — Section 8: Regression & Localization Completeness', () {
    test('8. Full localization coverage for all Secret Chat keys across uz, en, ru', () {
      final testKeys = [
        'secret_chat',
        'encrypted_image',
        'encrypted_voice',
        'pick_image',
        'take_photo',
        'recording_voice',
        'slide_to_cancel',
        'tap_to_download',
        'downloading',
        'decrypting',
        'mic_permission_required',
        'uploading_media',
        'media_too_large',
        'safety_number_title',
        'disappearing_messages',
      ];

      for (final lang in ['uz', 'en', 'ru']) {
        LocalizationService.langNotifier.value = lang;
        for (final key in testKeys) {
          final text = LocalizationService.translate(key);
          expect(text, isNot(equals(key)), reason: 'Missing "$key" in "$lang"');
          expect(text.trim(), isNotEmpty);
        }
      }
    });
  });
}
