import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/voice_chat_repository.dart';
import '../pages/voice_chat_room_page.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

class StartVoiceChatDialog extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhoto;
  final bool isChannel;

  const StartVoiceChatDialog({
    super.key,
    required this.chatId,
    required this.chatTitle,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhoto,
    this.isChannel = false,
  });

  static Future<void> show({
    required BuildContext context,
    required String chatId,
    required String chatTitle,
    required String currentUserId,
    required String currentUserName,
    String? currentUserPhoto,
    bool isChannel = false,
  }) {
    return showDialog(
      context: context,
      builder: (_) => StartVoiceChatDialog(
        chatId: chatId,
        chatTitle: chatTitle,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserPhoto: currentUserPhoto,
        isChannel: isChannel,
      ),
    );
  }

  @override
  State<StartVoiceChatDialog> createState() => _StartVoiceChatDialogState();
}

class _StartVoiceChatDialogState extends State<StartVoiceChatDialog> {
  late final TextEditingController _titleController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.chatTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = context.read<VoiceChatRepository>();
      await repo.startVoiceChat(
        chatId: widget.chatId,
        title: title,
        hostId: widget.currentUserId,
        hostName: widget.currentUserName,
        hostPhoto: widget.currentUserPhoto,
        isChannel: widget.isChannel,
      );

      if (mounted) {
        Navigator.of(context).pop();
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            LocalizationService.translate('space_voice_chat'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isChannel
                ? LocalizationService.translate('voice_chat_channel_intro')
                : LocalizationService.translate('voice_chat_group_intro'),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: LocalizationService.translate('voice_chat_topic_label'),
              labelStyle:
                  TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            LocalizationService.translate('cancel'),
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _isLoading ? null : _start,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  LocalizationService.translate('start_stream_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
