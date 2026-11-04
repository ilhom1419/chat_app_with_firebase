import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../domain/entities/voice_chat.dart';
import '../../domain/repositories/voice_chat_repository.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

class VoiceChatRoomPage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;

  const VoiceChatRoomPage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
  });

  @override
  State<VoiceChatRoomPage> createState() => _VoiceChatRoomPageState();
}

class _VoiceChatRoomPageState extends State<VoiceChatRoomPage>
    with TickerProviderStateMixin {
  MediaStream? _localAudioStream;
  bool _isSpeakerphone = true;
  late AnimationController _pulseController;
  late AnimationController _handPulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _handPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _joinRoomAndInitAudio();
  }

  Future<void> _joinRoomAndInitAudio() async {
    final repo = context.read<VoiceChatRepository>();
    await repo.joinVoiceChat(
      chatId: widget.chatId,
      userId: widget.currentUserId,
      userName: widget.currentUserName,
      userPhoto: widget.currentUserPhoto,
    );

    // Initial audio device route
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerphone);
    } catch (e) {
      debugPrint('Error setting speakerphone: $e');
    }
  }

  Future<void> _enableMicrophone() async {
    try {
      if (_localAudioStream == null) {
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
        setState(() {
          _localAudioStream = stream;
        });
      }
      _localAudioStream?.getAudioTracks().forEach((track) {
        track.enabled = true;
      });
      if (mounted) {
        await context.read<VoiceChatRepository>().toggleMute(
              chatId: widget.chatId,
              userId: widget.currentUserId,
              isMuted: false,
            );
        await context.read<VoiceChatRepository>().setSpeaking(
              chatId: widget.chatId,
              userId: widget.currentUserId,
              isSpeaking: true,
            );
      }
    } catch (e) {
      debugPrint('Error enabling microphone: $e');
    }
  }

  Future<void> _disableMicrophone() async {
    try {
      _localAudioStream?.getAudioTracks().forEach((track) {
        track.enabled = false;
      });
      if (mounted) {
        await context.read<VoiceChatRepository>().toggleMute(
              chatId: widget.chatId,
              userId: widget.currentUserId,
              isMuted: true,
            );
        await context.read<VoiceChatRepository>().setSpeaking(
              chatId: widget.chatId,
              userId: widget.currentUserId,
              isSpeaking: false,
            );
      }
    } catch (e) {
      debugPrint('Error disabling microphone: $e');
    }
  }

  void _toggleSpeakerphone() async {
    setState(() {
      _isSpeakerphone = !_isSpeakerphone;
    });
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerphone);
    } catch (e) {
      debugPrint('Error toggling speakerphone: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _handPulseController.dispose();
    try {
      _localAudioStream?.getTracks().forEach((track) => track.stop());
      _localAudioStream?.dispose();
    } catch (e) {
      debugPrint('Error disposing stream: $e');
    }
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    try {
      await context.read<VoiceChatRepository>().leaveVoiceChat(
            chatId: widget.chatId,
            userId: widget.currentUserId,
          );
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmEndLive(VoiceChat voiceChat) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(LocalizationService.translate('end_voice_chat_title'),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          LocalizationService.translate('end_voice_chat_desc'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context
                  .read<VoiceChatRepository>()
                  .endVoiceChat(voiceChat.chatId);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(LocalizationService.translate('end_action'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSpeakerActionsModal(
      VoiceChatParticipant speaker, bool isHostUser) {
    if (!isHostUser || speaker.userId == widget.currentUserId) return;

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  speaker.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.mic_off_rounded,
                    color: Colors.orangeAccent),
                title: Text(LocalizationService.translate('mute_mic_action'),
                    style: const TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await context.read<VoiceChatRepository>().toggleMute(
                        chatId: widget.chatId,
                        userId: speaker.userId,
                        isMuted: true,
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.headset_rounded,
                    color: Colors.redAccent),
                title: Text(LocalizationService.translate('move_to_listeners'),
                    style: const TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await context
                      .read<VoiceChatRepository>()
                      .revokeSpeakPermission(
                        chatId: widget.chatId,
                        targetUserId: speaker.userId,
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<VoiceChatRepository>();

    return StreamBuilder<VoiceChat?>(
      stream: repo.watchActiveVoiceChat(widget.chatId),
      builder: (context, snapshot) {
        final voiceChat = snapshot.data;
        if (voiceChat == null || !voiceChat.isActive) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F1A),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.headset_off_rounded,
                      size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    LocalizationService.translate('voice_chat_ended'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(LocalizationService.translate('leave_action'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final isHost = voiceChat.isUserHost(widget.currentUserId);
        final myParticipant = voiceChat.participants[widget.currentUserId];
        final canSpeak = myParticipant?.canSpeak ?? false;
        final isHandRaised = myParticipant?.isHandRaised ?? false;
        final isMuted = myParticipant?.isMuted ?? true;

        final speakers = voiceChat.speakers;
        final handRaised = voiceChat.handRaised;
        final listeners = voiceChat.listeners;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF161626),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        voiceChat.localizedTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  LocalizationService.of(context).get('participants_count_param', args: {'count': '${voiceChat.totalParticipants}'}),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: _leaveRoom,
                icon: const Icon(Icons.exit_to_app_rounded,
                    color: Colors.redAccent, size: 18),
                label: Text(
                  LocalizationService.of(context).get('leave_action'),
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 📋 Main scrollable room content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // 🎙️ Section 1: Spikerlar (Speakers)
                    _buildSectionHeader(LocalizationService.translate('voice_speakers_section', params: {'count': '${speakers.length}'})),
                    const SizedBox(height: 12),
                    _buildSpeakersGrid(speakers, isHost),

                    // ✋ Section 2: Qo'l ko'targanlar (Raised Hands)
                    if (handRaised.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(LocalizationService.translate('voice_raised_hands_section', params: {'count': '${handRaised.length}'})),
                      const SizedBox(height: 12),
                      _buildHandRaisedList(handRaised, isHost),
                    ],

                    // 🎧 Section 3: Tinglovchilar (Listeners)
                    const SizedBox(height: 24),
                    _buildSectionHeader(LocalizationService.translate('voice_listeners_section', params: {'count': '${listeners.length}'})),
                    const SizedBox(height: 12),
                    if (listeners.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            LocalizationService.translate('all_members_became_speakers'),
                            style:
                                const TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      _buildListenersGrid(listeners),
                  ],
                ),
              ),

              // 🎛️ Bottom Action Bar
              _buildBottomControls(
                isHost: isHost,
                canSpeak: canSpeak,
                isHandRaised: isHandRaised,
                isMuted: isMuted,
                voiceChat: voiceChat,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSpeakersGrid(
      List<VoiceChatParticipant> speakers, bool isHostUser) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: speakers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final speaker = speakers[index];
        final isSpeaking = speaker.isSpeaking;
        final hasPhoto =
            speaker.photo != null && speaker.photo!.isNotEmpty;

        return GestureDetector(
          onTap: () => _showSpeakerActionsModal(speaker, isHostUser),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Glowing animated ring when speaking
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale =
                          isSpeaking ? 1.0 + (_pulseController.value * 0.12) : 1.0;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSpeaking
                                  ? AppColors.online
                                  : (speaker.isMuted
                                      ? Colors.white24
                                      : AppColors.primary),
                              width: isSpeaking ? 3 : 2,
                            ),
                            boxShadow: isSpeaking
                                ? [
                                    BoxShadow(
                                      color: AppColors.online.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    },
                  ),

                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    backgroundImage: hasPhoto
                        ? (speaker.photo!.startsWith('data:image')
                            ? AppImage.provider(speaker.photo)
                            : NetworkImage(speaker.photo!))
                        : null,
                    child: !hasPhoto
                        ? Text(
                            speaker.name.isNotEmpty
                                ? speaker.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          )
                        : null,
                  ),

                  // Mic Status Icon Badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: speaker.isMuted
                            ? Colors.redAccent
                            : AppColors.online,
                        border: Border.all(
                            color: const Color(0xFF0F0F1A), width: 1.5),
                      ),
                      child: Icon(
                        speaker.isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                speaker.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: speaker.isHost
                      ? Colors.amber.withOpacity(0.2)
                      : AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  speaker.isHost ? 'Host' : 'Spiker',
                  style: TextStyle(
                    color: speaker.isHost ? Colors.amber : AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandRaisedList(
      List<VoiceChatParticipant> handRaised, bool isHostUser) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < handRaised.length; i++) ...[
            if (i > 0)
              Divider(
                color: Colors.white.withOpacity(0.08),
                height: 1,
                thickness: 1,
              ),
            VoiceChatHandRaisedItem(
              participant: handRaised[i],
              isHostUser: isHostUser,
              onApprove: () async {
                await context
                    .read<VoiceChatRepository>()
                    .grantSpeakPermission(
                      chatId: widget.chatId,
                      targetUserId: handRaised[i].userId,
                    );
              },
              onReject: () async {
                await context
                    .read<VoiceChatRepository>()
                    .lowerHand(
                      chatId: widget.chatId,
                      userId: handRaised[i].userId,
                    );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListenersGrid(List<VoiceChatParticipant> listeners) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listeners.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final listener = listeners[index];
        final hasPhoto =
            listener.photo != null && listener.photo!.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2E2E3E),
              backgroundImage: hasPhoto
                  ? (listener.photo!.startsWith('data:image')
                      ? AppImage.provider(listener.photo)
                      : NetworkImage(listener.photo!))
                  : null,
              child: !hasPhoto
                  ? Text(
                      listener.name.isNotEmpty
                          ? listener.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              listener.name,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomControls({
    required bool isHost,
    required bool canSpeak,
    required bool isHandRaised,
    required bool isMuted,
    required VoiceChat voiceChat,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Audio Route Toggle (Speakerphone vs Earpiece)
            IconButton(
              icon: Icon(
                _isSpeakerphone
                    ? Icons.volume_up_rounded
                    : Icons.phone_in_talk_rounded,
                color: Colors.white,
                size: 26,
              ),
              tooltip: _isSpeakerphone
                  ? LocalizationService.translate('speaker_phone')
                  : LocalizationService.translate('earpiece'),
              onPressed: _toggleSpeakerphone,
            ),

            // 2. Main Action: (Mic Toggle for Speakers) OR (Raise Hand for Listeners)
            if (canSpeak)
              GestureDetector(
                onTap: () {
                  if (isMuted) {
                    _enableMicrophone();
                  } else {
                    _disableMicrophone();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isMuted
                          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                          : [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isMuted ? Colors.redAccent : AppColors.online)
                            .withOpacity(0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              )
            else
              // Raise Hand Button for Listener
              GestureDetector(
                onTap: () async {
                  final repo = context.read<VoiceChatRepository>();
                  if (isHandRaised) {
                    await repo.lowerHand(
                      chatId: widget.chatId,
                      userId: widget.currentUserId,
                    );
                  } else {
                    await repo.raiseHand(
                      chatId: widget.chatId,
                      userId: widget.currentUserId,
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: _handPulseController,
                  builder: (context, child) {
                    final scale = isHandRaised
                        ? 1.0 + (_handPulseController.value * 0.08)
                        : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isHandRaised
                                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                : [AppColors.primary, const Color(0xFF6366F1)],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: (isHandRaised
                                      ? Colors.amber
                                      : AppColors.primary)
                                  .withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pan_tool_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isHandRaised
                                  ? LocalizationService.translate('lower_hand')
                                  : LocalizationService.translate('raise_hand_btn'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 3. Host Action: End Live broadcast
            if (isHost)
              IconButton(
                icon: const Icon(Icons.stop_circle_rounded,
                    color: Colors.redAccent, size: 30),
                tooltip: LocalizationService.translate('end_stream_tooltip'),
                onPressed: () => _confirmEndLive(voiceChat),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// Participant card inside the Raised Hands section of Live Voice Chat.
/// Provides a compact, balanced horizontal layout with accessible moderator actions.
class VoiceChatHandRaisedItem extends StatelessWidget {
  final VoiceChatParticipant participant;
  final bool isHostUser;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const VoiceChatHandRaisedItem({
    super.key,
    required this.participant,
    required this.isHostUser,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        participant.photo != null && participant.photo!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.of(context).textScaler;
        final isCompact = constraints.maxWidth < 280 ||
            (constraints.maxWidth < 330 && textScaler.scale(14) > 18);

        final avatar = CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary,
          backgroundImage: hasPhoto
              ? (participant.photo!.startsWith('data:image')
                  ? AppImage.provider(participant.photo)
                  : NetworkImage(participant.photo!))
              : null,
          child: !hasPhoto
              ? Text(
                  participant.name.isNotEmpty
                      ? participant.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                )
              : null,
        );

        final nameAndStatus = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              participant.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.pan_tool_rounded,
                  color: Colors.amber,
                  size: 13,
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'So\'z olmoqchi (Raised Hand)',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        );

        final actionsRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildActionButton(
              icon: Icons.check_rounded,
              color: AppColors.online,
              backgroundColor: AppColors.online.withOpacity(0.18),
              borderColor: AppColors.online.withOpacity(0.35),
              tooltip: LocalizationService.translate(
                  'voice_chat_approve_speaker'),
              semanticsLabel: LocalizationService.translate(
                  'voice_chat_approve_speaker'),
              onPressed: onApprove,
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              icon: Icons.close_rounded,
              color: Colors.redAccent,
              backgroundColor: Colors.redAccent.withOpacity(0.18),
              borderColor: Colors.redAccent.withOpacity(0.35),
              tooltip:
                  LocalizationService.translate('voice_chat_reject_speaker'),
              semanticsLabel:
                  LocalizationService.translate('voice_chat_reject_speaker'),
              onPressed: onReject,
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(child: nameAndStatus),
                      ],
                    ),
                    if (isHostUser) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionsRow,
                      ),
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: nameAndStatus),
                    if (isHostUser) ...[
                      const SizedBox(width: 10),
                      actionsRow,
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    required String tooltip,
    required String semanticsLabel,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
