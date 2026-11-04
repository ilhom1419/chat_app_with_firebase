import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_media_payload.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_message.dart';
import 'package:chat_app/features/secret_chat/data/services/secret_media_crypto_service.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  group('PHASE F — Secret Chat Media Cryptographic Security Tests', () {
    test('1. Media key is 256 bits (32 bytes) and securely random', () {
      final key1 = SecretMediaCryptoService.generateKey();
      final key2 = SecretMediaCryptoService.generateKey();

      expect(key1.length, equals(32));
      expect(key2.length, equals(32));
      expect(key1, isNot(equals(key2)));
    });

    test('2. Media nonce is 96 bits (12 bytes) and unique per encryption', () {
      final nonce1 = SecretMediaCryptoService.generateNonce();
      final nonce2 = SecretMediaCryptoService.generateNonce();

      expect(nonce1.length, equals(12));
      expect(nonce2.length, equals(12));
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('3. Image encryption with AES-256-GCM produces authenticated ciphertext', () {
      final plainImageBytes = Uint8List.fromList(
        List.generate(1024, (i) => (i * 7 + 13) % 256),
      );
      final key = SecretMediaCryptoService.generateKey();
      final nonce = SecretMediaCryptoService.generateNonce();
      final aad = Uint8List.fromList(utf8.encode('media_img_test_001'));

      final ciphertext = SecretMediaCryptoService.encryptMedia(
        plaintextBytes: plainImageBytes,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );

      // Ciphertext must differ from plaintext
      expect(ciphertext, isNot(equals(plainImageBytes)));
      // Ciphertext includes 16 bytes of authentication tag (GCM tag)
      expect(ciphertext.length, equals(plainImageBytes.length + 16));

      // Decrypt with authentic parameters
      final decrypted = SecretMediaCryptoService.decryptMedia(
        ciphertextAndTag: ciphertext,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );

      expect(decrypted, equals(plainImageBytes));
    });

    test('4. Voice message encryption and decryption roundtrip', () {
      final plainAudioBytes = Uint8List.fromList(
        utf8.encode('RIFF....WAVEfmt ....dataFakeAudioPayload'),
      );
      final key = SecretMediaCryptoService.generateKey();
      final nonce = SecretMediaCryptoService.generateNonce();
      final aad = Uint8List.fromList(utf8.encode('media_voice_test_002'));

      final ciphertext = SecretMediaCryptoService.encryptMedia(
        plaintextBytes: plainAudioBytes,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );

      expect(ciphertext.length, equals(plainAudioBytes.length + 16));

      final decrypted = SecretMediaCryptoService.decryptMedia(
        ciphertextAndTag: ciphertext,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );

      expect(decrypted, equals(plainAudioBytes));
    });

    test('5. Modified or corrupted ciphertext is strictly rejected (AEAD integrity)', () {
      final plaintext = Uint8List.fromList(utf8.encode('Confidential image data'));
      final key = SecretMediaCryptoService.generateKey();
      final nonce = SecretMediaCryptoService.generateNonce();
      final aad = Uint8List.fromList(utf8.encode('media_tamper_test'));

      final ciphertext = SecretMediaCryptoService.encryptMedia(
        plaintextBytes: plaintext,
        key: key,
        nonce: nonce,
        associatedData: aad,
      );

      // Tamper 1: modify one byte in ciphertext body
      final tamperedBody = Uint8List.fromList(ciphertext);
      tamperedBody[3] ^= 0xFF;

      expect(
        () => SecretMediaCryptoService.decryptMedia(
          ciphertextAndTag: tamperedBody,
          key: key,
          nonce: nonce,
          associatedData: aad,
        ),
        throwsA(isA<Exception>()),
      );

      // Tamper 2: modify authentication tag (last 16 bytes)
      final tamperedTag = Uint8List.fromList(ciphertext);
      tamperedTag[tamperedTag.length - 1] ^= 0x01;

      expect(
        () => SecretMediaCryptoService.decryptMedia(
          ciphertextAndTag: tamperedTag,
          key: key,
          nonce: nonce,
          associatedData: aad,
        ),
        throwsA(isA<Exception>()),
      );

      // Tamper 3: wrong AAD (mediaId mismatch)
      expect(
        () => SecretMediaCryptoService.decryptMedia(
          ciphertextAndTag: ciphertext,
          key: key,
          nonce: nonce,
          associatedData: Uint8List.fromList(utf8.encode('wrong_media_id')),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('6. Unauthorized device with wrong key or nonce cannot decrypt', () {
      final plaintext = Uint8List.fromList(utf8.encode('Secret voice sample'));
      final correctKey = SecretMediaCryptoService.generateKey();
      final attackerKey = SecretMediaCryptoService.generateKey();
      final correctNonce = SecretMediaCryptoService.generateNonce();
      final wrongNonce = SecretMediaCryptoService.generateNonce();
      final aad = Uint8List.fromList(utf8.encode('media_attack_test'));

      final ciphertext = SecretMediaCryptoService.encryptMedia(
        plaintextBytes: plaintext,
        key: correctKey,
        nonce: correctNonce,
        associatedData: aad,
      );

      // Wrong key fails
      expect(
        () => SecretMediaCryptoService.decryptMedia(
          ciphertextAndTag: ciphertext,
          key: attackerKey,
          nonce: correctNonce,
          associatedData: aad,
        ),
        throwsA(isA<Exception>()),
      );

      // Wrong nonce fails
      expect(
        () => SecretMediaCryptoService.decryptMedia(
          ciphertextAndTag: ciphertext,
          key: correctKey,
          nonce: wrongNonce,
          associatedData: aad,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('PHASE F — Media Message Envelope & Payload Serialization', () {
    test('7. Media payload encoding and parsing handles both image and voice', () {
      final imagePayload = SecretMediaPayload(
        type: SecretMediaType.image,
        mediaId: 'img_abc123',
        storagePath: 'secret_chats/chat_123/media/img_abc123',
        mediaUrl: 'https://firebasestorage.googleapis.com/...',
        keyBase64: base64Encode(List.filled(32, 1)),
        nonceBase64: base64Encode(List.filled(12, 2)),
        caption: 'Maxfiy rasm',
        width: 1920,
        height: 1080,
        size: 204800,
        mimeType: 'image/jpeg',
      );

      final encoded = SecretMediaCryptoService.encodeMediaPayload(imagePayload);
      expect(SecretMediaCryptoService.isMediaPayload(encoded), isTrue);

      final parsed = SecretMediaCryptoService.parseMediaPayload(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.mediaId, equals('img_abc123'));
      expect(parsed.type, equals(SecretMediaType.image));
      expect(parsed.storagePath, equals('secret_chats/chat_123/media/img_abc123'));
      expect(parsed.caption, equals('Maxfiy rasm'));
      expect(parsed.width, equals(1920));
      expect(parsed.height, equals(1080));
      expect(parsed.size, equals(204800));
      expect(parsed.mimeType, equals('image/jpeg'));
    });

    test('8. SecretMessage entity correctly classifies image, voice and text', () {
      final now = DateTime.now();

      // Normal text message
      final textMsg = SecretMessage(
        messageId: 'msg_text_01',
        chatId: 'chat_01',
        senderId: 'alice',
        senderDeviceId: 'dev_a',
        recipientDeviceId: 'dev_b',
        payload: 'EncryptedEnvelopeBase64==',
        envelopeType: 1,
        selfDestructDuration: 0,
        createdAt: now,
        decryptedText: 'Oddiy matn xabari',
      );

      expect(textMsg.isMedia, isFalse);
      expect(textMsg.isImage, isFalse);
      expect(textMsg.isVoice, isFalse);
      expect(textMsg.mediaPayload, isNull);

      // Encrypted Image message
      final imagePayload = SecretMediaPayload(
        type: SecretMediaType.image,
        mediaId: 'img_test_1',
        storagePath: 'secret_chats/chat_01/media/img_test_1',
        mediaUrl: 'https://...',
        keyBase64: base64Encode(List.filled(32, 5)),
        nonceBase64: base64Encode(List.filled(12, 6)),
        caption: 'Rasmli xabar',
        size: 150000,
        mimeType: 'image/jpeg',
      );

      final imageMsg = SecretMessage(
        messageId: 'msg_img_01',
        chatId: 'chat_01',
        senderId: 'alice',
        senderDeviceId: 'dev_a',
        recipientDeviceId: 'dev_b',
        payload: 'EncryptedEnvelopeBase64==',
        envelopeType: 1,
        selfDestructDuration: 0,
        createdAt: now,
        decryptedText: SecretMediaCryptoService.encodeMediaPayload(imagePayload),
        mediaPayload: imagePayload,
      );

      expect(imageMsg.isMedia, isTrue);
      expect(imageMsg.isImage, isTrue);
      expect(imageMsg.isVoice, isFalse);
      expect(imageMsg.mediaPayload!.mediaId, equals('img_test_1'));

      // Encrypted Voice message
      final voicePayload = SecretMediaPayload(
        type: SecretMediaType.voice,
        mediaId: 'voice_test_1',
        storagePath: 'secret_chats/chat_01/media/voice_test_1',
        mediaUrl: 'https://...',
        keyBase64: base64Encode(List.filled(32, 7)),
        nonceBase64: base64Encode(List.filled(12, 8)),
        durationSeconds: 15,
        size: 64000,
        mimeType: 'audio/m4a',
      );

      final voiceMsg = SecretMessage(
        messageId: 'msg_voice_01',
        chatId: 'chat_01',
        senderId: 'bob',
        senderDeviceId: 'dev_b',
        recipientDeviceId: 'dev_a',
        payload: 'EncryptedEnvelopeBase64==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now,
        decryptedText: SecretMediaCryptoService.encodeMediaPayload(voicePayload),
        mediaPayload: voicePayload,
      );

      expect(voiceMsg.isMedia, isTrue);
      expect(voiceMsg.isImage, isFalse);
      expect(voiceMsg.isVoice, isTrue);
      expect(voiceMsg.mediaPayload!.durationSeconds, equals(15));
    });

    test('9. Media key and nonce are never present in raw Firestore map', () {
      final now = DateTime.now();
      final msg = SecretMessage(
        messageId: 'msg_sec_01',
        chatId: 'chat_01',
        senderId: 'alice',
        senderDeviceId: 'dev_a',
        recipientDeviceId: 'dev_b',
        payload: 'SignalCiphertextWithoutPlaintextKey',
        envelopeType: 1,
        selfDestructDuration: 60,
        createdAt: now,
      );

      final firestoreMap = msg.toFirestore();

      expect(firestoreMap.containsKey('mediaKey'), isFalse);
      expect(firestoreMap.containsKey('mediaNonce'), isFalse);
      expect(firestoreMap.containsKey('keyBase64'), isFalse);
      expect(firestoreMap.containsKey('nonceBase64'), isFalse);
      expect(firestoreMap.containsKey('plaintext'), isFalse);
      expect(firestoreMap.containsKey('decryptedText'), isFalse);
      expect(firestoreMap['payload'], equals('SignalCiphertextWithoutPlaintextKey'));
    });
  });

  group('PHASE F — Disappearing Media Integration & Memory Privacy', () {
    test('10. Disappearing media adheres to existing timer lifecycle', () {
      final now = DateTime.now();
      final voicePayload = SecretMediaPayload(
        type: SecretMediaType.voice,
        mediaId: 'voice_disappear',
        storagePath: 'secret_chats/chat_01/media/voice_disappear',
        mediaUrl: 'https://...',
        keyBase64: base64Encode(List.filled(32, 9)),
        nonceBase64: base64Encode(List.filled(12, 10)),
        durationSeconds: 10,
        size: 32000,
        mimeType: 'audio/m4a',
      );

      final disappearingMsg = SecretMessage(
        messageId: 'msg_disappearing_voice',
        chatId: 'chat_01',
        senderId: 'alice',
        senderDeviceId: 'dev_a',
        recipientDeviceId: 'dev_b',
        payload: 'Envelope==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now.subtract(const Duration(seconds: 10)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 2)),
        decryptedText: SecretMediaCryptoService.encodeMediaPayload(voicePayload),
        mediaPayload: voicePayload,
      );

      // Countdown is active, not yet expired
      expect(disappearingMsg.isCountdownActive, isTrue);
      expect(disappearingMsg.isExpired, isFalse);
      expect(disappearingMsg.remainingTime!.inSeconds, inInclusiveRange(2, 3));

      // After 6 seconds, message expires
      final expiredMsg = disappearingMsg.copyWith(
        readAt: now.subtract(const Duration(seconds: 6)),
      );
      expect(expiredMsg.isExpired, isTrue);
      expect(expiredMsg.remainingTime, equals(Duration.zero));
    });

    test('11. In-memory decryptedBytes attach cleanly to payload', () {
      final originalDecrypted = Uint8List.fromList([1, 2, 3, 4, 5]);
      final payload = SecretMediaPayload(
        type: SecretMediaType.image,
        mediaId: 'in_memory_test',
        storagePath: 'secret_chats/chat_01/media/in_memory_test',
        mediaUrl: 'https://...',
        keyBase64: base64Encode(List.filled(32, 1)),
        nonceBase64: base64Encode(List.filled(12, 2)),
        size: 5,
        mimeType: 'image/jpeg',
      );

      expect(payload.decryptedBytes, isNull);

      final attached = payload.copyWith(decryptedBytes: originalDecrypted);
      expect(attached.decryptedBytes, isNotNull);
      expect(attached.decryptedBytes, equals(originalDecrypted));
    });
  });

  group('PHASE F — Localization Completeness', () {
    test('12. All Phase F translation keys exist across uz, en, ru', () {
      final requiredKeys = [
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
      ];

      for (final lang in ['uz', 'en', 'ru']) {
        LocalizationService.langNotifier.value = lang;
        for (final key in requiredKeys) {
          final translated = LocalizationService.translate(key);
          expect(
            translated,
            isNot(equals(key)),
            reason: 'Missing translation for key "$key" in language "$lang"',
          );
          expect(
            translated.trim(),
            isNotEmpty,
            reason: 'Empty translation for key "$key" in language "$lang"',
          );
        }
      }
    });
  });
}
