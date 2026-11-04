import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/services/scheduled_message_service.dart';
import '../../domain/entities/scheduled_message.dart';

class ScheduledMessagesPage extends StatefulWidget {
  final String chatId;
  final String chatTitle;
  final ScheduledMessageService? serviceOverride;

  const ScheduledMessagesPage({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.serviceOverride,
  });

  @override
  State<ScheduledMessagesPage> createState() => _ScheduledMessagesPageState();
}

class _ScheduledMessagesPageState extends State<ScheduledMessagesPage> {
  late final ScheduledMessageService _service;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? ScheduledMessageService();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('HH:mm').format(dt);

    if (checkDate == today) {
      final todayStr = LocalizationService.currentLanguage == 'uz'
          ? 'Bugun'
          : LocalizationService.currentLanguage == 'ru'
              ? 'Сегодня'
              : 'Today';
      return '$todayStr, $timeStr';
    } else if (checkDate == tomorrow) {
      final tomorrowStr = LocalizationService.currentLanguage == 'uz'
          ? 'Ertaga'
          : LocalizationService.currentLanguage == 'ru'
              ? 'Завтра'
              : 'Tomorrow';
      return '$tomorrowStr, $timeStr';
    }
    return '${DateFormat('dd.MM.yyyy').format(dt)}, $timeStr';
  }

  Future<void> _cancelMessage(String userId, ScheduledMessage msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('cancel_scheduled_message')),
        content: Text(LocalizationService.translate('cancel_schedule_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocalizationService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(LocalizationService.translate('cancel_scheduled_message')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(msg.scheduledMessageId));

    try {
      final ok = await _service.cancelScheduledMessage(
        userId: userId,
        scheduledMessageId: msg.scheduledMessageId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? LocalizationService.translate('scheduled_message_canceled')
                : LocalizationService.translate('message_sent'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocalizationService.translate('schedule_failed')}: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(msg.scheduledMessageId));
      }
    }
  }

  Future<void> _sendNow(String userId, ScheduledMessage msg) async {
    setState(() => _processingIds.add(msg.scheduledMessageId));

    try {
      final ok = await _service.executeDueMessage(
        userId: userId,
        scheduledMessageId: msg.scheduledMessageId,
        forceSend: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? LocalizationService.translate('message_sent')
                : LocalizationService.translate('schedule_failed'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocalizationService.translate('schedule_failed')}: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(msg.scheduledMessageId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.uid : null;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(LocalizationService.translate('scheduled_messages')),
        ),
        body: const Center(child: Text('Authentication required')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.translate('scheduled_messages'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              widget.chatTitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<ScheduledMessage>>(
        stream: _service.watchPendingScheduledMessages(
          currentUserId,
          chatId: widget.chatId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFFF59E0B),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LocalizationService.translate('no_scheduled_messages'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: messages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isProcessing = _processingIds.contains(msg.scheduledMessageId);

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Time & Badges
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateTime(msg.scheduledAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        if (msg.isSilent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.notifications_off_rounded,
                                  size: 12,
                                  color: Color(0xFF38BDF8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  LocalizationService.translate('silent_notification'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isProcessing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Message text
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Send Now Button
                        TextButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _sendNow(currentUserId, msg),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                            LocalizationService.translate('send_now'),
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Cancel Button
                        TextButton.icon(
                          onPressed: isProcessing
                              ? null
                              : () => _cancelMessage(currentUserId, msg),
                          icon: const Icon(Icons.close_rounded,
                              size: 16, color: Colors.redAccent),
                          label: Text(
                            LocalizationService.translate('cancel'),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.redAccent),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
