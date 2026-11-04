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
import '../../../chats/presentation/pages/chat_list_page.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../shared/widgets/yeschat_logo.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      AdaptiveDialog.show(
        context: context,
        title: LocalizationService.translate('error'),
        content: LocalizationService.translate('fill_all_fields'),
      );
      return;
    }

    context.read<AuthBloc>().add(AuthSignUpRequested(
          email: email,
          password: password,
          displayName: name,
        ));
  }

  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => ChatListPage()),
            (route) => false,
          );
        } else if (state is AuthFailure) {
          AdaptiveDialog.show(
            context: context,
            title: LocalizationService.translate('registration_error'),
            content: state.message,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ValueListenableBuilder<String>(
          valueListenable: LocalizationService.langNotifier,
          builder: (context, lang, _) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              appBar: AppBar(
                backgroundColor:
                    isDark ? const Color(0xFF0F172A) : Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white : Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: const YesChatLogo(
                          size: 80,
                          borderRadius: 20,
                          showShadow: true,
                        ),
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 20),

                      Center(
                        child: Text(
                          LocalizationService.translate('create_account_title'),
                          style: AppTextStyles.h1().copyWith(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight),
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 8),

                      Center(
                        child: Text(
                          LocalizationService.translate(
                              'join_network_subtitle'),
                          style: AppTextStyles.body().copyWith(
                              color: isDark
                                  ? Colors.white54
                                  : AppColors.textSecondaryLight),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 32),

                      // Name
                      AdaptiveTextField(
                        controller: _nameController,
                        placeholder:
                            LocalizationService.translate('display_name'),
                        prefix: const Icon(Icons.person_outline_rounded,
                            color: Colors.grey),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideX(begin: -0.1, end: 0),
                      const SizedBox(height: 16),

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
                          .fadeIn(delay: 500.ms)
                          .slideX(begin: 0.1, end: 0),
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
                          .fadeIn(delay: 600.ms)
                          .slideX(begin: -0.1, end: 0),
                      const SizedBox(height: 32),

                      // Register Button
                      AdaptiveButton(
                        text: LocalizationService.translate('signup_btn'),
                        isLoading: isLoading,
                        onPressed: _onRegister,
                        color: AppColors.primary,
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
