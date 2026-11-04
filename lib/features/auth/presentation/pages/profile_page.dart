import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/cache/hive_service.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../core/services/app_share_service.dart';
import '../../../../core/services/passcode_service.dart';
import '../../../../core/theme/theme_manager.dart';
import '../../../../main.dart';
import '../../../../shared/utils/app_image.dart';
import '../../../../shared/widgets/adaptive_scaffold.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../shared/widgets/yeschat_logo.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../chats/domain/entities/chat.dart';
import '../../../chats/domain/repositories/chat_repository.dart';
import '../../../chats/presentation/bloc/chat_list_bloc.dart';
import '../../../chats/presentation/bloc/chat_list_state.dart';
import '../../../chats/presentation/pages/folders_management_page.dart';
import '../../../chats/presentation/pages/settings_page.dart';
import '../../../saved_messages/presentation/pages/saved_messages_page.dart';

class ProfilePage extends StatefulWidget {
  final bool embedMode;
  const ProfilePage({super.key, this.embedMode = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = fb.FirebaseAuth.instance;
  bool _isUploadingPhoto = false;

  String? _resolveCurrentUserId(BuildContext context) {
    final fbUser = _auth.currentUser;
    if (fbUser != null && fbUser.uid.isNotEmpty) return fbUser.uid;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.uid.isNotEmpty) {
      return authState.user.uid;
    }

    final localSession = HiveService.getAuthSession();
    if (localSession != null && localSession['uid'] != null) {
      return localSession['uid'] as String;
    }

    return null;
  }

  Future<void> _onPickImage(String uid, String currentName, String currentEmail) async {
    if (_isUploadingPhoto) return;

    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Image picker error: $e');
    }

    if (pickedFile == null || !mounted) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        pickedFile.path,
        minWidth: 512,
        minHeight: 512,
        quality: 80,
      );

      if (compressedBytes != null) {
        final base64Image = base64Encode(compressedBytes);
        final base64Url = "data:image/jpeg;base64,$base64Image";

        // 1. Update Firestore
        await _firestore.collection('users').doc(uid).set({
          'photoURL': base64Url,
        }, SetOptions(merge: true));

        // 2. Update local Hive session
        await HiveService.saveAuthSession(
          uid: uid,
          email: currentEmail,
          displayName: currentName,
          photoURL: base64Url,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LocalizationService.translate('profile_updated_success'),
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.formatError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  void _showEditProfileSheet({
    required BuildContext context,
    required String uid,
    required String currentName,
    required String currentUsername,
    required String currentBio,
    required String currentEmail,
    required String? currentPhotoURL,
  }) {
    final nameController = TextEditingController(text: currentName);
    final usernameController = TextEditingController(
      text: currentUsername.startsWith('@') ? currentUsername.substring(1) : currentUsername,
    );
    final bioController = TextEditingController(text: currentBio);
    bool isSaving = false;
    String? usernameError;

    showKakkuFloatingBottomSheet(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LocalizationService.translate('edit_profile_title'),
                        style: AppTextStyles.h2().copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Display Name input
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: LocalizationService.translate('display_name'),
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.inputLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Username input
                  TextField(
                    controller: usernameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                      LengthLimitingTextInputFormatter(30),
                    ],
                    decoration: InputDecoration(
                      labelText: LocalizationService.translate('username_label'),
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      prefixText: '@',
                      prefixStyle: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.primary),
                      errorText: usernameError,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.inputLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bio input
                  TextField(
                    controller: bioController,
                    maxLines: 2,
                    maxLength: 120,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: LocalizationService.translate('bio_label'),
                      hintText: LocalizationService.translate('bio_hint'),
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      prefixIcon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.inputLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              final rawUsername = usernameController.text.trim().toLowerCase();
                              final newBio = bioController.text.trim();

                              if (newName.isEmpty) {
                                setModalState(() {
                                  usernameError = LocalizationService.translate('fill_all_fields');
                                });
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                                usernameError = null;
                              });

                              try {
                                // Check username uniqueness if changed and not empty
                                if (rawUsername.isNotEmpty && rawUsername != currentUsername.toLowerCase()) {
                                  if (rawUsername.length < 3) {
                                    setModalState(() {
                                      usernameError = LocalizationService.translate('username_char_limit');
                                      isSaving = false;
                                    });
                                    return;
                                  }

                                  final existing = await _firestore
                                      .collection('users')
                                      .where('username', isEqualTo: rawUsername)
                                      .get();

                                  final taken = existing.docs.any((d) => d.id != uid);
                                  if (taken) {
                                    setModalState(() {
                                      usernameError = LocalizationService.translate('username_taken');
                                      isSaving = false;
                                    });
                                    return;
                                  }
                                }

                                // Update Firestore
                                await _firestore.collection('users').doc(uid).set({
                                  'displayName': newName,
                                  'username': rawUsername,
                                  'bio': newBio,
                                }, SetOptions(merge: true));

                                // Update Firebase Auth
                                await _auth.currentUser?.updateDisplayName(newName);

                                // Update local Hive session
                                await HiveService.saveAuthSession(
                                  uid: uid,
                                  email: currentEmail,
                                  displayName: newName,
                                  photoURL: currentPhotoURL,
                                );

                                if (modalCtx.mounted) {
                                  Navigator.of(modalCtx).pop();
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        LocalizationService.translate('profile_updated_success'),
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  usernameError = LocalizationService.formatError(e);
                                  isSaving = false;
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              LocalizationService.translate('save_btn'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            LocalizationService.translate('logout_confirm_title'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            LocalizationService.translate('logout_confirm_desc'),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                LocalizationService.translate('cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<AuthBloc>().add(AuthSignOutRequested());
              },
              child: Text(
                LocalizationService.translate('logout_btn'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = _resolveCurrentUserId(context);

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        if (uid == null) {
          final unauthBody = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  LocalizationService.translate('not_authenticated'),
                  style: AppTextStyles.h2(),
                ),
              ],
            ),
          );

          if (widget.embedMode) return unauthBody;
          return AdaptiveScaffold(
            title: Text(LocalizationService.translate('profile_title'), style: AppTextStyles.h2()),
            body: unauthBody,
          );
        }

        // Realtime Firestore listener with fallback
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            final docData = snapshot.data?.data();

            // Resilient fallbacks: Firestore -> AuthBloc -> FirebaseAuth -> Hive
            final authState = context.read<AuthBloc>().state;
            final authUser = authState is AuthAuthenticated ? authState.user : null;
            final fbUser = _auth.currentUser;
            final localSession = HiveService.getAuthSession();

            final displayName = (docData?['displayName'] as String?)?.trim().isNotEmpty == true
                ? docData!['displayName'] as String
                : (authUser?.displayName.trim().isNotEmpty == true
                    ? authUser!.displayName
                    : (fbUser?.displayName?.trim().isNotEmpty == true
                        ? fbUser!.displayName!
                        : (localSession?['displayName'] as String? ?? 'User')));

            final email = (docData?['email'] as String?)?.trim().isNotEmpty == true
                ? docData!['email'] as String
                : (authUser?.email.trim().isNotEmpty == true
                    ? authUser!.email
                    : (fbUser?.email?.trim().isNotEmpty == true
                        ? fbUser!.email!
                        : (localSession?['email'] as String? ?? '')));

            final photoURL = (docData?['photoURL'] as String?) ??
                authUser?.photoURL ??
                fbUser?.photoURL ??
                (localSession?['photoURL'] as String?);

            final username = (docData?['username'] as String?)?.trim() ?? '';
            final bio = (docData?['bio'] as String?)?.trim() ??
                (docData?['status'] as String?)?.trim() ??
                '';

            final hasPhoto = photoURL != null &&
                (photoURL.startsWith('data:image') || photoURL.startsWith('http'));

            final gradient = AppColors.avatarGradients[
                displayName.length % AppColors.avatarGradients.length];

            final bodyContent = ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              children: [
                // 1. HERO PROFILE CARD
                _buildHeroCard(
                  context: context,
                  uid: uid,
                  displayName: displayName,
                  username: username,
                  email: email,
                  bio: bio,
                  photoURL: photoURL,
                  hasPhoto: hasPhoto,
                  gradient: gradient,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 2. PROFILE DETAILS CARD
                _buildSectionHeader(
                  context,
                  title: LocalizationService.translate('profile_info'),
                  icon: Icons.person_outline_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildDetailsCard(
                  context: context,
                  uid: uid,
                  displayName: displayName,
                  username: username,
                  bio: bio,
                  email: email,
                  photoURL: photoURL,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 3. MESSAGES & STORAGE CARD
                _buildSectionHeader(
                  context,
                  title: LocalizationService.translate('messages_and_storage'),
                  icon: Icons.cloud_outlined,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildMessagesStorageCard(
                  context: context,
                  uid: uid,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 4. SETTINGS & SECURITY CARD
                _buildSectionHeader(
                  context,
                  title: LocalizationService.translate('settings_and_privacy'),
                  icon: Icons.security_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSettingsSecurityCard(
                  context: context,
                  uid: uid,
                  lang: lang,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),

                // 5. ABOUT YESCHAT
                _buildAboutCard(context, isDark: isDark),
                const SizedBox(height: 16),

                // 6. LOG OUT TILE
                _buildLogoutCard(context, isDark: isDark),
                const SizedBox(height: 36),
              ],
            );

            if (widget.embedMode) {
              return bodyContent;
            }

            return AdaptiveScaffold(
              title: Text(
                LocalizationService.translate('profile_title'),
                style: AppTextStyles.h2(),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              body: bodyContent,
            );
          },
        );
      },
    );
  }

  // HERO CARD
  Widget _buildHeroCard({
    required BuildContext context,
    required String uid,
    required String displayName,
    required String username,
    required String email,
    required String bio,
    required String? photoURL,
    required bool hasPhoto,
    required List<Color> gradient,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          // Avatar with camera badge
          Center(
            child: Stack(
              children: [
                Container(
                  width: 104,
                  height: 104,
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
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _isUploadingPhoto
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : ClipOval(
                          child: hasPhoto
                              ? (photoURL!.startsWith('data:image')
                                  ? AppImage.memory(
                                      photoURL,
                                      fit: BoxFit.cover,
                                      width: 104,
                                      height: 104,
                                    )
                                  : Image.network(
                                      photoURL,
                                      fit: BoxFit.cover,
                                      width: 104,
                                      height: 104,
                                      errorBuilder: (_, __, ___) => _buildAvatarInitial(displayName),
                                    ))
                              : _buildAvatarInitial(displayName),
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () => _onPickImage(uid, displayName, email),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cardColor,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Display Name
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: AppTextStyles.h1().copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),

          // Online pill status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.online,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                LocalizationService.translate('status_online'),
                style: const TextStyle(
                  color: AppColors.online,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (username.isNotEmpty) ...[
                Text(
                  ' • ',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),

          // Action buttons: Edit Profile & Share
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showEditProfileSheet(
                    context: context,
                    uid: uid,
                    currentName: displayName,
                    currentUsername: username,
                    currentBio: bio,
                    currentEmail: email,
                    currentPhotoURL: photoURL,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: Text(
                    LocalizationService.translate('edit_profile_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : AppColors.inputLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                  tooltip: LocalizationService.translate('share_profile'),
                  onPressed: () {
                    final shareText = username.isNotEmpty
                        ? 'YesChat! Profile: @$username ($displayName)'
                        : 'YesChat! Profile: $displayName';
                    AppShareService.shareText(text: shareText);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarInitial(String displayName) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'U';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // SECTION HEADER
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // DETAILS CARD
  Widget _buildDetailsCard({
    required BuildContext context,
    required String uid,
    required String displayName,
    required String username,
    required String bio,
    required String email,
    required String? photoURL,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Display Name
          _buildInfoTile(
            icon: Icons.person_rounded,
            title: displayName,
            subtitle: LocalizationService.translate('display_name'),
            trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
            isDark: isDark,
            onTap: () => _showEditProfileSheet(
              context: context,
              uid: uid,
              currentName: displayName,
              currentUsername: username,
              currentBio: bio,
              currentEmail: email,
              currentPhotoURL: photoURL,
            ),
          ),
          _buildDivider(isDark),

          // Username
          _buildInfoTile(
            icon: Icons.alternate_email_rounded,
            title: username.isNotEmpty
                ? '@$username'
                : LocalizationService.translate('set_username'),
            subtitle: LocalizationService.translate('username_label'),
            titleColor: username.isNotEmpty ? AppColors.primary : Colors.grey,
            trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
            isDark: isDark,
            onTap: () => _showEditProfileSheet(
              context: context,
              uid: uid,
              currentName: displayName,
              currentUsername: username,
              currentBio: bio,
              currentEmail: email,
              currentPhotoURL: photoURL,
            ),
          ),
          _buildDivider(isDark),

          // Bio
          _buildInfoTile(
            icon: Icons.info_outline_rounded,
            title: bio.isNotEmpty ? bio : LocalizationService.translate('bio_hint'),
            subtitle: LocalizationService.translate('bio_label'),
            titleColor: bio.isNotEmpty ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
            trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
            isDark: isDark,
            onTap: () => _showEditProfileSheet(
              context: context,
              uid: uid,
              currentName: displayName,
              currentUsername: username,
              currentBio: bio,
              currentEmail: email,
              currentPhotoURL: photoURL,
            ),
          ),
          _buildDivider(isDark),

          // Email
          _buildInfoTile(
            icon: Icons.email_outlined,
            title: email.isNotEmpty ? email : '---',
            subtitle: LocalizationService.translate('email_hint'),
            trailing: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
            isDark: isDark,
            onTap: email.isNotEmpty
                ? () {
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.translate('email_copied')),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                : null,
          ),
          _buildDivider(isDark),

          // Account ID (UID)
          _buildInfoTile(
            icon: Icons.fingerprint_rounded,
            title: uid,
            subtitle: LocalizationService.translate('user_id'),
            trailing: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
            isDark: isDark,
            onTap: () {
              Clipboard.setData(ClipboardData(text: uid));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LocalizationService.translate('id_copied')),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // MESSAGES & STORAGE CARD
  Widget _buildMessagesStorageCard({
    required BuildContext context,
    required String uid,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Saved Messages
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 22),
            ),
            title: Text(
              LocalizationService.translate('saved_messages_title'),
              style: AppTextStyles.title().copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            subtitle: Text(
              LocalizationService.translate('saved_messages_desc'),
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedMessagesPage(currentUserId: uid),
                ),
              );
            },
          ),
          _buildDivider(isDark),

          // Chat Folders
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder_rounded, color: Color(0xFF0A84FF), size: 22),
            ),
            title: Text(
              LocalizationService.translate('folders_title_profile'),
              style: AppTextStyles.title().copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            subtitle: Text(
              LocalizationService.translate('folders_desc_profile'),
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            onTap: () {
              final chatState = context.read<ChatListBloc>().state;
              final allChats = chatState is ChatListLoaded ? chatState.chats : <Chat>[];
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FoldersManagementPage(
                    currentUserId: uid,
                    chatRepository: context.read<ChatRepository>(),
                    allChats: allChats,
                    embedMode: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // SETTINGS & SECURITY CARD
  Widget _buildSettingsSecurityCard({
    required BuildContext context,
    required String uid,
    required String lang,
    required bool isDark,
  }) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Passcode Lock status
          FutureBuilder<Box>(
            future: Hive.openBox('settings'),
            builder: (context, snapshot) {
              final box = snapshot.data;
              final isPasscodeOn = box != null && PasscodeService.isPasscodeEnabled(uid: uid, box: box);

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isPasscodeOn ? AppColors.online : Colors.grey).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: isPasscodeOn ? AppColors.online : Colors.grey,
                    size: 22,
                  ),
                ),
                title: Text(
                  LocalizationService.translate('security_privacy_title'),
                  style: AppTextStyles.title().copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  isPasscodeOn
                      ? LocalizationService.translate('enabled_val')
                      : LocalizationService.translate('disabled_val'),
                  style: TextStyle(
                    color: isPasscodeOn ? AppColors.online : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              );
            },
          ),
          _buildDivider(isDark),

          // Dark Mode switch
          ListenableBuilder(
            listenable: locator<ThemeManager>(),
            builder: (context, _) {
              final themeManager = locator<ThemeManager>();
              return SwitchListTile.adaptive(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAF52DE).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    themeManager.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: const Color(0xFFAF52DE),
                    size: 22,
                  ),
                ),
                title: Text(
                  LocalizationService.translate('dark_mode'),
                  style: AppTextStyles.title().copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                value: themeManager.isDarkMode,
                onChanged: (val) => themeManager.toggleTheme(val),
                activeColor: AppColors.primary,
              );
            },
          ),
          _buildDivider(isDark),

          // Language Selector
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C896).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.language_rounded, color: Color(0xFF00C896), size: 22),
            ),
            title: Text(
              LocalizationService.translate('choose_lang'),
              style: AppTextStyles.title().copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            trailing: DropdownButton<String>(
              value: lang,
              dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              items: const [
                DropdownMenuItem(value: 'uz', child: Text("O'zbekcha")),
                DropdownMenuItem(value: 'ru', child: Text("Русский")),
                DropdownMenuItem(value: 'en', child: Text("English")),
              ],
              onChanged: (val) {
                if (val != null) {
                  LocalizationService.changeLanguage(val);
                }
              },
            ),
          ),
          _buildDivider(isDark),

          // Full Settings Page
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_rounded, color: Colors.grey, size: 22),
            ),
            title: Text(
              LocalizationService.translate('settings_title'),
              style: AppTextStyles.title().copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ABOUT CARD
  Widget _buildAboutCard(BuildContext context, {required bool isDark}) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const YesChatLogo(
            size: 44,
            borderRadius: 12,
            showShadow: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.translate('about_app'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${LocalizationService.translate('app_version')} 1.0.0 • ${LocalizationService.translate('app_tagline')}',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // LOGOUT CARD
  Widget _buildLogoutCard(BuildContext context, {required bool isDark}) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
        ),
        title: Text(
          LocalizationService.translate('logout_btn'),
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          LocalizationService.translate('logout_confirm_title'),
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.error),
        onTap: () => _confirmLogout(context),
      ),
    );
  }

  // HELPER TILES
  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: titleColor ?? (isDark ? Colors.white : Colors.black87),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: isDark ? const Color(0xFF334155) : Colors.grey[200],
    );
  }
}
