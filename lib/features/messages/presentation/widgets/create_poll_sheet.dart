import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/poll_data.dart';

class CreatePollSheet extends StatefulWidget {
  final Function(PollData poll) onPollCreated;

  const CreatePollSheet({
    super.key,
    required this.onPollCreated,
  });

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isAnonymous = true;
  bool _allowsMultipleAnswers = false;
  bool _isQuiz = false;
  int? _correctOptionIndex;

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      final removed = _optionControllers.removeAt(index);
      removed.dispose();

      if (_correctOptionIndex == index) {
        _correctOptionIndex = null;
      } else if (_correctOptionIndex != null && _correctOptionIndex! > index) {
        _correctOptionIndex = _correctOptionIndex! - 1;
      }
    });
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.translate('poll_validation_question')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final validOptions = <String>[];
    for (int i = 0; i < _optionControllers.length; i++) {
      final text = _optionControllers[i].text.trim();
      if (text.isNotEmpty) {
        validOptions.add(text);
      }
    }

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.translate('poll_validation_min_options')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isQuiz) {
      if (_correctOptionIndex == null ||
          _correctOptionIndex! >= _optionControllers.length ||
          _optionControllers[_correctOptionIndex!].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.translate('poll_validation_quiz_correct')),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Build PollData
    final pollOptions = <PollOption>[];
    int? correctOptionId;
    int idCounter = 0;

    for (int i = 0; i < _optionControllers.length; i++) {
      final text = _optionControllers[i].text.trim();
      if (text.isNotEmpty) {
        final optionId = idCounter++;
        if (_isQuiz && _correctOptionIndex == i) {
          correctOptionId = optionId;
        }
        pollOptions.add(PollOption(id: optionId, text: text, voterIds: const []));
      }
    }

    final poll = PollData(
      id: '',
      question: question,
      options: pollOptions,
      isAnonymous: _isAnonymous,
      allowsMultipleAnswers: _isQuiz ? false : _allowsMultipleAnswers,
      isQuiz: _isQuiz,
      correctOptionId: correctOptionId,
      explanation: _isQuiz ? _explanationController.text.trim() : null,
      isClosed: false,
    );

    widget.onPollCreated(poll);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      LocalizationService.translate('cancel'),
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    LocalizationService.translate('poll_create_title'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    onPressed: _submit,
                    child: Text(
                      LocalizationService.translate('create'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Form Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Question section
                  Text(
                    LocalizationService.translate('poll_question_label'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _questionController,
                    maxLines: 3,
                    maxLength: 255,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: LocalizationService.translate('type_poll_question_hint'),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counterText: "",
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Options section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${LocalizationService.translate('poll_options_label')} (${_optionControllers.length}/10)",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (_isQuiz) ...[
                        Text(
                          LocalizationService.translate('poll_validation_quiz_correct'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...List.generate(_optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          if (_isQuiz) ...[
                            Radio<int>(
                              value: index,
                              groupValue: _correctOptionIndex,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setState(() {
                                  _correctOptionIndex = val;
                                });
                              },
                            ),
                          ],
                          Expanded(
                            child: TextField(
                              controller: _optionControllers[index],
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: LocalizationService.translate('poll_option_n', params: {'n': index + 1}),
                                hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          if (_optionControllers.length > 2) ...[
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.error, size: 20),
                              onPressed: () => _removeOption(index),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  if (_optionControllers.length < 10) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add_rounded,
                            color: AppColors.primary),
                        label: Text(
                          LocalizationService.translate('add_option'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Settings section
                  Text(
                    LocalizationService.translate('settings'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('anonymous_voting')),
                    subtitle: Text(
                        LocalizationService.translate('anonymous_voting_desc')),
                    value: _isAnonymous,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isAnonymous = val;
                      });
                    },
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('multiple_answers')),
                    subtitle:
                        Text(LocalizationService.translate('multiple_answers_desc')),
                    value: _allowsMultipleAnswers,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _isQuiz
                        ? null
                        : (val) {
                            setState(() {
                              _allowsMultipleAnswers = val;
                            });
                          },
                  ),

                  SwitchListTile(
                    title: Text(LocalizationService.translate('quiz_mode')),
                    subtitle: Text(
                        LocalizationService.translate('quiz_mode_desc')),
                    value: _isQuiz,
                    activeColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isQuiz = val;
                        if (val) {
                          _allowsMultipleAnswers = false;
                        }
                      });
                    },
                  ),

                  if (_isQuiz) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Izoh / Tushuntirish (ixtiyoriy)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _explanationController,
                      maxLines: 2,
                      maxLength: 200,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Nima uchun ushbu javob to'g'riligini tushuntiring...",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        counterText: "",
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
