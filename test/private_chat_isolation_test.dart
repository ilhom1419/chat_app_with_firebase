import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/messages/domain/entities/outbox_message.dart';
import 'package:chat_app/features/messages/domain/repositories/message_repository.dart';
import 'package:chat_app/features/messages/data/services/offline_outbox_service.dart';
import 'package:chat_app/features/messages/presentation/bloc/message_bloc.dart';
import 'package:chat_app/features/messages/presentation/bloc/message_event.dart';
import 'package:chat_app/features/messages/presentation/bloc/message_state.dart';
import 'package:chat_app/features/chats/domain/entities/chat.dart';
import 'package:chat_app/features/chats/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chats/presentation/bloc/chat_list_bloc.dart';
import 'package:chat_app/features/chats/presentation/bloc/chat_list_event.dart';
import 'package:chat_app/features/chats/presentation/bloc/chat_list_state.dart';

class MockMessageRepository implements MessageRepository {
  final Map<String, List<Message>> storage = {};
  final Map<String, StreamController<List<Message>>> controllers = {};
  final List<Map<String, dynamic>> sentCalls = [];

  StreamController<List<Message>> _getController(String chatId) {
    return controllers.putIfAbsent(
        chatId, () => StreamController<List<Message>>.broadcast());
  }

  void seedMessages(String chatId, List<Message> messages) {
    storage[chatId] = List.from(messages);
    _getController(chatId).add(storage[chatId]!);
  }

  @override
  Stream<List<Message>> getMessages(String chatId) {
    final controller = _getController(chatId);
    // Yield current snapshot immediately on listen
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(storage[chatId] ?? []);
      }
    });
    return controller.stream;
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
    final id = messageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
    sentCalls.add({
      'messageId': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
    });

    final newMsg = Message(
      id: id,
      senderId: senderId,
      text: text,
      type: type,
      isRead: false,
      isDeleted: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    storage.putIfAbsent(chatId, () => []).add(newMsg);
    _getController(chatId).add(List.from(storage[chatId]!));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockChatRepository implements ChatRepository {
  final Map<String, List<Chat>> userChats = {};
  final Map<String, StreamController<List<Chat>>> controllers = {};

  StreamController<List<Chat>> _getController(String userId) {
    return controllers.putIfAbsent(
        userId, () => StreamController<List<Chat>>.broadcast());
  }

  void seedChats(String userId, List<Chat> chats) {
    userChats[userId] = List.from(chats);
    _getController(userId).add(userChats[userId]!);
  }

  @override
  Stream<List<Chat>> getChats(String currentUserId) {
    final controller = _getController(currentUserId);
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(userChats[currentUserId] ?? []);
      }
    });
    return controller.stream;
  }

  @override
  Future<String> createOrGetChat(String currentUserId, String otherUserId) async {
    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      throw ArgumentError('currentUserId and otherUserId must not be empty');
    }
    final ids = [currentUserId, otherUserId]..sort();
    return ids.join('_');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userA = 'user_a_men';
  const userB = 'user_b_anna';
  const userC = 'user_c_alla';

  late MockMessageRepository mockMessageRepo;
  late MockChatRepository mockChatRepo;
  late OfflineOutboxService outboxService;
  late MessageBloc messageBloc;
  late ChatListBloc chatListBloc;

  setUp(() {
    mockMessageRepo = MockMessageRepository();
    mockChatRepo = MockChatRepository();
    outboxService = OfflineOutboxService(messageRepository: mockMessageRepo);
    messageBloc = MessageBloc(
      messageRepository: mockMessageRepo,
      outboxService: outboxService,
    );
    chatListBloc = ChatListBloc(chatRepository: mockChatRepo);
  });

  tearDown(() async {
    await messageBloc.close();
    await chatListBloc.close();
  });

  group('Canonical Conversation Identity & Resolution', () {
    test('TEST 07 & 08: Deterministic canonical pair IDs and symmetric resolution', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatBA = await mockChatRepo.createOrGetChat(userB, userA);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);
      final chatBC = await mockChatRepo.createOrGetChat(userB, userC);

      // A -> B and B -> A resolve to the EXACT SAME conversation
      expect(chatAB, equals(chatBA));

      // Different participant pairs produce strictly isolated conversations
      expect(chatAB, isNot(equals(chatAC)));
      expect(chatAB, isNot(equals(chatBC)));
      expect(chatAC, isNot(equals(chatBC)));

      expect(chatAB, contains(userA));
      expect(chatAB, contains(userB));
      expect(chatAC, contains(userA));
      expect(chatAC, contains(userC));
    });

    test('TEST 08b: Rejects empty or invalid participant IDs', () async {
      expect(() => mockChatRepo.createOrGetChat('', userB), throwsArgumentError);
      expect(() => mockChatRepo.createOrGetChat(userA, ''), throwsArgumentError);
    });
  });

  group('Three-User Private Message Routing Isolation', () {
    test('TEST 01, 02, 03: Message A -> B is strictly absent from A <-> C and B <-> C', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);
      final chatBC = await mockChatRepo.createOrGetChat(userB, userC);

      await mockMessageRepo.sendMessage(
        chatId: chatAB,
        senderId: userA,
        text: 'Salom Anna',
      );

      // Visible in A <-> B
      final msgsAB = mockMessageRepo.storage[chatAB] ?? [];
      expect(msgsAB.length, equals(1));
      expect(msgsAB.first.text, equals('Salom Anna'));
      expect(msgsAB.first.senderId, equals(userA));

      // Strictly absent from A <-> C
      final msgsAC = mockMessageRepo.storage[chatAC] ?? [];
      expect(msgsAC.isEmpty, isTrue);

      // Strictly absent from B <-> C
      final msgsBC = mockMessageRepo.storage[chatBC] ?? [];
      expect(msgsBC.isEmpty, isTrue);
    });

    test('TEST 04, 05: Message B -> C is visible only to B <-> C and absent from User A', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);
      final chatBC = await mockChatRepo.createOrGetChat(userB, userC);

      await mockMessageRepo.sendMessage(
        chatId: chatBC,
        senderId: userB,
        text: 'Salom Alla',
      );

      // Visible in B <-> C
      final msgsBC = mockMessageRepo.storage[chatBC] ?? [];
      expect(msgsBC.length, equals(1));
      expect(msgsBC.first.text, equals('Salom Alla'));
      expect(msgsBC.first.senderId, equals(userB));

      // Absent from A <-> B and A <-> C
      expect(mockMessageRepo.storage[chatAB] ?? [], isEmpty);
      expect(mockMessageRepo.storage[chatAC] ?? [], isEmpty);
    });

    test('TEST 06: Message A -> C is visible only in A <-> C and absent from Anna (B)', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);

      await mockMessageRepo.sendMessage(
        chatId: chatAC,
        senderId: userA,
        text: 'Salom Alla from Men',
      );

      final msgsAC = mockMessageRepo.storage[chatAC] ?? [];
      expect(msgsAC.length, equals(1));
      expect(msgsAC.first.text, equals('Salom Alla from Men'));

      // Anna's conversation with A remains completely empty
      expect(mockMessageRepo.storage[chatAB] ?? [], isEmpty);
    });
  });

  group('Realtime Bloc Isolation & Rapid Navigation Switching', () {
    test('TEST 09, 10, 11: Rapidly switching between Anna and Alla does NOT mix message states', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);

      mockMessageRepo.seedMessages(chatAB, [
        Message(
          id: 'msg_anna_1',
          senderId: userA,
          text: 'Xabar Annaga',
          type: MessageType.text,
          isRead: true,
          timestamp: DateTime.now(),
        ),
      ]);

      mockMessageRepo.seedMessages(chatAC, [
        Message(
          id: 'msg_alla_1',
          senderId: userA,
          text: 'Xabar Allaga',
          type: MessageType.text,
          isRead: true,
          timestamp: DateTime.now(),
        ),
      ]);

      // 1. Open Anna's chat
      messageBloc.add(LoadMessages(chatAB, currentUserId: userA));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(messageBloc.state, isA<MessageLoaded>());
      var stateLoaded = messageBloc.state as MessageLoaded;
      expect(stateLoaded.chatId, equals(chatAB));
      expect(stateLoaded.messages.first.text, equals('Xabar Annaga'));

      // 2. Switch rapidly to Alla's chat
      messageBloc.add(LoadMessages(chatAC, currentUserId: userA));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(messageBloc.state, isA<MessageLoaded>());
      stateLoaded = messageBloc.state as MessageLoaded;
      expect(stateLoaded.chatId, equals(chatAC));
      expect(stateLoaded.messages.first.text, equals('Xabar Allaga'));

      // 3. Late arriving event on Anna's conversation must NOT pollute Alla's active state
      mockMessageRepo.seedMessages(chatAB, [
        Message(
          id: 'msg_anna_2',
          senderId: userB,
          text: 'Anna javobi',
          type: MessageType.text,
          isRead: true,
          timestamp: DateTime.now(),
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 10));

      // Alla's state MUST remain isolated to chatAC
      stateLoaded = messageBloc.state as MessageLoaded;
      expect(stateLoaded.chatId, equals(chatAC));
      expect(stateLoaded.messages.any((m) => m.text == 'Anna javobi'), isFalse);
      expect(stateLoaded.messages.first.text, equals('Xabar Allaga'));
    });

    test('TEST 11b: LeaveChat event cleanly resets conversation state', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      messageBloc.add(LoadMessages(chatAB, currentUserId: userA));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(messageBloc.state, isA<MessageLoaded>());

      // User exits chat page
      messageBloc.add(LeaveChat(chatAB));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(messageBloc.state, isA<MessageInitial>());
    });
  });

  group('Offline Outbox Destination Immutability', () {
    test('TEST 14 & 15: Outbox queue retains immutable destination across chat navigation', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);

      final msgForB = OutboxMessage(
        id: 'outbox_b_1',
        chatId: chatAB,
        senderId: userA,
        text: 'Salom Anna offline',
        timestamp: DateTime.now(),
      );

      final msgForC = OutboxMessage(
        id: 'outbox_c_1',
        chatId: chatAC,
        senderId: userA,
        text: 'Salom Alla offline',
        timestamp: DateTime.now().add(const Duration(milliseconds: 10)),
      );

      // Enqueue both messages while offline
      await outboxService.enqueue(msgForB);
      await outboxService.enqueue(msgForC);

      // Verify pending messages are scoped strictly by conversation
      final pendingB = outboxService.getPendingMessages(userA, chatId: chatAB);
      expect(pendingB.length, equals(1));
      expect(pendingB.first.id, equals('outbox_b_1'));
      expect(pendingB.first.chatId, equals(chatAB));

      final pendingC = outboxService.getPendingMessages(userA, chatId: chatAC);
      expect(pendingC.length, equals(1));
      expect(pendingC.first.id, equals('outbox_c_1'));
      expect(pendingC.first.chatId, equals(chatAC));

      // Process queue (connectivity returned)
      await outboxService.processQueue(userA);

      // Verify each message delivered ONLY to its intended conversation
      expect(mockMessageRepo.sentCalls.length, equals(2));
      final callForB = mockMessageRepo.sentCalls.firstWhere((c) => c['messageId'] == 'outbox_b_1');
      expect(callForB['chatId'], equals(chatAB));
      expect(callForB['text'], equals('Salom Anna offline'));

      final callForC = mockMessageRepo.sentCalls.firstWhere((c) => c['messageId'] == 'outbox_c_1');
      expect(callForC['chatId'], equals(chatAC));
      expect(callForC['text'], equals('Salom Alla offline'));
    });

    test('TEST 17: Retrying a failed message delivers only to its original conversation', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final failedMsg = OutboxMessage(
        id: 'failed_b_1',
        chatId: chatAB,
        senderId: userA,
        text: 'Qayta yuboriladigan xabar',
        timestamp: DateTime.now(),
        status: MessageStatus.failed,
      );

      await outboxService.enqueue(failedMsg);
      await outboxService.retryMessage(userA, 'failed_b_1', chatAB);

      final retryCall = mockMessageRepo.sentCalls.last;
      expect(retryCall['messageId'], equals('failed_b_1'));
      expect(retryCall['chatId'], equals(chatAB));
    });
  });

  group('Account Isolation & Sign-out Cache Purge', () {
    test('TEST 18: Logout clears ChatListBloc preventing data exposure to new account', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);

      mockChatRepo.seedChats(userA, [
        Chat(
          id: chatAB,
          participantIds: const [userA, userB],
          otherUserId: userB,
          otherUserName: 'Anna',
          otherUserIsOnline: false,
          lastMessage: 'Shaxsiy sir',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
        ),
      ]);

      // User A loads chats
      chatListBloc.add(LoadChats(userA));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(chatListBloc.state, isA<ChatListLoaded>());
      final loadedA = chatListBloc.state as ChatListLoaded;
      expect(loadedA.chats.first.otherUserName, equals('Anna'));

      // User A logs out
      chatListBloc.add(ClearChats());
      messageBloc.add(const LeaveChat(''));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(chatListBloc.state, isA<ChatListInitial>());
      expect(messageBloc.state, isA<MessageInitial>());

      // User B logs in
      mockChatRepo.seedChats(userB, []);
      chatListBloc.add(LoadChats(userB));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(chatListBloc.state, isA<ChatListLoaded>());
      final loadedB = chatListBloc.state as ChatListLoaded;
      expect(loadedB.chats.isEmpty, isTrue);
    });

    test('TEST 19: Queued outbox messages are strictly scoped by sender UID', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      await outboxService.enqueue(OutboxMessage(
        id: 'a_secret_msg',
        chatId: chatAB,
        senderId: userA,
        text: 'User A confidential',
        timestamp: DateTime.now(),
      ));

      // User B must NEVER see or process User A's outbox messages
      final pendingForB = outboxService.getPendingMessages(userB);
      expect(pendingForB, isEmpty);

      final pendingForA = outboxService.getPendingMessages(userA);
      expect(pendingForA.length, equals(1));
      expect(pendingForA.first.id, equals('a_secret_msg'));
    });
  });

  group('Message Reconciliation & Optimistic State Integrity', () {
    test('TEST 27: Optimistic message append is strictly bound to active matching chatId', () async {
      final chatAB = await mockChatRepo.createOrGetChat(userA, userB);
      final chatAC = await mockChatRepo.createOrGetChat(userA, userC);

      // Active in chatAC (Alla)
      messageBloc.add(LoadMessages(chatAC, currentUserId: userA));
      await Future.delayed(const Duration(milliseconds: 10));

      // Dispatch send message targeting chatAB (Anna)
      messageBloc.add(SendTextMessage(
        messageId: 'opt_msg_b',
        chatId: chatAB,
        senderId: userA,
        text: 'Anna uchun matn',
      ));
      await Future.delayed(const Duration(milliseconds: 10));

      // Active state for Alla MUST NOT contain the optimistic message intended for Anna
      final activeState = messageBloc.state as MessageLoaded;
      expect(activeState.chatId, equals(chatAC));
      expect(activeState.messages.any((m) => m.id == 'opt_msg_b'), isFalse);
    });
  });
}
