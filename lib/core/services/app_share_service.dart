import 'package:flutter/services.dart';

class AppShareService {
  static const MethodChannel _channel = MethodChannel('app_share');

  /// Opens the native Android share sheet or copies to clipboard as fallback
  static Future<bool> shareText({
    required String text,
    String? subject,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject,
      });
      return result ?? false;
    } catch (_) {
      // Fallback: Copy to clipboard if platform channel is unavailable (e.g. testing or web)
      await Clipboard.setData(ClipboardData(text: text));
      return false;
    }
  }
}
