import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/chats/domain/repositories/chat_repository.dart';
import 'features/chats/data/repositories/chat_repository_impl.dart';
import 'features/chats/presentation/bloc/chat_list_bloc.dart';
import 'features/messages/domain/repositories/message_repository.dart';
import 'features/messages/data/repositories/message_repository_impl.dart';
import 'features/messages/presentation/bloc/message_bloc.dart';
import 'features/stories/domain/repositories/story_repository.dart';
import 'features/stories/data/repositories/story_repository_impl.dart';
import 'features/voice_chat/domain/repositories/voice_chat_repository.dart';
import 'features/voice_chat/data/repositories/voice_chat_repository_impl.dart';
import 'core/design_system/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'core/localization/localization_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'features/messages/presentation/widgets/incoming_call_dialog.dart';
import 'features/auth/presentation/pages/passcode_page.dart';
import 'core/services/passcode_service.dart';
import 'core/diagnostics/kakku_auth_trace.dart';
import 'dart:async';
import 'main.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> with WidgetsBindingObserver {
  final authRepository = AuthRepositoryImpl();
  final chatRepository = ChatRepositoryImpl();
  final messageRepository = MessageRepositoryImpl();
  final storyRepository = StoryRepositoryImpl();
  final voiceChatRepository = VoiceChatRepositoryImpl();

  Timer? _inactivityTimer;
  DateTime? _backgroundTime;
  bool _isCurrentlyLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnlineStatus(true);
    _startInactivityTimer();
  }

  @override
  void dispose() {
    KakkuAuthTrace.log('APP_DISPOSE');
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnlineStatus(false);
    super.dispose();
  }

  void _startInactivityTimer() async {
    _inactivityTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final box = await Hive.openBox('settings');
    final isPasscodeEnabled =
        PasscodeService.isPasscodeEnabled(uid: uid, box: box);
    if (!isPasscodeEnabled) return;

    final autoLockSeconds =
        PasscodeService.getAutoLockDuration(uid: uid, box: box);
    if (autoLockSeconds <= 0) return;

    _inactivityTimer = Timer(Duration(seconds: autoLockSeconds), () {
      _lockApp();
    });
  }

  void _resetInactivityTimer() {
    _startInactivityTimer();
  }

  void _lockApp() {
    _inactivityTimer?.cancel();
    final context = navigatorKey.currentContext;
    if (context == null || _isCurrentlyLocked) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isCurrentlyLocked = true;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/passcode'),
        builder: (_) => PasscodePage(
          userId: uid,
          mode: PasscodeMode.enter,
          onSuccess: (passcodeCtx) {
            _isCurrentlyLocked = false;
            Navigator.of(passcodeCtx).pop();
            _startInactivityTimer();
          },
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      KakkuAuthTrace.log('APP_RESUMED', details: {
        'hasFirebaseUser': FirebaseAuth.instance.currentUser != null,
        'userHash': KakkuAuthTrace.safeUid(FirebaseAuth.instance.currentUser?.uid),
      });
      _setUserOnlineStatus(true);
      _checkAutoLockOnResume();
    } else {
      KakkuAuthTrace.log('APP_BACKGROUND', details: {
        'hasFirebaseUser': FirebaseAuth.instance.currentUser != null,
        'state': state.name,
      });
      _setUserOnlineStatus(false);
      _backgroundTime = DateTime.now();
      _inactivityTimer?.cancel();
    }
  }

  void _checkAutoLockOnResume() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final box = await Hive.openBox('settings');
    final isPasscodeEnabled =
        PasscodeService.isPasscodeEnabled(uid: uid, box: box);
    final autoLockSeconds =
        PasscodeService.getAutoLockDuration(uid: uid, box: box);
    if (isPasscodeEnabled &&
        autoLockSeconds > 0 &&
        _backgroundTime != null &&
        !_isCurrentlyLocked) {
      final difference = DateTime.now().difference(_backgroundTime!).inSeconds;
      if (difference >= autoLockSeconds) {
        _lockApp();
      } else {
        _startInactivityTimer();
      }
    } else if (!_isCurrentlyLocked) {
      _startInactivityTimer();
    }
  }

  Future<void> _setUserOnlineStatus(bool isOnline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Error updating status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<ChatRepository>.value(value: chatRepository),
        RepositoryProvider<MessageRepository>.value(value: messageRepository),
        RepositoryProvider<StoryRepository>.value(value: storyRepository),
        RepositoryProvider<VoiceChatRepository>.value(
            value: voiceChatRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(authRepository: authRepository),
          ),
          BlocProvider<ChatListBloc>(
            create: (context) => ChatListBloc(chatRepository: chatRepository),
          ),
          BlocProvider<MessageBloc>(
            create: (context) =>
                MessageBloc(messageRepository: messageRepository),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812), // iPhone X standart o'lchami
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            final themeManager = locator<ThemeManager>();
            return ListenableBuilder(
              listenable: Listenable.merge([themeManager, LocalizationService.langNotifier]),
              builder: (context, _) {
                return Listener(
                  onPointerDown: (_) => _resetInactivityTimer(),
                  child: MaterialApp(
                    navigatorKey: navigatorKey,
                    title: 'YesChat!',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.lightTheme,
                    darkTheme: AppTheme.darkTheme,
                    themeMode: themeManager.themeMode,
                    locale: LocalizationService.currentLocale,
                    supportedLocales: LocalizationService.supportedLocales,
                    localizationsDelegates:
                        LocalizationService.localizationsDelegates,
                    builder: (context, child) {
                      return IncomingCallListener(child: child ?? const SplashPage());
                    },
                    home: const SplashPage(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
