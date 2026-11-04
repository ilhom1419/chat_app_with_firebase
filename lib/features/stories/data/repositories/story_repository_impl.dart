import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../models/story_model.dart';

class StoryRepositoryImpl implements StoryRepository {
  final FirebaseFirestore _firestore;

  StoryRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _storiesCollection => _firestore.collection('stories');

  @override
  Stream<List<Story>> getActiveStories({String? currentUserId}) {
    if (currentUserId != null && currentUserId.trim().isNotEmpty) {
      return getRelationshipScopedStories(currentUserId.trim());
    }
    return _getLegacyActiveStories();
  }

  /// Authoritative Relationship-Scoped Story Stream.
  ///
  /// Implements the exact visibility contract:
  /// - Current user's own stories (always visible)
  /// - Stories from users with whom [currentUserId] has an active direct chat relationship
  /// - Stories from Groups [currentUserId] is currently a joined member of
  /// - Stories from Channels [currentUserId] is currently subscribed to
  ///
  /// Completely excludes:
  /// - Stories from unrelated users (even if they exist in /users or search)
  /// - Stories from Groups not joined
  /// - Stories from Channels not subscribed to
  /// - Stories from blocked users
  /// - Expired stories
  Stream<List<Story>> getRelationshipScopedStories(String currentUserId) {
    late StreamController<List<Story>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? chatsSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    final storySubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    Set<String> blockedUserIds = {};
    Set<String> directChatPartnerUids = {};
    Set<String> joinedGroupIds = {};
    Set<String> subscribedChannelIds = {};

    // Map: chunkIndex -> List<Story>
    final chunkStoriesMap = <int, List<Story>>{};

    void emitFilteredStories() {
      if (controller.isClosed) return;
      final now = DateTime.now();

      final allRawStories = <Story>[];
      for (final chunkList in chunkStoriesMap.values) {
        allRawStories.addAll(chunkList);
      }

      // Deduplicate by story ID
      final seenIds = <String>{};
      final uniqueStories = <Story>[];
      for (final s in allRawStories) {
        if (seenIds.add(s.id)) {
          uniqueStories.add(s);
        }
      }

      // Strict Defense-in-Depth fail-closed filtering
      final validStories = <Story>[];
      for (final story in uniqueStories) {
        // 1. Expiry check
        if (story.isExpired || now.isAfter(story.expiresAt)) continue;

        // 2. Blocked check
        if (blockedUserIds.contains(story.authorId)) continue;

        // 3. Authorization check
        if (story.authorId == currentUserId) {
          // Own story
          validStories.add(story);
        } else if (story.isChannel) {
          // Channel story: visible only if subscribed
          if (subscribedChannelIds.contains(story.authorId)) {
            validStories.add(story);
          }
        } else if (story.isGroup) {
          // Group story: visible only if joined member
          if (joinedGroupIds.contains(story.authorId)) {
            validStories.add(story);
          }
        } else {
          // Direct chat user story: visible only if active direct chat relationship exists
          if (directChatPartnerUids.contains(story.authorId)) {
            validStories.add(story);
          }
        }
      }

      // Sort by createdAt descending
      validStories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(validStories);
    }

    void updateStoryListeners() {
      for (final sub in storySubs) {
        sub.cancel();
      }
      storySubs.clear();
      chunkStoriesMap.clear();

      final targetAuthorIds = <String>{
        currentUserId,
        ...directChatPartnerUids,
        ...joinedGroupIds,
        ...subscribedChannelIds,
      };

      // Split into chunks of 30 for Firestore whereIn constraint
      final idList = targetAuthorIds.toList();
      final chunks = <List<String>>[];
      for (var i = 0; i < idList.length; i += 30) {
        chunks.add(idList.sublist(
          i,
          (i + 30 > idList.length) ? idList.length : i + 30,
        ));
      }

      if (chunks.isEmpty) {
        emitFilteredStories();
        return;
      }

      final now = DateTime.now();
      for (var i = 0; i < chunks.length; i++) {
        final chunkIndex = i;
        final chunk = chunks[i];

        final sub = _firestore
            .collection('stories')
            .where('authorId', whereIn: chunk)
            .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
            .snapshots()
            .listen(
          (snap) {
            final chunkList =
                snap.docs.map((doc) => StoryModel.fromFirestore(doc)).toList();
            chunkStoriesMap[chunkIndex] = chunkList;
            emitFilteredStories();
          },
          onError: (e) {
            debugPrint('Error listening to story chunk: $e');
          },
        );

        storySubs.add(sub);
      }
    }

    void onChatsUpdated(QuerySnapshot<Map<String, dynamic>> snap) {
      final newDirectPartners = <String>{};
      final newGroups = <String>{};
      final newChannels = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final isGroup = data['isGroup'] as bool? ?? false;
        final isChannel = data['isChannel'] as bool? ?? false;
        final participants = List<String>.from(data['participants'] ?? []);

        if (isGroup) {
          if (participants.contains(currentUserId)) {
            newGroups.add(doc.id);
          }
        } else if (isChannel) {
          if (participants.contains(currentUserId)) {
            newChannels.add(doc.id);
          }
        } else {
          // Direct chat: participants contains current user and the other user
          for (final p in participants) {
            if (p != currentUserId && !blockedUserIds.contains(p)) {
              newDirectPartners.add(p);
            }
          }
        }
      }

      final partnersChanged = directChatPartnerUids.length != newDirectPartners.length ||
          !directChatPartnerUids.containsAll(newDirectPartners);
      final groupsChanged = joinedGroupIds.length != newGroups.length ||
          !joinedGroupIds.containsAll(newGroups);
      final channelsChanged = subscribedChannelIds.length != newChannels.length ||
          !subscribedChannelIds.containsAll(newChannels);

      directChatPartnerUids = newDirectPartners;
      joinedGroupIds = newGroups;
      subscribedChannelIds = newChannels;

      if (partnersChanged || groupsChanged || channelsChanged || storySubs.isEmpty) {
        updateStoryListeners();
      } else {
        emitFilteredStories();
      }
    }

    void onUserUpdated(DocumentSnapshot<Map<String, dynamic>> snap) {
      if (snap.exists && snap.data() != null) {
        final newBlocked =
            Set<String>.from(snap.data()!['blockedUsers'] ?? []);
        if (newBlocked.length != blockedUserIds.length ||
            !blockedUserIds.containsAll(newBlocked)) {
          blockedUserIds = newBlocked;
          directChatPartnerUids.removeAll(blockedUserIds);
          updateStoryListeners();
        }
      }
    }

    controller = StreamController<List<Story>>.broadcast(
      onListen: () {
        userSub = _firestore
            .collection('users')
            .doc(currentUserId)
            .snapshots()
            .listen(
              onUserUpdated,
              onError: (e) =>
                  debugPrint('Error watching user for stories: $e'),
            );

        chatsSub = _firestore
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .snapshots()
            .listen(
              onChatsUpdated,
              onError: (e) =>
                  debugPrint('Error watching chats for stories: $e'),
            );
      },
      onCancel: () {
        chatsSub?.cancel();
        userSub?.cancel();
        for (final sub in storySubs) {
          sub.cancel();
        }
        storySubs.clear();
      },
    );

    return controller.stream;
  }

  Stream<List<Story>> _getLegacyActiveStories() {
    final now = DateTime.now();
    return _storiesCollection
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) {
      final stories = snapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc))
          .toList();
      stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return stories;
    });
  }

  @override
  Stream<List<Story>> getUserStories(String authorId) {
    final now = DateTime.now();
    return _storiesCollection
        .where('authorId', isEqualTo: authorId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: false)
        .snapshots()
        .map((snapshot) {
      final stories = snapshot.docs
          .map((doc) => StoryModel.fromFirestore(doc))
          .toList();
      stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return stories;
    });
  }

  @override
  Future<String> createStory({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    bool isChannel = false,
    bool isGroup = false,
    String? mediaUrl,
    String? caption,
    String? textContent,
    int gradientIndex = 0,
    Duration duration = const Duration(hours: 24),
  }) async {
    final docRef = _storiesCollection.doc();
    final now = DateTime.now();
    final expiresAt = now.add(duration);

    final story = StoryModel(
      id: docRef.id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      isChannel: isChannel,
      isGroup: isGroup,
      mediaUrl: mediaUrl,
      caption: caption,
      textContent: textContent,
      gradientIndex: gradientIndex,
      createdAt: now,
      expiresAt: expiresAt,
      viewersData: const {},
      reactions: const {},
    );

    await docRef.set(story.toJson());
    return docRef.id;
  }

  @override
  Future<void> markStoryAsViewed({
    required String storyId,
    required String userId,
    required String userName,
    String? userPhoto,
  }) async {
    final docRef = _storiesCollection.doc(storyId);
    final viewer = StoryViewer(
      userId: userId,
      userName: userName,
      userPhoto: userPhoto,
      viewedAt: DateTime.now(),
    );

    await docRef.update({
      'viewersData.$userId': viewer.toMap(),
    });
  }

  @override
  Future<void> reactToStory({
    required String storyId,
    required String userId,
    required String userName,
    String? userPhoto,
    required String emoji,
  }) async {
    final docRef = _storiesCollection.doc(storyId);
    final viewer = StoryViewer(
      userId: userId,
      userName: userName,
      userPhoto: userPhoto,
      viewedAt: DateTime.now(),
      reaction: emoji,
    );

    await docRef.update({
      'reactions.$userId': emoji,
      'viewersData.$userId': viewer.toMap(),
    });
  }

  @override
  Future<void> deleteStory(String storyId) async {
    await _storiesCollection.doc(storyId).delete();
  }
}
