import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../core/network/webrtc_signaling_service.dart';
import '../bloc/message_bloc.dart';
import '../bloc/message_event.dart';

class CallPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserName;
  final String? receiverUserId;
  final String? otherUserAvatar;
  final bool isVideo;
  final bool isCaller;
  final String? existingCallId;

  const CallPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserName,
    this.receiverUserId,
    this.otherUserAvatar,
    required this.isVideo,
    this.isCaller = true,
    this.existingCallId,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final WebRTCSignalingService _signaling = WebRTCSignalingService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  String _status = '';
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  int _seconds = 0;
  Timer? _callTimer;
  String? _callId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _status = LocalizationService.translate('ringing');
    _callId = widget.existingCallId;
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _signaling.onAddRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _status = LocalizationService.translate('connected');
        });
        _startTimer();
      }
    };

    _signaling.onCallEnded = () {
      if (mounted) {
        _endCall(byRemote: true);
      }
    };

    await _signaling.openUserMedia(
      _localRenderer,
      _remoteRenderer,
      isVideo: widget.isVideo,
    );

    if (widget.isCaller) {
      _callId = await _signaling.createRoom(
        _remoteRenderer,
        chatId: widget.chatId,
        callerId: widget.currentUserId,
        callerName: widget.otherUserName,
        receiverId: widget.receiverUserId ?? '',
        isVideo: widget.isVideo,
      );
    } else if (widget.existingCallId != null) {
      await _signaling.joinRoom(
        widget.existingCallId!,
        _remoteRenderer,
      );
      if (mounted) {
        setState(() {
          _isConnected = true;
          _status = LocalizationService.translate('connected');
        });
        _startTimer();
      }
    }

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _signaling.toggleMic(_isMuted);
  }

  void _toggleCamera() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _signaling.toggleCamera(_isVideoOff);
  }

  void _switchCamera() {
    _signaling.switchCamera();
  }

  void _endCall({bool byRemote = false}) async {
    _callTimer?.cancel();

    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');
    final durationStr = '$minutes:$secs';
    final callType = widget.isVideo ? 'Video call' : 'Voice call';
    final logText = '📞 $callType ended ($durationStr)';

    if (!byRemote) {
      await _signaling.hangUp(_localRenderer, _remoteRenderer, _callId);
      if (mounted) {
        context.read<MessageBloc>().add(SendTextMessage(
              chatId: widget.chatId,
              senderId: widget.currentUserId,
              text: logText,
            ));
      }
    }

    await _localRenderer.dispose();
    await _remoteRenderer.dispose();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');
    final durationStr = '$minutes:$secs';

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Stack(
            children: [
              // Remote stream view or Avatar view
              if (widget.isVideo && !_isVideoOff && _isConnected)
                Positioned.fill(
                  child: RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Text(
                          widget.otherUserName.isNotEmpty
                              ? widget.otherUserName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.otherUserName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnected ? durationStr : _status,
                        style: TextStyle(
                          fontSize: 16,
                          color: _isConnected ? Colors.greenAccent : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),

              // PIP overlay for local video stream in video call
              if (widget.isVideo && _isInitialized && !_isVideoOff)
                Positioned(
                  top: 50,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 110,
                      height: 150,
                      color: Colors.black54,
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Call duration chip
              if (widget.isVideo && _isConnected)
                Positioned(
                  top: 50,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      durationStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Bottom control actions panel
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mic toggle
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                        onPressed: _toggleMute,
                      ),

                      // Camera toggle (video call only)
                      if (widget.isVideo)
                        IconButton(
                          icon: Icon(
                            _isVideoOff ? Icons.videocam_off : Icons.videocam,
                            color: Colors.white,
                          ),
                          onPressed: _toggleCamera,
                        ),

                      // Switch Camera (video call only)
                      if (widget.isVideo)
                        IconButton(
                          icon: const Icon(
                            Icons.cameraswitch,
                            color: Colors.white,
                          ),
                          onPressed: _switchCamera,
                        ),

                      // End Call
                      GestureDetector(
                        onTap: () => _endCall(byRemote: false),
                        child: const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.call_end,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
