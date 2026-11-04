import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

/// Service managing user-scoped Passcode (PIN lock) and security settings.
/// Every user account has its own isolated PIN code, biometric flag, and auto-lock settings.
class PasscodeService {
  static const String settingsBoxName = 'settings';

  static String? _resolveUid(String? explicitUid) {
    if (explicitUid != null && explicitUid.isNotEmpty) {
      return explicitUid;
    }
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String passcodeKey([String? uid]) {
    final resolved = _resolveUid(uid);
    return resolved != null && resolved.isNotEmpty
        ? 'app_passcode_$resolved'
        : 'app_passcode';
  }

  static String enabledKey([String? uid]) {
    final resolved = _resolveUid(uid);
    return resolved != null && resolved.isNotEmpty
        ? 'is_passcode_enabled_$resolved'
        : 'is_passcode_enabled';
  }

  static String biometricKey([String? uid]) {
    final resolved = _resolveUid(uid);
    return resolved != null && resolved.isNotEmpty
        ? 'is_biometric_enabled_$resolved'
        : 'is_biometric_enabled';
  }

  static String autoLockKey([String? uid]) {
    final resolved = _resolveUid(uid);
    return resolved != null && resolved.isNotEmpty
        ? 'auto_lock_duration_$resolved'
        : 'auto_lock_duration';
  }

  /// Migrates single-user legacy passcode to the currently logged in user UID once,
  /// then removes global keys so subsequent new accounts never inherit this PIN.
  static void migrateLegacyIfNeeded(String uid, Box box) {
    if (uid.isEmpty) return;
    final userPasscode = box.get(passcodeKey(uid));
    if (userPasscode == null) {
      final legacyPasscode = box.get('app_passcode') as String?;
      final legacyEnabled =
          box.get('is_passcode_enabled', defaultValue: false) as bool;
      if (legacyPasscode != null && legacyPasscode.isNotEmpty && legacyEnabled) {
        box.put(passcodeKey(uid), legacyPasscode);
        box.put(enabledKey(uid), true);
        final legacyBio =
            box.get('is_biometric_enabled', defaultValue: false) as bool;
        box.put(biometricKey(uid), legacyBio);
        final legacyAuto = box.get('auto_lock_duration', defaultValue: 0) as int;
        box.put(autoLockKey(uid), legacyAuto);

        // Delete legacy global keys so no other account inherits them
        box.delete('app_passcode');
        box.delete('is_passcode_enabled');
      }
    }
  }

  static bool isPasscodeEnabled({String? uid, Box? box}) {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName) ? Hive.box(settingsBoxName) : null);
    if (b == null) return false;

    final resolvedUid = _resolveUid(uid);
    if (resolvedUid != null && resolvedUid.isNotEmpty) {
      migrateLegacyIfNeeded(resolvedUid, b);
      return b.get(enabledKey(resolvedUid), defaultValue: false) as bool;
    }

    return b.get(enabledKey(null), defaultValue: false) as bool;
  }

  static String? getPasscode({String? uid, Box? box}) {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName) ? Hive.box(settingsBoxName) : null);
    if (b == null) return null;

    final resolvedUid = _resolveUid(uid);
    if (resolvedUid != null && resolvedUid.isNotEmpty) {
      migrateLegacyIfNeeded(resolvedUid, b);
      return b.get(passcodeKey(resolvedUid)) as String?;
    }

    return b.get(passcodeKey(null)) as String?;
  }

  static Future<void> setPasscode(String pin,
      {String? uid, Box? box}) async {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName)
            ? Hive.box(settingsBoxName)
            : await Hive.openBox(settingsBoxName));

    final resolvedUid = _resolveUid(uid);
    await b.putAll({
      passcodeKey(resolvedUid): pin,
      enabledKey(resolvedUid): true,
    });
  }

  static Future<void> disablePasscode({String? uid, Box? box}) async {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName)
            ? Hive.box(settingsBoxName)
            : await Hive.openBox(settingsBoxName));

    final resolvedUid = _resolveUid(uid);
    await b.putAll({
      passcodeKey(resolvedUid): null,
      enabledKey(resolvedUid): false,
      biometricKey(resolvedUid): false,
    });
  }

  static bool isBiometricEnabled({String? uid, Box? box}) {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName) ? Hive.box(settingsBoxName) : null);
    if (b == null) return false;

    final resolvedUid = _resolveUid(uid);
    return b.get(biometricKey(resolvedUid), defaultValue: false) as bool;
  }

  static Future<void> setBiometricEnabled(bool enabled,
      {String? uid, Box? box}) async {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName)
            ? Hive.box(settingsBoxName)
            : await Hive.openBox(settingsBoxName));

    final resolvedUid = _resolveUid(uid);
    await b.put(biometricKey(resolvedUid), enabled);
  }

  static int getAutoLockDuration({String? uid, Box? box}) {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName) ? Hive.box(settingsBoxName) : null);
    if (b == null) return 0;

    final resolvedUid = _resolveUid(uid);
    return b.get(autoLockKey(resolvedUid), defaultValue: 0) as int;
  }

  static Future<void> setAutoLockDuration(int seconds,
      {String? uid, Box? box}) async {
    final b = box ??
        (Hive.isBoxOpen(settingsBoxName)
            ? Hive.box(settingsBoxName)
            : await Hive.openBox(settingsBoxName));

    final resolvedUid = _resolveUid(uid);
    await b.put(autoLockKey(resolvedUid), seconds);
  }
}

