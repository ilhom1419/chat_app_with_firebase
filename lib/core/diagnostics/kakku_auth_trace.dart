import 'package:flutter/foundation.dart';

/// Structured debug diagnostics for authentication session lifecycle
/// Tag: KAKKU_AUTH_TRACE
class KakkuAuthTrace {
  static int _sequence = 0;
  static bool enabled = true;

  static void log(String event, {Map<String, dynamic>? details}) {
    if (!enabled) return;
    _sequence++;
    final buffer = StringBuffer();
    buffer.write('[KAKKU_AUTH_TRACE #$_sequence] $event');
    if (details != null && details.isNotEmpty) {
      buffer.write(' | ');
      buffer.write(details.entries.map((e) => '${e.key}=${e.value}').join(', '));
    }
    debugPrint(buffer.toString());
  }

  /// Non-reversible safe identifier for diagnostics
  static String safeUid(String? uid) {
    if (uid == null || uid.isEmpty) return 'none';
    return 'u_${uid.hashCode.toRadixString(16)}';
  }

  static void reset() {
    _sequence = 0;
  }
}

