import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../pages/story_viewer_page.dart';
import '../pages/create_story_page.dart';
import 'stories_ring.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

class StoriesTray extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;

  const StoriesTray({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  /// Factory helper for opening StoryViewerPage with smooth fade+scale transition
  static Route<void> createStoryViewerRoute({
    required List<Story> stories,
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhoto,
    int initialIndex = 0,
  }) {
    return PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) {
        return StoryViewerPage(
          stories: stories,
          initialIndex: initialIndex,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserPhoto: currentUserPhoto,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
    );
  }

  void _openStoryViewer(
    BuildContext context,
    List<Story> stories, [
    int initialIndex = 0,
  ]) {
    Navigator.of(context).push(
      createStoryViewerRoute(
        stories: stories,
        initialIndex: initialIndex,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserPhoto: currentUserPhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storyRepo = context.read<StoryRepository>();

    return StreamBuilder<List<Story>>(
      stream: storyRepo.getActiveStories(currentUserId: currentUserId),
      builder: (context, snapshot) {
        final allStories = snapshot.data ?? [];

        // Group stories by authorId
        final myStories =
            allStories.where((s) => s.authorId == currentUserId).toList();

        final otherStoriesMap = <String, List<Story>>{};
        for (final story in allStories) {
          if (story.authorId != currentUserId) {
            otherStoriesMap.putIfAbsent(story.authorId, () => []).add(story);
          }
        }

        // Sort other authors: authors with unread stories first
        final sortedAuthors = otherStoriesMap.keys.toList()
          ..sort((a, b) {
            final aHasUnseen =
                otherStoriesMap[a]!.any((s) => !s.isViewedBy(currentUserId));
            final bHasUnseen =
                otherStoriesMap[b]!.any((s) => !s.isViewedBy(currentUserId));
            if (aHasUnseen && !bHasUnseen) return -1;
            if (!aHasUnseen && bHasUnseen) return 1;
            // Otherwise sort by most recent story
            final aLatest = otherStoriesMap[a]!.first.createdAt;
            final bLatest = otherStoriesMap[b]!.first.createdAt;
            return bLatest.compareTo(aLatest);
          });

        final trayContent = SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 1 + sortedAuthors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              Widget item;
              if (index == 0) {
                // 👤 1. "Mening tarixim" (Current user's story / Add button)
                item = _buildMyStoryItem(context, myStories);
              } else {
                // 👥 2. Other users' / channels' stories
                final authorId = sortedAuthors[index - 1];
                final authorStories = otherStoriesMap[authorId]!;
                final firstStory = authorStories.first;
                final hasUnseen =
                    authorStories.any((s) => !s.isViewedBy(currentUserId));

                item = _buildAuthorStoryItem(
                  context: context,
                  authorStories: authorStories,
                  firstStory: firstStory,
                  hasUnseen: hasUnseen,
                );
              }

              return item;
            },
          ),
        );

        if (onVerticalDragUpdate != null || onVerticalDragEnd != null) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: onVerticalDragUpdate,
            onVerticalDragEnd: onVerticalDragEnd,
            child: trayContent,
          );
        }

        return trayContent;
      },
    );
  }

  Widget _buildMyStoryItem(BuildContext context, List<Story> myStories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasStories = myStories.isNotEmpty;
    final hasPhoto = currentUserPhoto != null && currentUserPhoto!.isNotEmpty;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (hasStories) {
          _openStoryViewer(context, myStories, 0);
        } else {
          _openCreateStory(context);
        }
      },
      onLongPress: () {
        if (hasStories) {
          _showMyStoryOptions(context, myStories);
        }
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                StoriesRing(
                  hasStories: hasStories,
                  hasUnseenStories: hasStories,
                  radius: 27,
                  strokeWidth: 2.5,
                  child: hasPhoto
                      ? (currentUserPhoto!.startsWith('data:image')
                          ? AppImage.memory(
                              currentUserPhoto,
                              fit: BoxFit.cover,
                              width: 54,
                              height: 54,
                            )
                          : Image.network(
                              currentUserPhoto!,
                              fit: BoxFit.cover,
                              width: 54,
                              height: 54,
                            ))
                      : Container(
                          color: AppColors.primary,
                          alignment: Alignment.center,
                          child: Text(
                            currentUserName.isNotEmpty
                                ? currentUserName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                        ),
                ),

                // Blue "+" badge attached to the lower-right edge (22x22dp with 2.5dp border)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openCreateStory(context),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: bgColor,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              LocalizationService.translate('my_story'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showMyStoryOptions(BuildContext context, List<Story> myStories) {
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_red_eye_rounded,
                    color: Colors.white),
                title: Text(
                  LocalizationService.translate('view_story'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openStoryViewer(context, myStories, 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primary),
                title: Text(
                  LocalizationService.translate('new_story_add'),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openCreateStory(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuthorStoryItem({
    required BuildContext context,
    required List<Story> authorStories,
    required Story firstStory,
    required bool hasUnseen,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = firstStory.authorAvatar != null &&
        firstStory.authorAvatar!.isNotEmpty;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _openStoryViewer(context, authorStories, 0);
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                StoriesRing(
                  hasStories: true,
                  hasUnseenStories: hasUnseen,
                  radius: 27,
                  strokeWidth: 2.5,
                  child: hasPhoto
                      ? (firstStory.authorAvatar!.startsWith('data:image')
                          ? AppImage.memory(
                              firstStory.authorAvatar,
                              fit: BoxFit.cover,
                              width: 54,
                              height: 54,
                            )
                          : Image.network(
                              firstStory.authorAvatar!,
                              fit: BoxFit.cover,
                              width: 54,
                              height: 54,
                            ))
                      : Container(
                          color: AppColors.avatarGradients[
                              firstStory.authorName.length %
                                  AppColors.avatarGradients.length][0],
                          alignment: Alignment.center,
                          child: Text(
                            firstStory.authorName.isNotEmpty
                                ? firstStory.authorName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                        ),
                ),
                if (firstStory.isChannel)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: bgColor,
                          width: 2.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              firstStory.authorName,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: hasUnseen ? FontWeight.w600 : FontWeight.w400,
                color: hasUnseen
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateStory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateStoryPage(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          currentUserPhoto: currentUserPhoto,
        ),
      ),
    );
  }
}
