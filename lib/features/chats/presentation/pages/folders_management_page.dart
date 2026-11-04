import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/chat_folder.dart';
import '../../domain/repositories/chat_repository.dart';
import '../widgets/create_folder_sheet.dart';
import '../../../../core/localization/localization_service.dart';

class FoldersManagementPage extends StatelessWidget {
  final String currentUserId;
  final ChatRepository chatRepository;
  final List<Chat> allChats;
  final bool embedMode;

  const FoldersManagementPage({
    super.key,
    required this.currentUserId,
    required this.chatRepository,
    required this.allChats,
    this.embedMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        final bodyContent = StreamBuilder<List<ChatFolder>>(
          stream: chatRepository.getUserFolders(currentUserId),
          builder: (context, snapshot) {
            final customFolders = snapshot.data ?? [];

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                embedMode ? 100 : 32,
              ),
              children: [
                  // Top Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.folder_special_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.translate(
                                    'sort_chats_banner_title'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                LocalizationService.translate(
                                    'sort_chats_banner_desc'),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Create New Folder Button
                  Material(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: AppColors.primary),
                      ),
                      title: Text(
                        LocalizationService.translate('create_folder'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      subtitle: Text(
                        LocalizationService.translate('create_folder_subtitle'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 14),
                      onTap: () {
                        CreateFolderSheet.show(
                          context: context,
                          currentUserId: currentUserId,
                          chatRepository: chatRepository,
                          allChats: allChats,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // User's Custom Folders
                  if (customFolders.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        LocalizationService.translate('your_folders'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Material(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (int i = 0; i < customFolders.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            () {
                              final folder = customFolders[i];
                              final matchedCount =
                                  allChats.where((c) => folder.matches(c)).length;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    folder.icon,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                title: Text(
                                  folder.localizedName,
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  LocalizationService.plural(
                                      'chats_count', matchedCount),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 20),
                                      onPressed: () {
                                        CreateFolderSheet.show(
                                          context: context,
                                          currentUserId: currentUserId,
                                          chatRepository: chatRepository,
                                          allChats: allChats,
                                          existingFolder: folder,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 20),
                                      onPressed: () {
                                        _confirmDeleteFolder(context, folder);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recommended Folders Section
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      LocalizationService.translate('recommended_folders'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Material(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildRecommendedTile(
                          context: context,
                          name: LocalizationService.translate('recommended_work'),
                          icon: '💼',
                          desc: LocalizationService.translate(
                              'recommended_work_desc'),
                          folder: const ChatFolder(
                            id: '',
                            name: 'Ish',
                            icon: '💼',
                            presetId: 'work',
                            includeDirect: true,
                            includeGroups: true,
                            includeChannels: false,
                          ),
                          customFolders: customFolders,
                        ),
                        const Divider(height: 1),
                        _buildRecommendedTile(
                          context: context,
                          name:
                              LocalizationService.translate('recommended_study'),
                          icon: '🎓',
                          desc: LocalizationService.translate(
                              'recommended_study_desc'),
                          folder: const ChatFolder(
                            id: '',
                            name: 'O‘qish',
                            icon: '🎓',
                            presetId: 'study',
                            includeDirect: false,
                            includeGroups: true,
                            includeChannels: true,
                          ),
                          customFolders: customFolders,
                        ),
                        const Divider(height: 1),
                        _buildRecommendedTile(
                          context: context,
                          name: LocalizationService.translate(
                              'recommended_friends'),
                          icon: '👥',
                          desc: LocalizationService.translate(
                              'recommended_friends_desc'),
                          folder: const ChatFolder(
                            id: '',
                            name: 'Do‘stlar',
                            icon: '👥',
                            presetId: 'friends',
                            includeDirect: true,
                            includeGroups: false,
                            includeChannels: false,
                          ),
                          customFolders: customFolders,
                        ),
                        const Divider(height: 1),
                        _buildRecommendedTile(
                          context: context,
                          name: LocalizationService.translate(
                              'recommended_family'),
                          icon: '❤️',
                          desc: LocalizationService.translate(
                              'recommended_family_desc'),
                          folder: const ChatFolder(
                            id: '',
                            name: 'Oila',
                            icon: '❤️',
                            presetId: 'family',
                            includeDirect: true,
                            includeGroups: true,
                            includeChannels: false,
                          ),
                          customFolders: customFolders,
                        ),
                        const Divider(height: 1),
                        _buildRecommendedTile(
                          context: context,
                          name: LocalizationService.translate(
                              'recommended_important'),
                          icon: '⭐️',
                          desc: LocalizationService.translate(
                              'recommended_important_desc'),
                          folder: const ChatFolder(
                            id: '',
                            name: 'Muhim',
                            icon: '⭐️',
                            presetId: 'important',
                            includeDirect: true,
                            includeGroups: true,
                            includeChannels: true,
                            includeUnreadOnly: true,
                          ),
                          customFolders: customFolders,
                        ),
                        const Divider(height: 1),
                        _buildRecommendedTile(
                          context: context,
                          name: LocalizationService.translate(
                              'recommended_projects'),
                          icon: '🚀',
                          desc: LocalizationService.translate(
                              'recommended_projects_desc'),
                          folder: const ChatFolder(
                            id: '',
                            name: 'Loyihalar',
                            icon: '🚀',
                            presetId: 'projects',
                            includeDirect: false,
                            includeGroups: true,
                            includeChannels: true,
                          ),
                          customFolders: customFolders,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );

        if (embedMode) {
          return ColoredBox(
            color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
            child: bodyContent,
          );
        }

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(
              LocalizationService.translate('chat_folders'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            backgroundColor:
                isDark ? const Color(0xFF0F172A) : Colors.white,
          ),
          body: bodyContent,
        );
      },
    );
  }

  Widget _buildRecommendedTile({
    required BuildContext context,
    required String name,
    required String icon,
    required String desc,
    required ChatFolder folder,
    required List<ChatFolder> customFolders,
  }) {
    final alreadyExists = customFolders.any((f) =>
        f.name.toLowerCase() == name.toLowerCase() ||
        f.localizedName.toLowerCase() == name.toLowerCase());

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.12),
        child: Text(icon, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11.5)),
      trailing: alreadyExists
          ? Chip(
              label: Text(
                LocalizationService.translate('added_folder_btn'),
                style: const TextStyle(fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                try {
                  await chatRepository.createFolder(currentUserId, folder);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.translate(
                            'folder_added_success',
                            params: {'name': name})),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Xatolik: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: Text(
                LocalizationService.translate('add_folder_btn'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, ChatFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocalizationService.translate(
          'delete_folder_title_param',
          params: {'name': folder.localizedName},
        )),
        content: Text(
          LocalizationService.translate('delete_folder_warning'),
        ),
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
                await chatRepository.deleteFolder(currentUserId, folder.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.translate(
                        'folder_deleted_success',
                        params: {'name': folder.localizedName},
                      )),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xatolik: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(
              LocalizationService.translate('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
