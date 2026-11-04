import 'package:flutter/widgets.dart';

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
  static List<BoxShadow> get bubble => [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}
