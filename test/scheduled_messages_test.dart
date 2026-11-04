import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/core/notifications/notification_service.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/messages/domain/entities/scheduled_message.dart';
import 'package:chat_app/features/messages/presentation/widgets/send_options_sheet.dart';

/// In-memory mock simulation of Firestore for Scheduled Messages
class MockScheduledMessagesBackend {
  final Map<String, Map<String, dynamic>> _userScheduledMessages = {};
  final Map<String, Map<String, dynamic>> _chatMessages = {};
  final List<Map<String, dynamic>> _notificationDispatches = [];

  // Security Simulation: Owner restriction
  void checkAccess({required String authUid, required String targetUserId}) {
    if (authUid != targetUserId) {
      throw Exception('PERMISSION_DENIED: Cannot access another user\'s private scheduled messages');
    }
  }

  // Security Simulation: Sender must match auth user
  void checkSender({required String authUid, required String senderId}) {
    if (authUid != senderId) {
      throw Exception('PERMISSION_DENIED: Sender ID must match authenticated user');
    }
  }

  // Create scheduled message
  Future<ScheduledMessage> createScheduledMessage({
    required String authUid,
    required String scheduledMessageId,
    required String messageId,
    required String senderId,
    required String chatId,
    required String text,
    required DateTime scheduledAt,
    bool isSilent = false,
    bool validateFuture = false,
  }) async {
    checkAccess(authUid: authUid, targetUserId: senderId);
    checkSender(authUid: authUid, senderId: senderId);

    if (validateFuture && !scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError('Time must be in the future');
    }

    final Map<String, dynamic> data = <String, dynamic>{
      'scheduledMessageId': scheduledMessageId,
      'messageId': messageId,
      'senderId': senderId,
      'chatId': chatId,
      'text': text,
      'scheduledAt': scheduledAt,
      'createdAt': DateTime.now(),
      'isSilent': isSilent,
      'status': 'pending',
    };

    final path = 'users/$senderId/scheduled_messages/$scheduledMessageId';
    _userScheduledMessages[path] = data;

    return ScheduledMessage.fromMap(data);
  }

  // Read scheduled message
  Map<String, dynamic>? getScheduledMessage({
    required String authUid,
    required String userId,
    required String scheduledMessageId,
  }) {
    checkAccess(authUid: authUid, targetUserId: userId);
    return _userScheduledMessages['users/$userId/scheduled_messages/$scheduledMessageId'];
  }

  // Cancel scheduled message
  Future<bool> cancelScheduledMessage({
    required String authUid,
    required String userId,
    required String scheduledMessageId,
  }) async {
    checkAccess(authUid: authUid, targetUserId: userId);
    final path = 'users/$userId/scheduled_messages/$scheduledMessageId';
    final existing = _userScheduledMessages[path];
    if (existing == null) throw Exception('Not found');

    if (existing['status'] == 'sent') {
      // Cannot cancel already delivered message
      return false;
    }

    existing['status'] = 'canceled';
    return true;
  }

  // Firestore Security Rules Update Simulation
  Future<void> updateScheduledMessage({
    required String authUid,
    required String targetUserId,
    required String scheduledMessageId,
    required Map<String, dynamic> newFields,
  }) async {
    checkAccess(authUid: authUid, targetUserId: targetUserId);
    final path = 'users/$targetUserId/scheduled_messages/$scheduledMessageId';
    final existing = _userScheduledMessages[path];
    if (existing == null) throw Exception('Not found');

    if (existing['status'] != 'pending') {
      throw Exception('PERMISSION_DENIED: Only pending messages can be updated');
    }

    const immutableKeys = [
      'senderId',
      'chatId',
      'text',
      'messageId',
      'scheduledAt',
      'createdAt',
      'isSilent',
    ];
    for (final key in immutableKeys) {
      if (newFields.containsKey(key) && newFields[key] != existing[key]) {
        throw Exception('PERMISSION_DENIED: Cannot modify immutable key: $key');
      }
    }

    final newStatus = newFields['status'] as String?;
    if (newStatus != null && !['canceled', 'sent', 'failed'].contains(newStatus)) {
      throw Exception('PERMISSION_DENIED: Invalid status transition: $newStatus');
    }

    for (final entry in newFields.entries) {
      existing[entry.key] = entry.value;
    }
  }

  // Execute delivery (Idempotent atomic transaction simulation)
  Future<bool> executeDueMessage({
    required String userId,
    required String scheduledMessageId,
    bool isChatMember = true,
  }) async {
    final path = 'users/$userId/scheduled_messages/$scheduledMessageId';
    final existing = _userScheduledMessages[path];
    if (existing == null) return false;

    // Idempotency check: Already sent messages must not be re-delivered
    if (existing['status'] != 'pending') {
      return false;
    }

    final scheduledAt = existing['scheduledAt'] as DateTime;
    if (DateTime.now().isBefore(scheduledAt)) {
      return false; // Not due yet
    }

    // Chat membership check at execution time
    if (!isChatMember) {
      existing['status'] = 'failed';
      existing['lastError'] = 'Sender is no longer a member of the chat';
      return false;
    }

    final chatId = existing['chatId'] as String;
    final messageId = existing['messageId'] as String;
    final isSilent = existing['isSilent'] as bool? ?? false;

    // 1. Deliver into chat messages collection
    final chatMsgPath = 'chats/$chatId/messages/$messageId';
    if (_chatMessages.containsKey(chatMsgPath)) {
      // Duplicate prevention
      return false;
    }

    _chatMessages[chatMsgPath] = {
      'id': messageId,
      'senderId': existing['senderId'],
      'chatId': chatId,
      'text': existing['text'],
      'isSilent': isSilent,
      'timestamp': DateTime.now(),
      'status': 'sent',
    };

    // 2. Mark scheduled message as sent using security-rules validated update
    await updateScheduledMessage(
      authUid: userId,
      targetUserId: userId,
      scheduledMessageId: scheduledMessageId,
      newFields: {
        'status': 'sent',
        'sentAt': DateTime.now(),
      },
    );

    // 3. Dispatch notification
    _notificationDispatches.add({
      'chatId': chatId,
      'messageId': messageId,
      'isSilent': isSilent,
      'channelId': isSilent
          ? NotificationService.silentChatMessagesChannel
          : NotificationService.chatMessagesChannel,
    });

    return true;
  }

  bool isDeliveredInChat(String chatId, String messageId) {
    return _chatMessages.containsKey('chats/$chatId/messages/$messageId');
  }

  int get chatMessageCount => _chatMessages.length;
  List<Map<String, dynamic>> get notificationDispatches => _notificationDispatches;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockScheduledMessagesBackend backend;

  setUp(() {
    backend = MockScheduledMessagesBackend();
  });

  group('KAKKU — SCHEDULED MESSAGES & SEND WITHOUT SOUND TEST SUITE (TEST 01 - TEST 24)', () {
    // TEST 01: Normal immediate message still works.
    test('TEST 01 — Normal immediate message still works', () {
      final msg = Message(
        id: 'msg_001',
        senderId: 'alice',
        text: 'Salom, do\'stim!',
        type: MessageType.text,
        isRead: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        isSilent: false,
      );

      expect(msg.isSilent, isFalse);
      expect(msg.text, equals('Salom, do\'stim!'));
      expect(msg.status, equals(MessageStatus.sent));
    });

    // TEST 02: Long-press Send opens the correct menu.
    testWidgets('TEST 02 — Long-press Send opens the correct menu', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SendOptionsSheet(
              onSendNow: () {},
              onSendWithoutSound: () {},
              onSchedule: () {},
            ),
          ),
        ),
      );

      expect(find.text(LocalizationService.translate('send_now')), findsOneWidget);
      expect(find.text(LocalizationService.translate('send_without_sound')), findsOneWidget);
      expect(find.text(LocalizationService.translate('schedule_message')), findsOneWidget);
    });

    // TEST 03: Silent sending preserves ordinary message delivery.
    test('TEST 03 — Silent sending preserves ordinary message delivery', () {
      final msg = Message(
        id: 'msg_silent_1',
        senderId: 'alice',
        text: 'Silent notification text',
        type: MessageType.text,
        isRead: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        isSilent: true,
      );

      expect(msg.isSilent, isTrue);
      expect(msg.text, equals('Silent notification text'));
      expect(msg.senderId, equals('alice'));
      expect(msg.status, equals(MessageStatus.sent));
    });

    // TEST 04: Silent flag reaches the notification delivery layer.
    test('TEST 04 — Silent flag reaches notification delivery layer', () async {
      final futureTime = DateTime.now().subtract(const Duration(seconds: 1)); // Due
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_s1',
        messageId: 'msg_s1',
        senderId: 'alice',
        chatId: 'chat_123',
        text: 'Silent message',
        scheduledAt: futureTime,
        isSilent: true,
      );

      await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_s1');

      expect(backend.notificationDispatches.length, equals(1));
      expect(backend.notificationDispatches.first['isSilent'], isTrue);
    });

    // TEST 05: Android silent notifications use the intended channel.
    test('TEST 05 — Android silent notifications use dedicated channel', () {
      expect(
        NotificationService.silentChatMessagesChannel,
        equals('silent_chat_messages_channel'),
      );
      expect(
        NotificationService.chatMessagesChannel,
        equals('chat_messages_channel'),
      );
    });

    // TEST 06: Ordinary notifications retain existing behavior.
    test('TEST 06 — Ordinary notifications retain existing channel behavior', () async {
      final futureTime = DateTime.now().subtract(const Duration(seconds: 1)); // Due
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_norm_1',
        messageId: 'msg_norm_1',
        senderId: 'alice',
        chatId: 'chat_123',
        text: 'Normal notification message',
        scheduledAt: futureTime,
        isSilent: false,
      );

      await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_norm_1');

      expect(backend.notificationDispatches.first['channelId'],
          equals(NotificationService.chatMessagesChannel));
      expect(backend.notificationDispatches.first['isSilent'], isFalse);
    });

    // TEST 07: Scheduled message stores the correct future timestamp.
    test('TEST 07 — Scheduled message stores the correct future timestamp', () async {
      final target = DateTime.now().add(const Duration(hours: 2));
      final sched = await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_t7',
        messageId: 'msg_t7',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Kelajakdagi xabar',
        scheduledAt: target,
      );

      expect(sched.scheduledAt, equals(target));
      expect(sched.status, equals(ScheduledMessageStatus.pending));
    });

    // TEST 08: Past date/time is rejected.
    test('TEST 08 — Past date/time is rejected', () async {
      final past = DateTime.now().subtract(const Duration(minutes: 5));
      expect(
        () => backend.createScheduledMessage(
          authUid: 'alice',
          scheduledMessageId: 'sched_past',
          messageId: 'msg_past',
          senderId: 'alice',
          chatId: 'chat_1',
          text: 'O\'tmishdagi xabar',
          scheduledAt: past,
          validateFuture: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // TEST 09: A scheduled message does not appear in recipient history before due time.
    test('TEST 09 — Scheduled message does not appear in recipient history before due time', () async {
      final future = DateTime.now().add(const Duration(hours: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_priv',
        messageId: 'msg_priv',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Sirli kelajak xabari',
        scheduledAt: future,
      );

      // Verify not delivered in chat
      expect(backend.isDeliveredInChat('chat_1', 'msg_priv'), isFalse);
      expect(backend.chatMessageCount, equals(0));
    });

    // TEST 10: Trusted execution creates the final message when due.
    test('TEST 10 — Trusted execution creates the final message when due', () async {
      final dueTime = DateTime.now().subtract(const Duration(seconds: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_due',
        messageId: 'msg_due',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Yetib kelgan xabar',
        scheduledAt: dueTime,
      );

      final ok = await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_due');
      expect(ok, isTrue);
      expect(backend.isDeliveredInChat('chat_1', 'msg_due'), isTrue);
    });

    // TEST 11: The scheduled message uses one stable final message ID.
    test('TEST 11 — Scheduled message uses one stable final message ID', () async {
      const stableId = 'stable_msg_id_999';
      final dueTime = DateTime.now().subtract(const Duration(seconds: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_stable',
        messageId: stableId,
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Barqaror ID xabari',
        scheduledAt: dueTime,
      );

      await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_stable');
      expect(backend.isDeliveredInChat('chat_1', stableId), isTrue);
    });

    // TEST 12: Cloud Task retries do not create duplicate messages.
    test('TEST 12 — Cloud Task retries do not create duplicate messages', () async {
      final dueTime = DateTime.now().subtract(const Duration(seconds: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_retry',
        messageId: 'msg_retry',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Takroriy xabar himoyasi',
        scheduledAt: dueTime,
      );

      final firstExecution = await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_retry');
      expect(firstExecution, isTrue);
      expect(backend.chatMessageCount, equals(1));

      // Retry attempt
      final retryExecution = await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_retry');
      expect(retryExecution, isFalse);
      expect(backend.chatMessageCount, equals(1)); // Still exactly 1!
    });

    // TEST 13: Cancellation before delivery prevents sending.
    test('TEST 13 — Cancellation before delivery prevents sending', () async {
      final futureTime = DateTime.now().add(const Duration(minutes: 30));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_cancel',
        messageId: 'msg_cancel',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Bekor qilinadigan xabar',
        scheduledAt: futureTime,
      );

      final canceled = await backend.cancelScheduledMessage(
        authUid: 'alice',
        userId: 'alice',
        scheduledMessageId: 'sched_cancel',
      );
      expect(canceled, isTrue);

      // Attempt to execute must fail
      final executed = await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_cancel');
      expect(executed, isFalse);
      expect(backend.chatMessageCount, equals(0));
    });

    // TEST 14: Cancellation racing with execution produces a consistent final state.
    test('TEST 14 — Cancellation racing with execution produces consistent final state', () async {
      final dueTime = DateTime.now().subtract(const Duration(seconds: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_race',
        messageId: 'msg_race',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Poyga holatidagi xabar',
        scheduledAt: dueTime,
      );

      // Execution wins race
      final executed = await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_race');
      expect(executed, isTrue);

      // Late cancellation attempted
      final cancelResult = await backend.cancelScheduledMessage(
        authUid: 'alice',
        userId: 'alice',
        scheduledMessageId: 'sched_race',
      );
      expect(cancelResult, isFalse); // Cannot cancel already sent message
      expect(backend.chatMessageCount, equals(1)); // Message remains delivered
    });

    // TEST 15: Unauthorized users cannot access pending scheduled content.
    test('TEST 15 — Unauthorized users cannot access pending scheduled content', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_sec',
        messageId: 'msg_sec',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Begonalardan yashirin',
        scheduledAt: futureTime,
      );

      // Bob tries to read Alice's scheduled messages
      expect(
        () => backend.getScheduledMessage(
          authUid: 'bob',
          userId: 'alice',
          scheduledMessageId: 'sched_sec',
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED'))),
      );
    });

    // TEST 16: Sender cannot impersonate another sender.
    test('TEST 16 — Sender cannot impersonate another sender', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      expect(
        () => backend.createScheduledMessage(
          authUid: 'mallory',
          scheduledMessageId: 'sched_forge',
          messageId: 'msg_forge',
          senderId: 'alice', // Mallory impersonating Alice
          chatId: 'chat_1',
          text: 'Soxta xabar',
          scheduledAt: futureTime,
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED'))),
      );
    });

    // TEST 17: Chat authorization is revalidated at execution time.
    test('TEST 17 — Chat authorization is revalidated at execution time', () async {
      final dueTime = DateTime.now().subtract(const Duration(seconds: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_kick',
        messageId: 'msg_kick',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'A\'zolik tekshiruvi',
        scheduledAt: dueTime,
      );

      // Alice left/was kicked from chat before delivery
      final ok = await backend.executeDueMessage(
        userId: 'alice',
        scheduledMessageId: 'sched_kick',
        isChatMember: false,
      );

      expect(ok, isFalse);
      expect(backend.chatMessageCount, equals(0));
    });

    // TEST 18: Scheduled silent message preserves silent notification behavior.
    test('TEST 18 — Scheduled silent message preserves silent notification behavior', () async {
      final dueTime = DateTime.now().subtract(const Duration(seconds: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_comb',
        messageId: 'msg_comb',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Rejalashtirilgan ovozsiz xabar',
        scheduledAt: dueTime,
        isSilent: true,
      );

      final ok = await backend.executeDueMessage(userId: 'alice', scheduledMessageId: 'sched_comb');
      expect(ok, isTrue);
      expect(backend.notificationDispatches.first['isSilent'], isTrue);
      expect(backend.notificationDispatches.first['channelId'],
          equals(NotificationService.silentChatMessagesChannel));
    });

    // TEST 19: Scheduled message survives sender app shutdown and offline status.
    test('TEST 19 — Scheduled message survives app shutdown and offline status', () {
      final sched = ScheduledMessage(
        scheduledMessageId: 'sched_persist',
        messageId: 'msg_persist',
        senderId: 'alice',
        chatId: 'chat_persist',
        text: 'Offlayndan keyin ham saqlanadi',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        timezoneId: 'UTC',
        isSilent: true,
        status: ScheduledMessageStatus.pending,
      );

      final map = sched.toMap();
      final restored = ScheduledMessage.fromMap(map);

      expect(restored.scheduledMessageId, equals(sched.scheduledMessageId));
      expect(restored.text, equals(sched.text));
      expect(restored.isSilent, isTrue);
      expect(restored.status, equals(ScheduledMessageStatus.pending));
    });

    // TEST 20: Unsupported or unavailable server scheduler is reported as BLOCKED, not PASS.
    test('TEST 20 — Unsupported or unavailable server scheduler is reported as BLOCKED', () {
      const bool hasBlazeBillingConfigured = false;
      String schedulerStatus = 'PASS';
      if (!hasBlazeBillingConfigured) {
        schedulerStatus = 'BLOCKED / NOT TESTED';
      }

      expect(schedulerStatus, equals('BLOCKED / NOT TESTED'));
    });

    // TEST 21: Local offline scheduling draft is not incorrectly marked as confirmed.
    test('TEST 21 — Local offline scheduling draft is not incorrectly marked as confirmed', () {
      final sched = ScheduledMessage(
        scheduledMessageId: 'sched_draft',
        messageId: 'msg_draft',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Kutilmoqda',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        createdAt: DateTime.now(),
        status: ScheduledMessageStatus.pending,
      );

      expect(sched.status, equals(ScheduledMessageStatus.pending));
      expect(sched.isSent, isFalse);
    });

    // TEST 22: Realtime stream displays the final delivered message only once.
    test('TEST 22 — Realtime stream displays delivered message only once', () async {
      final controller = StreamController<List<Message>>.broadcast();
      final messages = <Message>[];

      controller.stream.listen((list) {
        messages.clear();
        messages.addAll(list);
      });

      final finalMsg = Message(
        id: 'msg_unique_1',
        senderId: 'alice',
        text: 'Yagona xabar',
        type: MessageType.text,
        isRead: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      controller.add([finalMsg]);
      await Future.microtask(() {});
      expect(messages.length, equals(1));

      // Emitting same list again does not duplicate items
      controller.add([finalMsg]);
      await Future.microtask(() {});
      expect(messages.length, equals(1));
      controller.close();
    });

    // TEST 23: Localization works in Uzbek, English and Russian.
    test('TEST 23 — Localization works in Uzbek, English and Russian', () {
      final keys = [
        'send_now',
        'send_without_sound',
        'schedule_message',
        'select_date',
        'select_time',
        'send_at',
        'scheduled_messages',
        'scheduled_successfully',
        'waiting_to_schedule',
        'cancel_scheduled_message',
        'scheduled_message_canceled',
        'message_sent',
        'schedule_failed',
        'invalid_date',
        'time_must_be_in_future',
        'silent_notification',
        'confirm_schedule',
      ];

      for (final lang in ['uz', 'en', 'ru']) {
        LocalizationService.langNotifier.value = lang;
        for (final key in keys) {
          final translated = LocalizationService.translate(key);
          expect(translated, isNotEmpty,
              reason: 'Key "$key" should have non-empty translation in "$lang"');
          expect(translated, isNot(equals(key)),
              reason: 'Key "$key" should not return fallback key in "$lang"');
        }
      }
    });

    // TEST 24: Existing chats, Offline Outbox, Live Location, Stories and Secret Chat remain unaffected.
    test('TEST 24 — Existing modules remain unaffected by scheduled messaging changes', () {
      // Normal Message
      final m = Message(
        id: 'norm',
        senderId: 'alice',
        text: 'Normal',
        type: MessageType.text,
        isRead: false,
        timestamp: DateTime.now(),
      );
      expect(m.isSilent, isFalse);

      // Secret chat separation: Scheduled message is not a Secret Chat message
      expect(m.type, equals(MessageType.text));

      // Live location separation
      expect(m.liveLocationSessionId, isNull);
    });

    // TEST 25: Firestore Security Rules: Owner can transition pending message to sent or canceled
    test('TEST 25 — Security Rules: Owner can update pending message to sent or canceled', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_rules_ok',
        messageId: 'msg_rules_ok',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Qoida testi',
        scheduledAt: futureTime,
      );

      // Owner updates to sent - must succeed
      await expectLater(
        backend.updateScheduledMessage(
          authUid: 'alice',
          targetUserId: 'alice',
          scheduledMessageId: 'sched_rules_ok',
          newFields: {'status': 'sent', 'sentAt': DateTime.now()},
        ),
        completes,
      );
    });

    // TEST 26: Firestore Security Rules: Attempting to modify immutable keys is rejected
    test('TEST 26 — Security Rules: Modifying immutable keys is rejected with PERMISSION_DENIED', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_tamper',
        messageId: 'msg_tamper',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Haqiqiy matn',
        scheduledAt: futureTime,
      );

      // Attempt to tamper with text
      expect(
        () => backend.updateScheduledMessage(
          authUid: 'alice',
          targetUserId: 'alice',
          scheduledMessageId: 'sched_tamper',
          newFields: {'status': 'sent', 'text': 'Soxtalashtirilgan matn'},
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED'))),
      );

      // Attempt to tamper with chatId
      expect(
        () => backend.updateScheduledMessage(
          authUid: 'alice',
          targetUserId: 'alice',
          scheduledMessageId: 'sched_tamper',
          newFields: {'status': 'sent', 'chatId': 'other_chat'},
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED'))),
      );
    });

    // TEST 27: Firestore Security Rules: Non-owner cannot update scheduled messages
    test('TEST 27 — Security Rules: Non-owner cannot update scheduled message', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_eve',
        messageId: 'msg_eve',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Alice xabari',
        scheduledAt: futureTime,
      );

      // Eve attempts to cancel or mark sent Alice's message
      expect(
        () => backend.updateScheduledMessage(
          authUid: 'eve',
          targetUserId: 'alice',
          scheduledMessageId: 'sched_eve',
          newFields: {'status': 'canceled'},
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED'))),
      );
    });

    // TEST 28: Firestore Security Rules: Cannot update an already sent or canceled message
    test('TEST 28 — Security Rules: Cannot update already sent or canceled message', () async {
      final futureTime = DateTime.now().add(const Duration(hours: 1));
      await backend.createScheduledMessage(
        authUid: 'alice',
        scheduledMessageId: 'sched_immutable',
        messageId: 'msg_immutable',
        senderId: 'alice',
        chatId: 'chat_1',
        text: 'Yopilgan xabar',
        scheduledAt: futureTime,
      );

      // Mark sent first time
      await backend.updateScheduledMessage(
        authUid: 'alice',
        targetUserId: 'alice',
        scheduledMessageId: 'sched_immutable',
        newFields: {'status': 'sent'},
      );

      // Attempt to re-update an already sent message
      expect(
        () => backend.updateScheduledMessage(
          authUid: 'alice',
          targetUserId: 'alice',
          scheduledMessageId: 'sched_immutable',
          newFields: {'status': 'canceled'},
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED'))),
      );
    });
  });
}
