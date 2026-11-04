import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';

enum SendOptionType {
  sendNow,
  sendWithoutSound,
  schedule,
}

class SendOptionsSheet extends StatelessWidget {
  final VoidCallback onSendNow;
  final VoidCallback onSendWithoutSound;
  final VoidCallback onSchedule;

  const SendOptionsSheet({
    super.key,
    required this.onSendNow,
    required this.onSendWithoutSound,
    required this.onSchedule,
  });

  static Future<SendOptionType?> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showKakkuFloatingBottomSheet<SendOptionType>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) {
        return SendOptionsSheet(
          onSendNow: () => Navigator.of(ctx).pop(SendOptionType.sendNow),
          onSendWithoutSound: () =>
              Navigator.of(ctx).pop(SendOptionType.sendWithoutSound),
          onSchedule: () => Navigator.of(ctx).pop(SendOptionType.schedule),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag indicator handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _buildOption(
          context: context,
          icon: Icons.send_rounded,
          iconColor: AppColors.primary,
          title: LocalizationService.translate('send_now'),
          onTap: onSendNow,
        ),
        Divider(
          height: 1,
          indent: 56,
          endIndent: 16,
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
        _buildOption(
          context: context,
          icon: Icons.notifications_off_rounded,
          iconColor: const Color(0xFF38BDF8),
          title: LocalizationService.translate('send_without_sound'),
          onTap: onSendWithoutSound,
        ),
        Divider(
          height: 1,
          indent: 56,
          endIndent: 16,
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
        _buildOption(
          context: context,
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: LocalizationService.translate('schedule_message'),
          onTap: onSchedule,
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withOpacity(isDark ? 0.2 : 0.12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
