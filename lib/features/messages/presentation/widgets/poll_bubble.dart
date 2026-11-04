import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/message.dart';
import '../bloc/message_bloc.dart';
import '../bloc/message_event.dart';

class PollBubble extends StatefulWidget {
  final Message message;
  final String chatId;
  final String currentUserId;
  final bool isMe;
  final bool isChannelOwnerOrAdmin;

  const PollBubble({
    super.key,
    required this.message,
    required this.chatId,
    required this.currentUserId,
    required this.isMe,
    this.isChannelOwnerOrAdmin = false,
  });

  @override
  State<PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends State<PollBubble> {
  final Set<int> _tempSelectedOptions = {};

  @override
  void initState() {
    super.initState();
    _initSelections();
  }

  @override
  void didUpdateWidget(covariant PollBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.poll != widget.message.poll) {
      _initSelections();
    }
  }

  void _initSelections() {
    final poll = widget.message.poll;
    if (poll != null) {
      _tempSelectedOptions.clear();
      _tempSelectedOptions.addAll(poll.getUserSelectedOptionIds(widget.currentUserId));
    }
  }

  void _onVoteSingle(int optionId) {
    final poll = widget.message.poll;
    if (poll == null || poll.isClosed) return;

    context.read<MessageBloc>().add(
          VotePollRequested(
            chatId: widget.chatId,
            messageId: widget.message.id,
            userId: widget.currentUserId,
            selectedOptionIds: [optionId],
          ),
        );
  }

  void _onToggleMultiOption(int optionId) {
    final poll = widget.message.poll;
    if (poll == null || poll.isClosed) return;

    setState(() {
      if (_tempSelectedOptions.contains(optionId)) {
        _tempSelectedOptions.remove(optionId);
      } else {
        _tempSelectedOptions.add(optionId);
      }
    });
  }

  void _onSubmitMultiVote() {
    final poll = widget.message.poll;
    if (poll == null || poll.isClosed) return;

    context.read<MessageBloc>().add(
          VotePollRequested(
            chatId: widget.chatId,
            messageId: widget.message.id,
            userId: widget.currentUserId,
            selectedOptionIds: _tempSelectedOptions.toList(),
          ),
        );
  }

  void _onRetractVote() {
    final poll = widget.message.poll;
    if (poll == null || poll.isClosed) return;

    context.read<MessageBloc>().add(
          VotePollRequested(
            chatId: widget.chatId,
            messageId: widget.message.id,
            userId: widget.currentUserId,
            selectedOptionIds: const [],
          ),
        );
  }

  void _onClosePoll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate("end_poll_title")),
        content: Text(
            LocalizationService.translate("end_poll_confirm_desc")),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate("cancel")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<MessageBloc>().add(
                    ClosePollRequested(
                      chatId: widget.chatId,
                      messageId: widget.message.id,
                    ),
                  );
            },
            child: Text(LocalizationService.translate("end_poll_action"), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.message.poll;
    if (poll == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasVoted = poll.hasVoted(widget.currentUserId);
    final canClose = (poll.creatorId == widget.currentUserId ||
            widget.isChannelOwnerOrAdmin) &&
        !poll.isClosed;

    final mySelected = poll.getUserSelectedOptionIds(widget.currentUserId);
    final isSelectionChanged =
        !_tempSelectedOptions.containsAll(mySelected) ||
            !mySelected.toSet().containsAll(_tempSelectedOptions);

    return Container(
      width: 290,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Type badge & status
          Row(
            children: [
              Icon(
                poll.isClosed
                    ? Icons.lock_outline_rounded
                    : (poll.isQuiz
                        ? Icons.lightbulb_outline_rounded
                        : (poll.isAnonymous
                            ? Icons.visibility_off_outlined
                            : Icons.how_to_vote_outlined)),
                size: 14,
                color: poll.isClosed
                    ? Colors.grey
                    : (poll.isQuiz ? Colors.amber : AppColors.primary),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  poll.isClosed
                      ? LocalizationService.translate("poll_closed")
                      : (poll.isQuiz
                          ? LocalizationService.translate("poll_quiz")
                          : (poll.isAnonymous
                              ? LocalizationService.translate("poll_anonymous")
                              : LocalizationService.translate("poll_public"))),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: poll.isClosed
                        ? Colors.grey
                        : (poll.isQuiz
                            ? Colors.amber.shade700
                            : AppColors.primary),
                  ),
                ),
              ),
              if (canClose) ...[
                GestureDetector(
                  onTap: _onClosePoll,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stop_circle_outlined,
                            size: 11, color: AppColors.error),
                        const SizedBox(width: 3),
                        Text(
                          LocalizationService.translate("close_poll"),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Question
          Text(
            poll.question,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),

          if (poll.allowsMultipleAnswers && !poll.isClosed && !poll.isQuiz) ...[
            const SizedBox(height: 4),
            Text(
              LocalizationService.translate("multiple_choice_hint"),
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Options
          ...poll.options.map((option) {
            final isUserVotedForThis = option.hasUserVoted(widget.currentUserId);
            final percentage = poll.getPercentage(option.id);
            final percentInt = (percentage * 100).round();

            // Quiz logic:
            final bool isQuizOptionCorrect =
                poll.isQuiz && poll.correctOptionId == option.id;
            final bool showQuizResult = poll.isQuiz && (hasVoted || poll.isClosed);

            Color optionBgColor;
            Color progressColor;
            Color borderColor;

            if (showQuizResult) {
              if (isQuizOptionCorrect) {
                optionBgColor = const Color(0xFF10B981).withOpacity(0.12);
                progressColor = const Color(0xFF10B981).withOpacity(0.35);
                borderColor = const Color(0xFF10B981);
              } else if (isUserVotedForThis) {
                optionBgColor = AppColors.error.withOpacity(0.12);
                progressColor = AppColors.error.withOpacity(0.35);
                borderColor = AppColors.error;
              } else {
                optionBgColor = isDark
                    ? const Color(0xFF0F172A).withOpacity(0.4)
                    : const Color(0xFFF1F5F9);
                progressColor = isDark ? Colors.white10 : Colors.black12;
                borderColor = Colors.transparent;
              }
            } else if (hasVoted || poll.isClosed) {
              if (isUserVotedForThis) {
                optionBgColor = AppColors.primary.withOpacity(0.10);
                progressColor = AppColors.primary.withOpacity(0.35);
                borderColor = AppColors.primary.withOpacity(0.5);
              } else {
                optionBgColor = isDark
                    ? const Color(0xFF0F172A).withOpacity(0.4)
                    : const Color(0xFFF1F5F9);
                progressColor = isDark ? Colors.white10 : Colors.black12;
                borderColor = Colors.transparent;
              }
            } else {
              // Not voted yet
              optionBgColor = isDark
                  ? const Color(0xFF0F172A).withOpacity(0.5)
                  : const Color(0xFFF1F5F9);
              progressColor = Colors.transparent;
              borderColor =
                  poll.allowsMultipleAnswers && _tempSelectedOptions.contains(option.id)
                      ? AppColors.primary
                      : (isDark ? Colors.white10 : Colors.black12);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: poll.isClosed
                    ? null
                    : (poll.allowsMultipleAnswers && !poll.isQuiz
                        ? () => _onToggleMultiOption(option.id)
                        : (hasVoted ? null : () => _onVoteSingle(option.id))),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: optionBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: borderColor,
                      width: borderColor == Colors.transparent ? 0.6 : 1.2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Progress bar animation
                      if (hasVoted || poll.isClosed) ...[
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: percentage),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return FractionallySizedBox(
                              widthFactor: val.clamp(0.0, 1.0),
                              child: Container(
                                height: 44,
                                color: progressColor,
                              ),
                            );
                          },
                        ),
                      ],

                      // Content row
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Selector indicator if not voted yet
                            if (!hasVoted && !poll.isClosed) ...[
                              if (poll.allowsMultipleAnswers && !poll.isQuiz) ...[
                                Icon(
                                  _tempSelectedOptions.contains(option.id)
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  size: 18,
                                  color: _tempSelectedOptions.contains(option.id)
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                              ] else ...[
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 10),
                            ],

                            // Option text
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isUserVotedForThis
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),

                            // Percentage & icons if voted
                            if (hasVoted || poll.isClosed) ...[
                              const SizedBox(width: 8),
                              if (showQuizResult) ...[
                                if (isQuizOptionCorrect) ...[
                                  const Icon(Icons.check_circle_rounded,
                                      size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                ] else if (isUserVotedForThis) ...[
                                  const Icon(Icons.cancel_rounded,
                                      size: 16, color: AppColors.error),
                                  const SizedBox(width: 4),
                                ],
                              ] else if (isUserVotedForThis) ...[
                                const Icon(Icons.check_circle_rounded,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                "$percentInt%",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Multiple choice submit button
          if (poll.allowsMultipleAnswers &&
              !poll.isClosed &&
              !poll.isQuiz &&
              !hasVoted &&
              _tempSelectedOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _onSubmitMultiVote,
                child: Text(
                  LocalizationService.translate("vote_action"),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // Multiple choice update vote button if already voted
          if (poll.allowsMultipleAnswers &&
              !poll.isClosed &&
              !poll.isQuiz &&
              hasVoted &&
              isSelectionChanged) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _onSubmitMultiVote,
                child: Text(
                  LocalizationService.translate("update_vote"),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          // Quiz explanation box (visible after answering or poll closed)
          if (poll.isQuiz &&
              poll.explanation != null &&
              poll.explanation!.trim().isNotEmpty &&
              (hasVoted || poll.isClosed)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        LocalizationService.translate("explanation_label"),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poll.explanation!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Footer: Total votes & Retract vote action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationService.plural("votes_count", poll.totalVoters),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              if (hasVoted && !poll.isClosed && !poll.isQuiz) ...[
                GestureDetector(
                  onTap: _onRetractVote,
                  child: Text(
                    LocalizationService.translate("retract_vote"),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withOpacity(0.85),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
