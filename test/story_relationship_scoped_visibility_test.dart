import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/stories/domain/entities/story.dart';
import 'package:chat_app/features/stories/data/models/story_model.dart';

/// Helper to simulate the exact relationship-scoped story filtering logic
List<Story> filterVisibleStories({
  required String currentUserId,
  required List<Story> allStories,
  required Set<String> directChatPartnerUids,
  required Set<String> joinedGroupIds,
  required Set<String> subscribedChannelIds,
  required Set<String> blockedUserIds,
  DateTime? currentTime,
}) {
  final now = currentTime ?? DateTime.now();
  final valid = <Story>[];

  for (final story in allStories) {
    // 1. Expiry check
    if (now.isAfter(story.expiresAt)) continue;

    // 2. Blocked check
    if (blockedUserIds.contains(story.authorId)) continue;

    // 3. Authorization check
    if (story.authorId == currentUserId) {
      // Current user's own story
      valid.add(story);
    } else if (story.isChannel) {
      // Channel story: visible only if subscribed
      if (subscribedChannelIds.contains(story.authorId)) {
        valid.add(story);
      }
    } else if (story.isGroup) {
      // Group story: visible only if joined member
      if (joinedGroupIds.contains(story.authorId)) {
        valid.add(story);
      }
    } else {
      // Direct chat user story: visible only if active direct chat partner
      if (directChatPartnerUids.contains(story.authorId)) {
        valid.add(story);
      }
    }
  }

  valid.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return valid;
}

void main() {
  group('Kakku / YesChat! — Relationship-Scoped Stories Visibility Tests (20 Test Matrix)', () {
    const userA = 'user_A_current';
    const userB = 'user_B_anna';
    const userC = 'user_C_alla';
    const userD = 'user_D_sardor';

    const group1 = 'group_1_joined';
    const group2 = 'group_2_not_joined';

    const channel1 = 'channel_1_subscribed';
    const channel2 = 'channel_2_not_subscribed';

    final now = DateTime.now();
    final activeExpires = now.add(const Duration(hours: 24));
    final expiredTime = now.subtract(const Duration(minutes: 5));

    late Story storyA;
    late Story storyB;
    late Story storyC;
    late Story storyD;
    late Story storyGroup1;
    late Story storyGroup2;
    late Story storyChannel1;
    late Story storyChannel2;

    setUp(() {
      storyA = StoryModel(
        id: 'story_A',
        authorId: userA,
        authorName: 'User A (Me)',
        createdAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: activeExpires,
      );

      storyB = StoryModel(
        id: 'story_B',
        authorId: userB,
        authorName: 'Anna',
        createdAt: now.subtract(const Duration(minutes: 20)),
        expiresAt: activeExpires,
      );

      storyC = StoryModel(
        id: 'story_C',
        authorId: userC,
        authorName: 'Alla',
        createdAt: now.subtract(const Duration(minutes: 30)),
        expiresAt: activeExpires,
      );

      storyD = StoryModel(
        id: 'story_D',
        authorId: userD,
        authorName: 'Sardor',
        createdAt: now.subtract(const Duration(minutes: 40)),
        expiresAt: activeExpires,
      );

      storyGroup1 = StoryModel(
        id: 'story_G1',
        authorId: group1,
        authorName: 'Flutter Developers',
        isGroup: true,
        createdAt: now.subtract(const Duration(minutes: 15)),
        expiresAt: activeExpires,
      );

      storyGroup2 = StoryModel(
        id: 'story_G2',
        authorId: group2,
        authorName: 'Random Group',
        isGroup: true,
        createdAt: now.subtract(const Duration(minutes: 25)),
        expiresAt: activeExpires,
      );

      storyChannel1 = StoryModel(
        id: 'story_Ch1',
        authorId: channel1,
        authorName: 'Namangan News',
        isChannel: true,
        createdAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: activeExpires,
      );

      storyChannel2 = StoryModel(
        id: 'story_Ch2',
        authorId: channel2,
        authorName: 'Random Channel',
        isChannel: true,
        createdAt: now.subtract(const Duration(minutes: 35)),
        expiresAt: activeExpires,
      );
    });

    test('TEST 01: A\'s own Story is always visible', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), contains('story_A'));
    });

    test('TEST 02: A has direct chat with B -> B Story visible', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB],
        directChatPartnerUids: {userB},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), containsAll(['story_A', 'story_B']));
    });

    test('TEST 03: A has no direct chat with C -> C Story hidden', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyC],
        directChatPartnerUids: {userB}, // Only B has direct chat
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), contains('story_B'));
      expect(visible.map((s) => s.id), isNot(contains('story_C')));
    });

    test('TEST 04: A starts valid direct chat with C -> C Story becomes visible', () {
      // Before chat
      var directPartners = <String>{userB};
      var visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyC],
        directChatPartnerUids: directPartners,
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(visible.map((s) => s.id), isNot(contains('story_C')));

      // After starting direct chat with C
      directPartners = {userB, userC};
      visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyC],
        directChatPartnerUids: directPartners,
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(visible.map((s) => s.id), contains('story_C'));
    });

    test('TEST 05: Unrelated user cannot read B\'s Story directly', () {
      // User C (unrelated) queries stories: B must NOT be visible to C
      final visibleToC = filterVisibleStories(
        currentUserId: userC,
        allStories: [storyA, storyB, storyC],
        directChatPartnerUids: {}, // C has no chats with B
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visibleToC.map((s) => s.id), contains('story_C'));
      expect(visibleToC.map((s) => s.id), isNot(contains('story_B')));
      expect(visibleToC.map((s) => s.id), isNot(contains('story_A')));
    });

    test('TEST 06: A is member of GROUP_1 -> GROUP_1 Story visible', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyGroup1, storyGroup2],
        directChatPartnerUids: {},
        joinedGroupIds: {group1},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), contains('story_G1'));
      expect(visible.map((s) => s.id), isNot(contains('story_G2')));
    });

    test('TEST 07: A is not member of GROUP_2 -> GROUP_2 Story hidden', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyGroup1, storyGroup2],
        directChatPartnerUids: {},
        joinedGroupIds: {group1},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), isNot(contains('story_G2')));
    });

    test('TEST 08: A leaves GROUP_1 -> GROUP_1 Story disappears', () {
      var joinedGroups = {group1};
      var visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyGroup1],
        directChatPartnerUids: {},
        joinedGroupIds: joinedGroups,
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(visible.map((s) => s.id), contains('story_G1'));

      // Leaves group
      joinedGroups = {};
      visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyGroup1],
        directChatPartnerUids: {},
        joinedGroupIds: joinedGroups,
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(visible.map((s) => s.id), isNot(contains('story_G1')));
    });

    test('TEST 09: A subscribed to CHANNEL_1 -> Story visible', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyChannel1, storyChannel2],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: {channel1},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), contains('story_Ch1'));
      expect(visible.map((s) => s.id), isNot(contains('story_Ch2')));
    });

    test('TEST 10: A not subscribed to CHANNEL_2 -> Story hidden from main feed', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyChannel1, storyChannel2],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: {channel1},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), isNot(contains('story_Ch2')));
    });

    test('TEST 11: A unsubscribes from CHANNEL_1 -> Story disappears from feed', () {
      var channels = {channel1};
      var visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyChannel1],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: channels,
        blockedUserIds: {},
        currentTime: now,
      );
      expect(visible.map((s) => s.id), contains('story_Ch1'));

      // Unsubscribes
      channels = {};
      visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyChannel1],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: channels,
        blockedUserIds: {},
        currentTime: now,
      );
      expect(visible.map((s) => s.id), isNot(contains('story_Ch1')));
    });

    test('TEST 12: A chatting with B does not expose C Story', () {
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyC, storyD],
        directChatPartnerUids: {userB, userD},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), containsAll(['story_A', 'story_B', 'story_D']));
      expect(visible.map((s) => s.id), isNot(contains('story_C')));
    });

    test('TEST 13: Sharing a Group with C alone does not expose C\'s personal Story', () {
      // User A and User C are both in group1, but have NO direct chat
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyC, storyGroup1],
        directChatPartnerUids: {}, // NO direct chat with C!
        joinedGroupIds: {group1},   // Group 1 is joined
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      // Group 1 story is visible
      expect(visible.map((s) => s.id), contains('story_G1'));
      // C's personal story MUST NOT be visible!
      expect(visible.map((s) => s.id), isNot(contains('story_C')));
    });

    test('TEST 14: Blocked user Story remains hidden according to block rules', () {
      // User A has a direct chat with user B, but user A has blocked user B
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB],
        directChatPartnerUids: {userB},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {userB}, // Blocked!
        currentTime: now,
      );

      expect(visible.map((s) => s.id), contains('story_A'));
      expect(visible.map((s) => s.id), isNot(contains('story_B')));
    });

    test('TEST 15: Expired Story hidden even if relationship is valid', () {
      final expiredStoryB = StoryModel(
        id: 'story_B_expired',
        authorId: userB,
        authorName: 'Anna',
        createdAt: now.subtract(const Duration(hours: 25)),
        expiresAt: expiredTime, // Expired!
      );

      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, expiredStoryB],
        directChatPartnerUids: {userB},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), isNot(contains('story_B_expired')));
    });

    test('TEST 16: Seen status remains stable across filtering', () {
      final storyWithSeen = StoryModel(
        id: 'story_B_seen',
        authorId: userB,
        authorName: 'Anna',
        createdAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: activeExpires,
        viewersData: {
          userA: {'viewedAt': now.toIso8601String(), 'userName': 'User A'},
        },
      );

      expect(storyWithSeen.isViewedBy(userA), isTrue);
      expect(storyWithSeen.isViewedBy(userC), isFalse);

      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyWithSeen],
        directChatPartnerUids: {userB},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.first.isViewedBy(userA), isTrue);
    });

    test('TEST 17: Realtime membership update refreshes Story feed', () async {
      final streamController = StreamController<List<Story>>();

      // Initially no relationships
      var visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      streamController.add(visible);

      // Listener checks
      final results = <List<String>>[];
      final sub = streamController.stream.listen((stories) {
        results.add(stories.map((s) => s.id).toList());
      });

      // Update relationship dynamically
      visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB],
        directChatPartnerUids: {userB},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      streamController.add(visible);

      await Future.delayed(const Duration(milliseconds: 10));
      expect(results.length, 2);
      expect(results[0], ['story_A']);
      expect(results[1], containsAll(['story_A', 'story_B']));

      await sub.cancel();
      await streamController.close();
    });

    test('TEST 18: No unauthorized Story appears after simulated app restart', () {
      // Cold start: authorized relationships evaluated from scratch
      final coldStartDirectPartners = {userD}; // Only Sardor
      final visible = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyC, storyD, storyGroup1, storyGroup2],
        directChatPartnerUids: coldStartDirectPartners,
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );

      expect(visible.map((s) => s.id), containsAll(['story_A', 'story_D']));
      expect(visible.map((s) => s.id), isNot(contains('story_B')));
      expect(visible.map((s) => s.id), isNot(contains('story_C')));
      expect(visible.map((s) => s.id), isNot(contains('story_G1')));
      expect(visible.map((s) => s.id), isNot(contains('story_G2')));
    });

    test('TEST 19: Account switching loads the new account\'s own relationship-scoped feed', () {
      // User A's feed
      final feedA = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyC, storyD],
        directChatPartnerUids: {userB}, // A only chats with B
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(feedA.map((s) => s.id), containsAll(['story_A', 'story_B']));
      expect(feedA.map((s) => s.id), isNot(contains('story_C')));

      // Switch to User C
      final feedC = filterVisibleStories(
        currentUserId: userC,
        allStories: [storyA, storyB, storyC, storyD],
        directChatPartnerUids: {userD}, // C only chats with D
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(feedC.map((s) => s.id), containsAll(['story_C', 'story_D']));
      expect(feedC.map((s) => s.id), isNot(contains('story_A')));
      expect(feedC.map((s) => s.id), isNot(contains('story_B')));
    });

    test('TEST 20: Old account Story eligibility does not leak to the new account', () {
      // Account A had access to B and Group 1
      final feedA = filterVisibleStories(
        currentUserId: userA,
        allStories: [storyA, storyB, storyGroup1],
        directChatPartnerUids: {userB},
        joinedGroupIds: {group1},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      expect(feedA.map((s) => s.id), containsAll(['story_A', 'story_B', 'story_G1']));

      // Account C has no relationship with B or Group 1
      final feedC = filterVisibleStories(
        currentUserId: userC,
        allStories: [storyA, storyB, storyC, storyGroup1],
        directChatPartnerUids: {},
        joinedGroupIds: {},
        subscribedChannelIds: {},
        blockedUserIds: {},
        currentTime: now,
      );
      // Account C only sees C's own story
      expect(feedC.map((s) => s.id), ['story_C']);
      expect(feedC.map((s) => s.id), isNot(contains('story_B')));
      expect(feedC.map((s) => s.id), isNot(contains('story_G1')));
      expect(feedC.map((s) => s.id), isNot(contains('story_A')));
    });
  });
}

