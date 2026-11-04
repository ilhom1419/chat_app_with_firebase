import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../shared/widgets/adaptive_button.dart';
import '../../../../shared/widgets/adaptive_text_field.dart';
import '../../../../shared/widgets/adaptive_dialog.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'register_page.dart';
import '../../../chats/presentation/pages/chat_list_page.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../shared/widgets/yeschat_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AdaptiveDialog.show(
        context: context,
        title: LocalizationService.translate('error'),
        content: LocalizationService.translate('fill_all_fields'),
      );
      return;
    }

    context.read<AuthBloc>().add(AuthSignInRequested(email, password));
  }

  void _showForgotPasswordDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailResetController =
        TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text(
            LocalizationService.translate('forgot_password_dialog_title'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocalizationService.translate('forgot_password_dialog_desc'),
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 14),
              ),
              const SizedBox(height: 16),
              AdaptiveTextField(
                controller: emailResetController,
                placeholder: LocalizationService.translate('email_hint'),
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(Icons.email_outlined, color: Colors.grey),
              ),
            ],
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final email = emailResetController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.translate(
                          'forgot_password_empty_email')),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                context.read<AuthBloc>().add(AuthPasswordResetRequested(email));
                Navigator.of(ctx).pop();
              },
              child: Text(LocalizationService.translate('send_btn')),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.langNotifier,
      builder: (context, lang, _) {
        return BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ChatListPage()),
              );
            } else if (state is AuthPasswordResetSuccess) {
              AdaptiveDialog.show(
                context: context,
                title: LocalizationService.translate(
                    'forgot_password_success_title'),
                content: LocalizationService.translate(
                    'forgot_password_success_desc'),
              );
            } else if (state is AuthFailure) {
              AdaptiveDialog.show(
                context: context,
                title: LocalizationService.translate('authentication_error'),
                content: state.message,
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      // Logo / Icon
                      Center(
                        child: const YesChatLogo(
                          size: 86,
                          borderRadius: 22,
                          showShadow: true,
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 20),

                      // Title
                      Center(
                        child: Text(
                          LocalizationService.translate('login_title'),
                          style: AppTextStyles.h1().copyWith(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 6),

                      Center(
                        child: Text(
                          LocalizationService.translate('welcome_to_app'),
                          style: AppTextStyles.body().copyWith(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondaryLight),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 40),

                      // Email
                      AdaptiveTextField(
                        controller: _emailController,
                        placeholder:
                            LocalizationService.translate('email_hint'),
                        keyboardType: TextInputType.emailAddress,
                        prefix: const Icon(Icons.email_outlined,
                            color: Colors.grey),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideX(begin: -0.1, end: 0),
                      const SizedBox(height: 16),

                      // Password
                      AdaptiveTextField(
                        controller: _passwordController,
                        placeholder:
                            LocalizationService.translate('password_hint'),
                        obscureText: true,
                        prefix: const Icon(Icons.lock_outline_rounded,
                            color: Colors.grey),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms)
                          .slideX(begin: 0.1, end: 0),
                      const SizedBox(height: 12),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: _showForgotPasswordDialog,
                          child: Text(
                            LocalizationService.translate(
                                'forgot_password_btn'),
                            style: AppTextStyles.body().copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 550.ms),
                      const SizedBox(height: 24),

                      // Sign In Button
                      AdaptiveButton(
                        text: LocalizationService.translate('login_btn'),
                        isLoading: isLoading,
                        onPressed: _onLogin,
                        color: AppColors.primary,
                      ).animate().fadeIn(delay: 600.ms),
                      const SizedBox(height: 24),

                      // Navigation to register
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LocalizationService.translate('dont_have_account'),
                            style: AppTextStyles.body().copyWith(
                                color: isDark
                                    ? Colors.white54
                                    : AppColors.textSecondaryLight),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const RegisterPage()),
                              );
                            },
                            child: Text(
                              LocalizationService.translate('signup_btn'),
                              style: AppTextStyles.body().copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 700.ms),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
