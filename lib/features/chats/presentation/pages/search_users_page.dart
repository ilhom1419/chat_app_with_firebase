import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/widgets/adaptive_scaffold.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../messages/presentation/pages/message_page.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../core/localization/localization_service.dart';

class SearchUsersPage extends StatefulWidget {
  const SearchUsersPage({super.key});

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.uid;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) async {
    if (query.trim().isEmpty || _currentUserId == null) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final chatRepository = context.read<ChatRepository>();
      final users =
          await chatRepository.searchUsers(query.trim(), _currentUserId!);

      final cleanQuery = query.trim().replaceAll('@', '').toLowerCase();

      final chatsSnap = await FirebaseFirestore.instance
          .collection('chats')
          .where('type', isEqualTo: 'public')
          .get();

      final publicChats = chatsSnap.docs
          .map((doc) => doc.data())
          .where((data) {
            final name = (data['groupName'] as String? ?? '').toLowerCase();
            final username = (data['username'] as String? ?? '').toLowerCase();
            return name.contains(cleanQuery) || username.contains(cleanQuery);
          })
          .toList();

      setState(() {
        _searchResults = [...users, ...publicChats];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }

  void _startChat(AppUser otherUser) async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chatRepository = context.read<ChatRepository>();
      // Chat yaratish yoki mavjudini olish
      final chatId =
          await chatRepository.createOrGetChat(_currentUserId!, otherUser.uid);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Chat xonasiga o'tish
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MessagePage(
              chatId: chatId,
              otherUserId: otherUser.uid,
              otherUserName: otherUser.displayName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        return AdaptiveScaffold(
          title: Text(LocalizationService.translate('search_users_title'),
              style: AppTextStyles.h2()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: LocalizationService.translate('search_by_name'),
                    hintStyle:
                        TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: isDark ? Colors.white38 : Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF1E293B) : AppColors.inputLight,
                  ),
                  onChanged: _onSearch,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? LocalizationService.translate(
                                      'type_to_search')
                                  : 'No users found',
                              style: AppTextStyles.body().copyWith(
                                  color: isDark
                                      ? Colors.white38
                                      : AppColors.textSecondaryLight),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final item = _searchResults[index];

                              if (item is Map<String, dynamic>) {
                                final isChannel =
                                    item['isChannel'] as bool? ?? false;
                                final groupName = item['groupName'] as String? ??
                                    (isChannel ? LocalizationService.translate('channel_fallback') : LocalizationService.translate('group_fallback'));
                                final chatId = item['id'] as String;
                                final photoURL = item['groupAvatar'] as String?;
                                final username = item['username'] as String?;
                                final memberCount = (item['memberCount'] as num?)?.toInt() ??
                                    (item['participants'] as List?)?.length ?? 0;
                                final hasPhoto = photoURL != null &&
                                    photoURL.startsWith('data:image');
                                final gradient = AppColors.avatarGradients[
                                    groupName.length %
                                        AppColors.avatarGradients.length];

                                return ListTile(
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => MessagePage(
                                          chatId: chatId,
                                          otherUserId: '',
                                          otherUserName: groupName,
                                        ),
                                      ),
                                    );
                                  },
                                  leading: Container(
                                    width: 44,
                                    height: 44,
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
                                              width: 44,
                                              height: 44,
                                            )
                                          : Center(
                                              child: Icon(
                                                isChannel
                                                    ? Icons.campaign_rounded
                                                    : Icons.groups_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    groupName,
                                    style: AppTextStyles.title().copyWith(
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.textPrimaryLight),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(
                                        isChannel
                                            ? Icons.campaign_rounded
                                            : Icons.groups_rounded,
                                        size: 14,
                                        color: isChannel
                                            ? Colors.blue
                                            : Colors.teal,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isChannel
                                            ? LocalizationService.translate('public_channel_with_count', params: {'count': memberCount.toString()})
                                            : LocalizationService.translate('public_group_with_count', params: {'count': memberCount.toString()}),
                                        style: TextStyle(
                                            color: isChannel
                                                ? Colors.blue
                                                : Colors.teal,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (username != null &&
                                          username.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '@$username',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black45,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }

                              final user = item as AppUser;
                              final gradient = AppColors.avatarGradients[
                                  user.displayName.length %
                                      AppColors.avatarGradients.length];
                              final hasPhoto = user.photoURL != null &&
                                  user.photoURL!.startsWith('data:image');

                              return ListTile(
                                onTap: () => _startChat(user),
                                leading: Container(
                                  width: 44,
                                  height: 44,
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
                                            user.photoURL,
                                            fit: BoxFit.cover,
                                            width: 44,
                                            height: 44,
                                          )
                                        : Center(
                                            child: Text(
                                              user.displayName
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  user.displayName,
                                  style: AppTextStyles.title().copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.email,
                                      style: AppTextStyles.caption().copyWith(
                                          color: isDark
                                              ? Colors.white54
                                              : AppColors.textSecondaryLight),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.isOnline
                                          ? LocalizationService.translate('online')
                                          : (user.lastSeen != null
                                              ? LocalizationService.formatLastSeen(user.lastSeen!)
                                              : LocalizationService.translate('offline')),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: user.isOnline
                                            ? AppColors.online
                                            : Colors.grey,
                                        fontWeight: user.isOnline
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: user.isOnline
                                        ? AppColors.online
                                        : Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
