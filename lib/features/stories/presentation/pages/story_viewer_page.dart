import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../../../chats/domain/repositories/chat_repository.dart';
import '../utils/story_gradients.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

class StoryViewerPage extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;

  const StoryViewerPage({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  VideoPlayerController? _videoController;

  bool _isPaused = false;
  bool _isUIVisible = true;
  bool _isFitCover = true; // Toggle between BoxFit.cover and BoxFit.contain
  String? _flyingEmoji;

  // Interactive swipe down to dismiss
  double _dragOffsetY = 0.0;

  // Reply controller & focus
  final _replyController = TextEditingController();
  final _replyFocusNode = FocusNode();

  static const Duration _defaultStoryDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.stories.length - 1);

    // Set immersive fullscreen system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _progressController = AnimationController(
      vsync: this,
      duration: _defaultStoryDuration,
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _pause();
      } else {
        _resume();
      }
    });

    _startCurrentStory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadNextStory();
  }

  void _preloadNextStory() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex < widget.stories.length) {
      final nextStory = widget.stories[nextIndex];
      final url = nextStory.mediaUrl;
      if (url != null && url.isNotEmpty) {
        if (url.startsWith('http')) {
          precacheImage(NetworkImage(url), context);
        } else if (url.startsWith('data:image')) {
          final bytes = AppImage.decode(url);
          if (bytes != null && bytes.isNotEmpty) {
            precacheImage(MemoryImage(bytes), context);
          }
        }
      }
    }
  }

  void _startCurrentStory() {
    _cleanupVideoController();

    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;
    final currentStory = widget.stories[_currentIndex];

    final url = currentStory.mediaUrl;
    final isVideo = url != null &&
        (url.endsWith('.mp4') ||
            url.endsWith('.mov') ||
            url.endsWith('.webm') ||
            url.contains('/video'));

    if (isVideo) {
      _initVideoPlayer(url);
    } else {
      _progressController.duration = _defaultStoryDuration;
      _progressController.reset();
      if (!_isPaused) {
        _progressController.forward();
      }
    }

    _markCurrentAsViewed();
    _preloadNextStory();
  }

  void _initVideoPlayer(String url) async {
    try {
      final controller = url.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(url))
          : VideoPlayerController.file(File(url.replaceFirst('file://', '')));

      _videoController = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {});
      final duration = controller.value.duration;
      _progressController.duration =
          duration > Duration.zero ? duration : _defaultStoryDuration;
      _progressController.reset();

      if (!_isPaused) {
        controller.play();
        _progressController.forward();
      }

      controller.addListener(() {
        if (controller.value.position >= controller.value.duration &&
            controller.value.duration > Duration.zero) {
          _goToNextStory();
        }
      });
    } catch (e) {
      debugPrint('Error initializing story video: $e');
      _progressController.duration = _defaultStoryDuration;
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _cleanupVideoController() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
  }

  void _markCurrentAsViewed() {
    if (_currentIndex < 0 || _currentIndex >= widget.stories.length) return;
    final currentStory = widget.stories[_currentIndex];

    // Only mark viewed if not already marked and not own story
    if (currentStory.authorId != widget.currentUserId &&
        !currentStory.isViewedBy(widget.currentUserId)) {
      try {
        context.read<StoryRepository>().markStoryAsViewed(
              storyId: currentStory.id,
              userId: widget.currentUserId,
              userName: widget.currentUserName,
              userPhoto: widget.currentUserPhoto,
            );
      } catch (e) {
        debugPrint('StoryRepository not available in context: $e');
      }
    }
  }

  void _goToNextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startCurrentStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToPreviousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startCurrentStory();
    } else {
      _progressController.reset();
      _progressController.forward();
      _videoController?.seekTo(Duration.zero);
      _videoController?.play();
    }
  }

  void _pause() {
    if (!_isPaused) {
      _isPaused = true;
      _progressController.stop();
      _videoController?.pause();
    }
  }

  void _resume() {
    if (_isPaused && !_replyFocusNode.hasFocus) {
      _isPaused = false;
      _progressController.forward();
      _videoController?.play();
    }
  }

  void _sendReaction(String emoji) async {
    final currentStory = widget.stories[_currentIndex];
    setState(() {
      _flyingEmoji = emoji;
    });

    await context.read<StoryRepository>().reactToStory(
          storyId: currentStory.id,
          userId: widget.currentUserId,
          userName: widget.currentUserName,
          userPhoto: widget.currentUserPhoto,
          emoji: emoji,
        );

    // Reset flying emoji animation after 1.4 seconds
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _flyingEmoji = null;
        });
      }
    });
  }

  void _sendReplyMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final currentStory = widget.stories[_currentIndex];
    _replyController.clear();
    _replyFocusNode.unfocus();

    try {
      final chatRepo = context.read<ChatRepository>();
      final chatId = await chatRepo.createOrGetChat(
        widget.currentUserId,
        currentStory.authorId,
      );

      final replyContent = LocalizationService.translate(
        'story_reply_prefix',
        params: {'text': trimmed},
      );
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'text': replyContent,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'text',
      });

      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': replyContent,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.currentUserId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.translate('reply_sent_success')),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending reply: $e');
    }
  }

  void _showViewersSheet(Story story) {
    _pause();
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (ctx) {
        final viewers = story.viewersList;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${LocalizationService.translate('story_views')} (${viewers.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent),
                      tooltip: LocalizationService.translate('delete_story'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _confirmDeleteStory(story);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),
                if (viewers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        LocalizationService.translate('no_views_yet'),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 14),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (ctx, index) {
                        final viewer = viewers[index];
                        final hasPhoto = viewer.userPhoto != null &&
                            viewer.userPhoto!.startsWith('data:image');
                        final timeStr =
                            DateFormat('HH:mm').format(viewer.viewedAt);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            backgroundImage: hasPhoto
                                ? AppImage.provider(viewer.userPhoto)
                                : null,
                            child: !hasPhoto
                                ? Text(
                                    viewer.userName.isNotEmpty
                                        ? viewer.userName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(
                            viewer.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Ko\'rildi: $timeStr',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          trailing: viewer.reaction != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    viewer.reaction!,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _resume();
    });
  }

  void _confirmDeleteStory(Story story) {
    _pause();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(LocalizationService.translate('delete_story'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          LocalizationService.translate('delete_story_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resume();
            },
            child: Text(LocalizationService.translate('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<StoryRepository>().deleteStory(story.id);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(LocalizationService.translate('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cleanupVideoController();
    _progressController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return LocalizationService.of(context).get('just_now');
    if (diff.inMinutes < 60) return LocalizationService.of(context).get('minutes_ago', args: {'count': '${diff.inMinutes}'});
    if (diff.inHours < 24) return LocalizationService.of(context).get('hours_ago', args: {'count': '${diff.inHours}'});
    return DateFormat('dd.MM HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.stories.length) {
      return const SizedBox.shrink();
    }
    final currentStory = widget.stories[_currentIndex];
    final isOwnStory = currentStory.authorId == widget.currentUserId;
    final hasAuthorPhoto = currentStory.authorAvatar != null &&
        currentStory.authorAvatar!.isNotEmpty;

    // Calculate scale and translation for interactive swipe down to dismiss
    final dismissScale = (1.0 - (_dragOffsetY / 1200)).clamp(0.85, 1.0);
    final dismissTranslateY = _dragOffsetY.clamp(0.0, 400.0);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTapDown: (details) {
          // If reply is focused, tap closes keyboard
          if (_replyFocusNode.hasFocus) {
            _replyFocusNode.unfocus();
            return;
          }

          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth * 0.3) {
            _goToPreviousStory();
          } else {
            _goToNextStory();
          }
        },
        onDoubleTap: () {
          // Double tap toggles aspect ratio (Cover vs Contain)
          setState(() {
            _isFitCover = !_isFitCover;
          });
        },
        onLongPressStart: (_) {
          _pause();
          setState(() {
            _isUIVisible = false;
          });
        },
        onLongPressEnd: (_) {
          _resume();
          setState(() {
            _isUIVisible = true;
          });
        },
        onVerticalDragUpdate: (details) {
          final dy = details.primaryDelta ?? 0;
          if (dy > 0 || _dragOffsetY > 0) {
            setState(() {
              _dragOffsetY = (_dragOffsetY + dy).clamp(0.0, 500.0);
            });
          }
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_dragOffsetY > 120 || velocity > 400) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              _dragOffsetY = 0.0;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
          offset: Offset(0, dismissTranslateY),
          child: Transform.scale(
            scale: dismissScale,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 🖼️ 1. True Fullscreen Media Content (Image, Video or Vibrant Gradient Text)
                Positioned.fill(
                  child: _buildStoryContent(currentStory),
                ),

                // 🌟 Floating reaction animation
                if (_flyingEmoji != null)
                  Center(
                    child: Text(
                      _flyingEmoji!,
                      style: const TextStyle(fontSize: 84),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.4, 0.4),
                          end: const Offset(1.8, 1.8),
                          duration: 650.ms,
                          curve: Curves.elasticOut,
                        )
                        .fadeOut(delay: 700.ms, duration: 400.ms),
                  ),

                // 🔝 2. Top Progress & Header Bar (with gradient scrim)
                AnimatedOpacity(
                  opacity: _isUIVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      // Top gradient scrim for perfect legibility
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.black.withValues(alpha: 0.25),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Multi-segment progress indicators
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: List.generate(
                                  widget.stories.length,
                                  (index) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      child: AnimatedBuilder(
                                        animation: _progressController,
                                        builder: (context, _) {
                                          double value = 0.0;
                                          if (index < _currentIndex) {
                                            value = 1.0;
                                          } else if (index == _currentIndex) {
                                            value = _progressController.value;
                                          }
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: value,
                                              minHeight: 3,
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.3),
                                              valueColor:
                                                  const AlwaysStoppedAnimation<
                                                      Color>(Colors.white),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Header with Author & Controls
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 19,
                                    backgroundColor: AppColors.primary,
                                    backgroundImage: hasAuthorPhoto
                                        ? (currentStory.authorAvatar!
                                                .startsWith('data:image')
                                            ? AppImage.provider(
                                                currentStory.authorAvatar)
                                            : NetworkImage(
                                                currentStory.authorAvatar!))
                                        : null,
                                    child: !hasAuthorPhoto
                                        ? Text(
                                            currentStory.authorName.isNotEmpty
                                                ? currentStory.authorName[0]
                                                    .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                currentStory.authorName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  shadows: [
                                                    Shadow(
                                                      blurRadius: 4,
                                                      color: Colors.black87,
                                                    )
                                                  ],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (currentStory.isChannel) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  LocalizationService.translate(
                                                      'channel_badge'),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          _formatTime(currentStory.createdAt),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 4,
                                                color: Colors.black87,
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Aspect ratio toggle (Cover vs Fit)
                                  if (currentStory.mediaUrl != null &&
                                      currentStory.mediaUrl!.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        _isFitCover
                                            ? Icons.fit_screen_rounded
                                            : Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      tooltip: _isFitCover
                                          ? 'Asl o\'lcham'
                                          : 'To\'liq ekran',
                                      onPressed: () {
                                        setState(() {
                                          _isFitCover = !_isFitCover;
                                        });
                                      },
                                    ),
                                  if (isOwnStory)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 24),
                                      onPressed: () =>
                                          _confirmDeleteStory(currentStory),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 28),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔻 3. Bottom Actions Bar (with gradient scrim)
                AnimatedOpacity(
                  opacity: _isUIVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      // Bottom gradient scrim
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 200,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.88),
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Optional Story Caption Box
                              if (currentStory.caption != null &&
                                  currentStory.caption!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    currentStory.caption!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              // Bottom Controls: Author vs Viewer
                              isOwnStory
                                  ? _buildAuthorBottomBar(currentStory)
                                  : _buildViewerBottomBar(currentStory),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story story) {
    final fitToUse = _isFitCover ? BoxFit.cover : BoxFit.contain;

    if (story.mediaUrl != null && story.mediaUrl!.isNotEmpty) {
      final url = story.mediaUrl!;
      final isVideo = url.endsWith('.mp4') ||
          url.endsWith('.mov') ||
          url.endsWith('.webm') ||
          url.contains('/video');
      final isBase64 = url.startsWith('data:image') ||
          (!url.startsWith('http') && !url.startsWith('/'));

      Widget mediaWidget;

      if (isVideo) {
        if (_videoController != null &&
            _videoController!.value.isInitialized) {
          mediaWidget = Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          );
        } else {
          mediaWidget = const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
      } else if (isBase64) {
        mediaWidget = AppImage.memory(
          url,
          fit: fitToUse,
          width: double.infinity,
          height: double.infinity,
        );
      } else if (url.startsWith('/') || url.startsWith('file://')) {
        final filePath = url.replaceFirst('file://', '');
        mediaWidget = Image.file(
          File(filePath),
          fit: fitToUse,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        // Network Image
        mediaWidget = Image.network(
          url,
          fit: fitToUse,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.black,
              child: const Center(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    color: Colors.white70,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (ctx, _, __) => Container(
            color: const Color(0xFF1E1E2E),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded,
                      color: Colors.white38, size: 54),
                  SizedBox(height: 12),
                  Text(
                    'Rasmni yuklab bo\'lmadi',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SizedBox.expand(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 3.5,
          onInteractionStart: (_) => _pause(),
          onInteractionEnd: (_) => _resume(),
          child: mediaWidget,
        ),
      );
    } else {
      // Vibrant Gradient Text Story
      final gradient = StoryGradients.getGradient(story.gradientIndex);
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        alignment: Alignment.center,
        child: Text(
          story.textContent ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            height: 1.35,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.black45,
                offset: Offset(0, 3),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
  }

  Widget _buildAuthorBottomBar(Story story) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: GestureDetector(
          onTap: () => _showViewersSheet(story),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  LocalizationService.plural('views_count', story.viewsCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewerBottomBar(Story story) {
    const emojis = ['❤️', '🔥', '😂', '😮', '😢', '👍', '👏', '🎉'];
    final myReaction = story.reactions[widget.currentUserId];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row of quick reaction emojis
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: emojis.map((emoji) {
                final isSelected = myReaction == emoji;
                return GestureDetector(
                  onTap: () => _sendReaction(emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.25),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 1.5)
                          : Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Telegram-grade reply field
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          focusNode: _replyFocusNode,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText:
                                LocalizationService.translate('type_message'),
                            hintStyle: const TextStyle(
                                color: Colors.white60, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: _sendReplyMessage,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () =>
                            _sendReplyMessage(_replyController.text),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
