import 'package:flutter/widgets.dart';

class AppColors {
  // Primary — chuqur ko'k-binafsha (zamonaviy messenger uslubi)
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52D5);
  static const Color primaryLight = Color(0xFFEEEDFF);

  // Xabar pufakchalari
  static const Color bubbleSent = Color(0xFF6C63FF); // O'zim yuborgan
  static const Color bubbleReceived = Color(0xFFFFFFFF); // Kelgan (light)
  static const Color bubbleReceivedDark = Color(0xFF1E1E2E); // Kelgan (dark)

  // Holat ranglari
  static const Color online = Color(0xFF34C759); // Onlayn nuqtasi
  static const Color success = Color(0xFF22C55E); // Muvaffaqiyat holati
  static const Color unreadBadge = Color(0xFF22C55E); // O'qilmagan xabarlar hisoblagich nishoni
  static const Color typing = Color(0xFF6C63FF);
  static const Color read = Color(0xFF6C63FF); // Ko'rilgan belgi
  static const Color sent = Color(0xFF94A3B8); // Yuborildi belgi
  static const Color error = Color(0xFFFF3B30);

  // Fon — Light
  static const Color bgLight = Color(0xFFF0F2F8);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color inputLight = Color(0xFFEEEFF5);

  // Fon — Dark
  static const Color bgDark = Color(0xFF0B0B14);
  static const Color surfaceDark = Color(0xFF161622);
  static const Color inputDark = Color(0xFF1E1E2E);

  // Matn
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Avatar rang gradientlar (ismi bo'yicha tasodifiy)
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF6C63FF), Color(0xFF9D97FF)],
    [Color(0xFFFF6B6B), Color(0xFFFF9D9D)],
    [Color(0xFF00C896), Color(0xFF00E5AB)],
    [Color(0xFFFFB347), Color(0xFFFFD47B)],
    [Color(0xFF0A84FF), Color(0xFF5AC8FA)],
    [Color(0xFFAF52DE), Color(0xFFD187F7)],
  ];
}
