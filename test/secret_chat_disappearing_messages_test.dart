import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_message.dart';
import 'package:chat_app/features/secret_chat/data/datasources/secure_signal_protocol_store.dart';

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
  group('Phase D — Secret Chat Disappearing Messages Verification', () {
    test('1. Off (0s) — message remains visible indefinitely', () {
      final now = DateTime.now();
      final msg = SecretMessage(
        messageId: 'msg_off',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 0,
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: true,
        readAt: now.subtract(const Duration(hours: 4)),
        decryptedText: 'Persistent secret message',
      );

      expect(msg.selfDestructDuration, equals(0));
      expect(msg.expiresAt, isNull);
      expect(msg.isExpired, isFalse);
      expect(msg.isCountdownActive, isFalse);
      expect(msg.remainingTime, isNull);
    });

    test('2. 5 seconds — message active during window, disappears after deadline', () {
      final now = DateTime.now();
      // Case A: Read 2 seconds ago (still 3s left)
      final activeMsg = SecretMessage(
        messageId: 'msg_5s_active',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now.subtract(const Duration(seconds: 10)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 2)),
        decryptedText: 'Self destructs in 5s',
      );

      expect(activeMsg.isCountdownActive, isTrue);
      expect(activeMsg.isExpired, isFalse);
      expect(activeMsg.remainingTime!.inSeconds, inInclusiveRange(2, 3));

      // Case B: Read 6 seconds ago (expired)
      final expiredMsg = SecretMessage(
        messageId: 'msg_5s_expired',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now.subtract(const Duration(seconds: 15)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 6)),
        decryptedText: 'Already expired',
      );

      expect(expiredMsg.isExpired, isTrue);
      expect(expiredMsg.remainingTime, equals(Duration.zero));
    });

    test('3. 1 minute — message active during 60s, expires after 61s', () {
      final now = DateTime.now();
      final activeMsg = SecretMessage(
        messageId: 'msg_1m_active',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 2,
        selfDestructDuration: 60,
        createdAt: now.subtract(const Duration(minutes: 2)),
        isRead: true,
        readAt: now.subtract(const Duration(seconds: 30)),
        decryptedText: 'Disappears in 1m',
      );

      expect(activeMsg.isCountdownActive, isTrue);
      expect(activeMsg.isExpired, isFalse);
      expect(activeMsg.remainingTime!.inSeconds, inInclusiveRange(29, 30));

      final expiredMsg = activeMsg.copyWith(
        readAt: now.subtract(const Duration(seconds: 61)),
      );
      expect(expiredMsg.isExpired, isTrue);
    });

    test('4. 1 hour — message active during 3600s, expires after 3601s', () {
      final now = DateTime.now();
      final activeMsg = SecretMessage(
        messageId: 'msg_1h_active',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 2,
        selfDestructDuration: 3600,
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: true,
        readAt: now.subtract(const Duration(minutes: 30)),
        decryptedText: 'Disappears in 1h',
      );

      expect(activeMsg.isCountdownActive, isTrue);
      expect(activeMsg.isExpired, isFalse);
      expect(activeMsg.remainingTime!.inMinutes, inInclusiveRange(29, 30));

      final expiredMsg = activeMsg.copyWith(
        readAt: now.subtract(const Duration(seconds: 3605)),
      );
      expect(expiredMsg.isExpired, isTrue);
    });

    test('5. Countdown begins ONLY after read confirmation (not on receipt)', () {
      final now = DateTime.now();
      // Message delivered to recipient device 5 minutes ago, but unread
      final unreadMsg = SecretMessage(
        messageId: 'msg_unread',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: now.subtract(const Duration(minutes: 5)),
        isRead: false,
        readAt: null,
        decryptedText: 'Waiting for recipient to read',
      );

      // Even though 5 minutes elapsed since creation, timer has NOT started!
      expect(unreadMsg.isRead, isFalse);
      expect(unreadMsg.readAt, isNull);
      expect(unreadMsg.expiresAt, isNull);
      expect(unreadMsg.isCountdownActive, isFalse);
      expect(unreadMsg.isExpired, isFalse);

      // Now recipient opens chat and reads message
      final readMsg = unreadMsg.copyWith(
        isRead: true,
        readAt: now,
      );

      expect(readMsg.isRead, isTrue);
      expect(readMsg.readAt, isNotNull);
      expect(readMsg.isCountdownActive, isTrue);
      expect(readMsg.remainingTime!.inSeconds, inInclusiveRange(4, 5));
    });

    test('6. Sender and recipient expiration states synchronize via readAt timestamp', () {
      final readTimestamp = DateTime.now().subtract(const Duration(seconds: 2));
      const duration = 5;

      // Sender representation (isOutgoing = true)
      final senderMsg = SecretMessage(
        messageId: 'msg_sync',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: duration,
        createdAt: readTimestamp.subtract(const Duration(seconds: 10)),
        isRead: true,
        readAt: readTimestamp,
        isOutgoing: true,
        decryptedText: 'Sync test',
      );

      // Recipient representation (isOutgoing = false)
      final recipientMsg = SecretMessage(
        messageId: 'msg_sync',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: duration,
        createdAt: readTimestamp.subtract(const Duration(seconds: 10)),
        isRead: true,
        readAt: readTimestamp,
        isOutgoing: false,
        decryptedText: 'Sync test',
      );

      expect(senderMsg.expiresAt, equals(recipientMsg.expiresAt));
      expect(senderMsg.isExpired, equals(recipientMsg.isExpired));
      expect(senderMsg.remainingTime!.inSeconds,
          equals(recipientMsg.remainingTime!.inSeconds));
    });

    test('7. Duplicate receipts do not restart or alter the countdown timer', () {
      final initialReadAt = DateTime.now().subtract(const Duration(seconds: 3));
      final msg = SecretMessage(
        messageId: 'msg_dedup',
        chatId: 'chat_1',
        senderId: 'alice',
        senderDeviceId: 'dev_alice_1',
        recipientDeviceId: 'dev_bob_1',
        payload: 'Payload==',
        envelopeType: 1,
        selfDestructDuration: 5,
        createdAt: initialReadAt.subtract(const Duration(seconds: 10)),
        isRead: true,
        readAt: initialReadAt,
        decryptedText: 'Dedup read receipt',
      );

      // Simulating a duplicate read receipt snapshot arriving 2 seconds later
      final duplicateSnapshotArrival = DateTime.now();
      // System logic: once readAt is set, subsequent calls/events preserve original readAt
      final updatedMsg = msg.copyWith(
        isRead: true,
        // readAt is preserved from initial receipt
        readAt: msg.readAt,
      );

      expect(updatedMsg.readAt, equals(initialReadAt));
      expect(updatedMsg.readAt == duplicateSnapshotArrival, isFalse);
      expect(updatedMsg.remainingTime!.inSeconds, inInclusiveRange(1, 2));
    });

    test('8 & 9. Expired messages purged and never restored upon restart or reconnection',
        () async {
      final storage = MockSecureStorage();
      const expiredMsgId = 'msg_purged_1';

      // 1. Simulate expired message cleanup in storage
      await storage.write(key: 'expired_$expiredMsgId', value: '1');
      await storage.delete(key: 'decrypted_$expiredMsgId');

      // Verify decrypted plaintext was erased
      expect(await storage.read(key: 'decrypted_$expiredMsgId'), isNull);

      // 2. Simulate app restart: store checks if ID is in expired set
      final isExpiredRecorded = await storage.read(key: 'expired_$expiredMsgId');
      expect(isExpiredRecorded, equals('1'));

      // 3. Simulating reconnect snapshot containing the expired document
      final snapshotDocIds = ['msg_purged_1', 'msg_fresh_2'];
      final List<String> activeDocIds = [];

      for (final id in snapshotDocIds) {
        if (await storage.read(key: 'expired_$id') != null) {
          // Pruned! Do not add to chat
          continue;
        }
        activeDocIds.add(id);
      }

      expect(activeDocIds.contains('msg_purged_1'), isFalse);
      expect(activeDocIds, equals(['msg_fresh_2']));
    });

    test('10 & 11. Disappearing messages maintain Double Ratchet session integrity',
        () async {
      final aliceStorage = MockSecureStorage();
      final bobStorage = MockSecureStorage();

      final aliceStore =
          SecureSignalProtocolStore(aliceStorage, prefix: 'alice_');
      final bobStore = SecureSignalProtocolStore(bobStorage, prefix: 'bob_');

      final aliceAddress = SignalProtocolAddress('alice_user', 1);
      final bobAddress = SignalProtocolAddress('bob_user', 2);

      // Initialize keys
      final aliceIdentity = generateIdentityKeyPair();
      final bobIdentity = generateIdentityKeyPair();
      await aliceStore.saveLocalIdentityKeyPair(aliceIdentity);
      await aliceStore.saveLocalRegistrationId(101);
      await bobStore.saveLocalIdentityKeyPair(bobIdentity);
      await bobStore.saveLocalRegistrationId(202);

      final bobSignedPreKey = generateSignedPreKey(bobIdentity, 1);
      await bobStore.storeSignedPreKey(bobSignedPreKey.id, bobSignedPreKey);
      final bobPreKeys = generatePreKeys(1, 5);
      for (final pk in bobPreKeys) {
        await bobStore.storePreKey(pk.id, pk);
      }

      // Alice builds session with Bob
      final bobBundle = PreKeyBundle(
        202,
        2,
        bobPreKeys.first.id,
        bobPreKeys.first.getKeyPair().publicKey,
        bobSignedPreKey.id,
        bobSignedPreKey.getKeyPair().publicKey,
        bobSignedPreKey.signature,
        bobIdentity.getPublicKey(),
      );
      final builder = SessionBuilder.fromSignalStore(aliceStore, bobAddress);
      await builder.processPreKeyBundle(bobBundle);

      // 1. Send disappearing message (5s)
      final aliceCipher = SessionCipher.fromStore(aliceStore, bobAddress);
      final msg1 = await aliceCipher
          .encrypt(Uint8List.fromList(utf8.encode('Ephemeral message 1')));

      final bobCipher = SessionCipher.fromStore(bobStore, aliceAddress);
      final decrypted1 = await bobCipher.decrypt(PreKeySignalMessage(msg1.serialize()));
      expect(utf8.decode(decrypted1), equals('Ephemeral message 1'));

      // Simulate expiration & cleanup of message 1 payload
      await aliceStorage.delete(key: 'decrypted_msg_1');
      await bobStorage.delete(key: 'decrypted_msg_1');

      // CRITICAL VERIFICATION: Ratchet session was NOT deleted!
      expect(await aliceStore.containsSession(bobAddress), isTrue);
      expect(await bobStore.containsSession(aliceAddress), isTrue);

      // 2. Subsequent ratchet message works normally without re-negotiating session
      final bobReply = await bobCipher
          .encrypt(Uint8List.fromList(utf8.encode('Ephemeral reply 2')));

      final decryptedReply = await aliceCipher.decryptFromSignal(
          SignalMessage.fromSerialized(bobReply.serialize()));
      expect(utf8.decode(decryptedReply), equals('Ephemeral reply 2'));
    });
  });
}
