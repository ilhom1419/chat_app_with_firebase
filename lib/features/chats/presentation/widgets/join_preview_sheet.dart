import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../messages/presentation/pages/message_page.dart';

class InviteLinkService {
  static String generateInviteCode({required bool isChannel}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    final prefix = isChannel ? 'c_' : 'g_';
    final randomStr = String.fromCharCodes(
      Iterable.generate(
          12, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
    );
    return '$prefix$randomStr';
  }

  static String formatInviteLink(String code) {
    return 'https://chat.me/+$code';
  }

  static String extractCode(String input) {
    String clean = input.trim();
    if (clean.startsWith('https://')) clean = clean.substring(8);
    if (clean.startsWith('http://')) clean = clean.substring(7);

    if (clean.startsWith('chat.me/+')) {
      clean = clean.substring(9);
    } else if (clean.startsWith('chat.me/joinchat/')) {
      clean = clean.substring(17);
    } else if (clean.startsWith('chat.me/')) {
      clean = clean.substring(8);
    } else if (clean.startsWith('t.me/+')) {
      clean = clean.substring(6);
    } else if (clean.startsWith('t.me/joinchat/')) {
      clean = clean.substring(14);
    } else if (clean.startsWith('t.me/')) {
      clean = clean.substring(5);
    } else if (clean.startsWith('app://join/')) {
      clean = clean.substring(11);
    }

    if (clean.startsWith('+')) clean = clean.substring(1);
    if (clean.startsWith('@')) clean = clean.substring(1);

    if (clean.contains('?')) clean = clean.split('?').first;
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    return clean;
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> resolveChat(
      String rawInput) async {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    final code = extractCode(trimmed);
    final collection = FirebaseFirestore.instance.collection('chats');

    // 1. Direct match on inviteLink (exact input)
    try {
      final snap1 =
          await collection.where('inviteLink', isEqualTo: trimmed).limit(1).get();
      if (snap1.docs.isNotEmpty) return snap1.docs.first;
    } catch (_) {}

    // 2. Match on inviteCode
    if (code.isNotEmpty) {
      try {
        final snap2 =
            await collection.where('inviteCode', isEqualTo: code).limit(1).get();
        if (snap2.docs.isNotEmpty) return snap2.docs.first;
      } catch (_) {}

      // 3. Match on standardized chat.me inviteLink
      try {
        final snap3 = await collection
            .where('inviteLink', isEqualTo: 'https://chat.me/+$code')
            .limit(1)
            .get();
        if (snap3.docs.isNotEmpty) return snap3.docs.first;
      } catch (_) {}

      // 3b. Match on legacy t.me inviteLink
      try {
        final snap3b = await collection
            .where('inviteLink', isEqualTo: 'https://t.me/+$code')
            .limit(1)
            .get();
        if (snap3b.docs.isNotEmpty) return snap3b.docs.first;
      } catch (_) {}

      // 4. Match on legacy app://join/
      try {
        final snap4 = await collection
            .where('inviteLink', isEqualTo: 'app://join/$code')
            .limit(1)
            .get();
        if (snap4.docs.isNotEmpty) return snap4.docs.first;
      } catch (_) {}

      try {
        final snap4b = await collection
            .where('inviteLink', isEqualTo: 'app://join/channel_$code')
            .limit(1)
            .get();
        if (snap4b.docs.isNotEmpty) return snap4b.docs.first;
      } catch (_) {}

      // 4c. Match on public username
      try {
        final snapUser = await collection
            .where('username', isEqualTo: code)
            .limit(1)
            .get();
        if (snapUser.docs.isNotEmpty) return snapUser.docs.first;
      } catch (_) {}

      try {
        final snapUserLower = await collection
            .where('username', isEqualTo: code.toLowerCase())
            .limit(1)
            .get();
        if (snapUserLower.docs.isNotEmpty) return snapUserLower.docs.first;
      } catch (_) {}

      // 5. Try document ID directly
      try {
        final doc = await collection.doc(code).get();
        if (doc.exists) return doc;
      } catch (_) {}
    }

    // 6. Try raw input as doc id
    try {
      final doc = await collection.doc(trimmed).get();
      if (doc.exists) return doc;
    } catch (_) {}

    return null;
  }

  static Future<void> joinChat({
    required BuildContext context,
    required String chatId,
    required Map<String, dynamic> chatData,
    required String currentUserId,
    required String currentUserName,
  }) async {
    final participants = List<String>.from(chatData['participants'] ?? []);
    final isChannel = chatData['isChannel'] as bool? ?? false;

    if (!participants.contains(currentUserId)) {
      String? myPhoto;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        if (userDoc.exists) {
          myPhoto = userDoc.data()?['photoURL'] as String?;
        }
      } catch (_) {}

      final batch = FirebaseFirestore.instance.batch();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

      final updates = <String, dynamic>{
        'participants': FieldValue.arrayUnion([currentUserId]),
        'memberCount': FieldValue.increment(1),
        'userNames.$currentUserId': currentUserName,
        'unreadCount.$currentUserId': 0,
      };
      if (myPhoto != null) {
        updates['userPhotos.$currentUserId'] = myPhoto;
      }
      batch.update(chatRef, updates);

      // A'zolar subcollection'iga qo'shish
      final memberRef = chatRef.collection('members').doc(currentUserId);
      batch.set(memberRef, {
        'userId': currentUserId,
        'displayName': currentUserName,
        'photoURL': myPhoto,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'permissions': {
          'canSendMessages': true,
          'canSendMedia': true,
          'canSendPolls': true,
          'canAddMembers': true,
          'canPinMessages': false,
          'canChangeInfo': false,
          'canManageTopics': false,
        },
      }, SetOptions(merge: true));

      final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final msgRef = chatRef.collection('messages').doc(msgId);
      final joinText = isChannel
          ? '$currentUserName kanalga obuna bo\'ldi'
          : '$currentUserName guruhga taklif havolasi orqali qo\'shildi';

      batch.set(msgRef, {
        'id': msgId,
        'senderId': 'system',
        'text': joinText,
        'type': 'text',
        'isRead': false,
        'isDeleted': false,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      });

      await batch.commit();
    }
  }

  static Future<String> regenerateInviteLink({
    required String chatId,
    required bool isChannel,
  }) async {
    final newCode = generateInviteCode(isChannel: isChannel);
    final newLink = formatInviteLink(newCode);

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'inviteLink': newLink,
      'inviteCode': newCode,
    });

    return newLink;
  }
}

class TelegramJoinPreviewSheet extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> chatDoc;
  final String currentUserId;
  final String currentUserName;

  const TelegramJoinPreviewSheet({
    super.key,
    required this.chatDoc,
    required this.currentUserId,
    required this.currentUserName,
  });

  static Future<void> show({
    required BuildContext context,
    required DocumentSnapshot<Map<String, dynamic>> chatDoc,
    required String currentUserId,
    required String currentUserName,
  }) {
    return showKakkuFloatingBottomSheet(
      context: context,
      builder: (ctx) => TelegramJoinPreviewSheet(
        chatDoc: chatDoc,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
    );
  }

  @override
  State<TelegramJoinPreviewSheet> createState() =>
      _TelegramJoinPreviewSheetState();
}

class _TelegramJoinPreviewSheetState extends State<TelegramJoinPreviewSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.chatDoc.data() ?? {};
    final chatId = widget.chatDoc.id;
    final isChannel =
        (data['isChannel'] as bool? ?? false) || data['type'] == 'channel';
    final isGroup = !isChannel &&
        ((data['isGroup'] as bool? ?? false) || data['type'] == 'group');
    final groupName = data['groupName'] as String? ??
        (isChannel
            ? LocalizationService.translate('tab_channels')
            : LocalizationService.translate('tab_groups'));
    final avatar = data['groupAvatar'] as String?;
    final participants = List<String>.from(data['participants'] ?? []);
    final isAlreadyMember = participants.contains(widget.currentUserId);
    final type = data['type'] as String? ?? 'public';

    final hasPhoto = avatar != null && avatar.startsWith('data:image');
    final gradient = AppColors.avatarGradients[
        groupName.length % AppColors.avatarGradients.length];

    final memberCountText = isChannel
        ? LocalizationService.plural('subscribers_count', participants.length)
        : LocalizationService.plural('members_count', participants.length);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            // Telegram-style Avatar
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasPhoto
                    ? null
                    : LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasPhoto
                    ? AppImage.memory(
                        avatar,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        isChannel ? Icons.campaign_rounded : Icons.group_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              groupName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle / Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isChannel
                        ? Colors.blue.withOpacity(0.15)
                        : AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isChannel
                            ? Icons.campaign_outlined
                            : Icons.people_outline_rounded,
                        size: 14,
                        color: isChannel ? Colors.blue : AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isChannel
                            ? LocalizationService.translate('tab_channels')
                            : LocalizationService.translate('group_badge'),
                        style: TextStyle(
                          color: isChannel ? Colors.blue : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  memberCountText,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (type == 'private') ...[
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    LocalizationService.translate('private_badge'),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),

            // Primary Join or Open Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          if (!isAlreadyMember) {
                            await InviteLinkService.joinChat(
                              context: context,
                              chatId: chatId,
                              chatData: data,
                              currentUserId: widget.currentUserId,
                              currentUserName: widget.currentUserName,
                            );
                          }

                          if (mounted) {
                            Navigator.of(context).pop(); // Close sheet
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MessagePage(
                                  chatId: chatId,
                                  otherUserId: '',
                                  otherUserName: groupName,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(LocalizationService.formatError(e)),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAlreadyMember
                      ? const Color(0xFF10B981)
                      : (isChannel ? Colors.blue : AppColors.primary),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isAlreadyMember
                                ? Icons.chat_bubble_outline_rounded
                                : (isChannel
                                    ? Icons.campaign_rounded
                                    : Icons.group_add_rounded),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isAlreadyMember
                                ? (isChannel
                                    ? LocalizationService.translate('go_to_channel')
                                    : (isGroup
                                        ? LocalizationService.translate('go_to_group')
                                        : LocalizationService.translate('go_to_chat')))
                                : (isChannel
                                    ? LocalizationService.translate('join_channel')
                                    : LocalizationService.translate('join_group')),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  LocalizationService.translate('cancel'),
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
