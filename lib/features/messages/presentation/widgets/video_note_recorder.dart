import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

class VideoNoteRecorder extends StatefulWidget {
  final Function(String videoPath, int durationSeconds) onVideoRecorded;

  const VideoNoteRecorder({
    super.key,
    required this.onVideoRecorded,
  });

  @override
  State<VideoNoteRecorder> createState() => _VideoNoteRecorderState();
}

class _VideoNoteRecorderState extends State<VideoNoteRecorder>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  VideoPlayerController? _previewPlayerController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _isRecording = false;
  bool _isPreviewMode = false;
  String? _recordedVideoPath;
  int _seconds = 0;
  static const int _maxSeconds = 25; // Fits perfectly into Firestore document
  Timer? _timer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera({int? cameraIndex}) async {
    setState(() => _isInitializing = true);
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isInitializing = false);
        return;
      }

      if (cameraIndex != null) {
        _selectedCameraIndex = cameraIndex % _cameras.length;
      } else {
        // Default to front camera
        final frontIndex = _cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
      }

      await _cameraController?.dispose();

      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _switchCamera() {
    if (_isRecording || _cameras.length < 2) return;
    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _initCamera(cameraIndex: nextIndex);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
    _previewPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _seconds = 0;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_seconds >= _maxSeconds) {
          _stopRecording(autoSend: false);
        } else {
          setState(() {
            _seconds++;
          });
        }
      });
    } catch (e) {
      debugPrint("Error starting video recording: $e");
    }
  }

  Future<void> _stopRecording({bool autoSend = false}) async {
    _timer?.cancel();
    if (_cameraController == null || !_isRecording) return;
    try {
      final XFile file = await _cameraController!.stopVideoRecording();
      final recordedPath = file.path;
      final recordedDuration = _seconds > 0 ? _seconds : 1;

      if (autoSend) {
        widget.onVideoRecorded(recordedPath, recordedDuration);
        if (mounted) Navigator.pop(context);
        return;
      }

      // Enter preview mode so user can review their video note
      setState(() {
        _isRecording = false;
        _isPreviewMode = true;
        _recordedVideoPath = recordedPath;
      });

      _previewPlayerController = VideoPlayerController.file(File(recordedPath));
      await _previewPlayerController!.initialize();
      _previewPlayerController!.setLooping(true);
      await _previewPlayerController!.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error stopping video recording: $e");
    }
  }

  void _reRecord() {
    _previewPlayerController?.dispose();
    _previewPlayerController = null;
    setState(() {
      _isPreviewMode = false;
      _recordedVideoPath = null;
      _seconds = 0;
    });
  }

  void _sendRecordedVideo() {
    if (_recordedVideoPath != null) {
      widget.onVideoRecorded(
        _recordedVideoPath!,
        _seconds > 0 ? _seconds : 1,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double circleSize = 250.0;
    final progress = _seconds / _maxSeconds;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.redAccent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isRecording
                            ? Colors.redAccent.withOpacity(0.6)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRecording) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          _isPreviewMode
                              ? LocalizationService.translate('video_note_preview')
                              : (_isRecording
                                  ? '0:${_seconds.toString().padLeft(2, '0')} / 0:$_maxSeconds'
                                  : LocalizationService.translate('record_video_note')),
                          style: TextStyle(
                            color: _isRecording ? Colors.redAccent : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48), // Balance close button
                ],
              ),
            ),

            const Spacer(),

            // Circular Camera / Video Preview
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Animated Glow when recording
                  if (_isRecording)
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: circleSize + 24,
                        height: circleSize + 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.35),
                              blurRadius: 28,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Progress ring
                  SizedBox(
                    width: circleSize + 12,
                    height: circleSize + 12,
                    child: CustomPaint(
                      painter: _VideoNoteProgressPainter(
                        progress: _isRecording ? progress : 0.0,
                        color: _isRecording
                            ? Colors.redAccent
                            : AppColors.primary,
                      ),
                    ),
                  ),

                  // Circular Crop of Camera or Preview
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isRecording
                            ? Colors.redAccent
                            : (_isPreviewMode
                                ? AppColors.primary
                                : Colors.white70),
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _isPreviewMode &&
                              _previewPlayerController != null &&
                              _previewPlayerController!.value.isInitialized
                          ? SizedBox(
                              width: circleSize,
                              height: circleSize,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _previewPlayerController!
                                      .value.size.width,
                                  height: _previewPlayerController!
                                      .value.size.height,
                                  child: VideoPlayer(_previewPlayerController!),
                                ),
                              ),
                            )
                          : (_isInitializing
                              ? Container(
                                  color: const Color(0xFF0F172A),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              : (_cameraController != null &&
                                      _cameraController!.value.isInitialized)
                                  ? SizedBox(
                                      width: circleSize,
                                      height: circleSize,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _cameraController!
                                                  .value.previewSize?.height ??
                                              circleSize,
                                          height: _cameraController!
                                                  .value.previewSize?.width ??
                                              circleSize,
                                          child: CameraPreview(
                                              _cameraController!),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFF0F172A),
                                      child: Center(
                                        child: Text(
                                          LocalizationService.translate('camera_failed_to_open'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    )),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom Controls Area
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
              child: _isPreviewMode
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Re-record / Delete
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              iconSize: 32,
                              icon: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.refresh_rounded,
                                    color: Colors.white),
                              ),
                              onPressed: _reRecord,
                            ),
                            const SizedBox(height: 4),
                            Text(LocalizationService.translate('record_again'),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),

                        // Send Button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _sendRecordedVideo,
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.primary.withOpacity(0.45),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 32),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(LocalizationService.translate('send_action'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Switch Camera Button
                        IconButton(
                          iconSize: 32,
                          icon: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _isRecording ? null : _switchCamera,
                        ),

                        // Main Record / Stop Button
                        GestureDetector(
                          onTap: () {
                            if (!_isRecording) {
                              _startRecording();
                            } else {
                              _stopRecording();
                            }
                          },
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.redAccent
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording
                                          ? Colors.redAccent
                                          : AppColors.primary)
                                      .withOpacity(0.4),
                                  blurRadius: 18,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop_rounded
                                  : Icons.videocam_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),

                        // Direct Stop & Send button while recording, or Cancel
                        if (_isRecording)
                          IconButton(
                            iconSize: 32,
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => _stopRecording(autoSend: true),
                          )
                        else
                          IconButton(
                            iconSize: 32,
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoNoteProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _VideoNoteProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VideoNoteProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
