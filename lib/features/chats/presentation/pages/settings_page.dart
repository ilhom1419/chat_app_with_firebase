import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/widgets/adaptive_scaffold.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../auth/presentation/pages/passcode_page.dart';
import '../../../../core/theme/theme_manager.dart';
import '../../../../main.dart';
import '../../../../shared/widgets/yeschat_logo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/passcode_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  String _getAutoLockText(int duration) {
    if (duration == 0) return LocalizationService.translate('never_val');
    if (duration == 300)
      return '5 ${LocalizationService.translate('minutes_val')}';
    if (duration == 600)
      return '10 ${LocalizationService.translate('minutes_val')}';
    if (duration == 1800)
      return '30 ${LocalizationService.translate('minutes_val')}';
    if (duration == 3600)
      return '1 ${LocalizationService.translate('hours_val')}';
    return '$duration s';
  }

  void _showAutoLockDialog(BuildContext context, Box box) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currentVal = PasscodeService.getAutoLockDuration(uid: uid, box: box);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Text(
            LocalizationService.translate('auto_lock'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogOption(context, box, 0,
                  LocalizationService.translate('never_val'), currentVal),
              _buildDialogOption(
                  context,
                  box,
                  300,
                  '5 ${LocalizationService.translate('minutes_val')}',
                  currentVal),
              _buildDialogOption(
                  context,
                  box,
                  600,
                  '10 ${LocalizationService.translate('minutes_val')}',
                  currentVal),
              _buildDialogOption(
                  context,
                  box,
                  1800,
                  '30 ${LocalizationService.translate('minutes_val')}',
                  currentVal),
              _buildDialogOption(
                  context,
                  box,
                  3600,
                  '1 ${LocalizationService.translate('hours_val')}',
                  currentVal),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogOption(
      BuildContext context, Box box, int value, String label, int currentVal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RadioListTile<int>(
      title: Text(
        label,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      ),
      activeColor: AppColors.primary,
      value: value,
      groupValue: currentVal,
      onChanged: (val) async {
        if (val != null) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          await PasscodeService.setAutoLockDuration(val, uid: uid, box: box);
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        return AdaptiveScaffold(
          title: Text(
            LocalizationService.translate('settings_title'),
            style: AppTextStyles.h2(),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: ListTile(
                    leading: const Icon(Icons.language_rounded,
                        color: AppColors.primary),
                    title: Text(
                      LocalizationService.translate('choose_lang'),
                      style: AppTextStyles.title().copyWith(
                        color:
                            isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: lang,
                      dropdownColor:
                          isDark ? const Color(0xFF0F172A) : Colors.white,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
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
                ),
                const SizedBox(height: 12),
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: ListenableBuilder(
                    listenable: locator<ThemeManager>(),
                    builder: (context, _) {
                      final themeManager = locator<ThemeManager>();
                      return SwitchListTile.adaptive(
                        title: Text(
                          LocalizationService.translate('dark_mode'),
                          style: AppTextStyles.title().copyWith(
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        secondary: Icon(
                          themeManager.isDarkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: AppColors.primary,
                        ),
                        value: themeManager.isDarkMode,
                        onChanged: (value) {
                          themeManager.toggleTheme(value);
                        },
                        activeColor: AppColors.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: FutureBuilder<Box>(
                    future: Hive.openBox('settings'),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final box = snapshot.data!;

                      return ValueListenableBuilder<Box>(
                        valueListenable: box.listenable(),
                        builder: (context, box, _) {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          final isPasscodeEnabled =
                              PasscodeService.isPasscodeEnabled(uid: uid, box: box);
                          final isBiometricEnabled =
                              PasscodeService.isBiometricEnabled(uid: uid, box: box);
                          final autoLockDuration =
                              PasscodeService.getAutoLockDuration(uid: uid, box: box);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.lock_rounded,
                                    color: AppColors.primary),
                                title: Text(
                                  LocalizationService.translate(
                                      'passcode_lock'),
                                  style: AppTextStyles.title().copyWith(
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                subtitle: Text(
                                  isPasscodeEnabled
                                      ? LocalizationService.translate(
                                          'disable_passcode')
                                      : LocalizationService.translate(
                                          'enable_passcode'),
                                  style: AppTextStyles.caption()
                                      .copyWith(color: Colors.grey),
                                ),
                                trailing: Icon(
                                  isPasscodeEnabled
                                      ? Icons.lock_open_rounded
                                      : Icons.lock_outline_rounded,
                                  color: isPasscodeEnabled
                                      ? Colors.redAccent
                                      : AppColors.primary,
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PasscodePage(
                                        userId: uid,
                                        mode: isPasscodeEnabled
                                            ? PasscodeMode.disable
                                            : PasscodeMode.setup,
                                        onSuccess: (passcodeCtx) {
                                          Navigator.of(passcodeCtx).pop();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (isPasscodeEnabled) ...[
                                const Divider(height: 1, indent: 56),
                                ListTile(
                                  leading: const Icon(Icons.password_rounded,
                                      color: AppColors.primary),
                                  title: Text(
                                    LocalizationService.translate(
                                        'change_passcode'),
                                    style: AppTextStyles.title().copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  subtitle: Text(
                                    LocalizationService.translate(
                                        'change_passcode_desc'),
                                    style: AppTextStyles.caption()
                                        .copyWith(color: Colors.grey),
                                  ),
                                  trailing: const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: Colors.grey),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PasscodePage(
                                          mode: PasscodeMode.change,
                                          onSuccess: (passcodeCtx) {
                                            Navigator.of(passcodeCtx).pop();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  LocalizationService.translate(
                                                      'passcode_changed_success'),
                                                ),
                                                backgroundColor: AppColors.primary,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1, indent: 56),
                                SwitchListTile(
                                  secondary: const Icon(
                                      Icons.fingerprint_rounded,
                                      color: AppColors.primary),
                                  title: Text(
                                    LocalizationService.translate(
                                        'biometric_lock'),
                                    style: AppTextStyles.title().copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  value: isBiometricEnabled,
                                  onChanged: (val) async {
                                    await PasscodeService.setBiometricEnabled(
                                        val, uid: uid, box: box);
                                  },
                                ),
                                const Divider(height: 1, indent: 56),
                                ListTile(
                                  leading: const Icon(Icons.timer_outlined,
                                      color: AppColors.primary),
                                  title: Text(
                                    LocalizationService.translate('auto_lock'),
                                    style: AppTextStyles.title().copyWith(
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _getAutoLockText(autoLockDuration),
                                    style: AppTextStyles.caption()
                                        .copyWith(color: Colors.grey),
                                  ),
                                  trailing: const Icon(
                                      Icons.keyboard_arrow_right_rounded,
                                      color: Colors.grey),
                                  onTap: () =>
                                      _showAutoLockDialog(context, box),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        const YesChatLogo(
                          size: 46,
                          borderRadius: 14,
                          showShadow: false,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.translate('about_app'),
                                style: AppTextStyles.title().copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${LocalizationService.translate('app_version')} 1.0.0 • ${LocalizationService.translate('app_tagline')}',
                                style: AppTextStyles.caption().copyWith(
                                  color: isDark ? Colors.white60 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
