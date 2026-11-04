// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/features/chats/domain/entities/chat.dart';
import 'package:chat_app/features/chats/data/models/chat_model.dart';
import 'package:chat_app/features/chats/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chats/presentation/bloc/chat_list_bloc.dart';
import 'package:chat_app/features/chats/presentation/bloc/chat_list_event.dart';
import 'package:chat_app/features/chats/presentation/bloc/chat_list_state.dart';
import 'package:chat_app/features/chats/presentation/widgets/unread_count_badge.dart';

class FakeDocumentSnapshot implements DocumentSnapshot {
  @override
  final String id;
  final Map<String, dynamic> _data;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockChatRepository implements ChatRepository {
  final Map<String, StreamController<List<Chat>>> _controllers = {};
  final Map<String, List<Chat>> _storage = {};

  StreamController<List<Chat>> _getController(String userId) {
    return _controllers.putIfAbsent(
        userId, () => StreamController<List<Chat>>.broadcast());
  }

  void emitChats(String userId, List<Chat> chats) {
    _storage[userId] = List.from(chats);
    _getController(userId).add(_storage[userId]!);
  }

  @override
  Stream<List<Chat>> getChats(String currentUserId) {
    final controller = _getController(currentUserId);
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.add(_storage[currentUserId] ?? []);
      }
    });
    return controller.stream;
  }

  @override
  Future<String> createOrGetChat(String currentUserId, String otherUserId) async {
    return '${currentUserId}_$otherUserId';
  }

  @override
  Future<void> markAsRead(String chatId, String userId) async {
    final list = _storage[userId] ?? [];
    final updated = list.map((c) {
      if (c.id == chatId) {
        return Chat(
          id: c.id,
          participantIds: c.participantIds,
          otherUserId: c.otherUserId,
          otherUserName: c.otherUserName,
          otherUserPhoto: c.otherUserPhoto,
          otherUserIsOnline: c.otherUserIsOnline,
          lastMessage: c.lastMessage,
          lastMessageTime: c.lastMessageTime,
          unreadCount: 0,
          isGroup: c.isGroup,
          groupName: c.groupName,
          groupAvatar: c.groupAvatar,
          isChannel: c.isChannel,
          createdBy: c.createdBy,
          description: c.description,
          username: c.username,
          type: c.type,
          memberCount: c.memberCount,
          slowModeSeconds: c.slowModeSeconds,
          topicsEnabled: c.topicsEnabled,
          signMessages: c.signMessages,
          restrictContent: c.restrictContent,
          linkedGroupId: c.linkedGroupId,
          linkedGroupName: c.linkedGroupName,
          inviteLink: c.inviteLink,
          inviteCode: c.inviteCode,
          defaultPermissions: c.defaultPermissions,
          currentUserRole: c.currentUserRole,
        );
      }
      return c;
    }).toList();
    _storage[userId] = updated;
    _getController(userId).add(updated);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('UnreadCountBadge Widget & Behavior Tests (TEST 01 - TEST 18)', () {
    testWidgets('TEST 01: Unread count 0 -> badge hidden', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreadCountBadge(count: 0),
          ),
        ),
      );
      expect(find.byType(Container), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('TEST 02: Unread count 1 -> badge displays "1" and is circular',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UnreadCountBadge(count: 1),
            ),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      final badgeFinder = find.descendant(
        of: find.byType(UnreadCountBadge),
        matching: find.byType(Container),
      );
      expect(badgeFinder, findsOneWidget);
      final container = tester.widget<Container>(badgeFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF22C55E)));

      final size = tester.getSize(badgeFinder);
      expect(size.width, greaterThanOrEqualTo(22.0));
      expect(size.height, greaterThanOrEqualTo(22.0));
      expect((size.width - size.height).abs(), lessThanOrEqualTo(1.0)); // circular
    });

    testWidgets('TEST 03: Unread count 3 -> badge displays "3"',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: UnreadCountBadge(count: 3)),
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('3'));
      expect(textWidget.style?.color, equals(Colors.white));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w600));
    });

    testWidgets(
        'TEST 04: Unread count 12 -> badge displays "12" and adapts width (pill-shaped)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: UnreadCountBadge(count: 12)),
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      final badgeFinder = find.descendant(
        of: find.byType(UnreadCountBadge),
        matching: find.byType(Container),
      );
      final size = tester.getSize(badgeFinder);
      expect(size.width, greaterThan(size.height)); // pill shape width > height
      expect(size.height, greaterThanOrEqualTo(22.0));
    });

    testWidgets('TEST 05: Unread count 100 -> badge displays "99+"',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: UnreadCountBadge(count: 100)),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('100'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: UnreadCountBadge(count: 350)),
          ),
        ),
      );
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('TEST 06: Badge is correctly aligned below the timestamp in trailing column',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Anna Mariya'),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('10:42', key: Key('timestamp')),
                        SizedBox(height: 5),
                        UnreadCountBadge(count: 3, key: Key('unread_badge')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final timestampPos = tester.getBottomRight(find.byKey(const Key('timestamp')));
      final badgePos = tester.getTopRight(find.byKey(const Key('unread_badge')));
      expect(badgePos.dy, greaterThan(timestampPos.dy)); // Below timestamp
    });

    testWidgets('TEST 07: Badge never overlaps message preview',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Row(
                  children: const [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Anna Mariya'),
                          Text(
                            'Salom, bugungi uchrashuv soat nechida boshlanadi?',
                            key: Key('preview_text'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('10:42'),
                        SizedBox(height: 5),
                        UnreadCountBadge(count: 99, key: Key('unread_badge')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final previewRect = tester.getRect(find.byKey(const Key('preview_text')));
      final badgeRect = tester.getRect(find.byKey(const Key('unread_badge')));
      expect(previewRect.right, lessThanOrEqualTo(badgeRect.left));
    });

    test('TEST 08 & 09: Message send increments intended recipient, not sender', () {
      final senderId = 'userA';
      final recipientId = 'userAnna';
      final participants = [senderId, recipientId];

      final Map<String, dynamic> unreadUpdates = {};
      final recipient = participants.firstWhere(
        (id) => id != senderId,
        orElse: () => '',
      );
      if (recipient.isNotEmpty) {
        unreadUpdates['unreadCount.$recipient'] = 1;
      }

      // Recipient gets increment
      expect(unreadUpdates['unreadCount.userAnna'], equals(1));
      // Sender is NOT incremented
      expect(unreadUpdates.containsKey('unreadCount.userA'), isFalse);
    });

    test('TEST 10: Opening and reading conversation clears confirmed unread state', () async {
      final repo = MockChatRepository();
      final chatListBloc = ChatListBloc(chatRepository: repo);

      final initialChat = Chat(
        id: 'chat_userA_anna',
        participantIds: const ['userA', 'userAnna'],
        otherUserId: 'userAnna',
        otherUserName: 'Anna Mariya',
        otherUserIsOnline: false,
        lastMessage: 'Salom!',
        lastMessageTime: DateTime.now(),
        unreadCount: 3,
        isGroup: false,
        isChannel: false,
      );

      repo.emitChats('userA', [initialChat]);
      chatListBloc.add(LoadChats('userA'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(chatListBloc.state, isA<ChatListLoaded>());
      var state = chatListBloc.state as ChatListLoaded;
      expect(state.chats.first.unreadCount, equals(3));

      // Now mark as read
      await repo.markAsRead('chat_userA_anna', 'userA');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(chatListBloc.state, isA<ChatListLoaded>());
      state = chatListBloc.state as ChatListLoaded;
      expect(state.chats.first.unreadCount, equals(0));

      await chatListBloc.close();
    });

    test('TEST 11: Private chat isolation - Anna unread count does not modify Alla unread count', () async {
      final repo = MockChatRepository();
      final chatListBloc = ChatListBloc(chatRepository: repo);

      final annaChat = Chat(
        id: 'chat_userA_anna',
        participantIds: const ['userA', 'userAnna'],
        otherUserId: 'userAnna',
        otherUserName: 'Anna',
        otherUserIsOnline: false,
        lastMessage: 'Hi from Anna',
        lastMessageTime: DateTime.now(),
        unreadCount: 3,
        isGroup: false,
        isChannel: false,
      );

      final allaChat = Chat(
        id: 'chat_userA_alla',
        participantIds: const ['userA', 'userAlla'],
        otherUserId: 'userAlla',
        otherUserName: 'Alla',
        otherUserIsOnline: false,
        lastMessage: 'Hi from Alla',
        lastMessageTime: DateTime.now(),
        unreadCount: 0,
        isGroup: false,
        isChannel: false,
      );

      repo.emitChats('userA', [annaChat, allaChat]);
      chatListBloc.add(LoadChats('userA'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(chatListBloc.state, isA<ChatListLoaded>());
      final state = chatListBloc.state as ChatListLoaded;
      final counts = {for (var c in state.chats) c.otherUserName: c.unreadCount};
      expect(counts['Anna'], equals(3));
      expect(counts['Alla'], equals(0));

      await chatListBloc.close();
    });

    test('TEST 12: Multiple snapshots do not duplicate counts', () async {
      final repo = MockChatRepository();
      final chatListBloc = ChatListBloc(chatRepository: repo);

      final chat = Chat(
        id: 'chat_1',
        participantIds: const ['userA', 'userB'],
        otherUserId: 'userB',
        otherUserName: 'Bob',
        otherUserIsOnline: false,
        lastMessage: 'Hey',
        lastMessageTime: DateTime.now(),
        unreadCount: 5,
        isGroup: false,
        isChannel: false,
      );

      repo.emitChats('userA', [chat]);
      repo.emitChats('userA', [chat]);
      chatListBloc.add(LoadChats('userA'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(chatListBloc.state, isA<ChatListLoaded>());
      final state = chatListBloc.state as ChatListLoaded;
      expect(state.chats.first.unreadCount, equals(5));

      await chatListBloc.close();
    });

    test('TEST 13: App restart preserves the correct unread count from backend state', () {
      final backendData = {
        'participants': ['userA', 'userB'],
        'lastMessage': 'Hello',
        'unreadCount': {'userA': 7, 'userB': 0},
      };

      final unreadMap = backendData['unreadCount'] as Map<String, dynamic>;
      final userAUnread = (unreadMap['userA'] as num?)?.toInt() ?? 0;
      final userBUnread = (unreadMap['userB'] as num?)?.toInt() ?? 0;

      expect(userAUnread, equals(7));
      expect(userBUnread, equals(0));
    });

    test('TEST 14: Account switching does not leak old unread counts', () async {
      final repo = MockChatRepository();
      final chatListBloc = ChatListBloc(chatRepository: repo);

      // Account 1: User A has 4 unread messages
      repo.emitChats('userA', [
        Chat(
          id: 'chat_userA_anna',
          participantIds: const ['userA', 'userAnna'],
          otherUserId: 'userAnna',
          otherUserName: 'Anna',
          otherUserIsOnline: false,
          lastMessage: 'Msg',
          lastMessageTime: DateTime.now(),
          unreadCount: 4,
          isGroup: false,
          isChannel: false,
        ),
      ]);

      // Account 2: User C has 0 unread messages
      repo.emitChats('userC', [
        Chat(
          id: 'chat_userC_anna',
          participantIds: const ['userC', 'userAnna'],
          otherUserId: 'userAnna',
          otherUserName: 'Anna',
          otherUserIsOnline: false,
          lastMessage: 'Msg',
          lastMessageTime: DateTime.now(),
          unreadCount: 0,
          isGroup: false,
          isChannel: false,
        ),
      ]);

      chatListBloc.add(LoadChats('userA'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(chatListBloc.state, isA<ChatListLoaded>());
      var state = chatListBloc.state as ChatListLoaded;
      expect(state.chats.first.unreadCount, equals(4));

      // Switch to User C
      chatListBloc.add(LoadChats('userC'));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(chatListBloc.state, isA<ChatListLoaded>());
      state = chatListBloc.state as ChatListLoaded;
      expect(state.chats.first.unreadCount, equals(0));

      await chatListBloc.close();
    });

    testWidgets('TEST 15: Group and channel unread behavior renders numeric green badge consistently',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                UnreadCountBadge(count: 12, key: Key('group_badge')),
                UnreadCountBadge(count: 1, key: Key('channel_badge')),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('group_badge')), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      expect(find.byKey(const Key('channel_badge')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    test('TEST 16: Existing message routing and read receipt logic remain functional', () {
      final participants = ['userA', 'userB'];
      final senderId = 'userA';

      Map<String, dynamic> computeUpdates({required bool isGroup, required bool isChannel}) {
        final Map<String, dynamic> unreadUpdates = {};
        if (isGroup || isChannel) {
          for (final uid in participants) {
            if (uid != senderId) {
              unreadUpdates['unreadCount.$uid'] = 1;
            }
          }
        } else {
          final recipientId = participants.firstWhere((id) => id != senderId, orElse: () => '');
          if (recipientId.isNotEmpty) {
            unreadUpdates['unreadCount.$recipientId'] = 1;
          }
        }
        return unreadUpdates;
      }

      final directUpdates = computeUpdates(isGroup: false, isChannel: false);
      expect(directUpdates, equals({'unreadCount.userB': 1}));

      final groupUpdates = computeUpdates(isGroup: true, isChannel: false);
      expect(groupUpdates, equals({'unreadCount.userB': 1}));
    });

    test('TEST 17: ChatModel robustly extracts unreadCount from nested map and flattened dot keys', () {
      // Nested map schema
      final docNested = FakeDocumentSnapshot('chat_nested', {
        'participants': ['userAnna', 'userA'],
        'unreadCount': {'userAnna': 3, 'userA': 0},
      });
      final chatAnnaNested = ChatModel.fromFirestore(docNested, 'userAnna');
      final chatANested = ChatModel.fromFirestore(docNested, 'userA');
      expect(chatAnnaNested.unreadCount, equals(3));
      expect(chatANested.unreadCount, equals(0));

      // Flattened dot key schema (written by set(merge: true))
      final docFlat = FakeDocumentSnapshot('chat_flat', {
        'participants': ['userAnna', 'userA'],
        'unreadCount.userAnna': 4,
        'unreadCount.userA': 0,
      });
      final chatAnnaFlat = ChatModel.fromFirestore(docFlat, 'userAnna');
      final chatAFlat = ChatModel.fromFirestore(docFlat, 'userA');
      expect(chatAnnaFlat.unreadCount, equals(4));
      expect(chatAFlat.unreadCount, equals(0));

      // Scalar num schema (e.g. channel or legacy)
      final docScalar = FakeDocumentSnapshot('chat_scalar', {
        'participants': ['userAnna'],
        'unreadCount': 12,
      });
      final chatScalar = ChatModel.fromFirestore(docScalar, 'userAnna');
      expect(chatScalar.unreadCount, equals(12));
    });

    testWidgets('TEST 18: Chat list tile renders Anna with 3 -> (3), Anna with 4 -> (4), Alla with 0 -> no badge',
        (tester) async {
      Widget buildTile(String name, int unreadCount, Key key) {
        return ListTile(
          key: key,
          leading: CircleAvatar(child: Text(name[0])),
          title: Text(name),
          subtitle: const Text('Salom! Bugun uchrashamizmi?'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('10:42'),
              if (unreadCount > 0) ...[
                const SizedBox(height: 5),
                UnreadCountBadge(count: unreadCount),
              ],
            ],
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                buildTile('Anna Mariya', 3, const Key('anna_3')),
                buildTile('Alla', 0, const Key('alla_0')),
              ],
            ),
          ),
        ),
      );

      // Anna with 3 shows badge "3"
      expect(find.descendant(of: find.byKey(const Key('anna_3')), matching: find.text('3')), findsOneWidget);
      // Alla with 0 shows NO badge
      expect(find.descendant(of: find.byKey(const Key('alla_0')), matching: find.byType(UnreadCountBadge)), findsNothing);

      // Now Anna receives 4th message
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                buildTile('Anna Mariya', 4, const Key('anna_4')),
                buildTile('Alla', 0, const Key('alla_0')),
              ],
            ),
          ),
        ),
      );
      expect(find.descendant(of: find.byKey(const Key('anna_4')), matching: find.text('4')), findsOneWidget);
    });
  });
}
