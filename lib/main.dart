import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'core/diagnostics/kakku_auth_trace.dart';
import 'core/firebase/firebase_service.dart';
import 'core/cache/hive_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/localization/localization_service.dart';
import 'core/theme/theme_manager.dart';
import 'app.dart';

final locator = GetIt.instance;

void main() async {
  KakkuAuthTrace.log('APP_START');
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase
  KakkuAuthTrace.log('FIREBASE_INIT_STARTED');
  try {
    await FirebaseService.init();
    KakkuAuthTrace.log('FIREBASE_INIT_COMPLETED', details: {
      'hasFirebaseUser': FirebaseAuth.instance.currentUser != null,
      'userHash':
          KakkuAuthTrace.safeUid(FirebaseAuth.instance.currentUser?.uid),
    });
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    KakkuAuthTrace.log('FIREBASE_INIT_FAILED', details: {'error': e.toString()});
    print("Firebase init error: $e");
  }

  // Hive local cache
  await HiveService.init();

  // Localization service
  await LocalizationService.init();

  // Theme Manager setup
  final themeManager = ThemeManager();
  await themeManager.init();
  locator.registerSingleton<ThemeManager>(themeManager);

  // Push Notifications
  try {
    await NotificationService.init();
  } catch (e) {
    print("Notification service init error: $e");
  }

  runApp(const ChatApp());
}
