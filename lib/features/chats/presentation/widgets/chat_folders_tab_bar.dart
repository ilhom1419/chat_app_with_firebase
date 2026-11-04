import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/chat_folder.dart';

class ChatFoldersTabBar extends StatelessWidget {
  final List<ChatFolder> folders;
  final String activeFolderId;
  final Map<String, int> unreadCounts;
  final ValueChanged<String> onFolderSelected;
  final VoidCallback onAddFolderPressed;
  final ValueChanged<ChatFolder>? onFolderLongPressed;

  const ChatFoldersTabBar({
    super.key,
    required this.folders,
    required this.activeFolderId,
    required this.unreadCounts,
    required this.onFolderSelected,
    required this.onAddFolderPressed,
    this.onFolderLongPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.black.withOpacity(0.04),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: folders.length + 1, // +1 for the "+" button at the end
        itemBuilder: (context, index) {
          if (index == folders.length) {
            // "+" Add / Manage Folders Button at the end
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 8),
                child: InkWell(
                  onTap: onAddFolderPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            );
          }

          final folder = folders[index];
          final isSelected = folder.id == activeFolderId;
          final unread = unreadCounts[folder.id] ?? 0;

          return GestureDetector(
            onTap: () => onFolderSelected(folder.id),
            onLongPress: () {
              if (onFolderLongPressed != null) {
                onFolderLongPressed!(folder);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (folder.icon.isNotEmpty && !folder.isDefault) ...[
                        Text(
                          folder.icon,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        folder.localizedName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  // Telegram-style bottom indicator line
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 2.5,
                    width: isSelected ? 24 : 0,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
