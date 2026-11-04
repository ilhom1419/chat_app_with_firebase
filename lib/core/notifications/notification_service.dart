import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../localization/localization_service.dart';
import '../../features/chats/data/services/chat_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  print("FCM Background message: ${message.messageId}");
}

class NotificationService {
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String chatMessagesChannel = 'chat_messages_channel';
  static const String silentChatMessagesChannel = 'silent_chat_messages_channel';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    chatMessagesChannel,
    'Chat Messages',
    description: 'Yangi chat xabarlari uchun bildirishnomalar',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _silentChannel = AndroidNotificationChannel(
    silentChatMessagesChannel,
    'Silent Chat Messages',
    description: 'Tovushsiz yangi chat xabarlari uchun bildirishnomalar',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static StreamSubscription? _firestoreNotificationSub;

  static Future<void> init() async {
    // 1. Android va iOS uchun ruxsat so'rash
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print("FCM Permission status: ${settings.authorizationStatus}");
    } catch (e) {
      print("FCM requestPermission error: $e");
    }

    // Android 13+ uchun mahalliy bildirishnoma ruxsati
    try {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.createNotificationChannel(_channel);
      await androidImplementation?.createNotificationChannel(_silentChannel);
    } catch (e) {
      print("Local notification channel error: $e");
    }

    // 2. Local notifications initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        print("Notification clicked with payload: ${details.payload}");
      },
    );

    // 3. FCM tokenni olish va Firestore'ga sinxronlash
    await syncToken();

    // Token yangilanganda avtomatik saqlash
    _fcm.onTokenRefresh.listen((newToken) {
      print("FCM Token refreshed: $newToken");
      syncToken(token: newToken);
    });

    // 4. Foreground (Ilova ochiq bo'lganda) xabarlarni qabul qilish va ko'rsatish
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground FCM message received: ${message.messageId}");
      final notification = message.notification;
      final title = notification?.title ??
          message.data['title'] ??
          LocalizationService.translate('new_message');
      final body = notification?.body ?? message.data['body'] ?? '';

      final chatId = message.data['chatId'];
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final isChatMuted = chatId != null &&
          ChatNotificationService.isChatMuted(chatId, userId: currentUid);

      final isSilent = message.data['isSilent'] == 'true' ||
          message.data['isSilent'] == true ||
          isChatMuted;

      showNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: chatId,
        isSilent: isSilent,
      );
    });

    // 5. Ilova fonda bo'lib notification bosilganda ochilishi
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("FCM onMessageOpenedApp: ${message.data}");
    });

    // 6. Ilova yopiq bo'lib notification bosilganda ochilishi
    try {
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        print("FCM initialMessage: ${initialMessage.data}");
      }
    } catch (e) {
      print("FCM getInitialMessage error: $e");
    }
  }

  // Tokenni Firestore'ga sinxronlash
  static Future<void> syncToken({String? token, String? uid}) async {
    try {
      if (Firebase.apps.isEmpty) return;
      final currentUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
      final currentToken = token ??
          await _fcm.getToken().timeout(
                const Duration(seconds: 3),
                onTimeout: () => null,
              );

      print("FCM Token: $currentToken");

      if (currentUid != null && currentToken != null && currentToken.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .set({
          'fcmToken': currentToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("FCM Token successfully synced for user: $currentUid");
      }
    } catch (e) {
      print("Error syncing FCM token: $e");
    }
  }

  // Mahalliy bildirishnoma ko'rsatish
  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
    bool isSilent = false,
  }) async {
    try {
      final channel = isSilent ? _silentChannel : _channel;
      await _localNotifications.show(
        id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: isSilent ? Importance.low : Importance.max,
            priority: isSilent ? Priority.low : Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: !isSilent,
            enableVibration: !isSilent,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: !isSilent,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  // Real-time Firestore notification listener
  static void startListeningToUserNotifications(String userId) {
    if (Firebase.apps.isEmpty) return;
    _firestoreNotificationSub?.cancel();
    final now = DateTime.now().subtract(const Duration(seconds: 5));

    _firestoreNotificationSub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null && data['isRead'] != true) {
            final title = data['title'] as String? ?? 'Yangi xabar';
            final body = data['body'] as String? ?? '';
            final chatId = data['chatId'] as String?;
            final isChatMuted = chatId != null &&
                ChatNotificationService.isChatMuted(chatId, userId: userId);

            final isSilent =
                (data['isSilent'] as bool? ?? false) || isChatMuted;

            showNotification(
              title: title,
              body: body,
              payload: chatId,
              isSilent: isSilent,
            );
          }
        }
      }
    });
  }

  static void stopListeningToUserNotifications() {
    _firestoreNotificationSub?.cancel();
    _firestoreNotificationSub = null;
  }
}
