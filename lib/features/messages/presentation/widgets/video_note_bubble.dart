import '../../../../core/localization/localization_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/message.dart';
import '../../../../core/design_system/app_colors.dart';

class VideoNoteBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const VideoNoteBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    final videoPath = widget.message.fileUrl ?? widget.message.imageUrl ?? '';
    if (videoPath.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      if (videoPath.startsWith('http://') || videoPath.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(videoPath));
      } else if (videoPath.startsWith('data:video') ||
          videoPath.startsWith('data:')) {
        // Decode Base64 data and cache into temporary mp4 file
        final commaIndex = videoPath.indexOf(',');
        final base64String =
            commaIndex != -1 ? videoPath.substring(commaIndex + 1) : videoPath;
        final bytes = base64Decode(base64String.replaceAll('\n', '').trim());

        final tempDir = await getTemporaryDirectory();
        final safeId = widget.message.id.isNotEmpty
            ? widget.message.id
            : videoPath.hashCode.abs().toString();
        final tempFile = File('${tempDir.path}/vnote_$safeId.mp4');

        if (!await tempFile.exists() ||
            (await tempFile.length()) != bytes.length) {
          await tempFile.writeAsBytes(bytes, flush: true);
        }

        _controller = VideoPlayerController.file(tempFile);
      } else {
        _controller = VideoPlayerController.file(File(videoPath));
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(1.0);

      // Listen for position changes to drive progress ring
      _controller!.addListener(_onControllerTick);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint("Video note load error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    }
  }

  void _onControllerTick() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const size = 210.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double progress = 0.0;
    int displaySecs = widget.message.duration ?? 0;

    if (_isInitialized && _controller != null) {
      final total = _controller!.value.duration.inMilliseconds;
      final current = _controller!.value.position.inMilliseconds;
      if (total > 0) {
        progress = (current / total).clamp(0.0, 1.0);
        final remainingMs = total - current;
        displaySecs = (remainingMs / 1000).ceil();
      }
    }

    final mins = (displaySecs ~/ 60).toString().padLeft(1, '0');
    final secs = (displaySecs % 60).toString().padLeft(2, '0');

    final primaryColor = widget.isMe
        ? AppColors.primary
        : (isDark ? Colors.tealAccent : const Color(0xFF0088CC));

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _toggleMute,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing shadow
            Container(
              width: size + 6,
              height: size + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),

            // Video player with true 1:1 circular center crop
            SizedBox(
              width: size,
              height: size,
              child: ClipOval(
                child: _isInitialized && _controller != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width > 0
                              ? _controller!.value.size.width
                              : size,
                          height: _controller!.value.size.height > 0
                              ? _controller!.value.size.height
                              : size,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF0F172A),
                        child: Center(
                          child: _hasError
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.videocam_off_rounded,
                                      color: Colors.white70,
                                      size: 34,
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _hasError = false;
                                          _isInitialized = false;
                                        });
                                        _initVideoPlayer();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             const Icon(Icons.refresh_rounded,
                                                 color: Colors.white, size: 14),
                                             const SizedBox(width: 4),
                                             Text(
                                               LocalizationService.translate('retry'),
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
                                  ],
                                )
                              : const CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2.5,
                                ),
                        ),
                      ),
              ),
            ),

            // Animated circular progress border
            IgnorePointer(
              child: CustomPaint(
                size: const Size(size + 6, size + 6),
                painter: _VideoNoteBubbleProgressPainter(
                  progress: progress,
                  activeColor: primaryColor,
                  trackColor: Colors.white.withOpacity(0.2),
                  strokeWidth: 3.5,
                ),
              ),
            ),

            // Center Play Icon when paused
            if (_isInitialized &&
                _controller != null &&
                !_controller!.value.isPlaying)
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),

            // Mute indicator badge (top right)
            if (_isInitialized && _isMuted)
              Positioned(
                top: 10,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_off_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

            // Bottom duration / remaining time badge
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isInitialized &&
                        _controller != null &&
                        _controller!.value.isPlaying) ...[
                      const Icon(
                        Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '$mins:$secs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
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

class _VideoNoteBubbleProgressPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final double strokeWidth;

  _VideoNoteBubbleProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      // Active progress arc
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VideoNoteBubbleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
