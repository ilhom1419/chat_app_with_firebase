import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/widgets/adaptive_scaffold.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../domain/entities/chat.dart';
import '../bloc/chat_list_bloc.dart';
import '../bloc/chat_list_event.dart';
import '../bloc/chat_list_state.dart';
import '../../../messages/presentation/pages/message_page.dart';
import 'search_users_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/create_channel_sheet.dart';
import '../widgets/join_preview_sheet.dart';
import '../../../../core/localization/localization_service.dart';
import 'settings_page.dart';
import '../../domain/entities/chat_folder.dart';
import '../../domain/repositories/chat_repository.dart';
import '../widgets/chat_folders_tab_bar.dart';
import '../widgets/create_folder_sheet.dart';
import 'folders_management_page.dart';
import '../../../../shared/utils/app_image.dart';
import '../widgets/unread_count_badge.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../auth/presentation/pages/passcode_page.dart';
import '../../../../core/services/passcode_service.dart';
import '../../../stories/presentation/widgets/stories_tray.dart';
import '../../../stories/presentation/pages/create_story_page.dart';
import '../../../saved_messages/presentation/pages/saved_messages_page.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../shared/widgets/yeschat_logo.dart';
import '../../../messages/presentation/bloc/message_bloc.dart';
import '../../../messages/presentation/bloc/message_event.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage>
    with SingleTickerProviderStateMixin {
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserPhoto;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedIndex = 0;
  String _activeFolderId = ChatFolder.allId;
  late AnimationController _storiesController;
  late Animation<double> _storiesAnimation;

  void _showFolderOptionsModal(ChatFolder folder, List<Chat> allChats) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      folder.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      folder.localizedName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (!folder.isDefault) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(LocalizationService.translate('edit_folder')),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    CreateFolderSheet.show(
                      context: context,
                      currentUserId: _currentUserId ?? '',
                      chatRepository: context.read<ChatRepository>(),
                      allChats: allChats,
                      existingFolder: folder,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: Text(LocalizationService.translate('delete_folder'),
                      style: const TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await context
                        .read<ChatRepository>()
                        .deleteFolder(_currentUserId!, folder.id);
                    if (mounted) {
                      setState(() {
                        _activeFolderId = ChatFolder.allId;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(LocalizationService.translate(
                                'folder_deleted_success',
                                params: {'name': folder.localizedName}))),
                      );
                    }
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.folder_special_outlined,
                    color: AppColors.primary),
                title: Text(LocalizationService.translate('manage_folders')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FoldersManagementPage(
                        currentUserId: _currentUserId ?? '',
                        chatRepository: context.read<ChatRepository>(),
                        allChats: allChats,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }



  void _showJoinViaLinkDialog() {
    final controller = TextEditingController();
    final authState = context.read<AuthBloc>().state;
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.uid : '';
    final currentUserName = authState is AuthAuthenticated
        ? (authState.user.displayName.isNotEmpty
            ? authState.user.displayName
            : 'Foydalanuvchi')
        : 'Foydalanuvchi';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        bool isChecking = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.link_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LocalizationService.translate('join_via_link'),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationService.translate('enter_invite_link_hint'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'https://chat.me/+... yoki kod',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.grey.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isChecking ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    LocalizationService.translate('cancel'),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                  ),
                  onPressed: isChecking
                      ? null
                      : () async {
                          final input = controller.text.trim();
                          if (input.isEmpty) return;

                          setDialogState(() => isChecking = true);

                          try {
                            final chatDoc =
                                await InviteLinkService.resolveChat(input);

                            if (ctx.mounted) {
                              Navigator.of(ctx).pop(); // Close input dialog
                            }

                            if (chatDoc == null || !chatDoc.exists) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(LocalizationService.translate(
                                        'invalid_link')),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                              return;
                            }

                            if (mounted) {
                              TelegramJoinPreviewSheet.show(
                                context: context,
                                chatDoc: chatDoc,
                                currentUserId: currentUserId,
                                currentUserName: currentUserName,
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isChecking = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Xatolik: $e')),
                              );
                            }
                          }
                        },
                  child: isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          LocalizationService.translate('check_link_btn'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteOrLeaveChatDialog(Chat chat) {
    if (_currentUserId == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGroupOrChannel = chat.isGroup || chat.isChannel;
    final isAdmin = chat.createdBy == _currentUserId;

    String title = LocalizationService.translate('delete_chat');
    String content = LocalizationService.translate('delete_chat_confirm');
    String actionLabel = LocalizationService.translate('delete');

    if (isGroupOrChannel) {
      if (isAdmin) {
        title = chat.isChannel
            ? LocalizationService.translate('delete_channel')
            : LocalizationService.translate('delete_group');
        content = chat.isChannel
            ? LocalizationService.translate('delete_channel_confirm')
            : LocalizationService.translate('delete_group_confirm');
        actionLabel = LocalizationService.translate('delete_permanently');
      } else {
        title = chat.isChannel
            ? LocalizationService.translate('leave_channel')
            : LocalizationService.translate('leave_group');
        content = chat.isChannel
            ? LocalizationService.translate('leave_channel_confirm')
            : LocalizationService.translate('leave_group_confirm');
        actionLabel = LocalizationService.translate('leave');
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(title,
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold)),
          content: Text(content,
              style:
                  TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(LocalizationService.translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  if (isGroupOrChannel && !isAdmin) {
                    // Non-admin leaves group/channel
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chat.id)
                        .update({
                      'participants': FieldValue.arrayRemove([_currentUserId!]),
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(chat.isChannel
                                ? LocalizationService.translate('channel_left')
                                : LocalizationService.translate('group_left'))),
                      );
                    }
                  } else {
                    // Admin deletes group/channel, or direct chat is deleted
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chat.id)
                        .delete();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(LocalizationService.translate(
                                'successfully_deleted'))),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Xatolik: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(actionLabel,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _getTabLabel(int index) {
    if (index == 0) return LocalizationService.translate('tab_chats');
    if (index == 1) return LocalizationService.translate('tab_folders');
    return LocalizationService.translate('tab_profile');
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.95)
            : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.chat_bubble_rounded),
          _buildNavItem(1, Icons.folder_special_rounded),
          _buildNavItem(2, Icons.account_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _getTabLabel(index);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white54 : Colors.black54),
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _storiesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _storiesAnimation = CurvedAnimation(
      parent: _storiesController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeInCubic,
    );
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.uid;
      _currentUserName = authState.user.displayName;
      _currentUserPhoto = authState.user.photoURL;
      context.read<ChatListBloc>().add(LoadChats(_currentUserId!));
      NotificationService.syncToken(uid: _currentUserId);
      NotificationService.startListeningToUserNotifications(_currentUserId!);
    }
  }

  @override
  void dispose() {
    _storiesController.dispose();
    _searchController.dispose();
    NotificationService.stopListeningToUserNotifications();
    super.dispose();
  }

  void _hideStories() {
    if (_storiesController.status != AnimationStatus.reverse &&
        _storiesController.value > 0.0) {
      _storiesController.reverse();
    }
  }

  void _showStories() {
    if (_storiesController.status != AnimationStatus.forward &&
        _storiesController.value < 1.0) {
      _storiesController.forward();
    }
  }

  void _onLogout() {
    context.read<AuthBloc>().add(AuthSignOutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.read<ChatListBloc>().add(ClearChats());
          context.read<MessageBloc>().add(const LeaveChat(''));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        } else if (state is AuthAuthenticated) {
          setState(() {
            _currentUserId = state.user.uid;
            _currentUserName = state.user.displayName;
            _currentUserPhoto = state.user.photoURL;
          });
          context.read<ChatListBloc>().add(LoadChats(state.user.uid));
        }
      },
      child: ValueListenableBuilder<String>(
        valueListenable: LocalizationService.langNotifier,
        builder: (context, lang, _) {
          return AdaptiveScaffold(
            bottomBar: _buildBottomNavigationBar(),
            title: _selectedIndex == 2
                ? Text(LocalizationService.translate('profile_title'),
                    style: AppTextStyles.h2())
                : _selectedIndex == 1
                    ? Text(
                        LocalizationService.translate('chat_folders'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const YesChatLogo(
                            size: 30,
                            borderRadius: 8,
                            showShadow: false,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'YesChat!',
                            style: AppTextStyles.h2().copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
            actions: _selectedIndex != 0
                ? null
                : [
                    FutureBuilder<Box>(
                      future: Hive.openBox('settings'),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final box = snapshot.data!;
                        final currentUid = _currentUserId ??
                            FirebaseAuth.instance.currentUser?.uid;
                        return ValueListenableBuilder<Box>(
                          valueListenable: box.listenable(),
                          builder: (context, box, _) {
                            final isPasscodeEnabled =
                                PasscodeService.isPasscodeEnabled(
                                    uid: currentUid, box: box);
                            if (isPasscodeEnabled) {
                              return IconButton(
                                icon: const Icon(Icons.lock_outline_rounded),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PasscodePage(
                                        userId: currentUid,
                                        mode: PasscodeMode.enter,
                                        onSuccess: (passcodeCtx) {
                                          Navigator.of(passcodeCtx).pop();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        if (authState is! AuthAuthenticated) {
                          return const SizedBox.shrink();
                        }
                        final uid = authState.user.uid;
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            String name = authState.user.displayName;
                            String? photoURL = authState.user.photoURL;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data()
                                  as Map<String, dynamic>?;
                              name = data?['displayName'] as String? ?? name;
                              photoURL =
                                  data?['photoURL'] as String? ?? photoURL;
                            }
                            final hasPhoto = photoURL != null &&
                                photoURL.startsWith('data:image');
                            final gradient = AppColors.avatarGradients[
                                name.length % AppColors.avatarGradients.length];

                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const ProfilePage()),
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
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
                                              width: 32,
                                              height: 32,
                                            )
                                          : Center(
                                              child: Text(
                                                name.isNotEmpty
                                                    ? name
                                                        .substring(0, 1)
                                                        .toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) {
                        if (value == 'group') {
                          final authState = context.read<AuthBloc>().state;
                          if (authState is AuthAuthenticated) {
                            showKakkuFloatingBottomSheet(
                              context: context,
                              builder: (ctx) => CreateGroupSheet(
                                currentUserId: authState.user.uid,
                                currentUserName:
                                    authState.user.displayName.isNotEmpty
                                        ? authState.user.displayName
                                        : 'Admin',
                              ),
                            );
                          }
                        } else if (value == 'channel') {
                          final authState = context.read<AuthBloc>().state;
                          if (authState is AuthAuthenticated) {
                            showKakkuFloatingBottomSheet(
                              context: context,
                              builder: (ctx) => CreateChannelSheet(
                                currentUserId: authState.user.uid,
                                currentUserName:
                                    authState.user.displayName.isNotEmpty
                                        ? authState.user.displayName
                                        : 'Admin',
                              ),
                            );
                          }
                        } else if (value == 'join_link') {
                          _showJoinViaLinkDialog();
                        } else if (value == 'search') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SearchUsersPage()),
                          );
                        } else if (value == 'profile') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ProfilePage()),
                          );
                        } else if (value == 'settings') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SettingsPage()),
                          );
                        } else if (value == 'folders') {
                          final state = context.read<ChatListBloc>().state;
                          final chats =
                              state is ChatListLoaded ? state.chats : <Chat>[];
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FoldersManagementPage(
                                currentUserId: _currentUserId ?? '',
                                chatRepository: context.read<ChatRepository>(),
                                allChats: chats,
                              ),
                            ),
                          );
                        } else if (value == 'create_story') {
                          if (_currentUserId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CreateStoryPage(
                                  currentUserId: _currentUserId!,
                                  currentUserName: (_currentUserName != null &&
                                          _currentUserName!.isNotEmpty)
                                      ? _currentUserName!
                                      : 'Foydalanuvchi',
                                  currentUserPhoto: _currentUserPhoto,
                                ),
                              ),
                            );
                          }
                        } else if (value == 'saved_messages') {
                          if (_currentUserId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SavedMessagesPage(
                                  currentUserId: _currentUserId!,
                                ),
                              ),
                            );
                          }
                        } else if (value == 'logout') {
                          _onLogout();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'create_story',
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate('add_story')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'saved_messages',
                          child: Row(
                            children: [
                              const Icon(Icons.bookmark_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate('saved_messages')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'folders',
                          child: Row(
                            children: [
                              const Icon(Icons.folder_special_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate('chat_folders')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'group',
                          child: Row(
                            children: [
                              const Icon(Icons.groups_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate(
                                  'create_group')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'channel',
                          child: Row(
                            children: [
                              const Icon(Icons.campaign_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate(
                                  'create_channel')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'join_link',
                          child: Row(
                            children: [
                              const Icon(Icons.link_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate(
                                  'join_via_link')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'search',
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate(
                                  'search_users')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate(
                                  'profile_title')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              const Icon(Icons.settings_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(LocalizationService.translate(
                                  'settings_title')),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(
                            children: [
                              const Icon(Icons.logout_rounded,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                LocalizationService.translate('logout_btn'),
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
            body: _selectedIndex == 2
                ? const ProfilePage(embedMode: true)
                : _selectedIndex == 1
                    ? BlocBuilder<ChatListBloc, ChatListState>(
                        builder: (context, state) {
                          final allChats =
                              state is ChatListLoaded ? state.chats : <Chat>[];
                          return FoldersManagementPage(
                            currentUserId: _currentUserId ?? '',
                            chatRepository: context.read<ChatRepository>(),
                            allChats: allChats,
                            embedMode: true,
                          );
                        },
                      )
                    : StreamBuilder<List<ChatFolder>>(
                        stream: _currentUserId != null
                            ? context
                                .read<ChatRepository>()
                                .getUserFolders(_currentUserId!)
                            : const Stream.empty(),
                        builder: (context, folderSnap) {
                          final customFolders = folderSnap.data ?? [];
                          final allFolders = [
                            ...ChatFolder.defaultFolders(),
                            ...customFolders,
                          ];

                          if (!allFolders.any((f) => f.id == _activeFolderId)) {
                            _activeFolderId = ChatFolder.allId;
                          }

                          final activeFolder = allFolders.firstWhere(
                            (f) => f.id == _activeFolderId,
                            orElse: () => allFolders.first,
                          );

                          return BlocBuilder<ChatListBloc, ChatListState>(
                            builder: (context, state) {
                              final chats = (state is ChatListLoaded)
                                  ? state.chats
                                  : <Chat>[];

                              // Calculate unread conversation counts for each folder
                              // Rule: Count the number of UNIQUE eligible conversations with unreadCount > 0
                              final unreadCounts = <String, int>{};
                              for (final folder in allFolders) {
                                int unreadConversationCount = 0;
                                final seenChatIds = <String>{};
                                for (final chat in chats) {
                                  if (chat.unreadCount > 0 &&
                                      folder.matches(chat) &&
                                      seenChatIds.add(chat.id)) {
                                    unreadConversationCount++;
                                  }
                                }
                                unreadCounts[folder.id] = unreadConversationCount;
                              }

                              // Folder filter
                              final folderFilteredChats = chats
                                  .where((chat) => activeFolder.matches(chat))
                                  .toList();

                              // Dynamic search filter
                              final filteredChats =
                                  folderFilteredChats.where((chat) {
                                final nameMatch = chat.otherUserName
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase());
                                final msgMatch = chat.lastMessage
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase());
                                return nameMatch || msgMatch;
                              }).toList();

                              return Column(
                                children: [
                                  // 📁 Top Scrollable Chat Folders Tab Bar (Telegram-grade)
                                  ChatFoldersTabBar(
                                    folders: allFolders,
                                    activeFolderId: _activeFolderId,
                                    unreadCounts: unreadCounts,
                                    onFolderSelected: (folderId) {
                                      setState(() {
                                        _activeFolderId = folderId;
                                      });
                                      _showStories();
                                    },
                                    onAddFolderPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => FoldersManagementPage(
                                            currentUserId:
                                                _currentUserId ?? '',
                                            chatRepository:
                                                context.read<ChatRepository>(),
                                            allChats: chats,
                                          ),
                                        ),
                                      );
                                    },
                                    onFolderLongPressed: (folder) {
                                      _showFolderOptionsModal(folder, chats);
                                    },
                                  ),
                                  const SizedBox(height: 8),

                                  // 📖 Stories Carousel (clean, circular, smooth animated collapse/expand)
                                  if (_currentUserId != null)
                                    SizeTransition(
                                      sizeFactor: _storiesAnimation,
                                      axisAlignment: -1.0,
                                      child: FadeTransition(
                                        opacity: _storiesAnimation,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            StoriesTray(
                                              currentUserId: _currentUserId!,
                                              currentUserName: (_currentUserName !=
                                                          null &&
                                                      _currentUserName!.isNotEmpty)
                                                  ? _currentUserName!
                                                  : 'Foydalanuvchi',
                                              currentUserPhoto: _currentUserPhoto,
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // 🔍 Search Bar (modern compact 48dp capsule)
                                  _buildSearchBar(),
                                  const SizedBox(height: 10),

                                  Expanded(
                                    child: NotificationListener<ScrollNotification>(
                                      onNotification: (notification) {
                                        if (notification.metrics.axis == Axis.vertical) {
                                          if (notification is UserScrollNotification) {
                                            if (notification.direction == ScrollDirection.reverse &&
                                                notification.metrics.maxScrollExtent > 40) {
                                              _hideStories();
                                            } else if (notification.direction == ScrollDirection.forward) {
                                              _showStories();
                                            }
                                          } else if (notification is ScrollUpdateNotification) {
                                            if (notification.metrics.pixels <= 10) {
                                              _showStories();
                                            }
                                          }
                                        }
                                        return false;
                                      },
                                      child: Builder(
                                      builder: (context) {
                                        final isDark = Theme.of(context).brightness == Brightness.dark;
                                        if (state is ChatListLoading) {
                                          return const Center(
                                              child:
                                                  CircularProgressIndicator());
                                        } else if (state is ChatListLoaded) {
                                          if (filteredChats.isEmpty) {
                                            final isSearch =
                                                _searchQuery.isNotEmpty;
                                            return Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    isSearch
                                                        ? Icons.search_off_rounded
                                                        : Icons
                                                            .chat_bubble_outline_rounded,
                                                    size: 64,
                                                    color: Colors.grey[300],
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    isSearch
                                                        ? LocalizationService.translate('no_chats_found')
                                                        : (activeFolder.id ==
                                                                ChatFolder.allId
                                                            ? LocalizationService.translate('no_chats')
                                                            : LocalizationService.translate(
                                                                'folder_empty',
                                                                params: {
                                                                    'name':
                                                                        activeFolder.localizedName
                                                                  })),
                                                    style: AppTextStyles.body()
                                                        .copyWith(
                                                      color: AppColors
                                                          .textSecondaryLight,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          final showSavedPinned =
                                              activeFolder.id == ChatFolder.allId &&
                                                  _searchQuery.isEmpty;
                                          return ListView.separated(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            itemCount: showSavedPinned
                                                ? filteredChats.length + 1
                                                : filteredChats.length,
                                            separatorBuilder:
                                                (context, index) =>
                                                    Divider(
                                                        height: 1,
                                                        indent: 78,
                                                        color: isDark
                                                            ? Colors.white.withOpacity(0.04)
                                                            : Colors.black.withOpacity(0.04)),
                                            itemBuilder: (context, index) {
                                              if (showSavedPinned) {
                                                if (index == 0) {
                                                  return _buildSavedMessagesTile();
                                                }
                                                final chat =
                                                    filteredChats[index - 1];
                                                return GestureDetector(
                                                  onLongPress: () =>
                                                      _showDeleteOrLeaveChatDialog(
                                                          chat),
                                                  child: _buildChatTile(chat),
                                                );
                                              }
                                              final chat =
                                                  filteredChats[index];
                                              return GestureDetector(
                                                onLongPress: () =>
                                                    _showDeleteOrLeaveChatDialog(
                                                        chat),
                                                child: _buildChatTile(chat),
                                              );
                                            },
                                          );
                                        } else if (state is ChatListFailure) {
                                          return Center(
                                            child: Text(
                                                'Error loading chats: ${state.error}'),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
          );
        },
      ),
    );
  }

  Widget _buildSavedMessagesTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(isDark ? 0.22 : 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.bookmark_rounded,
          color: AppColors.primary,
          size: 24,
        ),
      ),
      title: Text(
        LocalizationService.translate('saved_messages'),
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        LocalizationService.translate('private_storage'),
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 13,
        color: isDark ? Colors.white30 : Colors.black26,
      ),
      onTap: () {
        if (_currentUserId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SavedMessagesPage(currentUserId: _currentUserId!),
            ),
          );
        }
      },
    );
  }

  Widget _buildGroupTile(Chat chat) {
    final gradient = AppColors.avatarGradients[
        chat.otherUserName.length % AppColors.avatarGradients.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = chat.otherUserName;
    final photoURL = chat.otherUserPhoto;
    final hasPhoto = photoURL != null && photoURL.startsWith('data:image');

    return ListTile(
      key: ValueKey('group_tile_${chat.id}'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessagePage(
              chatId: chat.id,
              otherUserId: '',
              otherUserName: displayName,
            ),
          ),
        );
      },
      leading: Container(
        width: 50,
        height: 50,
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
                  width: 50,
                  height: 50,
                )
              : Center(
                  child: Text(
                    displayName.isNotEmpty
                        ? displayName.substring(0, 1).toUpperCase()
                        : 'G',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ),
      title: Row(
        children: [
          Icon(
            chat.isChannel ? Icons.campaign_rounded : Icons.groups_rounded,
            size: 16,
            color: chat.isChannel ? Colors.blue : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayName,
              style: AppTextStyles.title().copyWith(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(
        chat.lastMessage.isEmpty
            ? (chat.isChannel ? 'Kanal ochildi' : 'Guruh ochildi')
            : chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body().copyWith(
          color: chat.unreadCount > 0
              ? (isDark ? Colors.white : AppColors.textPrimaryLight)
              : (isDark ? Colors.white54 : AppColors.textSecondaryLight),
          fontWeight:
              chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('HH:mm').format(chat.lastMessageTime),
            style: AppTextStyles.timestamp()
                .copyWith(color: AppColors.textSecondaryLight),
          ),
          if (chat.unreadCount > 0) ...[
            const SizedBox(height: 5),
            UnreadCountBadge(count: chat.unreadCount),
          ],
        ],
      ),
    );
  }

  Widget _buildChatTile(Chat chat) {
    if (chat.isGroup || chat.isChannel) {
      return _buildGroupTile(chat);
    }

    final gradient = AppColors.avatarGradients[
        chat.otherUserName.length % AppColors.avatarGradients.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildTile(String displayName, bool isOnline, String? photoURL) {
      final hasPhoto = photoURL != null && photoURL.startsWith('data:image');
      return ListTile(
        key: ValueKey('chat_tile_${chat.id}'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MessagePage(
                chatId: chat.id,
                otherUserId: chat.otherUserId,
                otherUserName: displayName,
              ),
            ),
          );
        },
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
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
                        width: 52,
                        height: 52,
                      )
                    : Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.online,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            isDark ? const Color(0xFF0F172A) : Colors.white,
                        width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          displayName,
          style: AppTextStyles.title().copyWith(
              color: isDark ? Colors.white : AppColors.textPrimaryLight),
        ),
        subtitle: Text(
          chat.lastMessage.isEmpty ? 'No messages yet' : chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body().copyWith(
            color: chat.unreadCount > 0
                ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                : (isDark ? Colors.white54 : AppColors.textSecondaryLight),
            fontWeight:
                chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('HH:mm').format(chat.lastMessageTime),
              style: AppTextStyles.timestamp()
                  .copyWith(color: AppColors.textSecondaryLight),
            ),
            if (chat.unreadCount > 0) ...[
              const SizedBox(height: 5),
              UnreadCountBadge(count: chat.unreadCount),
            ],
          ],
        ),
      );
    }

    if (chat.otherUserId.isEmpty) {
      return buildTile(chat.otherUserName, chat.otherUserIsOnline, chat.otherUserPhoto);
    }

    return StreamBuilder<DocumentSnapshot>(
      key: ValueKey('user_stream_${chat.otherUserId}_${chat.id}'),
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(chat.otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        String displayName = chat.otherUserName;
        bool isOnline = chat.otherUserIsOnline;
        String? photoURL = chat.otherUserPhoto;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          displayName =
              userData?['displayName'] as String? ?? chat.otherUserName;
          isOnline = userData?['isOnline'] as bool? ?? chat.otherUserIsOnline;
          photoURL = userData?['photoURL'] as String? ?? photoURL;
        }

        return buildTile(displayName, isOnline, photoURL);
      },
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 48.0,
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
            width: 1.0,
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            color: textColor,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            hintText: LocalizationService.translate('search_hint'),
            hintStyle: TextStyle(
              color: hintColor,
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: hintColor,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 48,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(
                        Icons.cancel_rounded,
                        color: hintColor,
                        size: 18,
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 48,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
