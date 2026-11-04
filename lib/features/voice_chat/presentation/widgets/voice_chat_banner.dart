import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/voice_chat.dart';
import '../../domain/repositories/voice_chat_repository.dart';
import '../pages/voice_chat_room_page.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

class VoiceChatBanner extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;

  const VoiceChatBanner({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
  });

  @override
  State<VoiceChatBanner> createState() => _VoiceChatBannerState();
}

class _VoiceChatBannerState extends State<VoiceChatBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<VoiceChatRepository>();

    return StreamBuilder<VoiceChat?>(
      stream: repo.watchActiveVoiceChat(widget.chatId),
      builder: (context, snapshot) {
        final voiceChat = snapshot.data;
        if (voiceChat == null || !voiceChat.isActive) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final speakerCount = voiceChat.speakers.length;
        final listenerCount = voiceChat.totalParticipants - speakerCount;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VoiceChatRoomPage(
                  chatId: widget.chatId,
                  currentUserId: widget.currentUserId,
                  currentUserName: widget.currentUserName,
                  currentUserPhoto: widget.currentUserPhoto,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1E1B4B),
                        const Color(0xFF312E81),
                      ]
                    : [
                        const Color(0xFFEEF2FF),
                        const Color(0xFFE0E7FF),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 🟢 Pulsing Live Indicator
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.2);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.online.withOpacity(0.2),
                          border: Border.all(
                            color: AppColors.online,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.online,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Info: Title and Participant count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              voiceChat.localizedTitle,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.online,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${LocalizationService.of(context).get('speakers_count', args: {'count': '$speakerCount'})} • ${LocalizationService.of(context).get('listeners_count', args: {'count': '$listenerCount'})}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // "Qo'shilish" (Join) Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VoiceChatRoomPage(
                          chatId: widget.chatId,
                          currentUserId: widget.currentUserId,
                          currentUserName: widget.currentUserName,
                          currentUserPhoto: widget.currentUserPhoto,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    LocalizationService.of(context).get('voice_chat_join_banner'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
