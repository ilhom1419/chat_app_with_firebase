import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/design_system/app_colors.dart';

class VoicePlayerWidget extends StatefulWidget {
  final String url;
  final int duration;
  final bool isMe;
  final String? messageId;

  const VoicePlayerWidget({
    super.key,
    required this.url,
    required this.duration,
    required this.isMe,
    this.messageId,
  });

  @override
  State<VoicePlayerWidget> createState() => _VoicePlayerWidgetState();
}

class _VoicePlayerWidgetState extends State<VoicePlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0; // 1.0x -> 1.5x -> 2.0x

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.duration);
    _initAudioContext();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (_isPlaying) _isLoading = false;
        });
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted && dur.inSeconds > 0) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _initAudioContext() async {
    try {
      await _player.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
    } catch (e) {
      debugPrint("AudioContext error: $e");
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<String> _getPlaybackPath(String url) async {
    final tempDir = await getTemporaryDirectory();
    final safeHash = widget.messageId ?? url.hashCode.abs().toString();
    final tempFile = File('${tempDir.path}/voice_$safeHash.m4a');

    if (await tempFile.exists() && (await tempFile.length()) > 0) {
      return tempFile.path;
    }

    if (url.startsWith('data:audio') || url.startsWith('data:')) {
      final commaIndex = url.indexOf(',');
      final base64String =
          commaIndex != -1 ? url.substring(commaIndex + 1) : url;
      final bytes = base64Decode(base64String.replaceAll('\n', '').trim());
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile.path;
    }

    return url;
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      setState(() => _isLoading = true);
      try {
        final playPath = await _getPlaybackPath(widget.url);
        if (playPath.startsWith('http://') || playPath.startsWith('https://')) {
          await _player.play(UrlSource(playPath));
        } else {
          await _player.play(DeviceFileSource(playPath));
        }
        await _player.setPlaybackRate(_playbackSpeed);
      } catch (e) {
        debugPrint("Error playing voice note: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _cyclePlaybackSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    _player.setPlaybackRate(_playbackSpeed);
  }

  void _seekToRelative(double relativeProgress) {
    final totalSec = _totalDuration.inMilliseconds;
    if (totalSec > 0) {
      final targetMs = (relativeProgress * totalSec).toInt();
      _player.seek(Duration(milliseconds: targetMs));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.isMe
        ? Colors.white
        : (isDark ? const Color(0xFF818CF8) : AppColors.primary);

    final totalMs = _totalDuration.inMilliseconds > 0
        ? _totalDuration.inMilliseconds
        : (widget.duration * 1000);
    final currentMs = _position.inMilliseconds;
    final progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

    // Remaining or current duration display
    final displaySec = _isPlaying
        ? (_position.inSeconds)
        : (_totalDuration.inSeconds > 0
            ? _totalDuration.inSeconds
            : widget.duration);
    final mins = (displaySec ~/ 60).toString().padLeft(1, '0');
    final secs = (displaySec % 60).toString().padLeft(2, '0');

    // Generate natural speech waveform profile using url hash seed
    final List<double> heights = List.generate(28, (i) {
      final seed = widget.url.hashCode + i * 47;
      final pseudo = (math.sin(seed.toDouble()) * 10000).abs() % 1.0;
      // Human speech voice curve (bell curve shape)
      final bell = math.sin((i / 27.0) * math.pi);
      return (0.18 + 0.82 * (pseudo * 0.6 + bell * 0.4)).clamp(0.2, 1.0);
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause / Loading button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.22)
                    : primaryColor.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: primaryColor,
                        size: 26,
                      ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Waveform & Timer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Interactive Waveform
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final localPos =
                          box.globalToLocal(details.globalPosition);
                      final rel = (localPos.dx / 140.0).clamp(0.0, 1.0);
                      _seekToRelative(rel);
                    }
                  },
                  onTapDown: (details) {
                    final rel =
                        (details.localPosition.dx / 140.0).clamp(0.0, 1.0);
                    _seekToRelative(rel);
                  },
                  child: Container(
                    height: 26,
                    alignment: Alignment.centerLeft,
                    child: CustomPaint(
                      size: const Size(140, 24),
                      painter: _VoiceWaveformPainter(
                        heights: heights,
                        progress: progress,
                        activeColor: primaryColor,
                        inactiveColor: widget.isMe
                            ? Colors.white.withOpacity(0.35)
                            : (isDark
                                ? Colors.white24
                                : AppColors.primary.withOpacity(0.28)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 2),

                // Timer & Speed Control row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$mins:$secs',
                      style: TextStyle(
                        color: widget.isMe
                            ? Colors.white.withOpacity(0.85)
                            : (isDark ? Colors.white60 : Colors.black54),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),

                    // 1x / 1.5x / 2x Speed button
                    GestureDetector(
                      onTap: _cyclePlaybackSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.2)
                              : primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_playbackSpeed == 1.0 ? '1' : _playbackSpeed}x',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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

class _VoiceWaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _VoiceWaveformPainter({
    required this.heights,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final barCount = heights.length;
    final totalWidth = size.width;
    const barWidth = 2.8;
    final space = (totalWidth - (barCount * barWidth)) / (barCount - 1);
    final activeIndex = (progress * barCount).floor();

    for (int i = 0; i < barCount; i++) {
      final left = i * (barWidth + space);
      final barHeight = (heights[i] * size.height).clamp(4.0, size.height);
      final top = (size.height - barHeight) / 2;

      final paint = Paint()
        ..color = (i <= activeIndex) ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(1.5),
      );

      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
