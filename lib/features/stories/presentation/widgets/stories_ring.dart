import 'package:flutter/material.dart';

/// 📖 StoriesRing — Zamonaviy gradientli nurli halqa
/// Yangi ko'rilmagan hikoyalar uchun yorqin binafsha-qizil-sariq gradient,
/// Barchasi ko'rilgan hikoyalar uchun esa xira nozik chegarani ta'minlaydi.
/// Har qanday holatda ham avatarni mukammal doira shaklida ushlab turadi.
class StoriesRing extends StatelessWidget {
  final Widget child;
  final bool hasStories;
  final bool hasUnseenStories;
  final double radius;
  final double strokeWidth;
  final VoidCallback? onTap;

  const StoriesRing({
    super.key,
    required this.child,
    this.hasStories = true,
    this.hasUnseenStories = true,
    this.radius = 27.0,
    this.strokeWidth = 2.5,
    this.onTap,
  });

  // Stories signature vibrant gradient (Violet -> Coral Pink -> Amber -> Violet)
  static const List<Color> unseenGradient = [
    Color(0xFF6C63FF),
    Color(0xFFFF3366),
    Color(0xFFFFB300),
    Color(0xFF6C63FF),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSize = (radius + strokeWidth + 2.0) * 2;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

    final avatarWidget = ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: child,
      ),
    );

    if (!hasStories) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: totalSize,
          height: totalSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : Colors.black.withOpacity(0.09),
              width: 1.5,
            ),
          ),
          child: avatarWidget,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: totalSize,
        height: totalSize,
        padding: EdgeInsets.all(strokeWidth),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasUnseenStories
              ? const SweepGradient(
                  colors: unseenGradient,
                )
              : null,
          border: hasUnseenStories
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.20)
                      : Colors.black.withOpacity(0.14),
                  width: strokeWidth,
                ),
        ),
        child: Container(
          padding: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
          child: avatarWidget,
        ),
      ),
    );
  }
}

