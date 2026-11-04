import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../shared/utils/app_image.dart';
import '../../domain/entities/chat_member.dart';
import '../../data/models/chat_member_model.dart';
import '../../domain/repositories/chat_repository.dart';
import '../widgets/member_permissions_sheet.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';
import 'channel_stats_page.dart';
import '../../../messages/presentation/pages/message_page.dart';
import '../../../voice_chat/presentation/widgets/start_voice_chat_dialog.dart';
import '../../../voice_chat/presentation/pages/voice_chat_room_page.dart';
import '../../data/services/chat_notification_service.dart';
import '../../../../core/services/app_share_service.dart';
import '../widgets/join_preview_sheet.dart';

class ChannelGroupProfilePage extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final ChatRepository chatRepository;

  const ChannelGroupProfilePage({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    required this.chatRepository,
  });

  @override
  State<ChannelGroupProfilePage> createState() =>
      _ChannelGroupProfilePageState();
}

class _ChannelGroupProfilePageState extends State<ChannelGroupProfilePage> {
  final ChatNotificationService _chatNotificationService =
      ChatNotificationService();
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _usernameController;

  String? _newAvatarBase64;
  bool _isPublic = true;
  int _slowModeSeconds = 0;
  bool _signMessages = false;
  bool _restrictContent = false;
  bool _topicsEnabled = false;
  String? _usernameError;
  bool _isCheckingUsername = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _usernameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _initEditFields(Map<String, dynamic> data) {
    _nameController.text = data['groupName'] as String? ?? '';
    _descriptionController.text = data['description'] as String? ?? '';
    _usernameController.text = data['username'] as String? ?? '';
    _isPublic = (data['type'] as String? ?? 'public') == 'public';
    _slowModeSeconds = (data['slowModeSeconds'] as num?)?.toInt() ?? 0;
    _signMessages = data['signMessages'] as bool? ?? false;
    _restrictContent = data['restrictContent'] as bool? ?? false;
    _topicsEnabled = data['topicsEnabled'] as bool? ?? false;
    _newAvatarBase64 = data['groupAvatar'] as String?;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      final base64Img = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _newAvatarBase64 = base64Img;
      });
    }
  }

  Future<bool> _validateUsername(String username, String currentChatId) async {
    final clean = username.trim().replaceAll('@', '').toLowerCase();
    if (clean.isEmpty) {
      setState(() => _usernameError = null);
      return true;
    }

    if (clean.length < 5 || clean.length > 32) {
      setState(() => _usernameError =
          LocalizationService.translate('username_char_limit'));
      return false;
    }

    final validCharacters = RegExp(r'^[a-z0-9_]+$');
    if (!validCharacters.hasMatch(clean)) {
      setState(() => _usernameError =
          LocalizationService.translate('username_allowed_chars'));
      return false;
    }

    setState(() => _isCheckingUsername = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty && snap.docs.first.id != currentChatId) {
        setState(() {
          _usernameError = LocalizationService.translate('username_taken');
          _isCheckingUsername = false;
        });
        return false;
      }

      setState(() {
        _usernameError = null;
        _isCheckingUsername = false;
      });
      return true;
    } catch (e) {
      setState(() {
        _usernameError =
            '${LocalizationService.translate('error_checking_username')}: $e';
        _isCheckingUsername = false;
      });
      return false;
    }
  }

  Future<void> _saveSettings(String currentChatId) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocalizationService.translate('name_cannot_be_empty'))),
      );
      return;
    }

    final usernameText = _usernameController.text.trim().replaceAll('@', '').toLowerCase();
    if (usernameText.isNotEmpty) {
      final isValid = await _validateUsername(usernameText, currentChatId);
      if (!isValid) return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.chatRepository.updateChatSettings(
        currentChatId,
        name: name,
        description: _descriptionController.text.trim(),
        avatar: _newAvatarBase64,
        isPublic: _isPublic,
        slowModeSeconds: _slowModeSeconds,
        topicsEnabled: _topicsEnabled,
        signMessages: _signMessages,
        restrictContent: _restrictContent,
        username: usernameText.isEmpty ? null : usernameText,
      );

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.translate('settings_saved'))),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocalizationService.formatError(e))),
        );
      }
    }
  }

  void _showEditDescriptionDialog(
      BuildContext context, String currentDescription,
      {bool isChannel = false}) {
    final controller = TextEditingController(text: currentDescription);
    bool isSavingDesc = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(LocalizationService.translate('edit_description')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: isChannel
                            ? LocalizationService.translate('channel_description')
                            : LocalizationService.translate('group_description'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingDesc
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: Text(LocalizationService.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: isSavingDesc
                      ? null
                      : () async {
                          final newDesc = controller.text.trim();
                          setDialogState(() => isSavingDesc = true);
                          try {
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(widget.chatId)
                                .update({'description': newDesc});

                            if (mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    LocalizationService.translate(
                                        'saved_successfully'),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSavingDesc = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${LocalizationService.translate('save_failed')}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                  child: isSavingDesc
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(LocalizationService.translate('save_description')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditUsernameDialog(BuildContext context, String? currentUsername,
      {bool isChannel = false}) {
    final controller = TextEditingController(text: currentUsername ?? '');
    String? localError;
    bool isSavingUser = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isChannel
                  ? LocalizationService.translate('channel_username')
                  : LocalizationService.translate('group_username')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      prefixText: '@',
                      hintText: LocalizationService.translate('username_hint_example'),
                      errorText: localError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (localError != null) {
                        setDialogState(() => localError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocalizationService.translate('username_char_limit'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : Colors.black54,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSavingUser
                      ? null
                      : () => Navigator.of(dialogCtx).pop(),
                  child: Text(LocalizationService.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: isSavingUser
                      ? null
                      : () async {
                          final clean = controller.text
                              .trim()
                              .replaceAll('@', '')
                              .toLowerCase();

                          if (clean.isNotEmpty) {
                            if (clean.length < 5 || clean.length > 32) {
                              setDialogState(() => localError =
                                  LocalizationService.translate(
                                      'invalid_username'));
                              return;
                            }
                            final regex = RegExp(r'^[a-z0-9_]+$');
                            if (!regex.hasMatch(clean)) {
                              setDialogState(() => localError =
                                  LocalizationService.translate(
                                      'invalid_username'));
                              return;
                            }

                            setDialogState(() => isSavingUser = true);
                            try {
                              final snap = await FirebaseFirestore.instance
                                  .collection('chats')
                                  .where('username', isEqualTo: clean)
                                  .limit(1)
                                  .get();

                              if (snap.docs.isNotEmpty &&
                                  snap.docs.first.id != widget.chatId) {
                                setDialogState(() {
                                  isSavingUser = false;
                                  localError = LocalizationService.translate(
                                      'username_taken');
                                });
                                return;
                              }
                            } catch (e) {
                              setDialogState(() {
                                isSavingUser = false;
                                localError = '$e';
                              });
                              return;
                            }
                          } else {
                            setDialogState(() => isSavingUser = true);
                          }

                          try {
                            if (clean.isEmpty) {
                              await FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(widget.chatId)
                                  .update({'username': FieldValue.delete()});
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(widget.chatId)
                                  .update({'username': clean});
                            }

                            if (mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    LocalizationService.translate(
                                        'saved_successfully'),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSavingUser = false;
                              localError = '$e';
                            });
                          }
                        },
                  child: isSavingUser
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(LocalizationService.translate('save_btn')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareGroup(
    String groupName,
    String? username,
    String inviteLink,
    bool isChannel,
  ) async {
    String validLink = '';
    if (username != null && username.trim().isNotEmpty) {
      validLink = 'https://chat.me/${username.trim()}';
    } else if (inviteLink.trim().isNotEmpty) {
      validLink = inviteLink.trim();
    } else {
      final code = InviteLinkService.generateInviteCode(isChannel: isChannel);
      validLink = InviteLinkService.formatInviteLink(code);
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'inviteCode': code,
          'inviteLink': validLink,
        });
      } catch (_) {}
    }

    final prefix = isChannel
        ? LocalizationService.translate('join_channel_msg',
            params: {'name': groupName})
        : LocalizationService.translate('join_group_msg',
            params: {'name': groupName});
    final shareText = '$prefix\n$validLink';

    await AppShareService.shareText(
      text: shareText,
      subject: groupName,
    );
  }

  Future<void> _syncMissingMembers(
    String chatId,
    List<String> missingUids,
    String? createdBy,
    Map<String, dynamic> userNames,
    Map<String, dynamic> userPhotos,
  ) async {
    for (final uid in missingUids) {
      try {
        final isOwnerMember = uid == createdBy;
        String dName = (userNames[uid] as String?) ?? '';
        String? pUrl = userPhotos[uid] as String?;

        if (dName.isEmpty) {
          final uDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (uDoc.exists) {
            dName = (uDoc.data()?['name'] as String?) ??
                (uDoc.data()?['displayName'] as String?) ??
                'User';
            pUrl ??= (uDoc.data()?['photoUrl'] as String?) ??
                (uDoc.data()?['photoURL'] as String?);
          }
        }
        if (dName.isEmpty) dName = 'User';

        final memberModel = ChatMemberModel(
          userId: uid,
          displayName: dName,
          photoURL: pUrl,
          role: isOwnerMember ? MemberRole.owner : MemberRole.member,
          permissions: isOwnerMember
              ? const MemberPermissions.admin()
              : const MemberPermissions(),
          joinedAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('members')
            .doc(uid)
            .set(memberModel.toFirestore(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  void _showAddParticipantSheet(
      BuildContext context, List<String> currentParticipants) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> selected = [];

    showKakkuFloatingBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LocalizationService.translate('add_participant'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                Navigator.of(ctx).pop();
                                for (final uid in selected) {
                                  try {
                                    final uDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .get();
                                    final uData = uDoc.data() ?? {};
                                    final uName =
                                        uData['displayName'] as String? ?? LocalizationService.translate('user');
                                    await widget.chatRepository.joinChat(
                                        widget.chatId, uid, uName);
                                  } catch (_) {}
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            LocalizationService.translate('members_added_count', params: {'count': selected.length}))),
                                  );
                                }
                              },
                        child: Text(LocalizationService.translate('add'),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final users = snap.data!.docs
                            .where((doc) => !currentParticipants.contains(doc.id))
                            .toList();

                        if (users.isEmpty) {
                          return Center(
                              child: Text(LocalizationService.translate('no_new_users_to_add')));
                        }

                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final uDoc = users[index];
                            final uData = uDoc.data() as Map<String, dynamic>;
                            final uName =
                                uData['displayName'] as String? ?? LocalizationService.translate('user');
                            final photo = uData['photoURL'] as String?;
                            final isSel = selected.contains(uDoc.id);

                            return CheckboxListTile(
                              activeColor: AppColors.primary,
                              value: isSel,
                              secondary: photo != null &&
                                      photo.startsWith('data:image')
                                  ? ClipOval(
                                      child: AppImage.memory(
                                        photo,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : null,
                              title: Text(uName),
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    selected.add(uDoc.id);
                                  } else {
                                    selected.remove(uDoc.id);
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, currentLang, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Scaffold(
                backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                appBar: AppBar(title: Text(LocalizationService.translate('profile_title'))),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final isChannel = data['isChannel'] as bool? ?? false;
        final isGroup = data['isGroup'] as bool? ?? false;
        final groupName =
            data['groupName'] as String? ?? (isChannel ? LocalizationService.translate('channel_fallback') : LocalizationService.translate('group_fallback'));
        final description = data['description'] as String? ?? '';
        final username = data['username'] as String?;
        final type = data['type'] as String? ?? 'public';
        final isPublicType = type == 'public';
        final photoURL = data['groupAvatar'] as String?;
        final participants = List<String>.from(data['participants'] ?? []);
        final memberCount = (data['memberCount'] as num?)?.toInt() ?? participants.length;
        final inviteLink = data['inviteLink'] as String? ?? '';
        final createdBy = data['createdBy'] as String?;
        final isOwner = createdBy == widget.currentUserId;
        final linkedGroupId = data['linkedGroupId'] as String?;
        final linkedGroupName = data['linkedGroupName'] as String?;

        final hasPhoto = photoURL != null && photoURL.startsWith('data:image');
        final gradient = AppColors.avatarGradients[
            groupName.length % AppColors.avatarGradients.length];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('members')
              .doc(widget.currentUserId)
              .snapshots(),
          builder: (context, myMemberSnap) {
            ChatMember? myMember;
            if (myMemberSnap.hasData && myMemberSnap.data!.exists) {
              myMember = ChatMemberModel.fromFirestore(myMemberSnap.data!);
            }
            final isAdmin = isOwner || (myMember?.isAdmin ?? false);

            return Scaffold(
              backgroundColor:
                  isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
              appBar: AppBar(
                backgroundColor:
                    isDark ? const Color(0xFF0F172A) : Colors.white,
                elevation: 0,
                title: Text(
                  isChannel ? LocalizationService.translate('channel_info') : LocalizationService.translate('group_info'),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  if (isAdmin)
                    if (_isEditing)
                      TextButton(
                        onPressed: _isSaving ? null : () => _saveSettings(widget.chatId),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(LocalizationService.translate('save'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                        tooltip: LocalizationService.translate('edit'),
                        onPressed: () {
                          _initEditFields(data);
                          setState(() => _isEditing = true);
                        },
                      ),
                ],
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // Top Hero Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 20),
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isEditing ? _pickAvatar : null,
                            child: Stack(
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    gradient: (_newAvatarBase64 != null || hasPhoto)
                                        ? null
                                        : LinearGradient(
                                            colors: gradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: (_newAvatarBase64 != null)
                                        ? AppImage.memory(
                                            _newAvatarBase64,
                                            fit: BoxFit.cover,
                                            width: 96,
                                            height: 96,
                                          )
                                        : (hasPhoto
                                            ? AppImage.memory(
                                                photoURL,
                                                fit: BoxFit.cover,
                                                width: 96,
                                                height: 96,
                                              )
                                            : Center(
                                                child: Text(
                                                  groupName.isNotEmpty
                                                      ? groupName
                                                          .substring(0, 1)
                                                          .toUpperCase()
                                                      : 'C',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 36,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              )),
                                  ),
                                ),
                                if (_isEditing)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded,
                                          color: Colors.white, size: 18),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Name display or Edit field
                          if (_isEditing)
                            TextField(
                              controller: _nameController,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: LocalizationService.translate('enter_name_hint'),
                                border: const UnderlineInputBorder(),
                              ),
                            )
                          else
                            Text(
                              groupName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),

                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isChannel
                                    ? LocalizationService.plural(
                                        'subscribers_count',
                                        memberCount)
                                    : LocalizationService.plural(
                                        'members_count',
                                        memberCount),
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPublicType
                                      ? Colors.blue.withOpacity(0.12)
                                      : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPublicType
                                      ? LocalizationService.translate('badge_public')
                                      : LocalizationService.translate('badge_private'),
                                  style: TextStyle(
                                    color: isPublicType ? Colors.blue : Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Quick Action Buttons (Horizontally scrollable)
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 86,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildQuickActionButton(
                                    icon: Icons.mic_rounded,
                                    label: LocalizationService.translate('live_voice_chat'),
                                    onTap: () async {
                                      final activeSnap = await FirebaseFirestore.instance
                                          .collection('voice_chats')
                                          .doc(widget.chatId)
                                          .get();
                                      final isActive = activeSnap.exists &&
                                          (activeSnap.data()?['isActive'] as bool? ?? false);

                                      if (context.mounted) {
                                        if (isActive) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => VoiceChatRoomPage(
                                                chatId: widget.chatId,
                                                currentUserId: widget.currentUserId,
                                                currentUserName: widget.currentUserName,
                                              ),
                                            ),
                                          );
                                        } else {
                                          StartVoiceChatDialog.show(
                                            context: context,
                                            chatId: widget.chatId,
                                            chatTitle: groupName,
                                            currentUserId: widget.currentUserId,
                                            currentUserName: widget.currentUserName,
                                            isChannel: isChannel,
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  StreamBuilder<bool>(
                                    stream:
                                        _chatNotificationService.watchMuteStatus(
                                      widget.currentUserId,
                                      widget.chatId,
                                    ),
                                    initialData:
                                        ChatNotificationService.isChatMuted(
                                      widget.chatId,
                                      userId: widget.currentUserId,
                                    ),
                                    builder: (context, muteSnap) {
                                      final isMuted = muteSnap.data ?? false;
                                      return _buildQuickActionButton(
                                        icon: isMuted
                                            ? Icons.notifications_off_outlined
                                            : Icons.notifications_outlined,
                                        label: isMuted
                                            ? (isChannel
                                                ? LocalizationService.translate('unmute_channel')
                                                : LocalizationService.translate('unmute_group'))
                                            : (isChannel
                                                ? LocalizationService.translate('mute_channel')
                                                : LocalizationService.translate('mute_group')),
                                        onTap: () async {
                                          try {
                                            final newStatus =
                                                await _chatNotificationService
                                                    .toggleMute(
                                              widget.currentUserId,
                                              widget.chatId,
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    LocalizationService.translate(
                                                      newStatus
                                                          ? (isChannel ? 'channel_muted' : 'group_muted')
                                                          : (isChannel ? 'channel_unmuted' : 'group_unmuted'),
                                                    ),
                                                  ),
                                                  duration:
                                                      const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${LocalizationService.translate('save_failed')}: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  _buildQuickActionButton(
                                    icon: Icons.share_rounded,
                                    label: isChannel
                                        ? LocalizationService.translate('share_channel')
                                        : LocalizationService.translate('share_group'),
                                    onTap: () => _shareGroup(
                                      groupName,
                                      username,
                                      inviteLink,
                                      isChannel,
                                    ),
                                  ),
                                  if (isAdmin)
                                    _buildQuickActionButton(
                                      icon: Icons.bar_chart_rounded,
                                      label: LocalizationService.translate('stats_title'),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChannelStatsPage(
                                              chatId: widget.chatId,
                                              chatName: groupName,
                                              isChannel: isChannel,
                                              memberCount: memberCount,
                                              chatRepository: widget.chatRepository,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (isAdmin)
                                    _buildQuickActionButton(
                                      icon: Icons.person_add_alt_1_rounded,
                                      label: LocalizationService.translate('add_participant'),
                                      onTap: () => _showAddParticipantSheet(
                                          context, participants),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Information Card (Description, Username, Link)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tavsif (Description)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isChannel
                                    ? LocalizationService.translate('channel_description')
                                    : LocalizationService.translate('group_description'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isAdmin && !_isEditing)
                                GestureDetector(
                                  onTap: () => _showEditDescriptionDialog(
                                      context, description,
                                      isChannel: isChannel),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        LocalizationService.translate(
                                            'edit_description'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_isEditing)
                            TextField(
                              controller: _descriptionController,
                              maxLines: 3,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: LocalizationService.translate('description_hint'),
                                border: const OutlineInputBorder(),
                              ),
                            )
                          else
                            InkWell(
                              onTap: isAdmin
                                  ? () => _showEditDescriptionDialog(
                                      context, description,
                                      isChannel: isChannel)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  description.isEmpty
                                      ? LocalizationService.translate(
                                          'description_not_set')
                                      : description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: description.isEmpty
                                        ? (isDark
                                            ? Colors.white38
                                            : Colors.black38)
                                        : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          const Divider(height: 24),

                          // Username / Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                LocalizationService.translate('link_and_username'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark ? Colors.white54 : Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isAdmin && !_isEditing && isPublicType)
                                GestureDetector(
                                  onTap: () => _showEditUsernameDialog(
                                      context, username,
                                      isChannel: isChannel),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit_outlined,
                                          size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        (username != null &&
                                                username.isNotEmpty)
                                            ? LocalizationService.translate(
                                                'edit_description')
                                            : LocalizationService.translate(
                                                'setup_action'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_isEditing && isPublicType) ...[
                            TextField(
                              controller: _usernameController,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                prefixText: '@',
                                hintText: LocalizationService.translate('username_hint_example'),
                                errorText: _usernameError,
                                suffixIcon: _isCheckingUsername
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                _validateUsername(val, widget.chatId);
                              },
                            ),
                            const SizedBox(height: 12),
                          ] else if (isPublicType) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                  Icons.alternate_email_rounded,
                                  color: Colors.blue),
                              title: Text(
                                (username != null && username.isNotEmpty)
                                    ? '@$username'
                                    : LocalizationService.translate(
                                        'username_not_set'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (username != null &&
                                          username.isNotEmpty)
                                      ? Colors.blue
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.black38),
                                ),
                              ),
                              subtitle: (isAdmin &&
                                      (username == null || username.isEmpty))
                                  ? Text(LocalizationService.translate('tap_to_set'),
                                      style: const TextStyle(fontSize: 11))
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (username != null &&
                                      username.isNotEmpty) ...[
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded,
                                          size: 20),
                                      tooltip: LocalizationService.translate(
                                          'copy_link'),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: '@$username'));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                LocalizationService.translate(
                                                    'link_copied')),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share_rounded,
                                          size: 20),
                                      tooltip: isChannel
                                          ? LocalizationService.translate('share_channel')
                                          : LocalizationService.translate('share_group'),
                                      onPressed: () => _shareGroup(
                                        groupName,
                                        username,
                                        inviteLink,
                                        isChannel,
                                      ),
                                    ),
                                  ],
                                  if (isAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      tooltip: LocalizationService.translate('edit'),
                                      onPressed: () => _showEditUsernameDialog(
                                          context, username,
                                          isChannel: isChannel),
                                    ),
                                ],
                              ),
                              onTap: isAdmin
                                  ? () => _showEditUsernameDialog(
                                      context, username,
                                      isChannel: isChannel)
                                  : null,
                            ),
                          ],

                          if (inviteLink.isNotEmpty || isAdmin)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.link_rounded,
                                  color: AppColors.primary),
                              title: Text(
                                inviteLink.isNotEmpty
                                    ? inviteLink
                                    : LocalizationService.translate('create_link'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: inviteLink.isNotEmpty
                                      ? null
                                      : Colors.blue,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (inviteLink.isNotEmpty) ...[
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded,
                                          size: 20),
                                      tooltip: LocalizationService.translate(
                                          'copy_link'),
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: inviteLink));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                LocalizationService.translate(
                                                    'link_copied')),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share_rounded,
                                          size: 20),
                                      tooltip: isChannel
                                          ? LocalizationService.translate('share_channel')
                                          : LocalizationService.translate('share_group'),
                                      onPressed: () => _shareGroup(
                                        groupName,
                                        username,
                                        inviteLink,
                                        isChannel,
                                      ),
                                    ),
                                  ],
                                  if (inviteLink.isEmpty && isAdmin)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.add_link_rounded,
                                          size: 20,
                                          color: Colors.blue),
                                      onPressed: () => _shareGroup(
                                        groupName,
                                        username,
                                        inviteLink,
                                        isChannel,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: (inviteLink.isEmpty && isAdmin)
                                  ? () => _shareGroup(
                                        groupName,
                                        username,
                                        inviteLink,
                                        isChannel,
                                      )
                                  : null,
                            ),
                        ],
                      ),
                    ),

                    // Linked Discussion Group Card (Munozara guruhi)
                    if (isChannel) ...[
                      const SizedBox(height: 12),
                      _buildDiscussionGroupSection(
                        context: context,
                        isDark: isDark,
                        isAdmin: isAdmin,
                        channelId: widget.chatId,
                        channelName: groupName,
                        linkedGroupId: linkedGroupId,
                        linkedGroupName: linkedGroupName,
                      ),
                    ],

                    // Admin Settings in Edit Mode (Type, Slow Mode, Sign Messages)
                    if (_isEditing && isAdmin) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService.translate('additional_settings'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            // Public/Private Switch
                            SwitchListTile(
                              title: Text(LocalizationService.translate('public_channel_group')),
                              subtitle: Text(
                                  LocalizationService.translate('public_channel_group_desc')),
                              value: _isPublic,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() => _isPublic = val);
                              },
                            ),

                            // Slow Mode (only for groups)
                            if (isGroup) ...[
                              const Divider(),
                              ListTile(
                                title: Text(LocalizationService.translate('slow_mode')),
                                subtitle: Text(_slowModeSeconds == 0
                                    ? LocalizationService.translate('timer_off')
                                    : '$_slowModeSeconds s'),
                              ),
                              Slider(
                                value: _slowModeSeconds.toDouble(),
                                min: 0,
                                max: 300,
                                divisions: 5,
                                label: _slowModeSeconds == 0
                                    ? 'Off'
                                    : '${_slowModeSeconds}s',
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _slowModeSeconds = val.toInt());
                                },
                              ),
                              const Divider(),
                              SwitchListTile(
                                title: Text(LocalizationService.translate('topics_forum')),
                                subtitle: Text(
                                    LocalizationService.translate('topics_forum_desc')),
                                value: _topicsEnabled,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _topicsEnabled = val);
                                },
                              ),
                            ],

                            // Sign Messages (only for channels)
                            if (isChannel) ...[
                              const Divider(),
                              SwitchListTile(
                                title: Text(LocalizationService.translate('sign_messages')),
                                subtitle: Text(
                                    LocalizationService.translate('sign_messages_desc')),
                                value: _signMessages,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _signMessages = val);
                                },
                              ),
                            ],

                            // Restrict Content (Channels and Groups)
                            const Divider(),
                            SwitchListTile(
                              title: Text(LocalizationService.translate('protect_content')),
                              subtitle: Text(
                                  LocalizationService.translate('protect_content_desc')),
                              value: _restrictContent,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() => _restrictContent = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Members List Section
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${LocalizationService.translate('members_and_administrators')} ($memberCount)',
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isAdmin)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    LocalizationService.translate('add'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => _showAddParticipantSheet(
                                      context, participants),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('chats')
                                .doc(widget.chatId)
                                .collection('members')
                                .snapshots(),
                            builder: (context, memberSnap) {
                              if (memberSnap.hasError) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    LocalizationService.translate(
                                        'failed_load_members'),
                                    style: const TextStyle(
                                        color: Colors.redAccent),
                                  ),
                                );
                              }

                              if (memberSnap.connectionState ==
                                      ConnectionState.waiting &&
                                  !memberSnap.hasData) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(LocalizationService.translate(
                                            'loading_members')),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final Map<String, ChatMember> membersMap = {};
                              if (memberSnap.hasData) {
                                for (final doc in memberSnap.data!.docs) {
                                  try {
                                    membersMap[doc.id] =
                                        ChatMemberModel.fromFirestore(doc);
                                  } catch (_) {}
                                }
                              }

                              final userNamesMap = (data['userNames']
                                      as Map<String, dynamic>?) ??
                                  {};
                              final userPhotosMap = (data['userPhotos']
                                      as Map<String, dynamic>?) ??
                                  {};

                              // Merge all participants so member count and member list are 100% consistent!
                              final missingUids = <String>[];
                              for (final uid in participants) {
                                if (!membersMap.containsKey(uid)) {
                                  missingUids.add(uid);
                                  final isOwnerMember = uid == createdBy;
                                  final dName = (userNamesMap[uid]
                                          as String?) ??
                                      (uid == widget.currentUserId
                                          ? widget.currentUserName
                                          : LocalizationService.translate('user'));
                                  final pUrl = userPhotosMap[uid] as String?;

                                  membersMap[uid] = ChatMember(
                                    userId: uid,
                                    displayName: dName,
                                    photoURL: pUrl,
                                    role: isOwnerMember
                                        ? MemberRole.owner
                                        : MemberRole.member,
                                    joinedAt: DateTime.now(),
                                  );
                                }
                              }

                              if (missingUids.isNotEmpty && isAdmin) {
                                _syncMissingMembers(
                                  widget.chatId,
                                  missingUids,
                                  createdBy,
                                  userNamesMap,
                                  userPhotosMap,
                                );
                              }

                              if (membersMap.isEmpty) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(LocalizationService.translate(
                                      'no_members')),
                                );
                              }

                              final members = membersMap.values.toList();
                              members.sort((a, b) {
                                if (a.isOwner) return -1;
                                if (b.isOwner) return 1;
                                if (a.isAdmin && !b.isAdmin) return -1;
                                if (!a.isAdmin && b.isAdmin) return 1;
                                return a.displayName.compareTo(b.displayName);
                              });

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: members.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final m = members[index];
                                  final isOwnerMember =
                                      m.isOwner || m.userId == createdBy;
                                  final hasPhoto = m.photoURL != null &&
                                      m.photoURL!.isNotEmpty;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: hasPhoto
                                        ? ClipOval(
                                            child: AppImage.memory(
                                              m.photoURL!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : CircleAvatar(
                                            backgroundColor:
                                                AppColors.primary,
                                            radius: 20,
                                            child: Text(
                                              m.displayName.isNotEmpty
                                                  ? m.displayName
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
                                          ),
                                    title: Text(
                                      m.displayName +
                                          (m.userId == widget.currentUserId
                                              ? LocalizationService.translate('you_suffix')
                                              : ''),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      m.customTitle ??
                                          (isOwnerMember
                                              ? (isChannel
                                                  ? LocalizationService.translate('channel_owner')
                                                  : LocalizationService.translate('group_owner'))
                                              : (m.isAdmin
                                                  ? LocalizationService
                                                      .translate(
                                                          'administrators')
                                                  : LocalizationService
                                                      .translate(
                                                          'role_member'))),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isOwnerMember)
                                          Text(LocalizationService.translate('owner_badge'),
                                              style: const TextStyle(
                                                  color: Colors.amber,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 12))
                                        else if (m.isAdmin)
                                          Text(LocalizationService.translate('admin_badge'),
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 12)),
                                        if ((isAdmin || isOwner) &&
                                            !isOwnerMember) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 18,
                                              color: Colors.grey),
                                        ],
                                      ],
                                    ),
                                    onTap: (isAdmin || isOwner)
                                        ? () {
                                            showKakkuFloatingBottomSheet(
                                              context: context,
                                              builder: (ctx) =>
                                                  MemberPermissionsSheet(
                                                chatId: widget.chatId,
                                                member: m,
                                                isViewerOwner: isOwner,
                                                isViewerAdmin: isAdmin,
                                                isChannel: isChannel,
                                                chatRepository:
                                                    widget.chatRepository,
                                              ),
                                            );
                                          }
                                        : null,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Danger Zone / Exit Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: isOwner
                          ? ElevatedButton.icon(
                              icon: const Icon(Icons.delete_forever_rounded,
                                  color: Colors.white),
                              label: Text(
                                isChannel
                                    ? LocalizationService.translate(
                                        'delete_channel_permanently')
                                    : LocalizationService.translate(
                                        'delete_group_permanently'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                _confirmDeleteChat(
                                    context, widget.chatId, isChannel, groupName);
                              },
                            )
                          : OutlinedButton.icon(
                              icon: const Icon(Icons.exit_to_app_rounded,
                                  color: Colors.redAccent),
                              label: Text(
                                isChannel
                                    ? LocalizationService.translate(
                                        'leave_channel_btn')
                                    : LocalizationService.translate(
                                        'leave_group_btn'),
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                _confirmLeaveChat(
                                    context, widget.chatId, isChannel, groupName);
                              },
                            ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  },
);
}

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChat(
      BuildContext context, String chatId, bool isChannel, String chatName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isChannel
            ? LocalizationService.translate('delete_channel')
            : LocalizationService.translate('delete_group')),
        content: Text(isChannel
            ? LocalizationService.translate('delete_channel_confirm_named',
                params: {'name': chatName})
            : LocalizationService.translate('delete_group_confirm_named',
                params: {'name': chatName})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop(); // dialog
              try {
                await widget.chatRepository.deleteChat(chatId);
                if (mounted) {
                  Navigator.of(context).pop(); // profile page
                  Navigator.of(context).pop(); // message page -> back to chat list
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${LocalizationService.translate('save_failed')}: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(LocalizationService.translate('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveChat(
      BuildContext context, String chatId, bool isChannel, String chatName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isChannel
            ? LocalizationService.translate('leave_channel')
            : LocalizationService.translate('leave_group')),
        content: Text(isChannel
            ? LocalizationService.translate('leave_channel_confirm')
            : LocalizationService.translate('leave_group_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.chatRepository
                    .leaveChat(chatId, widget.currentUserId);
                if (mounted) {
                  Navigator.of(context).pop(); // profile page
                  Navigator.of(context).pop(); // message page
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${LocalizationService.translate('save_failed')}: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(LocalizationService.translate('leave'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionGroupSection({
    required BuildContext context,
    required bool isDark,
    required bool isAdmin,
    required String channelId,
    required String channelName,
    required String? linkedGroupId,
    required String? linkedGroupName,
  }) {
    final hasLinkedGroup = linkedGroupId != null && linkedGroupId.isNotEmpty;

    if (!hasLinkedGroup && !isAdmin) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.translate('discussion_group_title'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLinkedGroup
                          ? LocalizationService.translate('discussion_group_linked_desc')
                          : LocalizationService.translate('discussion_group_unlinked_desc'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasLinkedGroup) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          linkedGroupName ??
                              LocalizationService.translate('discussion_group_title'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 12, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              LocalizationService.translate('discussion_group_active'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MessagePage(
                            chatId: linkedGroupId,
                            otherUserId: '',
                            otherUserName: linkedGroupName ??
                                LocalizationService.translate('discussion_group_title'),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(LocalizationService.translate('folder_groups'), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.link_off_rounded,
                          color: Colors.redAccent, size: 20),
                      tooltip: LocalizationService.translate('unlink_group'),
                      onPressed: () => _confirmUnlinkDiscussionGroup(channelId),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Not linked, but is admin
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(12) > 13.5;

                final createBtn = ElevatedButton.icon(
                  onPressed: () => _createAndLinkGroup(channelId, channelName),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text(
                    LocalizationService.translate('create_new_group'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                final existingBtn = OutlinedButton.icon(
                  onPressed: () => _showSelectExistingGroupSheet(channelId),
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: Text(
                    LocalizationService.translate('existing_group'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    alignment: Alignment.center,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      createBtn,
                      const SizedBox(height: 8),
                      existingBtn,
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: createBtn),
                      const SizedBox(width: 8),
                      Expanded(child: existingBtn),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createAndLinkGroup(String channelId, String channelName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await widget.chatRepository.createAndLinkDiscussionGroup(
        channelId: channelId,
        channelName: channelName,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      );

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                LocalizationService.translate('discussion_group_linked')),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmUnlinkDiscussionGroup(String channelId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('unlink_group_title')),
        content: Text(
            LocalizationService.translate('unlink_group_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.chatRepository
                    .unlinkDiscussionGroup(channelId: channelId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.translate('discussion_group_unlinked')),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.formatError(e)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(LocalizationService.translate('unlink_action'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSelectExistingGroupSheet(String channelId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('isGroup', isEqualTo: true)
              .where('participants', arrayContains: widget.currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = (snapshot.data?.docs ?? []).where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final isCh = d['isChannel'] as bool? ?? false;
              final chId = doc.id;
              return !isCh && chId != channelId;
            }).toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            LocalizationService.translate('select_existing_group'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            LocalizationService.translate('no_suitable_group_found'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final d = doc.data() as Map<String, dynamic>;
                            final gName =
                                d['groupName'] as String? ?? LocalizationService.translate('tab_groups');
                            final memberCount =
                                (d['participants'] as List?)?.length ?? 0;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.15),
                                child: const Icon(Icons.groups_rounded,
                                    color: AppColors.primary),
                              ),
                              title: Text(gName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(LocalizationService.plural(
                                  'members_count', memberCount)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.of(ctx).pop();
                                  try {
                                    await widget.chatRepository
                                        .linkDiscussionGroup(
                                      channelId: channelId,
                                      groupId: doc.id,
                                      groupName: gName,
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              LocalizationService.translate(
                                                  'group_linked_success',
                                                  params: {'name': gName})),
                                          backgroundColor:
                                              const Color(0xFF10B981),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(LocalizationService.formatError(e)),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Text(LocalizationService.translate('link'),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
