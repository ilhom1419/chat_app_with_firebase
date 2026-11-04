import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';

class LiveLocationDurationSheet extends StatefulWidget {
  final Function(int durationSeconds)? onDurationSelected;

  const LiveLocationDurationSheet({
    super.key,
    this.onDurationSelected,
  });

  static Future<int?> show(
    BuildContext context, {
    Function(int durationSeconds)? onDurationSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showKakkuFloatingBottomSheet<int>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) => LiveLocationDurationSheet(
        onDurationSelected: (duration) {
          onDurationSelected?.call(duration);
        },
      ),
    );
  }

  @override
  State<LiveLocationDurationSheet> createState() =>
      _LiveLocationDurationSheetState();
}

class _LiveLocationDurationSheetState extends State<LiveLocationDurationSheet> {
  int _selectedDuration = 900; // 15 minutes default

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.share_location_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.translate('share_live_location'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationService.translate('live_location_active'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDurationOption(
              durationSeconds: 900,
              title: LocalizationService.translate('share_for_15_minutes'),
              subtitle: '15 min',
              icon: Icons.timer_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildDurationOption(
              durationSeconds: 3600,
              title: LocalizationService.translate('share_for_1_hour'),
              subtitle: '60 min',
              icon: Icons.timelapse_outlined,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      LocalizationService.translate('cancel'),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(_selectedDuration);
                      widget.onDurationSelected?.call(_selectedDuration);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      LocalizationService.translate('share_live_location'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption({
    required int durationSeconds,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedDuration == durationSeconds;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDuration = durationSeconds;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : (isDark ? Colors.white54 : Colors.black45),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black38),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : (isDark ? Colors.white38 : Colors.black26),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
