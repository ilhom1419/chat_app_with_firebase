import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import '../../../../core/cache/hive_service.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../core/diagnostics/kakku_auth_trace.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../shared/widgets/yeschat_logo.dart';
import '../../domain/entities/app_user.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';
import 'passcode_page.dart';
import '../../../../core/services/passcode_service.dart';
import '../../../chats/presentation/pages/chat_list_page.dart';

class SplashPage extends StatefulWidget {
  final Widget? homeTarget;
  final Widget? loginTarget;

  const SplashPage({super.key, this.homeTarget, this.loginTarget});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Fast path: If Hive already has a validated authenticated session,
    // immediately navigate to avoid ANY unnecessary login redirect.
    final localSession = HiveService.getAuthSession();
    if (localSession != null) {
      final localUser = AppUser(
        uid: localSession['uid'] as String,
        email: localSession['email'] as String,
        displayName: localSession['displayName'] as String,
        photoURL: localSession['photoURL'] as String?,
        isOnline: true,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(AuthAuthenticated(localUser));
      });
      context.read<AuthBloc>().add(AuthCheckRequested());
      return;
    }

    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is AuthAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(authBloc.state);
      });
    } else {
      authBloc.add(AuthCheckRequested());
    }
  }

  void _handleNavigation(AuthState state) {
    if (_navigated || !mounted) return;
    final navigator = Navigator.of(context);
    if (state is AuthAuthenticated) {
      _navigated = true;
      KakkuAuthTrace.log('ROUTER_REDIRECT_REQUESTED', details: {
        'destination': 'ChatListPage',
        'reason': 'AuthAuthenticated',
        'userHash': KakkuAuthTrace.safeUid(state.user.uid),
      });

      bool isPasscodeEnabled = false;
      if (Hive.isBoxOpen('settings')) {
        try {
          isPasscodeEnabled = PasscodeService.isPasscodeEnabled(
              uid: state.user.uid, box: Hive.box('settings'));
        } catch (_) {}
      }

      if (isPasscodeEnabled && mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => PasscodePage(
              userId: state.user.uid,
              mode: PasscodeMode.enter,
              onSuccess: (passcodeCtx) {
                Navigator.of(passcodeCtx).pushReplacement(
                  MaterialPageRoute(
                      builder: (_) =>
                          widget.homeTarget ?? const ChatListPage()),
                );
              },
            ),
          ),
        );
      } else if (mounted) {
        navigator.pushReplacement(
          MaterialPageRoute(
              builder: (_) => widget.homeTarget ?? const ChatListPage()),
        );
      }
    } else if (state is AuthUnauthenticated) {
      _navigated = true;
      KakkuAuthTrace.log('ROUTER_REDIRECT_REQUESTED', details: {
        'destination': 'LoginPage',
        'reason': 'AuthUnauthenticated',
      });
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => widget.loginTarget ?? const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) => _handleNavigation(state),
      builder: (context, state) {
        final isFailure = state is AuthFailure;
        return Scaffold(
          backgroundColor: AppColors.bgDark,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const YesChatLogo(
                  size: 110,
                  borderRadius: 28,
                  showShadow: true,
                )
                    .animate()
                    .scale(
                        delay: 200.ms,
                        duration: 600.ms,
                        curve: Curves.easeOutBack)
                    .shimmer(delay: 800.ms, duration: 1800.ms),
                const SizedBox(height: 24),
                Text(
                  'YesChat!',
                  style: AppTextStyles.h1().copyWith(
                    color: Colors.white,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  LocalizationService.translate('app_tagline'),
                  style: AppTextStyles.caption()
                      .copyWith(color: AppColors.textSecondaryDark),
                ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                if (isFailure) ...[
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption().copyWith(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(AuthCheckRequested());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(LocalizationService.translate('retry') == 'retry'
                        ? 'Qayta urinish'
                        : LocalizationService.translate('retry')),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
