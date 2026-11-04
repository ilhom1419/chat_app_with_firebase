import 'package:flutter/material.dart';

/// Base class for any visual layer (sticker, emoji, text) placed over the image.
abstract class EditableLayer {
  final String id;
  final Offset position;
  final double scale;
  final double rotation;
  final bool isSelected;

  const EditableLayer({
    required this.id,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isSelected = false,
  });

  EditableLayer copyWithBase({
    Offset? position,
    double? scale,
    double? rotation,
    bool? isSelected,
  });
}

/// Sticker layer referencing an image URL (PNG / Network / Asset).
class StickerLayer extends EditableLayer {
  final String stickerId;
  final String imageUrl;
  final String title;

  const StickerLayer({
    required super.id,
    required super.position,
    super.scale = 1.0,
    super.rotation = 0.0,
    super.isSelected = false,
    required this.stickerId,
    required this.imageUrl,
    required this.title,
  });

  @override
  StickerLayer copyWithBase({
    Offset? position,
    double? scale,
    double? rotation,
    bool? isSelected,
  }) {
    return StickerLayer(
      id: id,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      stickerId: stickerId,
      imageUrl: imageUrl,
      title: title,
    );
  }
}

/// Emoji layer displaying a large unicode emoji character.
class EmojiLayer extends EditableLayer {
  final String emoji;
  final double fontSize;

  const EmojiLayer({
    required super.id,
    required super.position,
    super.scale = 1.0,
    super.rotation = 0.0,
    super.isSelected = false,
    required this.emoji,
    this.fontSize = 52.0,
  });

  @override
  EmojiLayer copyWithBase({
    Offset? position,
    double? scale,
    double? rotation,
    bool? isSelected,
    double? fontSize,
  }) {
    return EmojiLayer(
      id: id,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      emoji: emoji,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

/// Text font style presets.
enum TextFontStylePreset {
  classic,
  bold,
  modern,
  handwriting,
  neon,
  typewriter,
}

/// Text layer with custom styling, font styles, colors and backgrounds.
class TextLayer extends EditableLayer {
  final String text;
  final Color textColor;
  final Color? backgroundColor;
  final double fontSize;
  final TextAlign textAlign;
  final TextFontStylePreset fontStylePreset;

  const TextLayer({
    required super.id,
    required super.position,
    super.scale = 1.0,
    super.rotation = 0.0,
    super.isSelected = false,
    required this.text,
    this.textColor = Colors.white,
    this.backgroundColor,
    this.fontSize = 28.0,
    this.textAlign = TextAlign.center,
    this.fontStylePreset = TextFontStylePreset.classic,
  });

  @override
  TextLayer copyWithBase({
    Offset? position,
    double? scale,
    double? rotation,
    bool? isSelected,
    String? text,
    Color? textColor,
    Color? backgroundColor,
    bool clearBackgroundColor = false,
    double? fontSize,
    TextAlign? textAlign,
    TextFontStylePreset? fontStylePreset,
  }) {
    return TextLayer(
      id: id,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
      text: text ?? this.text,
      textColor: textColor ?? this.textColor,
      backgroundColor: clearBackgroundColor ? null : (backgroundColor ?? this.backgroundColor),
      fontSize: fontSize ?? this.fontSize,
      textAlign: textAlign ?? this.textAlign,
      fontStylePreset: fontStylePreset ?? this.fontStylePreset,
    );
  }

  TextStyle getTextStyle() {
    switch (fontStylePreset) {
      case TextFontStylePreset.bold:
        return TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        );
      case TextFontStylePreset.modern:
        return TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
        );
      case TextFontStylePreset.handwriting:
        return TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        );
      case TextFontStylePreset.neon:
        return TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: textColor.withOpacity(0.9),
              blurRadius: 18,
            ),
            Shadow(
              color: textColor.withOpacity(0.6),
              blurRadius: 36,
            ),
          ],
        );
      case TextFontStylePreset.typewriter:
        return TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        );
      case TextFontStylePreset.classic:
        return TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        );
    }
  }
}
