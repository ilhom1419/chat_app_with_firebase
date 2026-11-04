import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/topic.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/localization/localization_service.dart';

class TopicsSheet extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String? activeTopicId;
  final bool canManageTopics;
  final ChatRepository chatRepository;
  final Function(Topic? selectedTopic) onTopicSelected;

  const TopicsSheet({
    super.key,
    required this.chatId,
    required this.currentUserId,
    this.activeTopicId,
    required this.canManageTopics,
    required this.chatRepository,
    required this.onTopicSelected,
  });

  @override
  State<TopicsSheet> createState() => _TopicsSheetState();
}

class _TopicsSheetState extends State<TopicsSheet> {
  void _showCreateTopicDialog() {
    final titleController = TextEditingController();
    String selectedEmoji = '💬';
    final emojis = ['💬', '📢', '❓', '💡', '🎉', '🚀', '📚', '🎮', '🎧', '⚡'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LocalizationService.translate('new_topic')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: LocalizationService.translate('topic_name_hint'),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              Text(LocalizationService.translate('choose_emoji'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: emojis.map((e) {
                  final isSel = selectedEmoji == e;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedEmoji = e),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary.withOpacity(0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: isSel
                            ? Border.all(color: AppColors.primary, width: 1.5)
                            : null,
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(LocalizationService.translate('cancel')),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final text = titleController.text.trim();
                if (text.isEmpty) return;
                Navigator.of(ctx).pop();
                await widget.chatRepository.createTopic(
                  chatId: widget.chatId,
                  title: text,
                  iconEmoji: selectedEmoji,
                  createdBy: widget.currentUserId,
                );
              },
              child: Text(LocalizationService.translate('create_btn'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
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

            // Top header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocalizationService.translate('topics_title'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (widget.canManageTopics) ...[
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: AppColors.primary, size: 24),
                      tooltip: LocalizationService.translate('new_topic'),
                      onPressed: _showCreateTopicDialog,
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // "All Messages" item
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.activeTopicId == null
                      ? AppColors.primary.withOpacity(0.18)
                      : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.forum_outlined,
                    color: AppColors.primary, size: 20),
              ),
              title: Text(LocalizationService.translate('all_messages'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(LocalizationService.translate('general_stream')),
              trailing: widget.activeTopicId == null
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                widget.onTopicSelected(null);
              },
            ),

            const Divider(height: 1),

            // Stream of topics
            Expanded(
              child: StreamBuilder<List<Topic>>(
                stream: widget.chatRepository.getTopics(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final topics = snapshot.data ?? [];
                  if (topics.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.topic_outlined,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 10),
                          Text(
                            LocalizationService.translate('no_topics_yet'),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (widget.canManageTopics) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(LocalizationService.translate('open_first_topic')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _showCreateTopicDialog,
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final topic = topics[index];
                      final isSelected = widget.activeTopicId == topic.id;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.18)
                                : (isDark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.04)),
                            shape: BoxShape.circle,
                          ),
                          child: Text(topic.iconEmoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                topic.title,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (topic.isPinned) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.push_pin_rounded,
                                  size: 14, color: AppColors.primary),
                            ],
                            if (topic.isClosed) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.lock_rounded,
                                  size: 14, color: Colors.grey),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          topic.lastMessage != null &&
                                  topic.lastMessage!.isNotEmpty
                              ? topic.lastMessage!
                              : (topic.isClosed
                                  ? LocalizationService.translate('topic_closed')
                                  : LocalizationService.translate('no_messages')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_rounded,
                                  color: AppColors.primary),
                              const SizedBox(width: 4),
                            ],
                            if (widget.canManageTopics) ...[
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded,
                                    size: 18),
                                onSelected: (val) async {
                                  if (val == 'pin') {
                                    await widget.chatRepository.pinTopic(
                                      chatId: widget.chatId,
                                      topicId: topic.id,
                                      isPinned: !topic.isPinned,
                                    );
                                  } else if (val == 'close') {
                                    await widget.chatRepository.closeTopic(
                                      chatId: widget.chatId,
                                      topicId: topic.id,
                                      isClosed: !topic.isClosed,
                                    );
                                  } else if (val == 'delete') {
                                    await widget.chatRepository.deleteTopic(
                                      chatId: widget.chatId,
                                      topicId: topic.id,
                                    );
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'pin',
                                    child: Text(topic.isPinned
                                        ? LocalizationService.translate('unpin_topic')
                                        : LocalizationService.translate('pin_topic')),
                                  ),
                                  PopupMenuItem(
                                    value: 'close',
                                    child: Text(topic.isClosed
                                        ? LocalizationService.translate('reopen_topic')
                                        : LocalizationService.translate('close_topic')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(LocalizationService.translate('delete_topic'),
                                        style: const TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onTopicSelected(topic);
                        },
                      );
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
