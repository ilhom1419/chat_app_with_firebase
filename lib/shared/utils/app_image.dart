import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

class AppImage {
  static final Map<String, Uint8List> _cache = {};

  /// Decodes base64 string to Uint8List and caches it in memory.
  /// Returning the same Uint8List reference preserves identity equality
  /// and prevents MemoryImage/Flutter image cache from reloading/flickering.
  static Uint8List? decode(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) return null;
    return _cache.putIfAbsent(base64String, () {
      try {
        final clean = base64String.contains(',')
            ? base64String.split(',').last.trim()
            : base64String.trim();
        return base64Decode(clean);
      } catch (e) {
        return Uint8List(0);
      }
    });
  }

  /// Returns a cached ImageProvider<Object> for use in DecorationImage or CircleAvatar
  static ImageProvider? provider(String? base64String) {
    final bytes = decode(base64String);
    if (bytes == null || bytes.isEmpty) return null;
    return MemoryImage(bytes);
  }

  /// Renders a memory image with gaplessPlayback: true so that it never clears/flickers
  /// or moves when navigating between pages.
  static Widget memory(
    String? base64String, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    BorderRadius? borderRadius,
    FilterQuality filterQuality = FilterQuality.medium,
  }) {
    final bytes = decode(base64String);
    if (bytes == null || bytes.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }

    Widget imageWidget = Image.memory(
      bytes,
      key: key,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: filterQuality,
      excludeFromSemantics: true,
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
