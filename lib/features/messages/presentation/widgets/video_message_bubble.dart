import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/message.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../media_editor/presentation/pages/video_trim_page.dart';
import '../../../../core/localization/localization_service.dart';

import 'chat_bubble_theme.dart';

class VideoMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final MessageGroupPosition position;

  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.position = MessageGroupPosition.single,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = false;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    final videoPath = widget.message.fileUrl ?? '';
    if (videoPath.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final safeId = widget.message.id.isNotEmpty
          ? widget.message.id
          : videoPath.hashCode.abs().toString();
      final tempFile = File('${tempDir.path}/video_$safeId.mp4');

      if (await tempFile.exists() && await tempFile.length() > 0) {
        _localFile = tempFile;
        _controller = VideoPlayerController.file(tempFile);
      } else if (videoPath.startsWith('http://') ||
          videoPath.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else if (videoPath.startsWith('data:video') ||
          videoPath.startsWith('data:')) {
        final commaIndex = videoPath.indexOf(',');
        final base64String =
            commaIndex != -1 ? videoPath.substring(commaIndex + 1) : videoPath;
        final bytes = base64Decode(base64String.replaceAll('\n', '').trim());

        await tempFile.writeAsBytes(bytes);
        _localFile = tempFile;
        _controller = VideoPlayerController.file(tempFile);
      } else {
        final f = File(videoPath);
        if (await f.exists()) {
          _localFile = f;
          _controller = VideoPlayerController.file(f);
        }
      }

      if (_controller != null) {
        await _controller!.initialize();
        _controller!.setLooping(false);
        _controller!.addListener(_onControllerUpdate);
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    } catch (e) {
      debugPrint("Error initializing video player: $e");
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
      } else {
        _controller!.play();
        _showControls = false;
      }
    });
  }

  void _openFullscreen() {
    if (_controller == null || !_isInitialized) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenVideoPlayer(
          controller: _controller!,
          fileName: widget.message.fileName ?? 'Video',
          localFile: _localFile,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final hasCaption =
        widget.message.text != null && widget.message.text!.trim().isNotEmpty;
    final timeStr = DateFormat('HH:mm').format(widget.message.timestamp);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.78;
    final bubbleRadius =
        ChatBubbleTheme.getBubbleRadius(isMe, widget.position);

    return Container(
      width: maxBubbleWidth,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: bubbleRadius,
        gradient: isMe
            ? LinearGradient(
                colors: isDark
                    ? const [Color(0xFF5B4FE9), Color(0xFF4338CA)]
                    : const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMe
            ? null
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        border: isMe
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE2E8F0),
                width: 0.75,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video Preview / Player Box
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: bubbleRadius.topLeft,
              bottom: hasCaption
                  ? Radius.zero
                  : (isMe ? bubbleRadius.bottomRight : bubbleRadius.bottomLeft),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video Content
                Container(
                  color: Colors.black,
                  constraints: BoxConstraints(
                    maxHeight: 280,
                    minHeight: 180,
                    maxWidth: maxBubbleWidth,
                  ),
                  child: _hasError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.broken_image_rounded,
                                  color: Colors.white54, size: 40),
                              SizedBox(height: 6),
                              Text(
                                'Video yuklanmadi',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : (_isInitialized && _controller != null
                          ? Center(
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio
                                    .clamp(0.65, 1.8),
                                child: VideoPlayer(_controller!),
                              ),
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )),
                ),

                // Touch listener for Play/Pause and controls toggle
                if (_isInitialized && _controller != null)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showControls = !_showControls;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),

                // Center Play / Pause Glass Button
                if (_isInitialized &&
                    _controller != null &&
                    (!_controller!.value.isPlaying || _showControls))
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.55),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _controller!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),

                // Bottom Controls Bar (Progress, Duration, Fullscreen, Mute)
                if (_isInitialized && _controller != null && _showControls)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            colors: const VideoProgressColors(
                              playedColor: Colors.blueAccent,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      _isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isMuted = !_isMuted;
                                        _controller!.setVolume(_isMuted ? 0 : 1);
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: _openFullscreen,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // File Size Badge (Top Left)
                if (widget.message.fileSize != null &&
                    widget.message.fileSize!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            widget.message.fileSize!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Time and Status Badge (Bottom Right if no caption)
                if (!hasCaption)
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.message.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 12,
                              color: widget.message.isRead
                                  ? Colors.lightBlueAccent
                                  : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Caption Text (if present)
          if (hasCaption)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.text!,
                    style: AppTextStyles.messageBubble().copyWith(
                      color: isMe
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A)),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.72)
                              : (isDark
                                  ? Colors.white54
                                  : AppColors.textSecondaryLight),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          widget.message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: widget.message.isRead
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String fileName;
  final File? localFile;

  const FullscreenVideoPlayer({
    super.key,
    required this.controller,
    required this.fileName,
    this.localFile,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main Video Display
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),

              // Top Bar with back button and file title
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Center Play / Pause Button
              if (_showControls)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // -10 seconds
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.replay_10_rounded,
                            color: Colors.white70),
                        onPressed: () {
                          final newPos = controller.value.position -
                              const Duration(seconds: 10);
                          controller.seekTo(newPos < Duration.zero
                              ? Duration.zero
                              : newPos);
                        },
                      ),
                      const SizedBox(width: 24),
                      // Play / Pause
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (controller.value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                          });
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.25),
                          ),
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // +10 seconds
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.forward_10_rounded,
                            color: Colors.white70),
                        onPressed: () {
                          final newPos = controller.value.position +
                              const Duration(seconds: 10);
                          final maxPos = controller.value.duration;
                          controller.seekTo(
                              newPos > maxPos ? maxPos : newPos);
                        },
                      ),
                    ],
                  ),
                ),

              // Bottom Progress Bar & Time
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          colors: const VideoProgressColors(
                            playedColor: Colors.blueAccent,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_formatDuration(controller.value.position)} / ${_formatDuration(controller.value.duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(controller.value.position.inSeconds / (controller.value.duration.inSeconds == 0 ? 1 : controller.value.duration.inSeconds) * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SendVideoPreviewDialog extends StatefulWidget {
  final File videoFile;
  final Function(String? caption, File videoFile) onSend;

  const SendVideoPreviewDialog({
    super.key,
    required this.videoFile,
    required this.onSend,
  });

  static Future<void> show({
    required BuildContext context,
    required File videoFile,
    required Function(String? caption, File videoFile) onSend,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SendVideo',
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => SendVideoPreviewDialog(
        videoFile: videoFile,
        onSend: onSend,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    );
  }

  @override
  State<SendVideoPreviewDialog> createState() => _SendVideoPreviewDialogState();
}

class _SendVideoPreviewDialogState extends State<SendVideoPreviewDialog> {
  late VideoPlayerController _controller;
  late File _currentVideoFile;
  final _captionController = TextEditingController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentVideoFile = widget.videoFile;
    _initVideo(_currentVideoFile);
  }

  void _initVideo(File file) {
    _controller = VideoPlayerController.file(file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.setLooping(true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video preview in center
            Center(
              child: _isInitialized
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                          if (!_controller.value.isPlaying)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.55),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // Top action bar
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Video jo\'natish',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // ✂️ Video Trim Button
                  IconButton(
                    icon: const Icon(Icons.content_cut_rounded,
                        color: Colors.white, size: 24),
                    tooltip: LocalizationService.translate('trim_video_tooltip'),
                    onPressed: () async {
                      _controller.pause();
                      final trimmed = await VideoTrimPage.open(
                        context,
                        videoFile: _currentVideoFile,
                      );
                      if (trimmed != null && mounted) {
                        setState(() {
                          _currentVideoFile = trimmed;
                          _isInitialized = false;
                        });
                        await _controller.dispose();
                        _initVideo(_currentVideoFile);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Bottom Caption & Send Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black.withOpacity(0.7),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: LocalizationService.translate('optional_caption_hint'),
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        final caption = _captionController.text.trim();
                        Navigator.of(context).pop();
                        widget.onSend(
                          caption.isNotEmpty ? caption : null,
                          _currentVideoFile,
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
