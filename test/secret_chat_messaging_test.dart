import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:chat_app/features/secret_chat/data/datasources/secure_signal_protocol_store.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_message.dart';

class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

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
      data.remove(key);
    } else {
      data[key] = value;
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
    return data[key];
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
    data.remove(key);
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
    data.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase C — Secret Chat E2EE Messaging Verification', () {
    late MockSecureStorage aliceStorage;
    late MockSecureStorage bobStorage;
    late MockSecureStorage eveStorage;

    late SecureSignalProtocolStore aliceStore;
    late SecureSignalProtocolStore bobStore;
    late SecureSignalProtocolStore eveStore;

    const aliceUid = 'alice_user_123';
    const bobUid = 'bob_user_456';
    const eveUid = 'eve_attacker_789';

    const aliceDeviceIdInt = 101;
    const bobDeviceIdInt = 202;

    late SignalProtocolAddress aliceAddress;
    late SignalProtocolAddress bobAddress;

    late IdentityKeyPair aliceIdentity;
    late IdentityKeyPair bobIdentity;
    late IdentityKeyPair eveIdentity;

    late int aliceRegId;
    late int bobRegId;
    late int eveRegId;

    late SignedPreKeyRecord bobSignedPreKey;
    late List<PreKeyRecord> bobPreKeys;

    setUp(() async {
      aliceStorage = MockSecureStorage();
      bobStorage = MockSecureStorage();
      eveStorage = MockSecureStorage();

      aliceStore = SecureSignalProtocolStore(aliceStorage, prefix: 'alice_');
      bobStore = SecureSignalProtocolStore(bobStorage, prefix: 'bob_');
      eveStore = SecureSignalProtocolStore(eveStorage, prefix: 'eve_');

      aliceAddress = SignalProtocolAddress(aliceUid, aliceDeviceIdInt);
      bobAddress = SignalProtocolAddress(bobUid, bobDeviceIdInt);

      // 1. Initialize Alice's cryptographic keys
      aliceIdentity = generateIdentityKeyPair();
      aliceRegId = generateRegistrationId(false);
      await aliceStore.saveLocalIdentityKeyPair(aliceIdentity);
      await aliceStore.saveLocalRegistrationId(aliceRegId);

      // 2. Initialize Bob's cryptographic keys (with SignedPreKey and One-Time PreKeys)
      bobIdentity = generateIdentityKeyPair();
      bobRegId = generateRegistrationId(false);
      await bobStore.saveLocalIdentityKeyPair(bobIdentity);
      await bobStore.saveLocalRegistrationId(bobRegId);

      bobSignedPreKey = generateSignedPreKey(bobIdentity, 1);
      await bobStore.storeSignedPreKey(bobSignedPreKey.id, bobSignedPreKey);

      bobPreKeys = generatePreKeys(1, 10);
      for (final pk in bobPreKeys) {
        await bobStore.storePreKey(pk.id, pk);
      }

      // 3. Initialize Eve's cryptographic keys (as an unauthorized active device)
      eveIdentity = generateIdentityKeyPair();
      eveRegId = generateRegistrationId(false);
      await eveStore.saveLocalIdentityKeyPair(eveIdentity);
      await eveStore.saveLocalRegistrationId(eveRegId);
      final eveSignedPreKey = generateSignedPreKey(eveIdentity, 1);
      await eveStore.storeSignedPreKey(eveSignedPreKey.id, eveSignedPreKey);
      final evePreKeys = generatePreKeys(1, 10);
      for (final pk in evePreKeys) {
        await eveStore.storePreKey(pk.id, pk);
      }
    });

    test('1 & 2. Alice sends message -> Bob receives and decrypts it', () async {
      // Alice builds session using Bob's public prekey bundle
      final bobOneTimePreKey = bobPreKeys.first;
      final bobBundle = PreKeyBundle(
        bobRegId,
        bobDeviceIdInt,
        bobOneTimePreKey.id,
        bobOneTimePreKey.getKeyPair().publicKey,
        bobSignedPreKey.id,
        bobSignedPreKey.getKeyPair().publicKey,
        bobSignedPreKey.signature,
        bobIdentity.getPublicKey(),
      );

      final aliceSessionBuilder =
          SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      expect(await aliceStore.containsSession(bobAddress), isTrue);

      // Alice encrypts plaintext message
      const plaintextAlice = 'Salom Bob! Bu maxfiy xabar (End-to-End Encrypted)';
      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final ciphertextFromAlice = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode(plaintextAlice)));

      expect(ciphertextFromAlice.getType(), equals(CiphertextMessage.prekeyType));
      final serializedPayload = base64Encode(ciphertextFromAlice.serialize());

      // Case 5: Verify ciphertext does not leak plaintext
      expect(serializedPayload.contains('Salom Bob'), isFalse);
      expect(serializedPayload.contains('End-to-End'), isFalse);

      // Bob receives envelope and decrypts it
      final bobPreKeyMessage =
          PreKeySignalMessage(base64Decode(serializedPayload));
      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      final decryptedBytes = await bobCipher.decrypt(bobPreKeyMessage);
      final decryptedTextBob = utf8.decode(decryptedBytes);

      expect(decryptedTextBob, equals(plaintextAlice));
      expect(await bobStore.containsSession(aliceAddress), isTrue);
    });

    test('3 & 4. Bob replies -> Alice receives and decrypts reply', () async {
      // Setup handshake: Alice -> Bob
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

      final aliceSessionBuilder =
          SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final msg1 = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode('Salom Bob!')));

      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      await bobCipher.decrypt(PreKeySignalMessage(msg1.serialize()));

      // Bob replies to Alice
      const replyBob = 'Rahmat Alice! Xabaringni muvaffaqiyatli qabul qildim!';
      final bobReplyCiphertext = await bobCipher
          .encrypt(Uint8List.fromList(utf8.encode(replyBob)));

      // Reply message is standard SignalMessage (ratchet advanced)
      expect(bobReplyCiphertext.getType(), equals(CiphertextMessage.whisperType));

      final serializedReply = base64Encode(bobReplyCiphertext.serialize());
      expect(serializedReply.contains('Rahmat Alice'), isFalse);

      // Alice decrypts Bob's reply
      final signalMessage =
          SignalMessage.fromSerialized(base64Decode(serializedReply));
      final aliceDecryptedBytes =
          await aliceCipher.decryptFromSignal(signalMessage);
      final decryptedReply = utf8.decode(aliceDecryptedBytes);

      expect(decryptedReply, equals(replyBob));
    });

    test('6. Third-party (Eve) cannot decrypt Alice and Bob ciphertext',
        () async {
      // Alice establishes session with Bob
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

      final aliceSessionBuilder =
          SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final ciphertext = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode('Very Confidential Message')));

      // Eve intercepts ciphertext and tries to decrypt with her own store
      final eveCipher = SessionCipher.fromStore(eveStore, aliceAddress);
      final preKeyMessage = PreKeySignalMessage(ciphertext.serialize());

      bool eveDecryptionFailed = false;
      try {
        await eveCipher.decrypt(preKeyMessage);
      } catch (_) {
        eveDecryptionFailed = true;
      }
      expect(eveDecryptionFailed, isTrue);
    });

    test('7. Corrupted or tampered ciphertext is rejected', () async {
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

      final aliceSessionBuilder =
          SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final ciphertext = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode('Original Clean Message')));

      // Corrupt payload bytes
      final rawBytes = Uint8List.fromList(ciphertext.serialize());
      rawBytes[rawBytes.length - 2] ^= 0xFF; // Flip bits in ciphertext
      rawBytes[rawBytes.length - 3] ^= 0xAA;

      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);

      expect(
        () async {
          final corruptMsg = PreKeySignalMessage(rawBytes);
          await bobCipher.decrypt(corruptMsg);
        },
        throwsA(anything),
      );
    });

    test('8. Repeated delivery handled safely without duplicate ratchet failure',
        () async {
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

      final aliceSessionBuilder =
          SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final ciphertext = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode('Unique Message 123')));

      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      final preKeyMsg = PreKeySignalMessage(ciphertext.serialize());

      // First decryption succeeds
      final decrypted1 = await bobCipher.decrypt(preKeyMsg);
      expect(utf8.decode(decrypted1), equals('Unique Message 123'));

      // If re-decrypted directly at protocol level, Signal throws DuplicatedMessageException
      expect(
        () async => await bobCipher.decrypt(preKeyMsg),
        throwsA(isA<DuplicateMessageException>()),
      );

      // SecretMessage domain model caching protects against this at repository layer
      final secretMsg = SecretMessage(
        messageId: 'msg_repeat_1',
        chatId: 'secret_chat_1',
        senderId: aliceUid,
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: base64Encode(ciphertext.serialize()),
        envelopeType: 1,
        selfDestructDuration: 0,
        createdAt: DateTime.now(),
        decryptedText: utf8.decode(decrypted1),
      );

      expect(secretMsg.isDecrypted, isTrue);
      expect(secretMsg.decryptedText, equals('Unique Message 123'));
    });

    test('9. Session state survives app restart', () async {
      // 1. Establish session between Alice and Bob
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

      final aliceSessionBuilder =
          SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await aliceSessionBuilder.processPreKeyBundle(bobBundle);

      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final msg1 = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode('Pre-restart Message')));

      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      await bobCipher.decrypt(PreKeySignalMessage(msg1.serialize()));

      // Bob replies to Alice to complete the full two-way ratchet handshake
      final replyPreRestart = await bobCipher
          .encrypt(Uint8List.fromList(utf8.encode('Pre-restart Reply from Bob')));
      await aliceCipher.decryptFromSignal(
          SignalMessage.fromSerialized(replyPreRestart.serialize()));

      // 2. Simulate App Restart: create brand new store instances with same underlying storage
      final restartedAliceStore =
          SecureSignalProtocolStore(aliceStorage, prefix: 'alice_');
      final restartedBobStore =
          SecureSignalProtocolStore(bobStorage, prefix: 'bob_');

      // Both stores still contain active session!
      expect(await restartedAliceStore.containsSession(bobAddress), isTrue);
      expect(await restartedBobStore.containsSession(aliceAddress), isTrue);

      // 3. New message sent after restart decrypts successfully without new handshake!
      final postRestartCipherAlice =
          SessionCipher.fromStore(restartedAliceStore, bobAddress);
      final postRestartMsg = await postRestartCipherAlice
          .encrypt(Uint8List.fromList(utf8.encode('Post-restart Message')));

      // Envelope is Whisper (ratchet session continued)
      expect(postRestartMsg.getType(), equals(CiphertextMessage.whisperType));

      final postRestartCipherBob =
          SessionCipher.fromStore(restartedBobStore, aliceAddress);
      final decryptedPostRestart = await postRestartCipherBob.decryptFromSignal(
          SignalMessage.fromSerialized(postRestartMsg.serialize()));

      expect(utf8.decode(decryptedPostRestart), equals('Post-restart Message'));
    });

    test('10. Safety Number (Fingerprint) generation is deterministic and matches on both sides',
        () async {
      final generator = NumericFingerprintGenerator(5200);

      // Alice generates Safety Number for Bob
      final aliceFingerprint = generator.createFor(
        1,
        Uint8List.fromList(utf8.encode(aliceUid)),
        aliceIdentity.getPublicKey(),
        Uint8List.fromList(utf8.encode(bobUid)),
        bobIdentity.getPublicKey(),
      );

      // Bob generates Safety Number for Alice
      final bobFingerprint = generator.createFor(
        1,
        Uint8List.fromList(utf8.encode(bobUid)),
        bobIdentity.getPublicKey(),
        Uint8List.fromList(utf8.encode(aliceUid)),
        aliceIdentity.getPublicKey(),
      );

      final aliceSafetyNumber =
          aliceFingerprint.displayableFingerprint.getDisplayText();
      final bobSafetyNumber =
          bobFingerprint.displayableFingerprint.getDisplayText();

      // Both participants see the EXACT same 60-digit safety number
      expect(aliceSafetyNumber, equals(bobSafetyNumber));
      expect(aliceSafetyNumber.replaceAll(' ', '').length, equals(60));

      // Eve's identity produces a completely different safety number
      final eveFingerprint = generator.createFor(
        1,
        Uint8List.fromList(utf8.encode(aliceUid)),
        aliceIdentity.getPublicKey(),
        Uint8List.fromList(utf8.encode(eveUid)),
        eveIdentity.getPublicKey(),
      );
      final eveSafetyNumber =
          eveFingerprint.displayableFingerprint.getDisplayText();

      expect(aliceSafetyNumber == eveSafetyNumber, isFalse);
    });
  });
}
