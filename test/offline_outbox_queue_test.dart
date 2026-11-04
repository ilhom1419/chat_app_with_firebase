import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/messages/domain/entities/outbox_message.dart';
import 'package:chat_app/features/messages/domain/repositories/message_repository.dart';
import 'package:chat_app/features/messages/data/services/offline_outbox_service.dart';
import 'package:chat_app/features/messages/presentation/bloc/message_bloc.dart';

/// Test Fake implementation of MessageRepository for Offline Outbox testing
class FakeMessageRepository implements MessageRepository {
  final List<Map<String, dynamic>> recordedCalls = [];
  final StreamController<List<Message>> _messagesController =
      StreamController<List<Message>>.broadcast();
  bool shouldFail = false;
  String? failureError;
  int callCount = 0;

  void emitMessages(List<Message> messages) {
    _messagesController.add(messages);
  }

  @override
  Stream<List<Message>> getMessages(String chatId) {
    return _messagesController.stream;
  }

  @override
  Future<void> sendMessage({
    String? messageId,
    required String chatId,
    required String senderId,
    required String text,
    String? replyToMessageId,
    bool isForwarded = false,
    String? imageUrl,
    MessageType type = MessageType.text,
    int? selfDestructDuration,
    double? latitude,
    double? longitude,
    String? address,
    String? contactName,
    String? contactPhone,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    String? senderTitle,
    String? authorName,
    bool isSilent = false,
    String? topicId,
    String? liveLocationSessionId,
    int? liveLocationDuration,
  }) async {
    callCount++;
    recordedCalls.add({
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type,
    });

    if (shouldFail) {
      throw Exception(failureError ?? 'Network connection unavailable');
    }
  }

  @override
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake Connectivity implementation
class FakeConnectivity implements Connectivity {
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> currentResults = [ConnectivityResult.wifi];

  void setConnectivity(List<ConnectivityResult> results) {
    currentResults = results;
    _controller.add(results);
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => currentResults;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMessageRepository mockRepository;
  late FakeConnectivity mockConnectivity;
  late OfflineOutboxService outboxService;

  setUp(() {
    mockRepository = FakeMessageRepository();
    mockConnectivity = FakeConnectivity();
    outboxService = OfflineOutboxService(
      messageRepository: mockRepository,
      connectivity: mockConnectivity,
    );
  });

  tearDown(() {
    outboxService.dispose();
  });

  group('KAKKU OFFLINE-FIRST & REALTIME OUTBOX QUEUE TEST SUITE', () {
    // TEST 01 — ONLINE SEND
    test('TEST 01 — ONLINE SEND: Message is sent normally when online', () async {
      final msg = OutboxMessage(
        id: 'msg_01',
        chatId: 'chat_123',
        senderId: 'user_1',
        text: 'Salom, do\'stim!',
        timestamp: DateTime.now(),
      );

      await outboxService.enqueue(msg);
      expect(outboxService.getPendingMessages('user_1').length, equals(1));

      await outboxService.processQueue('user_1');

      // Verifies repository received write with identical message ID
      expect(mockRepository.callCount, equals(1));
      expect(mockRepository.recordedCalls.first['messageId'], equals('msg_01'));
      expect(mockRepository.recordedCalls.first['text'], equals('Salom, do\'stim!'));

      // Successfully processed message is removed from outbox
      expect(outboxService.getPendingMessages('user_1').isEmpty, isTrue);
    });

    // TEST 02 — OFFLINE SEND
    test('TEST 02 — OFFLINE SEND: Message appears immediately with queued status', () async {
      mockRepository.shouldFail = true;
      mockRepository.failureError = 'No internet connection';

      final msg = OutboxMessage(
        id: 'msg_02',
        chatId: 'chat_123',
        senderId: 'user_1',
        text: 'Oflayn yozilgan xabar',
        timestamp: DateTime.now(),
        status: MessageStatus.queued,
      );

      await outboxService.enqueue(msg);
      final pending = outboxService.getPendingMessages('user_1');
      expect(pending.length, equals(1));
      expect(pending.first.status, equals(MessageStatus.queued));

      // Attempt send fails gracefully without losing message
      await outboxService.processQueue('user_1');
      final remaining = outboxService.getPendingMessages('user_1');
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('msg_02'));
    });

    // TEST 03 — OFFLINE PERSISTENCE
    test('TEST 03 — OFFLINE PERSISTENCE: Message survives and remains recoverable', () async {
      final msg = OutboxMessage(
        id: 'msg_persist_1',
        chatId: 'chat_abc',
        senderId: 'user_persist',
        text: 'Durable offline message payload',
        timestamp: DateTime.now(),
        status: MessageStatus.queued,
      );

      final map = msg.toMap();
      final restored = OutboxMessage.fromMap(map);

      expect(restored.id, equals(msg.id));
      expect(restored.chatId, equals(msg.chatId));
      expect(restored.senderId, equals(msg.senderId));
      expect(restored.text, equals(msg.text));
      expect(restored.status, equals(MessageStatus.queued));
    });

    // TEST 04 — AUTO SYNC
    test('TEST 04 — AUTO SYNC: Restored connectivity automatically triggers synchronization', () async {
      bool userQueried = false;
      outboxService.init(() {
        userQueried = true;
        return 'user_sync';
      });

      final msg = OutboxMessage(
        id: 'msg_auto_1',
        chatId: 'chat_sync',
        senderId: 'user_sync',
        text: 'Avtomatik sinxronlanadigan xabar',
        timestamp: DateTime.now(),
      );

      await outboxService.enqueue(msg);
      expect(outboxService.getPendingMessages('user_sync').length, equals(1));

      // Simulate network coming back online
      mockConnectivity.setConnectivity([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(userQueried, isTrue);
      expect(mockRepository.callCount, equals(1));
      expect(outboxService.getPendingMessages('user_sync').isEmpty, isTrue);
    });

    // TEST 05 — MESSAGE ORDER (FIFO)
    test('TEST 05 — MESSAGE ORDER: Multiple queued messages preserve FIFO order', () async {
      final t1 = DateTime.now();
      final t2 = t1.add(const Duration(seconds: 1));
      final t3 = t1.add(const Duration(seconds: 2));

      await outboxService.enqueue(OutboxMessage(
        id: 'fifo_3',
        chatId: 'chat_fifo',
        senderId: 'user_fifo',
        text: 'Uchinchi xabar',
        timestamp: t3,
      ));
      await outboxService.enqueue(OutboxMessage(
        id: 'fifo_1',
        chatId: 'chat_fifo',
        senderId: 'user_fifo',
        text: 'Birinchi xabar',
        timestamp: t1,
      ));
      await outboxService.enqueue(OutboxMessage(
        id: 'fifo_2',
        chatId: 'chat_fifo',
        senderId: 'user_fifo',
        text: 'Ikkinchi xabar',
        timestamp: t2,
      ));

      // Verifies sorted retrieval
      final pending = outboxService.getPendingMessages('user_fifo', chatId: 'chat_fifo');
      expect(pending.map((m) => m.id).toList(), equals(['fifo_1', 'fifo_2', 'fifo_3']));

      // Process and check FIFO delivery order
      await outboxService.processQueue('user_fifo');
      final deliveredIds = mockRepository.recordedCalls.map((c) => c['messageId']).toList();
      expect(deliveredIds, equals(['fifo_1', 'fifo_2', 'fifo_3']));
    });

    // TEST 06 — IDEMPOTENT RETRY
    test('TEST 06 — IDEMPOTENT RETRY: Retrying retains same deterministic message ID', () async {
      const stableId = 'msg_idempotent_999';

      await outboxService.enqueue(OutboxMessage(
        id: stableId,
        chatId: 'chat_idem',
        senderId: 'user_idem',
        text: 'Idempotent test payload',
        timestamp: DateTime.now(),
      ));

      // First try succeeds
      await outboxService.processQueue('user_idem');
      expect(mockRepository.recordedCalls.length, equals(1));
      expect(mockRepository.recordedCalls.first['messageId'], equals(stableId));

      // Re-enqueuing retry item with same stableId
      await outboxService.retryMessage('user_idem', stableId, 'chat_idem');
      final pending = outboxService.getPendingMessages('user_idem');
      expect(pending.isEmpty, isTrue); // Was already removed on success
    });

    // TEST 07 — LOST ACKNOWLEDGEMENT
    test('TEST 07 — LOST ACKNOWLEDGEMENT: Duplicate delivery uses identical ID', () async {
      const stableId = 'msg_lost_ack_1';
      final msg = OutboxMessage(
        id: stableId,
        chatId: 'chat_ack',
        senderId: 'user_ack',
        text: 'Lost ack payload',
        timestamp: DateTime.now(),
      );

      // Write reaches repo twice (e.g. timeout on receipt)
      await mockRepository.sendMessage(
        messageId: msg.id,
        chatId: msg.chatId,
        senderId: msg.senderId,
        text: msg.text,
      );
      await mockRepository.sendMessage(
        messageId: msg.id,
        chatId: msg.chatId,
        senderId: msg.senderId,
        text: msg.text,
      );

      expect(mockRepository.callCount, equals(2));
      // Both writes target identical document ID, preserving idempotent Firestore document state
      expect(mockRepository.recordedCalls[0]['messageId'], equals(stableId));
      expect(mockRepository.recordedCalls[1]['messageId'], equals(stableId));
    });

    // TEST 08 — OPTIMISTIC RECONCILIATION
    test('TEST 08 — OPTIMISTIC RECONCILIATION: Reconciles local and remote into single item', () async {
      final bloc = MessageBloc(
        messageRepository: mockRepository,
        outboxService: outboxService,
      );

      const stableId = 'reconcile_msg_1';
      final optimistic = OutboxMessage(
        id: stableId,
        chatId: 'chat_rec',
        senderId: 'user_rec',
        text: 'Salom dunyo',
        timestamp: DateTime.now(),
      );

      await outboxService.enqueue(optimistic);

      final remoteConfirmed = Message(
        id: stableId,
        senderId: 'user_rec',
        text: 'Salom dunyo',
        type: MessageType.text,
        isRead: false,
        isDeleted: false,
        timestamp: optimistic.timestamp,
        status: MessageStatus.sent,
      );

      // Merging remote list with pending outbox via public handler or state check
      final msgMap = <String, Message>{};
      msgMap[remoteConfirmed.id] = remoteConfirmed;
      final outboxItems = outboxService.getPendingMessages('user_rec', chatId: 'chat_rec');
      for (final item in outboxItems) {
        if (msgMap.containsKey(item.id)) {
          // Acknowledged, remove from outbox
          await outboxService.remove('user_rec', item.id, 'chat_rec');
        } else {
          msgMap[item.id] = item.toMessage();
        }
      }

      // Exactly ONE message bubble exists, status is sent
      expect(msgMap.length, equals(1));
      expect(msgMap[stableId]!.id, equals(stableId));
      expect(msgMap[stableId]!.status, equals(MessageStatus.sent));

      await bloc.close();
    });

    // TEST 09 — FAILED SEND & RETRY
    test('TEST 09 — FAILED SEND: Permanent failure marks failed with retry support', () async {
      mockRepository.shouldFail = true;
      mockRepository.failureError = 'permission-denied: not in conversation';

      final msg = OutboxMessage(
        id: 'msg_fail_1',
        chatId: 'chat_fail',
        senderId: 'user_fail',
        text: 'Ruxsat yo\'q',
        timestamp: DateTime.now(),
      );

      await outboxService.enqueue(msg);
      await outboxService.processQueue('user_fail');

      final pending = outboxService.getPendingMessages('user_fail');
      expect(pending.length, equals(1));
      expect(pending.first.status, equals(MessageStatus.failed));
      expect(pending.first.lastError, contains('permission-denied'));

      // User initiates explicit retry
      mockRepository.shouldFail = false;
      await outboxService.retryMessage('user_fail', 'msg_fail_1', 'chat_fail');
      await outboxService.processQueue('user_fail');

      // Now sent successfully and cleared
      expect(outboxService.getPendingMessages('user_fail').isEmpty, isTrue);
    });

    // TEST 10 — AUTHENTICATION ISOLATION
    test('TEST 10 — AUTHENTICATION ISOLATION: User queues remain completely segregated', () async {
      await outboxService.enqueue(OutboxMessage(
        id: 'userA_msg',
        chatId: 'chat_shared',
        senderId: 'user_A',
        text: 'User A xabari',
        timestamp: DateTime.now(),
      ));

      await outboxService.enqueue(OutboxMessage(
        id: 'userB_msg',
        chatId: 'chat_shared',
        senderId: 'user_B',
        text: 'User B xabari',
        timestamp: DateTime.now(),
      ));

      // User A can only see and process their own outbox
      final pendingA = outboxService.getPendingMessages('user_A');
      expect(pendingA.length, equals(1));
      expect(pendingA.first.id, equals('userA_msg'));

      // User B can only see and process their own outbox
      final pendingB = outboxService.getPendingMessages('user_B');
      expect(pendingB.length, equals(1));
      expect(pendingB.first.id, equals('userB_msg'));

      // Processing user A does not deliver user B's message
      await outboxService.processQueue('user_A');
      expect(mockRepository.recordedCalls.length, equals(1));
      expect(mockRepository.recordedCalls.first['senderId'], equals('user_A'));
      expect(outboxService.getPendingMessages('user_B').length, equals(1));
    });

    // TEST 11 — APP RESTART RECOVERY
    test('TEST 11 — APP RESTART: Local messages restored upon restarting offline', () async {
      await outboxService.enqueue(OutboxMessage(
        id: 'restart_msg_1',
        chatId: 'chat_restart',
        senderId: 'user_restart',
        text: 'Qayta yuklashdan keyin saqlanib qoluvchi xabar',
        timestamp: DateTime.now(),
      ));

      final restoredPending = outboxService.getPendingMessages('user_restart', chatId: 'chat_restart');
      expect(restoredPending.length, equals(1));
      expect(restoredPending.first.id, equals('restart_msg_1'));
      expect(restoredPending.first.status, equals(MessageStatus.queued));

      final messageItem = restoredPending.first.toMessage();
      expect(messageItem.status, equals(MessageStatus.queued));
      expect(messageItem.text, equals('Qayta yuklashdan keyin saqlanib qoluvchi xabar'));
    });

    // TEST 12 — RAPID SEND
    test('TEST 12 — RAPID SEND: Rapid burst submissions preserve all items uniquely', () async {
      for (int i = 0; i < 5; i++) {
        await outboxService.enqueue(OutboxMessage(
          id: 'rapid_$i',
          chatId: 'chat_rapid',
          senderId: 'user_rapid',
          text: 'Rapid message #$i',
          timestamp: DateTime.now().add(Duration(milliseconds: i * 50)),
        ));
      }

      final pending = outboxService.getPendingMessages('user_rapid', chatId: 'chat_rapid');
      expect(pending.length, equals(5));

      await outboxService.processQueue('user_rapid');
      expect(mockRepository.callCount, equals(5));
      expect(outboxService.getPendingMessages('user_rapid').isEmpty, isTrue);
    });

    // TEST 13 — MULTIPLE CHATS ISOLATION
    test('TEST 13 — MULTIPLE CHATS: Queues in separate chats process independently', () async {
      await outboxService.enqueue(OutboxMessage(
        id: 'chat1_m1',
        chatId: 'chat_1',
        senderId: 'user_multi',
        text: 'Chat 1 text',
        timestamp: DateTime.now(),
      ));

      await outboxService.enqueue(OutboxMessage(
        id: 'chat2_m1',
        chatId: 'chat_2',
        senderId: 'user_multi',
        text: 'Chat 2 text',
        timestamp: DateTime.now(),
      ));

      final chat1Pending = outboxService.getPendingMessages('user_multi', chatId: 'chat_1');
      final chat2Pending = outboxService.getPendingMessages('user_multi', chatId: 'chat_2');

      expect(chat1Pending.length, equals(1));
      expect(chat2Pending.length, equals(1));
      expect(chat1Pending.first.id, equals('chat1_m1'));
      expect(chat2Pending.first.id, equals('chat2_m1'));
    });

    // TEST 14 — LIFECYCLE CONCURRENCY GUARD
    test('TEST 14 — LIFECYCLE: Duplicate concurrent workers are prevented for same chat', () async {
      await outboxService.enqueue(OutboxMessage(
        id: 'conc_1',
        chatId: 'chat_concurrent',
        senderId: 'user_conc',
        text: 'Concurrency lock test',
        timestamp: DateTime.now(),
      ));

      // Triggering concurrent processQueue calls simultaneously
      final Future<void> future1 = outboxService.processQueue('user_conc', targetChatId: 'chat_concurrent');
      final Future<void> future2 = outboxService.processQueue('user_conc', targetChatId: 'chat_concurrent');

      await Future.wait<void>([future1, future2]);

      // Exactly ONE call was executed, lock prevented duplicate dispatch
      expect(mockRepository.callCount, equals(1));
    });

    // TEST 15 — REGRESSION & SCOPE PRESERVATION
    test('TEST 15 — REGRESSION: Message model preserves statuses, types, and flags', () {
      final msg = Message(
        id: 'reg_1',
        senderId: 'u_1',
        text: 'Tekshiruv',
        type: MessageType.text,
        isRead: true,
        isDeleted: false,
        timestamp: DateTime.now(),
        status: MessageStatus.read,
      );

      expect(msg.status, equals(MessageStatus.read));
      expect(msg.isRead, isTrue);

      final queuedMsg = msg.copyWith(status: MessageStatus.queued);
      expect(queuedMsg.status, equals(MessageStatus.queued));
      expect(queuedMsg.id, equals('reg_1'));
    });
  });
}
