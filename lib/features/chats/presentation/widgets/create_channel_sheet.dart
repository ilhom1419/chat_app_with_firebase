import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../core/localization/localization_service.dart';
import 'join_preview_sheet.dart';

class CreateChannelSheet extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const CreateChannelSheet({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<CreateChannelSheet> createState() => _CreateChannelSheetState();
}

class _CreateChannelSheetState extends State<CreateChannelSheet> {
  final _nameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  bool _isCreating = false;
  bool _isPublic = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onCreateChannel() async {
    final currentUserId = widget.currentUserId;
    final currentUserName = widget.currentUserName;

    final channelName = _nameController.text.trim();
    if (channelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(LocalizationService.translate('enter_channel_name_warn'))),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      // Creator is always participant, plus any selected subscribers
      final participants = [currentUserId, ..._selectedUserIds];
      final chatId = 'channel_${DateTime.now().millisecondsSinceEpoch}';

      // Aggregate participant names, photos, online states for serialization
      final userNames = <String, String>{
        currentUserId: currentUserName,
      };
      final userPhotos = <String, dynamic>{};
      final userOnlineStates = <String, bool>{};

      // Creator info
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data();
        userPhotos[currentUserId] = creatorData?['photoURL'];
        userOnlineStates[currentUserId] =
            creatorData?['isOnline'] as bool? ?? false;
      } else {
        userPhotos[currentUserId] = null;
        userOnlineStates[currentUserId] = false;
      }

      // Fetch names, photos, online states of other participants
      for (final id in _selectedUserIds) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          userNames[id] = data?['displayName'] as String? ?? 'User';
          userPhotos[id] = data?['photoURL'];
          userOnlineStates[id] = data?['isOnline'] as bool? ?? false;
        } else {
          userNames[id] = 'User';
          userPhotos[id] = null;
          userOnlineStates[id] = false;
        }
      }

      final unreadCount = <String, int>{};
      for (final id in participants) {
        unreadCount[id] = 0;
      }

      final code = InviteLinkService.generateInviteCode(isChannel: true);
      final inviteLink = InviteLinkService.formatInviteLink(code);

      final batch = FirebaseFirestore.instance.batch();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

      batch.set(chatRef, {
        'id': chatId,
        'participants': participants,
        'isGroup': false,
        'isChannel': true,
        'createdBy': currentUserId,
        'type': _isPublic ? 'public' : 'private',
        'inviteCode': code,
        'inviteLink': inviteLink,
        'groupName': channelName,
        'groupAvatar': null,
        'memberCount': participants.length,
        'slowModeSeconds': 0,
        'topicsEnabled': false,
        'signMessages': false,
        'lastMessage': 'Channel created by $currentUserName',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'userNames': userNames,
        'userPhotos': userPhotos,
        'userOnlineStates': userOnlineStates,
        'unreadCount': unreadCount,
      });

      // Creator Asoschi sifatida
      final ownerRef = chatRef.collection('members').doc(currentUserId);
      batch.set(ownerRef, {
        'userId': currentUserId,
        'displayName': currentUserName,
        'photoURL': userPhotos[currentUserId],
        'role': 'owner',
        'customTitle': '👑 Kanal Asoschisi',
        'joinedAt': FieldValue.serverTimestamp(),
        'permissions': {
          'canSendMessages': true,
          'canSendMedia': true,
          'canSendPolls': true,
          'canAddMembers': true,
          'canPinMessages': true,
          'canChangeInfo': true,
          'canManageTopics': true,
        },
      });

      // Boshqa a'zolar
      for (final id in _selectedUserIds) {
        final mRef = chatRef.collection('members').doc(id);
        batch.set(mRef, {
          'userId': id,
          'displayName': userNames[id] ?? 'User',
          'photoURL': userPhotos[id],
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'permissions': {
            'canSendMessages': false, // Kanallarda faqat adminlar post yozadi
            'canSendMedia': false,
            'canSendPolls': false,
            'canAddMembers': true,
            'canPinMessages': false,
            'canChangeInfo': false,
            'canManageTopics': false,
          },
        });
      }

      // Send initial system message
      final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
      final msgRef = chatRef.collection('messages').doc(msgId);
      batch.set(msgRef, {
        'id': msgId,
        'senderId': 'system',
        'text': 'Channel "$channelName" created.',
        'type': 'text',
        'isRead': false,
        'isDeleted': false,
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {},
      });

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Channel "$channelName" created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationService.translate('new_channel'),
                style: AppTextStyles.title().copyWith(fontSize: 18),
              ),
              if (_isCreating)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _onCreateChannel,
                  child: Text(
                    LocalizationService.translate('create_btn'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: LocalizationService.translate('channel_name_hint'),
              hintStyle:
                  TextStyle(color: isDark ? Colors.white38 : Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: Text(
              _isPublic
                  ? LocalizationService.translate('public_channel')
                  : LocalizationService.translate('private_channel'),
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _isPublic
                  ? LocalizationService.translate('public_channel_desc')
                  : LocalizationService.translate('private_channel_desc'),
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 11),
            ),
            value: _isPublic,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _isPublic = val;
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            LocalizationService.translate('select_participants'),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs
                    .where((doc) => doc.id != widget.currentUserId)
                    .toList();
                if (users.isEmpty) {
                  return const Center(child: Text('No users available.'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userDoc = users[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final displayName =
                        userData['displayName'] as String? ?? 'User';
                    final photoURL = userData['photoURL'] as String?;
                    final isSelected = _selectedUserIds.contains(userDoc.id);

                    final hasPhoto =
                        photoURL != null && photoURL.startsWith('data:image');
                    final gradient = AppColors.avatarGradients[
                        displayName.length % AppColors.avatarGradients.length];

                    return CheckboxListTile(
                      activeColor: AppColors.primary,
                      title: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: hasPhoto
                                  ? null
                                  : LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: hasPhoto
                                  ? AppImage.memory(
                                      photoURL,
                                      fit: BoxFit.cover,
                                      width: 36,
                                      height: 36,
                                    )
                                  : Center(
                                      child: Text(
                                        displayName.isNotEmpty
                                            ? displayName
                                                .substring(0, 1)
                                                .toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(displayName,
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black)),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(userDoc.id);
                          } else {
                            _selectedUserIds.remove(userDoc.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
