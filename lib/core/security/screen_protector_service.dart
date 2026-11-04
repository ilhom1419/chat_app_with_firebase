import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../platform/platform_info.dart';

/// ScreenProtectorService manages platform-level window screenshot and screen recording protection.
///
/// It uses reference counting to ensure FLAG_SECURE remains enabled while any protected screen
/// or modal dialog is active, and is only cleared when the last protected screen exits.
class ScreenProtectorService {
  ScreenProtectorService._();

  static const MethodChannel _channel = MethodChannel('screen_protector');

  static int _activeCount = 0;
  static Future<void> _chain = Future.value();

  /// The number of currently active screens / components requesting FLAG_SECURE.
  static int get activeSecureCount => _activeCount;

  /// Returns true if window screenshot/recording protection is currently requested.
  static bool get isSecureActive => _activeCount > 0;

  /// Enables screenshot and screen recording protection.
  /// Increments the active reference count. If transitioning from 0 to 1,
  /// invokes native `enableSecure` on the `screen_protector` channel.
  static Future<void> enableSecure() {
    _activeCount++;
    if (_activeCount == 1) {
      _chain = _chain.then((_) => _invokeNative('enableSecure'));
      return _chain;
    }
    return Future.value();
  }

  /// Disables screenshot and screen recording protection if no other protected components remain.
  /// Decrements the active reference count. When the count reaches 0,
  /// invokes native `disableSecure` on the `screen_protector` channel.
  static Future<void> disableSecure() {
    if (_activeCount > 0) {
      _activeCount--;
    }
    if (_activeCount == 0) {
      _chain = _chain.then((_) => _invokeNative('disableSecure'));
      return _chain;
    }
    return Future.value();
  }

  /// Force-clears protection and resets the active reference count to 0.
  /// Restores normal capture capabilities regardless of navigation depth.
  static Future<void> forceDisableSecure() {
    _activeCount = 0;
    _chain = _chain.then((_) => _invokeNative('disableSecure'));
    return _chain;
  }

  /// Re-asserts FLAG_SECURE on the native window if protection is currently active.
  /// Used during app lifecycle resume transitions to ensure system window flags remain intact.
  static Future<void> reapplyIfActive() {
    if (_activeCount > 0) {
      _chain = _chain.then((_) => _invokeNative('enableSecure'));
      return _chain;
    }
    return Future.value();
  }

  static Future<void> _invokeNative(String method) async {
    // Only invoke native channel on supported mobile platforms
    if (!PlatformInfo.isAndroid && !PlatformInfo.isIOS) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      debugPrint('ScreenProtectorService: MissingPluginException for $method');
    } on PlatformException catch (e) {
      debugPrint('ScreenProtectorService: PlatformException for $method: ${e.message}');
    } catch (e) {
      debugPrint('ScreenProtectorService: Unexpected error calling $method: $e');
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _activeCount = 0;
    _chain = Future.value();
  }

  @visibleForTesting
  static MethodChannel get channelForTesting => _channel;
}
