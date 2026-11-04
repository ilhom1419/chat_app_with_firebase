import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';
import '../../../chats/domain/repositories/chat_repository.dart';
import 'message_page.dart';

class PostCommentsPage extends StatefulWidget {
  final String chatId;
  final String channelName;
  final Message post;
  final String currentUserId;
  final String currentUserName;
  final MessageRepository messageRepository;
  final ChatRepository chatRepository;
  final String? linkedGroupId;

  const PostCommentsPage({
    super.key,
    required this.chatId,
    required this.channelName,
    required this.post,
    required this.currentUserId,
    required this.currentUserName,
    required this.messageRepository,
    required this.chatRepository,
    this.linkedGroupId,
  });

  @override
  State<PostCommentsPage> createState() => _PostCommentsPageState();
}

class _PostCommentsPageState extends State<PostCommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Message? _replyingToComment;
  String? _selectedImageBase64;
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
    );
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      setState(() {
        _selectedImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImageBase64 == null) return;
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      await widget.messageRepository.sendComment(
        chatId: widget.chatId,
        messageId: widget.post.id,
        senderId: widget.currentUserId,
        text: text,
        imageUrl: _selectedImageBase64,
        replyToMessageId: _replyingToComment?.id,
        authorName: widget.currentUserName,
      );

      _commentController.clear();
      setState(() {
        _replyingToComment = null;
        _selectedImageBase64 = null;
        _isSending = false;
      });

      // Scroll pastga
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.formatError(e))),
        );
      }
    }
  }

  void _showReactionSheet(Message comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: ['👍', '❤️', '🔥', '🎉', '👏', '😂', '😮', '😢'].map((emoji) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            widget.messageRepository.toggleCommentReaction(
                              chatId: widget.chatId,
                              messageId: widget.post.id,
                              commentId: comment.id,
                              userId: widget.currentUserId,
                              emoji: emoji,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: Text(LocalizationService.translate('reply')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _replyingToComment = comment);
                },
              ),
              if (comment.senderId == widget.currentUserId)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: Text(LocalizationService.translate('delete'), style: const TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.messageRepository.deleteComment(
                      widget.chatId,
                      widget.post.id,
                      comment.id,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.translate('comments'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.channelName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.linkedGroupId != null && widget.linkedGroupId!.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.forum_outlined, size: 16),
              label: Text(LocalizationService.translate('group_badge')),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MessagePage(
                      chatId: widget.linkedGroupId!,
                      otherUserName: '${widget.channelName} Discussion',
                      otherUserId: '',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Pinned Original Post Preview Bar
          _buildPostPreview(isDark),

          // Comments List
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: widget.messageRepository.getComments(widget.chatId, widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 44,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            LocalizationService.translate('no_comments_yet'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            LocalizationService.translate('be_first_to_comment'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _buildCommentItem(comment, isDark);
                  },
                );
              },
            ),
          ),

          // Bottom Input Bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildPostPreview(bool isDark) {
    String postSnippet = widget.post.text ?? '';
    if (postSnippet.isEmpty) {
      if (widget.post.imageUrl != null) postSnippet = LocalizationService.translate('photo_snippet');
      else if (widget.post.poll != null) postSnippet = '📊 ${LocalizationService.translate('poll_title')}: ${widget.post.poll!.question}';
      else postSnippet = 'Media post';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3.5,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.channelName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('dd.MM HH:mm').format(widget.post.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  postSnippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (widget.post.imageUrl != null) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                base64Decode(widget.post.imageUrl!.split(',').last),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentItem(Message comment, bool isDark) {
    final isMe = comment.senderId == widget.currentUserId;
    final timeStr = DateFormat('HH:mm').format(comment.timestamp);
    final hasReactions = comment.reactions.isNotEmpty;

    final reactionCounts = <String, int>{};
    for (final emoji in comment.reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onLongPress: () => _showReactionSheet(comment),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(comment.senderId).get(),
              builder: (context, snap) {
                String name = comment.authorName ?? 'User';
                String? photo;
                if (snap.hasData && snap.data!.exists) {
                  final uData = snap.data!.data() as Map<String, dynamic>?;
                  name = uData?['displayName'] as String? ?? name;
                  photo = uData?['photoURL'] as String?;
                }

                final hasPhoto = photo != null && photo.startsWith('data:image');
                final gradient = AppColors.avatarGradients[name.length % AppColors.avatarGradients.length];

                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: hasPhoto ? null : LinearGradient(colors: gradient),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: hasPhoto
                        ? Image.memory(
                            base64Decode(photo.split(',').last),
                            fit: BoxFit.cover,
                            width: 36,
                            height: 36,
                          )
                        : Center(
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),

            // Comment Content Box
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              comment.authorName ?? 'Foydalanuvchi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isMe ? AppColors.primary : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        if (comment.replyToMessageId != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Javob berildi',
                              style: TextStyle(fontSize: 10, color: AppColors.primary, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        if (comment.imageUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              base64Decode(comment.imageUrl!.split(',').last),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        if (comment.text != null && comment.text!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            comment.text!,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Reaction Badges
                  if (hasReactions) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: reactionCounts.entries.map((e) {
                        final hasMyReaction = comment.reactions[widget.currentUserId] == e.key;
                        return GestureDetector(
                          onTap: () {
                            widget.messageRepository.toggleCommentReaction(
                              chatId: widget.chatId,
                              messageId: widget.post.id,
                              commentId: comment.id,
                              userId: widget.currentUserId,
                              emoji: e.key,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasMyReaction
                                  ? AppColors.primary.withOpacity(0.2)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hasMyReaction ? AppColors.primary : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.key, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Text(
                                  '${e.value}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: hasMyReaction ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Replying Banner
            if (_replyingToComment != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        LocalizationService.of(context).get(
                          'reply_to_user',
                          args: {
                            'name': _replyingToComment!.authorName ?? LocalizationService.of(context).get('user'),
                            'text': _replyingToComment!.text ?? '',
                          },
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.primary),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyingToComment = null),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],

            // Selected Image Preview
            if (_selectedImageBase64 != null) ...[
              Container(
                height: 60,
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(_selectedImageBase64!.split(',').last),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImageBase64 = null),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Input Row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_rounded, color: AppColors.primary),
                  onPressed: _pickImage,
                  tooltip: LocalizationService.translate('attach_image_tooltip'),
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: LocalizationService.translate('leave_comment_hint'),
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, Color(0xFF6366F1)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: _sendComment,
                          tooltip: LocalizationService.translate('send_action'),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
