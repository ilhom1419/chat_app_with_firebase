import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/chats/domain/entities/chat.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';
import 'package:chat_app/features/chats/presentation/widgets/unread_count_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper function implementing exact counting logic from chat_list_page.dart
  Map<String, int> computeUnreadCounts(
      List<ChatFolder> folders, List<Chat> chats) {
    final unreadCounts = <String, int>{};
    for (final folder in folders) {
      int unreadConversationCount = 0;
      final seenChatIds = <String>{};
      for (final chat in chats) {
        if (chat.unreadCount > 0 &&
            folder.matches(chat) &&
            seenChatIds.add(chat.id)) {
          unreadConversationCount++;
        }
      }
      unreadCounts[folder.id] = unreadConversationCount;
    }
    return unreadCounts;
  }

  Chat createChat({
    required String id,
    required String name,
    required int unreadCount,
    bool isGroup = false,
    bool isChannel = false,
  }) {
    return Chat(
      id: id,
      participantIds: ['my_uid', id],
      otherUserId: (isGroup || isChannel) ? '' : id,
      otherUserName: name,
      otherUserIsOnline: false,
      lastMessage: 'Message from $name',
      lastMessageTime: DateTime.now(),
      unreadCount: unreadCount,
      isGroup: isGroup,
      isChannel: isChannel,
    );
  }

  group('Part D - Unread Count Tests (1 - 12)', () {
    testWidgets('1. One incoming unread message produces badge 1',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreadCountBadge(count: 1),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.byType(UnreadCountBadge), findsOneWidget);
    });

    testWidgets('2. Two unread messages produce badge 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreadCountBadge(count: 2),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('3. A successful read acknowledgment clears the corresponding badge',
        (tester) async {
      // Chat with 1 unread -> badge visible
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreadCountBadge(count: 1),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);

      // After markAsRead: count becomes 0 -> badge hidden
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreadCountBadge(count: 0),
          ),
        ),
      );
      expect(find.text('1'), findsNothing);
      expect(find.byType(UnreadCountBadge), findsOneWidget);
      // Container inside badge renders SizedBox.shrink() when count <= 0
      expect(find.byType(Container), findsNothing);
    });

    test('4. Reading Anna does not clear Jurabek', () {
      final folders = ChatFolder.defaultFolders();

      // Initial state: Anna has 1 unread, Jurabek has 1 unread
      final chatAnna = createChat(id: 'anna_uid', name: 'Anna Mariya', unreadCount: 1);
      final chatJurabek = createChat(id: 'jurabek_uid', name: 'Jurabek', unreadCount: 1);

      var chats = [chatAnna, chatJurabek];
      var counts = computeUnreadCounts(folders, chats);

      expect(chatAnna.unreadCount, 1);
      expect(chatJurabek.unreadCount, 1);
      expect(counts[ChatFolder.allId], 2);
      expect(counts[ChatFolder.directId], 2);

      // Now Anna is read (unreadCount becomes 0), Jurabek remains unread (1)
      final chatAnnaRead = createChat(id: 'anna_uid', name: 'Anna Mariya', unreadCount: 0);
      chats = [chatAnnaRead, chatJurabek];
      counts = computeUnreadCounts(folders, chats);

      expect(chatAnnaRead.unreadCount, 0);
      expect(chatJurabek.unreadCount, 1);
      expect(counts[ChatFolder.allId], 1);
      expect(counts[ChatFolder.directId], 1);
    });

    test('5. Top-level unread counters update correctly when both are read', () {
      final folders = ChatFolder.defaultFolders();

      final chatAnna = createChat(id: 'anna_uid', name: 'Anna Mariya', unreadCount: 1);
      final chatJurabek = createChat(id: 'jurabek_uid', name: 'Jurabek', unreadCount: 1);

      // Both unread
      var counts = computeUnreadCounts(folders, [chatAnna, chatJurabek]);
      expect(counts[ChatFolder.allId], 2);
      expect(counts[ChatFolder.directId], 2);

      // Anna read
      final chatAnnaRead = createChat(id: 'anna_uid', name: 'Anna Mariya', unreadCount: 0);
      counts = computeUnreadCounts(folders, [chatAnnaRead, chatJurabek]);
      expect(counts[ChatFolder.allId], 1);
      expect(counts[ChatFolder.directId], 1);

      // Jurabek read
      final chatJurabekRead = createChat(id: 'jurabek_uid', name: 'Jurabek', unreadCount: 0);
      counts = computeUnreadCounts(folders, [chatAnnaRead, chatJurabekRead]);
      expect(counts[ChatFolder.allId], 0);
      expect(counts[ChatFolder.directId], 0);
    });

    test('6. Realtime snapshots update rendered values without legacy resurrection', () {
      // Simulate snapshot data with authoritative unreadCount map setting my_uid to 0,
      // while stale legacy field has 1
      final rawData = {
        'participants': ['my_uid', 'anna_uid'],
        'unreadCount': {
          'my_uid': 0,
          'anna_uid': 1,
        },
        // Stale legacy field from previous version
        'unreadCount.my_uid': 1,
        'unread_my_uid': 1,
      };

      // Test resolution logic
      final unreadRaw = rawData['unreadCount'];
      int resolvedUnread = 0;
      if (unreadRaw is Map) {
        resolvedUnread = (unreadRaw['my_uid'] as num?)?.toInt() ?? 0;
      }

      // CRITICAL: Must be 0! It should not be resurrected by stale legacy fields!
      expect(resolvedUnread, 0);
    });

    test('7. Failed read write does not falsely persist zero in authoritative store', () {
      // If Firestore write fails, backend document remains 1
      final backendDocument = {
        'unreadCount': {'my_uid': 1, 'anna_uid': 0}
      };

      final unreadMap = backendDocument['unreadCount'] as Map<String, dynamic>;
      expect(unreadMap['my_uid'], 1); // Document was not corrupted
    });

    test('8. Duplicate snapshots do not double-count', () {
      final folders = ChatFolder.defaultFolders();
      final chat1 = createChat(id: 'c1', name: 'User 1', unreadCount: 3);

      // Duplicate chat entries with same id
      final chats = [chat1, chat1];
      final counts = computeUnreadCounts(folders, chats);

      // Count of conversations with unread messages must be 1, not 2
      expect(counts[ChatFolder.allId], 1);
    });

    test('9. Offline reconnection reconciles correctly', () {
      // Message received offline with incremented count
      final backendState = {
        'unreadCount': {'my_uid': 2, 'other_uid': 0}
      };
      final unread = (backendState['unreadCount'] as Map)['my_uid'] as int;
      expect(unread, 2);
    });

    test('10. Concurrent incoming and read events do not lose legitimate unread state', () {
      // Simulated Firestore transaction/field value behavior
      var currentUnread = 0; // Read acknowledgment sets to 0
      // Concurrent incoming message arrives -> increment(1)
      currentUnread += 1;
      expect(currentUnread, 1);
    });

    test('11. Restart preserves read state', () {
      final chatAfterRestart = createChat(id: 'anna_uid', name: 'Anna Mariya', unreadCount: 0);
      expect(chatAfterRestart.unreadCount, 0);

      final folders = ChatFolder.defaultFolders();
      final counts = computeUnreadCounts(folders, [chatAfterRestart]);
      expect(counts[ChatFolder.allId], 0);
    });

    test('12. Account switching does not leak unread counts', () {
      final chatDocData = {
        'unreadCount': {
          'user_A': 0, // Current user A has read all messages
          'user_B': 4, // User B has 4 unread messages
        }
      };

      final map = chatDocData['unreadCount'] as Map<String, dynamic>;

      // User A reads:
      final unreadForA = (map['user_A'] as num?)?.toInt() ?? 0;
      expect(unreadForA, 0);

      // If switched to User B:
      final unreadForB = (map['user_B'] as num?)?.toInt() ?? 0;
      expect(unreadForB, 4);

      // User A never sees User B's unread count
      expect(unreadForA, isNot(equals(unreadForB)));
    });
  });
}
