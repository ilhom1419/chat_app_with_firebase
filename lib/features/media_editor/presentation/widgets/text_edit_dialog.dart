import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/editable_layer.dart';

/// Modal dialog for adding or modifying styled text elements over the image.
class TextEditDialog extends StatefulWidget {
  final TextLayer? initialLayer;

  const TextEditDialog({
    super.key,
    this.initialLayer,
  });

  static Future<TextLayer?> show(
    BuildContext context, {
    TextLayer? initialLayer,
  }) {
    return showGeneralDialog<TextLayer>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => TextEditDialog(
        initialLayer: initialLayer,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    );
  }

  @override
  State<TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<TextEditDialog> {
  late TextEditingController _textController;
  late Color _textColor;
  Color? _backgroundColor;
  late double _fontSize;
  late TextAlign _textAlign;
  late TextFontStylePreset _fontStylePreset;

  final List<Color> _palette = const [
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30), // Red
    Color(0xFFFF9500), // Orange
    Color(0xFFFFCC00), // Yellow
    Color(0xFF34C759), // Green
    Color(0xFF00C7BE), // Cyan
    Color(0xFF007AFF), // Blue
    Color(0xFF5856D6), // Purple
    Color(0xFFFF2D55), // Pink
    Color(0xFF00FFCC), // Neon Aqua
    Color(0xFFFF007F), // Neon Magenta
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialLayer;
    _textController = TextEditingController(text: init?.text ?? '');
    _textColor = init?.textColor ?? Colors.white;
    _backgroundColor = init?.backgroundColor;
    _fontSize = init?.fontSize ?? 28.0;
    _textAlign = init?.textAlign ?? TextAlign.center;
    _fontStylePreset = init?.fontStylePreset ?? TextFontStylePreset.classic;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _cycleBackground() {
    setState(() {
      if (_backgroundColor == null) {
        // Semi-transparent dark
        _backgroundColor = Colors.black.withOpacity(0.55);
      } else if (_backgroundColor == Colors.black.withOpacity(0.55)) {
        // Solid colored background
        _backgroundColor = _textColor.withOpacity(0.9);
        _textColor = _textColor == Colors.white ? Colors.black : Colors.white;
      } else {
        // Reset to no background
        _backgroundColor = null;
        if (_textColor == Colors.black) _textColor = Colors.white;
      }
    });
  }

  void _cycleAlignment() {
    setState(() {
      if (_textAlign == TextAlign.center) {
        _textAlign = TextAlign.left;
      } else if (_textAlign == TextAlign.left) {
        _textAlign = TextAlign.right;
      } else {
        _textAlign = TextAlign.center;
      }
    });
  }

  void _onDone() {
    final trimmed = _textController.text.trim();
    if (trimmed.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final layer = TextLayer(
      id: widget.initialLayer?.id ?? 'txt_${DateTime.now().millisecondsSinceEpoch}',
      position: widget.initialLayer?.position ?? const Offset(80, 200),
      scale: widget.initialLayer?.scale ?? 1.0,
      rotation: widget.initialLayer?.rotation ?? 0.0,
      text: trimmed,
      textColor: _textColor,
      backgroundColor: _backgroundColor,
      fontSize: _fontSize,
      textAlign: _textAlign,
      fontStylePreset: _fontStylePreset,
      isSelected: true,
    );

    Navigator.of(context).pop(layer);
  }

  @override
  Widget build(BuildContext context) {
    final layerPreview = TextLayer(
      id: 'preview',
      position: Offset.zero,
      text: _textController.text.isEmpty ? 'Matn yozing...' : _textController.text,
      textColor: _textColor,
      backgroundColor: _backgroundColor,
      fontSize: _fontSize,
      textAlign: _textAlign,
      fontStylePreset: _fontStylePreset,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar: Cancel, Alignment, Background, Done
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  // Alignment toggle
                  IconButton(
                    icon: Icon(
                      _textAlign == TextAlign.left
                          ? Icons.format_align_left_rounded
                          : _textAlign == TextAlign.right
                              ? Icons.format_align_right_rounded
                              : Icons.format_align_center_rounded,
                      color: Colors.white,
                    ),
                    onPressed: _cycleAlignment,
                  ),
                  // Background badge toggle
                  IconButton(
                    icon: Icon(
                      _backgroundColor == null
                          ? Icons.text_format_rounded
                          : Icons.format_paint_rounded,
                      color: _backgroundColor != null ? AppColors.primary : Colors.white,
                    ),
                    onPressed: _cycleBackground,
                  ),
                  const SizedBox(width: 8),
                  // Done Button
                  ElevatedButton(
                    onPressed: _onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      LocalizationService.translate('save'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Center: Live Text Preview & Editor
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: _backgroundColor != null
                        ? BoxDecoration(
                            color: _backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: TextField(
                      controller: _textController,
                      autofocus: true,
                      maxLines: null,
                      textAlign: _textAlign,
                      style: layerPreview.getTextStyle(),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: LocalizationService.translate('add_text'),
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: _fontSize,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
            ),

            // Font Preset Selector
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFontChip(TextFontStylePreset.classic, 'font_classic'),
                  _buildFontChip(TextFontStylePreset.bold, 'font_bold'),
                  _buildFontChip(TextFontStylePreset.modern, 'font_modern'),
                  _buildFontChip(TextFontStylePreset.handwriting, 'font_handwriting'),
                  _buildFontChip(TextFontStylePreset.neon, 'font_neon'),
                  _buildFontChip(TextFontStylePreset.typewriter, 'font_typewriter'),
                ],
              ),
            ),

            // Color Palette Selector
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _palette.length,
                itemBuilder: (ctx, index) {
                  final color = _palette[index];
                  final isSelected = _textColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _textColor = color;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.black26,
                          width: isSelected ? 3 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.7),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontChip(TextFontStylePreset preset, String labelKey) {
    final isSelected = _fontStylePreset == preset;
    return GestureDetector(
      onTap: () {
        setState(() {
          _fontStylePreset = preset;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            LocalizationService.translate(labelKey),
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
