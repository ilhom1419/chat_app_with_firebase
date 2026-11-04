import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../data/services/video_trimmer_service.dart';

/// Full interactive video trimming editor with real playback, dual trim handles, and export.
class VideoTrimPage extends StatefulWidget {
  final File videoFile;

  const VideoTrimPage({
    super.key,
    required this.videoFile,
  });

  static Future<File?> open(BuildContext context, {required File videoFile}) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => VideoTrimPage(videoFile: videoFile),
      ),
    );
  }

  @override
  State<VideoTrimPage> createState() => _VideoTrimPageState();
}

class _VideoTrimPageState extends State<VideoTrimPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  Duration _totalDuration = Duration.zero;
  Duration _startTrim = Duration.zero;
  Duration _endTrim = Duration.zero;

  bool _isTrimming = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    try {
      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _totalDuration = _controller.value.duration;
        _startTrim = Duration.zero;
        _endTrim = _totalDuration;
      });

      _controller.addListener(_videoListener);
      _controller.play();
    } catch (e) {
      debugPrint('Error initializing video trimmer: $e');
    }
  }

  void _videoListener() {
    if (!mounted || !_isInitialized) return;

    final currentPos = _controller.value.position;
    // Loop playback within trimmed range
    if (currentPos >= _endTrim) {
      _controller.seekTo(_startTrim);
      _controller.play();
    } else if (currentPos < _startTrim) {
      _controller.seekTo(_startTrim);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _confirmTrimAndExport() async {
    final trimDuration = _endTrim - _startTrim;
    if (trimDuration.inMilliseconds < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.translate('video_too_short')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // If whole video is selected without trimming, return original file directly
    if (_startTrim == Duration.zero && (_endTrim >= _totalDuration || (_totalDuration - _endTrim).inMilliseconds.abs() < 200)) {
      Navigator.of(context).pop(widget.videoFile);
      return;
    }

    _controller.pause();

    setState(() {
      _isTrimming = true;
    });

    try {
      final trimmedFile = await VideoTrimmerService.trimVideo(
        sourceFile: widget.videoFile,
        start: _startTrim,
        end: _endTrim,
      );

      if (mounted) {
        Navigator.of(context).pop(trimmedFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTrimming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService.translate('export_failed')}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDuration = _endTrim - _startTrim;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Video Player Area
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
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller),
                            if (!_controller.value.isPlaying)
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(color: AppColors.primary),
            ),

            // 2. Top Header Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      LocalizationService.translate('trim_video'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Confirm Trim Button
                    ElevatedButton(
                      onPressed: _isInitialized && !_isTrimming ? _confirmTrimAndExport : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                      child: Text(
                        LocalizationService.translate('save'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Timeline & Trimming Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Durations Row: Start, Selected Length, End
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_startTrim),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary, width: 1),
                          ),
                          child: Text(
                            '${LocalizationService.translate('duration')}: ${_formatDuration(selectedDuration)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_endTrim),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Trimming Range Slider
                    if (_isInitialized && _totalDuration.inMilliseconds > 0)
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white24,
                          rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 9,
                            elevation: 4,
                          ),
                          thumbColor: Colors.white,
                          overlayColor: AppColors.primary.withOpacity(0.2),
                          rangeTrackShape: const RectangularRangeSliderTrackShape(),
                        ),
                        child: RangeSlider(
                          values: RangeValues(
                            _startTrim.inMilliseconds.toDouble(),
                            _endTrim.inMilliseconds.toDouble(),
                          ),
                          min: 0.0,
                          max: _totalDuration.inMilliseconds.toDouble(),
                          onChanged: (RangeValues values) {
                            setState(() {
                              _startTrim = Duration(milliseconds: values.start.round());
                              _endTrim = Duration(milliseconds: values.end.round());
                            });
                            // Seek to start position on scrub for live frame preview
                            _controller.seekTo(_startTrim);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 4. Processing overlay
            if (_isTrimming)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        LocalizationService.translate('processing'),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
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
