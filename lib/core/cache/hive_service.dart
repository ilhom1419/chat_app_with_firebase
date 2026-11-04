import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String chatsBoxName = 'cached_chats';
  static const String messagesBoxName = 'cached_messages';
  static const String outboxBoxName = 'outbox_messages';
  static const String authBoxName = 'auth_session';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Qutilarni ochish (open boxes)
    await Hive.openBox(chatsBoxName);
    await Hive.openBox(messagesBoxName);
    await Hive.openBox(outboxBoxName);
    await Hive.openBox(authBoxName);
  }

  static Box get chatsBox => Hive.box(chatsBoxName);
  static Box get messagesBox => Hive.box(messagesBoxName);
  static Box get outboxBox => Hive.box(outboxBoxName);
  static Box get authBox => Hive.box(authBoxName);

  static Future<void> saveAuthSession({
    required String uid,
    required String email,
    required String displayName,
    String? photoURL,
  }) async {
    if (!Hive.isBoxOpen(authBoxName)) {
      await Hive.openBox(authBoxName);
    }
    final box = authBox;
    await box.put('is_authenticated', true);
    await box.put('uid', uid);
    await box.put('email', email);
    await box.put('displayName', displayName);
    if (photoURL != null && photoURL.isNotEmpty) {
      await box.put('photoURL', photoURL);
    } else {
      await box.delete('photoURL');
    }
  }

  static Map<String, dynamic>? getAuthSession() {
    if (!Hive.isBoxOpen(authBoxName)) return null;
    final box = authBox;
    final isAuth = box.get('is_authenticated', defaultValue: false) as bool;
    final uid = box.get('uid') as String?;
    if (!isAuth || uid == null || uid.isEmpty) return null;
    return {
      'uid': uid,
      'email': (box.get('email') as String?) ?? '',
      'displayName': (box.get('displayName') as String?) ?? 'User',
      'photoURL': box.get('photoURL') as String?,
    };
  }

  static Future<void> clearAuthSession() async {
    if (!Hive.isBoxOpen(authBoxName)) {
      try {
        await Hive.openBox(authBoxName);
      } catch (_) {
        return;
      }
    }
    final box = authBox;
    await box.clear();
  }

  static Future<void> clearAll() async {
    await chatsBox.clear();
    await messagesBox.clear();
    if (Hive.isBoxOpen(outboxBoxName)) {
      await outboxBox.clear();
    }
  }
}
