import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_folder.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';

class CreateFolderSheet extends StatefulWidget {
  final String currentUserId;
  final ChatRepository chatRepository;
  final List<Chat> allChats;
  final ChatFolder? existingFolder;

  const CreateFolderSheet({
    super.key,
    required this.currentUserId,
    required this.chatRepository,
    required this.allChats,
    this.existingFolder,
  });

  static Future<void> show({
    required BuildContext context,
    required String currentUserId,
    required ChatRepository chatRepository,
    required List<Chat> allChats,
    ChatFolder? existingFolder,
  }) {
    return showKakkuFloatingBottomSheet(
      context: context,
      builder: (ctx) => CreateFolderSheet(
        currentUserId: currentUserId,
        chatRepository: chatRepository,
        allChats: allChats,
        existingFolder: existingFolder,
      ),
    );
  }

  @override
  State<CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends State<CreateFolderSheet> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late bool _includeDirect;
  late bool _includeGroups;
  late bool _includeChannels;
  late bool _includeUnreadOnly;
  late Set<String> _includedChatIds;
  late Set<String> _excludedChatIds;
  bool _isSaving = false;

  static const List<Map<String, String>> _presetFolders = [
    {'key': 'recommended_work', 'icon': '💼'},
    {'key': 'recommended_study', 'icon': '🎓'},
    {'key': 'recommended_friends', 'icon': '👥'},
    {'key': 'recommended_family', 'icon': '❤️'},
    {'key': 'recommended_important', 'icon': '⭐️'},
    {'key': 'recommended_projects', 'icon': '🚀'},
  ];

  final List<String> _icons = [
    '📁',
    '💼',
    '🎓',
    '👥',
    '⭐️',
    '🚀',
    '💬',
    '⚡',
    '🔔',
    '❤️',
    '🎯',
    '🔥',
  ];

  @override
  void initState() {
    super.initState();
    final f = widget.existingFolder;
    _nameController = TextEditingController(text: f?.name ?? '');
    _selectedIcon = f?.icon ?? '📁';
    _includeDirect = f?.includeDirect ?? true;
    _includeGroups = f?.includeGroups ?? true;
    _includeChannels = f?.includeChannels ?? true;
    _includeUnreadOnly = f?.includeUnreadOnly ?? false;
    _includedChatIds = Set<String>.from(f?.includedChatIds ?? []);
    _excludedChatIds = Set<String>.from(f?.excludedChatIds ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(LocalizationService.translate('folder_name_required')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final isEditing = widget.existingFolder != null;
      final folder = ChatFolder(
        id: widget.existingFolder?.id ?? '',
        name: name,
        icon: _selectedIcon,
        isDefault: false,
        includedChatIds: _includedChatIds.toList(),
        excludedChatIds: _excludedChatIds.toList(),
        includeDirect: _includeDirect,
        includeGroups: _includeGroups,
        includeChannels: _includeChannels,
        includeUnreadOnly: _includeUnreadOnly,
        order: widget.existingFolder?.order ?? 99,
      );

      if (isEditing) {
        await widget.chatRepository.updateFolder(widget.currentUserId, folder);
      } else {
        await widget.chatRepository.createFolder(widget.currentUserId, folder);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? LocalizationService.translate('folder_updated_success')
                : LocalizationService.translate('folder_created_success',
                    params: {'name': name})),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showChatPicker({required bool isExclude}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedSet = isExclude ? _excludedChatIds : _includedChatIds;

    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Text(
                            isExclude
                                ? LocalizationService.translate('excluded_chats')
                                : LocalizationService.translate('included_chats'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.check_rounded,
                                color: AppColors.primary),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: widget.allChats.isEmpty
                          ? Center(
                              child: Text(LocalizationService.translate(
                                  'no_chats_available')),
                            )
                          : ListView.builder(
                              itemCount: widget.allChats.length,
                              itemBuilder: (context, index) {
                                final chat = widget.allChats[index];
                                final isSelected =
                                    selectedSet.contains(chat.id);

                                return CheckboxListTile(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  title: Text(chat.otherUserName),
                                  subtitle: Text(
                                    chat.isChannel
                                        ? LocalizationService.translate(
                                            'channel_badge')
                                        : (chat.isGroup
                                            ? LocalizationService.translate(
                                                'group_badge')
                                            : LocalizationService.translate(
                                                'folder_direct')),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onChanged: (val) {
                                    setSheetState(() {
                                      if (val == true) {
                                        selectedSet.add(chat.id);
                                        if (isExclude) {
                                          _includedChatIds.remove(chat.id);
                                        } else {
                                          _excludedChatIds.remove(chat.id);
                                        }
                                      } else {
                                        selectedSet.remove(chat.id);
                                      }
                                    });
                                    setState(() {});
                                  },
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingFolder != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Text(
                    isEditing
                        ? LocalizationService.translate('edit_folder')
                        : LocalizationService.translate('create_folder'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Folder Name Field with Icon Picker
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _showIconPickerModal(context, isDark);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _selectedIcon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            LocalizationService.translate('folder_name_hint'),
                        filled: true,
                        fillColor:
                            isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              // Suggested Names Tags
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetFolders.map((preset) {
                  final localizedName =
                      LocalizationService.translate(preset['key']!);
                  return ActionChip(
                    label: Text(localizedName),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    backgroundColor:
                        isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      setState(() {
                        _nameController.text = localizedName;
                        _selectedIcon = preset['icon']!;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Chat Types Filter Header
              Text(
                LocalizationService.translate('included_chat_types'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                LocalizationService.translate('included_types_subtitle'),
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),

              // Filter Switches
              _buildSwitchTile(
                title: LocalizationService.translate('direct_chats_label'),
                icon: Icons.person_outline_rounded,
                value: _includeDirect,
                onChanged: (val) => setState(() => _includeDirect = val),
              ),
              _buildSwitchTile(
                title: LocalizationService.translate('groups_label'),
                icon: Icons.groups_outlined,
                value: _includeGroups,
                onChanged: (val) => setState(() => _includeGroups = val),
              ),
              _buildSwitchTile(
                title: LocalizationService.translate('channels_label'),
                icon: Icons.campaign_outlined,
                value: _includeChannels,
                onChanged: (val) => setState(() => _includeChannels = val),
              ),
              _buildSwitchTile(
                title: LocalizationService.translate('unread_only_label'),
                icon: Icons.mark_chat_unread_outlined,
                value: _includeUnreadOnly,
                onChanged: (val) => setState(() => _includeUnreadOnly = val),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Specific Chats Selection Section
              Text(
                LocalizationService.translate('select_specific_chats'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary),
                ),
                title: Text(LocalizationService.translate('add_chats')),
                subtitle: Text(
                  _includedChatIds.isEmpty
                      ? LocalizationService.translate(
                          'no_specific_chats_selected')
                      : LocalizationService.translate('chats_added_count',
                          params: {'count': _includedChatIds.length.toString()}),
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showChatPicker(isExclude: false),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.remove_rounded, color: Colors.redAccent),
                ),
                title: Text(LocalizationService.translate('exclude_chats')),
                subtitle: Text(
                  _excludedChatIds.isEmpty
                      ? LocalizationService.translate('no_excluded_chats')
                      : LocalizationService.translate('chats_excluded_count',
                          params: {'count': _excludedChatIds.length.toString()}),
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showChatPicker(isExclude: true),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing
                              ? LocalizationService.translate('save_changes')
                              : LocalizationService.translate(
                                  'create_folder_action'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  void _showIconPickerModal(BuildContext context, bool isDark) {
    showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.translate('choose_icon'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _icons.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIcon = emoji);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedIcon == emoji
                              ? AppColors.primary.withOpacity(0.2)
                              : (isDark
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9)),
                          border: _selectedIcon == emoji
                              ? Border.all(color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
