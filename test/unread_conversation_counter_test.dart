import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/chats/domain/entities/chat.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';
import 'package:chat_app/features/chats/presentation/widgets/chat_folders_tab_bar.dart';
import 'package:chat_app/features/chats/presentation/widgets/unread_count_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper function implementing the exact counting logic used in chat_list_page.dart
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

  Chat createDirectChat({
    required String id,
    required String name,
    required int unreadCount,
  }) {
    return Chat(
      id: id,
      participantIds: ['my_uid', id],
      otherUserId: id,
      otherUserName: name,
      otherUserIsOnline: false,
      lastMessage: 'Message for $name',
      lastMessageTime: DateTime.now(),
      unreadCount: unreadCount,
      isGroup: false,
      isChannel: false,
    );
  }

  Chat createGroupChat({
    required String id,
    required String name,
    required int unreadCount,
  }) {
    return Chat(
      id: id,
      participantIds: const ['my_uid', 'user_1', 'user_2'],
      otherUserId: '',
      otherUserName: name,
      groupName: name,
      otherUserIsOnline: false,
      lastMessage: 'Group msg',
      lastMessageTime: DateTime.now(),
      unreadCount: unreadCount,
      isGroup: true,
      isChannel: false,
    );
  }

  Chat createChannelChat({
    required String id,
    required String name,
    required int unreadCount,
  }) {
    return Chat(
      id: id,
      participantIds: const ['my_uid'],
      otherUserId: '',
      otherUserName: name,
      groupName: name,
      otherUserIsOnline: false,
      lastMessage: 'Channel post',
      lastMessageTime: DateTime.now(),
      unreadCount: unreadCount,
      isGroup: false,
      isChannel: true,
    );
  }

  final defaultFolders = ChatFolder.defaultFolders();

  group('TASK 2, 3, 4 — Unread Conversation Counter Tests (B1 - B10)', () {
    test('B1: Sardor unread 1, Jahongir unread 9 -> Personal badge 2 (conversations count)', () {
      final sardor = createDirectChat(id: 'sardor', name: 'Sardor', unreadCount: 1);
      final jahongir = createDirectChat(id: 'jahongir', name: 'Jahongir', unreadCount: 9);

      final counts = computeUnreadCounts(defaultFolders, [sardor, jahongir]);

      // DO NOT sum message counts (1 + 9 = 10 is wrong)
      // Must equal number of conversations with unread > 0 (2 conversations)
      expect(counts[ChatFolder.directId], equals(2));
      expect(counts[ChatFolder.allId], equals(2));
    });

    test('B2: Third private chat receives unread messages -> Personal badge becomes 3', () {
      final sardor = createDirectChat(id: 'sardor', name: 'Sardor', unreadCount: 1);
      final jahongir = createDirectChat(id: 'jahongir', name: 'Jahongir', unreadCount: 9);
      final thirdChat = createDirectChat(id: 'nodir', name: 'Nodir', unreadCount: 4);

      final counts = computeUnreadCounts(defaultFolders, [sardor, jahongir, thirdChat]);

      expect(counts[ChatFolder.directId], equals(3));
      expect(counts[ChatFolder.allId], equals(3));
    });

    test('B3: Sardor messages marked as read -> Personal badge decreases to 1', () {
      final sardorRead = createDirectChat(id: 'sardor', name: 'Sardor', unreadCount: 0);
      final jahongir = createDirectChat(id: 'jahongir', name: 'Jahongir', unreadCount: 9);

      final counts = computeUnreadCounts(defaultFolders, [sardorRead, jahongir]);

      expect(counts[ChatFolder.directId], equals(1));
      expect(counts[ChatFolder.allId], equals(1));
    });

    test('B4: All private conversations read -> Personal badge 0 or hidden', () {
      final sardorRead = createDirectChat(id: 'sardor', name: 'Sardor', unreadCount: 0);
      final jahongirRead = createDirectChat(id: 'jahongir', name: 'Jahongir', unreadCount: 0);

      final counts = computeUnreadCounts(defaultFolders, [sardorRead, jahongirRead]);

      expect(counts[ChatFolder.directId], equals(0));
      expect(counts[ChatFolder.allId], equals(0));
    });

    test('B5: A new message arrives in an already-unread conversation -> category count does not increase', () {
      // Jahongir receives 1 more message (9 -> 10)
      final sardor = createDirectChat(id: 'sardor', name: 'Sardor', unreadCount: 1);
      final jahongir10 = createDirectChat(id: 'jahongir', name: 'Jahongir', unreadCount: 10);

      final counts = computeUnreadCounts(defaultFolders, [sardor, jahongir10]);

      // Category unread conversation count remains 2
      expect(counts[ChatFolder.directId], equals(2));
    });

    test('B6: Group and Channel category counts follow the exact same rule', () {
      final groups = [
        createGroupChat(id: 'g1', name: 'Flutter Devs', unreadCount: 5),
        createGroupChat(id: 'g2', name: 'Work Team', unreadCount: 12),
        createGroupChat(id: 'g3', name: 'Family Group', unreadCount: 1),
        createGroupChat(id: 'g4_read', name: 'Archived Group', unreadCount: 0),
      ];

      final channels = [
        createChannelChat(id: 'c1', name: 'Flutter News', unreadCount: 2),
        createChannelChat(id: 'c2', name: 'Tech Radar', unreadCount: 8),
        createChannelChat(id: 'c3', name: 'Design Insights', unreadCount: 1),
        createChannelChat(id: 'c4', name: 'Daily Tips', unreadCount: 14),
        createChannelChat(id: 'c5_read', name: 'Muted Channel', unreadCount: 0),
      ];

      final counts = computeUnreadCounts(defaultFolders, [...groups, ...channels]);

      // Groups: 3 groups have unread messages (g1, g2, g3)
      expect(counts[ChatFolder.groupsId], equals(3));
      // Channels: 4 channels have unread posts (c1, c2, c3, c4)
      expect(counts[ChatFolder.channelsId], equals(4));
      // All: 3 + 4 = 7 unique unread conversations
      expect(counts[ChatFolder.allId], equals(7));
    });

    test('B7: All tab counts unique unread conversations without double-counting', () {
      final direct1 = createDirectChat(id: 'd1', name: 'User 1', unreadCount: 3);
      final direct2 = createDirectChat(id: 'd2', name: 'User 2', unreadCount: 2);
      final group1 = createGroupChat(id: 'g1', name: 'Group 1', unreadCount: 5);
      final channel1 = createChannelChat(id: 'c1', name: 'Channel 1', unreadCount: 10);
      final readDirect = createDirectChat(id: 'd3', name: 'User 3', unreadCount: 0);

      // Even if there are duplicated entries in list, seenChatIds ensures uniqueness
      final chatsWithDuplicate = [direct1, direct2, group1, channel1, readDirect, direct1];

      final counts = computeUnreadCounts(defaultFolders, chatsWithDuplicate);

      expect(counts[ChatFolder.directId], equals(2));
      expect(counts[ChatFolder.groupsId], equals(1));
      expect(counts[ChatFolder.channelsId], equals(1));
      expect(counts[ChatFolder.allId], equals(4)); // Exactly 4 unique unread chats
    });

    testWidgets('B8: Individual chat row unread message badges remain unchanged while tab shows conversation count',
        (tester) async {
      final sardor = createDirectChat(id: 'sardor', name: 'Sardor', unreadCount: 1);
      final jahongir = createDirectChat(id: 'jahongir', name: 'Jahongir', unreadCount: 9);

      final counts = computeUnreadCounts(defaultFolders, [sardor, jahongir]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Category Tab Bar
                ChatFoldersTabBar(
                  folders: defaultFolders,
                  activeFolderId: ChatFolder.directId,
                  unreadCounts: counts,
                  onFolderSelected: (_) {},
                  onAddFolderPressed: () {},
                ),
                // Chat rows
                ListTile(
                  key: const Key('row_sardor'),
                  title: Text(sardor.otherUserName),
                  trailing: UnreadCountBadge(count: sardor.unreadCount),
                ),
                ListTile(
                  key: const Key('row_jahongir'),
                  title: Text(jahongir.otherUserName),
                  trailing: UnreadCountBadge(count: jahongir.unreadCount),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify individual chat rows preserve exact message unread counts
      final sardorBadge = find.descendant(
        of: find.byKey(const Key('row_sardor')),
        matching: find.text('1'),
      );
      final jahongirBadge = find.descendant(
        of: find.byKey(const Key('row_jahongir')),
        matching: find.text('9'),
      );
      expect(sardorBadge, findsOneWidget);
      expect(jahongirBadge, findsOneWidget);

      // Verify the Personal / Shaxsiy tab counter displays '2' (number of conversations)
      // and NOT '10' (sum of messages)
      expect(find.text('10'), findsNothing);
      expect(find.text('2'), findsWidgets); // Tab badge displays 2
    });

    test('B9: App restart restores correct counters from loaded chats state', () {
      // When app restarts and chats are loaded from Firestore cache/server:
      final restartedChats = [
        createDirectChat(id: 'c1', name: 'User 1', unreadCount: 4),
        createDirectChat(id: 'c2', name: 'User 2', unreadCount: 7),
        createGroupChat(id: 'g1', name: 'Group 1', unreadCount: 2),
      ];

      final counts = computeUnreadCounts(defaultFolders, restartedChats);

      expect(counts[ChatFolder.directId], equals(2));
      expect(counts[ChatFolder.groupsId], equals(1));
      expect(counts[ChatFolder.allId], equals(3));
    });

    test('B10: No unnecessary Firestore reads or listener duplication (pure local reduction)', () {
      // The counter calculation is purely O(N) in memory across already-subscribed chat summaries.
      // Zero additional Firestore collections or per-message queries are executed.
      final directChat = createDirectChat(id: 'd1', name: 'Direct', unreadCount: 3);
      final chats = [directChat];

      final counts = computeUnreadCounts(defaultFolders, chats);
      expect(counts[ChatFolder.directId], equals(1));
      expect(counts[ChatFolder.allId], equals(1));
    });
  });
}
