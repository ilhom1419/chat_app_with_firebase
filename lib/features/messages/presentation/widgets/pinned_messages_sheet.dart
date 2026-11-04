import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/message.dart';

class PinnedMessagesSheet extends StatelessWidget {
  final List<Message> pinnedMessages;
  final bool canUnpin;
  final Function(Message message) onMessageSelected;
  final Function(Message message) onUnpin;

  const PinnedMessagesSheet({
    super.key,
    required this.pinnedMessages,
    required this.canUnpin,
    required this.onMessageSelected,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${LocalizationService.of(context).get('pinned_messages')} (${pinnedMessages.length})",
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      LocalizationService.of(context).get('close'),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            if (pinnedMessages.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    LocalizationService.of(context).get('no_pinned_messages'),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: pinnedMessages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final msg = pinnedMessages[index];

                    String preview = msg.text ?? '';
                    IconData icon = Icons.message_rounded;
                    if (msg.type == MessageType.image) {
                      preview = '📷 ${LocalizationService.of(context).get('photo')}';
                      icon = Icons.image_rounded;
                    } else if (msg.type == MessageType.video) {
                      preview = '🎥 ${LocalizationService.of(context).get('video')}';
                      icon = Icons.videocam_rounded;
                    } else if (msg.type == MessageType.voice) {
                      preview = '🎤 ${LocalizationService.of(context).get('voice_message')}';
                      icon = Icons.mic_rounded;
                    } else if (msg.type == MessageType.file) {
                      preview = '📄 ${msg.fileName ?? LocalizationService.of(context).get('file')}';
                      icon = Icons.description_rounded;
                    } else if (msg.type == MessageType.poll) {
                      preview = '📊 ${msg.poll?.question ?? LocalizationService.of(context).get('poll')}';
                      icon = Icons.poll_rounded;
                    } else if (msg.type == MessageType.sticker) {
                      preview = '🏷️ ${msg.text ?? LocalizationService.of(context).get('sticker')}';
                      icon = Icons.sticky_note_2_rounded;
                    } else if (msg.type == MessageType.gif) {
                      preview = '👾 GIF';
                      icon = Icons.gif_rounded;
                    }

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('d-MMM, HH:mm').format(msg.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      trailing: canUnpin
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: LocalizationService.translate('unpin_from_sheet'),
                              onPressed: () {
                                onUnpin(msg);
                              },
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        onMessageSelected(msg);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
