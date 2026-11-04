import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';

/// Unread message count badge for chat list items.
///
/// Visual rules:
/// - Hidden when count <= 0.
/// - Circular for single-digit counts (1..9).
/// - Pill-shaped with adaptive width for multi-digit counts (10..99, 99+).
/// - Displays '99+' when count >= 100.
/// - Kakku success green background (#22C55E), white semibold text.
class UnreadCountBadge extends StatelessWidget {
  final int count;

  const UnreadCountBadge({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final displayText = count >= 100 ? '99+' : count.toString();
    final isSingleDigit = count < 10;

    return Container(
      constraints: const BoxConstraints(
        minWidth: 23,
        minHeight: 23,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSingleDigit ? 0 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.unreadBadge,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: Text(
          displayText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
