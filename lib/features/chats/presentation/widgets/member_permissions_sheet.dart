import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/chat_member.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/localization/localization_service.dart';

class MemberPermissionsSheet extends StatefulWidget {
  final String chatId;
  final ChatMember member;
  final bool isViewerOwner;
  final bool isViewerAdmin;
  final bool isChannel;
  final ChatRepository chatRepository;

  const MemberPermissionsSheet({
    super.key,
    required this.chatId,
    required this.member,
    required this.isViewerOwner,
    required this.isViewerAdmin,
    required this.isChannel,
    required this.chatRepository,
  });

  @override
  State<MemberPermissionsSheet> createState() => _MemberPermissionsSheetState();
}

class _MemberPermissionsSheetState extends State<MemberPermissionsSheet> {
  late MemberRole _role;
  late TextEditingController _titleController;
  late bool _canSendMessages;
  late bool _canSendMedia;
  late bool _canSendPolls;
  late bool _canPinMessages;
  late bool _canAddMembers;
  late bool _canChangeInfo;
  late bool _canManageTopics;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.member.role == MemberRole.owner
        ? MemberRole.owner
        : (widget.member.isAdmin ? MemberRole.admin : MemberRole.member);
    _titleController =
        TextEditingController(text: widget.member.customTitle ?? '');

    final perms = widget.member.permissions;
    _canSendMessages = perms.canSendMessages;
    _canSendMedia = perms.canSendMedia;
    _canSendPolls = perms.canSendPolls;
    _canPinMessages = perms.canPinMessages;
    _canAddMembers = perms.canAddMembers;
    _canChangeInfo = perms.canChangeInfo;
    _canManageTopics = perms.canManageTopics;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final updatedPermissions = MemberPermissions(
        canSendMessages: _canSendMessages,
        canSendMedia: _canSendMedia,
        canSendPolls: _canSendPolls,
        canPinMessages: _canPinMessages,
        canAddMembers: _canAddMembers,
        canChangeInfo: _canChangeInfo,
        canManageTopics: _canManageTopics,
      );

      final title = _titleController.text.trim();

      await widget.chatRepository.updateMemberRole(
        widget.chatId,
        widget.member.userId,
        _role,
        customTitle: title.isNotEmpty ? title : null,
        permissions: updatedPermissions,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.translate(
              'permissions_updated_success',
              params: {'name': widget.member.displayName},
            )),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('remove_member_title')),
        content: Text(LocalizationService.translate(
          'remove_member_confirm',
          params: {
            'name': widget.member.displayName,
            'target': widget.isChannel
                ? LocalizationService.translate('tab_channels')
                : LocalizationService.translate('group_badge')
          },
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocalizationService.translate('delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await widget.chatRepository
            .removeMember(widget.chatId, widget.member.userId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate(
                'user_removed_success',
                params: {'name': widget.member.displayName},
              )),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.formatError(e)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _banMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('ban_member_title')),
        content: Text(LocalizationService.translate(
          'ban_member_confirm',
          params: {'name': widget.member.displayName},
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocalizationService.translate('role_banned'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await widget.chatRepository
            .banMember(widget.chatId, widget.member.userId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate(
                'user_banned_success',
                params: {'name': widget.member.displayName},
              )),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.formatError(e)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferOwnership() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate('transfer_ownership_title')),
        content: Text(LocalizationService.translate(
          'transfer_ownership_confirm',
          params: {
            'name': widget.member.displayName,
            'target': widget.isChannel
                ? LocalizationService.translate('tab_channels')
                : LocalizationService.translate('group_badge')
          },
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(LocalizationService.translate('confirm'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await widget.chatRepository
            .transferOwnership(widget.chatId, widget.member.userId);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate(
                'ownership_transferred_success',
                params: {'name': widget.member.displayName},
              )),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.formatError(e)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTargetOwner = widget.member.isOwner;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      LocalizationService.translate('close_btn'),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    LocalizationService.translate('permissions_title'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    onPressed: _isLoading || isTargetOwner ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            LocalizationService.translate('save_btn'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // User info header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          widget.member.displayName.isNotEmpty
                              ? widget.member.displayName
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.member.customTitle != null &&
                                      widget.member.customTitle!.isNotEmpty
                                  ? "${widget.member.customTitle} • ${widget.member.role.localizedName}"
                                  : widget.member.role.localizedName,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.member.isOwner
                                    ? Colors.amber
                                    : (widget.member.isAdmin
                                        ? AppColors.primary
                                        : Colors.grey),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Role selector
                  if (!isTargetOwner && widget.isViewerOwner) ...[
                    Text(
                      LocalizationService.translate('select_role'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                                child: Text(LocalizationService.translate('role_regular'))),
                            selected: _role == MemberRole.member,
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _role = MemberRole.member;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: Center(
                                child: Text(LocalizationService.translate('role_admin_badge'))),
                            selected: _role == MemberRole.admin,
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _role = MemberRole.admin;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Custom Admin Title
                  if (_role == MemberRole.admin || isTargetOwner) ...[
                    Text(
                      LocalizationService.translate('custom_title_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleController,
                      maxLength: 32,
                      decoration: InputDecoration(
                        hintText: LocalizationService.translate('custom_title_hint'),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        counterText: "",
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Permissions checklist
                  Text(
                    LocalizationService.translate('member_capabilities'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_send_messages')),
                    subtitle: Text(LocalizationService.translate('perm_send_messages_desc')),
                    value: _canSendMessages,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canSendMessages = val),
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_send_media')),
                    subtitle: Text(LocalizationService.translate('perm_send_media_desc')),
                    value: _canSendMedia,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canSendMedia = val),
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_send_polls')),
                    subtitle: Text(LocalizationService.translate('perm_send_polls_desc')),
                    value: _canSendPolls,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canSendPolls = val),
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_pin_messages')),
                    subtitle: Text(LocalizationService.translate('perm_pin_messages_desc')),
                    value: _canPinMessages,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canPinMessages = val),
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_add_members')),
                    subtitle: Text(LocalizationService.translate('perm_add_members_desc')),
                    value: _canAddMembers,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canAddMembers = val),
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_change_info')),
                    subtitle: Text(LocalizationService.translate('perm_change_info_desc')),
                    value: _canChangeInfo,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canChangeInfo = val),
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('perm_manage_topics')),
                    subtitle:
                        Text(LocalizationService.translate('perm_manage_topics_desc')),
                    value: _canManageTopics,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: isTargetOwner
                        ? null
                        : (val) => setState(() => _canManageTopics = val),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Danger zone buttons for admin/owner
                  if (!isTargetOwner) ...[
                    if (widget.isViewerOwner) ...[
                      ListTile(
                        leading: const Icon(Icons.stars_rounded,
                            color: Colors.amber),
                        title: Text(
                          LocalizationService.translate('transfer_ownership'),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                            LocalizationService.translate('transfer_ownership_desc')),
                        onTap: _transferOwnership,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],

                    ListTile(
                      leading: const Icon(Icons.block_rounded,
                          color: Colors.redAccent),
                      title: Text(
                        LocalizationService.translate('ban_user'),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                          LocalizationService.translate('ban_user_desc')),
                      onTap: _banMember,
                      contentPadding: EdgeInsets.zero,
                    ),

                    ListTile(
                      leading: const Icon(Icons.person_remove_rounded,
                          color: AppColors.error),
                      title: Text(
                        widget.isChannel
                            ? LocalizationService.translate('remove_from_channel')
                            : LocalizationService.translate('remove_from_group'),
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: _removeMember,
                      contentPadding: EdgeInsets.zero,
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
}
