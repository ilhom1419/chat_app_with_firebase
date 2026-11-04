import '../entities/story.dart';

abstract class StoryRepository {
  /// Returns relationship-scoped active stories for [currentUserId].
  ///
  /// If [currentUserId] is provided, returns ONLY stories from entities with whom
  /// [currentUserId] has an active authorized relationship:
  /// - Current user's own stories
  /// - Users with whom current user has an active direct/private chat
  /// - Groups current user has joined
  /// - Channels current user has subscribed to
  /// Excludes unrelated users, unjoined groups, unsubscribed channels, blocked users, and expired stories.
  Stream<List<Story>> getActiveStories({String? currentUserId});

  Stream<List<Story>> getUserStories(String authorId);

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
  });

  Future<void> markStoryAsViewed({
    required String storyId,
    required String userId,
    required String userName,
    String? userPhoto,
  });

  Future<void> reactToStory({
    required String storyId,
    required String userId,
    required String userName,
    String? userPhoto,
    required String emoji,
  });

  Future<void> deleteStory(String storyId);
}
