import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';
import '../../../../core/localization/localization_service.dart';

class ScheduleResult {
  final DateTime scheduledAt;
  final bool isSilent;

  const ScheduleResult({
    required this.scheduledAt,
    required this.isSilent,
  });
}

class ScheduleMessageDialog extends StatefulWidget {
  final DateTime? initialDateTime;
  final bool initialSilent;

  const ScheduleMessageDialog({
    super.key,
    this.initialDateTime,
    this.initialSilent = false,
  });

  static Future<ScheduleResult?> show(
    BuildContext context, {
    DateTime? initialDateTime,
    bool initialSilent = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showKakkuFloatingBottomSheet<ScheduleResult>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (_) => ScheduleMessageDialog(
        initialDateTime: initialDateTime,
        initialSilent: initialSilent,
      ),
    );
  }

  @override
  State<ScheduleMessageDialog> createState() => _ScheduleMessageDialogState();
}

class _ScheduleMessageDialogState extends State<ScheduleMessageDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isSilent;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultTarget = widget.initialDateTime ?? now.add(const Duration(minutes: 30));
    _selectedDate = DateTime(defaultTarget.year, defaultTarget.month, defaultTarget.day);
    _selectedTime = TimeOfDay(hour: defaultTarget.hour, minute: defaultTarget.minute);
    _isSilent = widget.initialSilent;
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  bool get _isValidFuture {
    return _combinedDateTime.isAfter(DateTime.now());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: Color(0xFF1E293B),
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: Color(0xFF1E293B),
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatPreview() {
    final combined = _combinedDateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(combined.year, combined.month, combined.day);

    final timeStr = DateFormat('HH:mm').format(combined);
    final tzName = combined.timeZoneName;

    if (checkDate == today) {
      final todayStr = LocalizationService.currentLanguage == 'uz'
          ? 'Bugun'
          : LocalizationService.currentLanguage == 'ru'
              ? 'Сегодня'
              : 'Today';
      return '$todayStr, $timeStr ($tzName)';
    } else if (checkDate == tomorrow) {
      final tomorrowStr = LocalizationService.currentLanguage == 'uz'
          ? 'Ertaga'
          : LocalizationService.currentLanguage == 'ru'
              ? 'Завтра'
              : 'Tomorrow';
      return '$tomorrowStr, $timeStr ($tzName)';
    }

    final dateStr = DateFormat('dd.MM.yyyy').format(combined);
    return '$dateStr, $timeStr ($tzName)';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValid = _isValidFuture;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LocalizationService.translate('schedule_message'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Date & Time Selectors Row
              Row(
                children: [
                  // Date Button
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LocalizationService.translate('select_date'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd.MM.yyyy')
                                        .format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Time Button
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LocalizationService.translate('select_time'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                  Text(
                                    '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Preview Box
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isValid
                      ? const Color(0xFF0284C7).withOpacity(isDark ? 0.2 : 0.08)
                      : Colors.redAccent.withOpacity(isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isValid
                        ? const Color(0xFF0284C7).withOpacity(0.3)
                        : Colors.redAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isValid
                          ? Icons.info_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: isValid ? const Color(0xFF0284C7) : Colors.redAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isValid
                            ? '${LocalizationService.translate('send_at')}: ${_formatPreview()}'
                            : LocalizationService.translate(
                                'time_must_be_in_future'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isValid
                              ? (isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF0284C7))
                              : Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Silent Delivery Toggle
              SwitchListTile(
                value: _isSilent,
                onChanged: (val) {
                  setState(() {
                    _isSilent = val;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                secondary: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8)
                        .withOpacity(isDark ? 0.2 : 0.12),
                  ),
                  child: const Icon(
                    Icons.notifications_off_rounded,
                    color: Color(0xFF38BDF8),
                    size: 18,
                  ),
                ),
                title: Text(
                  LocalizationService.translate('silent_notification'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  LocalizationService.translate('send_without_sound'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Button
              ElevatedButton(
                onPressed: isValid
                    ? () {
                        Navigator.of(context).pop(
                          ScheduleResult(
                            scheduledAt: _combinedDateTime,
                            isSilent: _isSilent,
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      isDark ? Colors.white12 : Colors.black12,
                  disabledForegroundColor:
                      isDark ? Colors.white30 : Colors.black26,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  LocalizationService.translate('confirm_schedule'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
