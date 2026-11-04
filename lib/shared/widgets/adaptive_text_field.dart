import 'package:flutter/material.dart' as m;
import 'package:flutter/cupertino.dart' as c;
import 'package:flutter/widgets.dart';
import '../../../core/platform/platform_info.dart';

class AdaptiveTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefix;
  final Widget? suffix;

  const AdaptiveTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = m.Theme.of(context).brightness == m.Brightness.dark;

    if (PlatformInfo.isIOS) {
      return c.CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        placeholderStyle: TextStyle(
            color: isDark
                ? c.CupertinoColors.placeholderText
                : const Color(0x99000000)),
        style: TextStyle(
            color: isDark ? c.CupertinoColors.white : c.CupertinoColors.black),
        obscureText: obscureText,
        keyboardType: keyboardType,
        prefix: prefix,
        suffix: suffix,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B)
              : c.CupertinoColors.extraLightBackgroundGray,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }
    return m.TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? m.Colors.white : m.Colors.black),
      decoration: m.InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(color: isDark ? m.Colors.white38 : m.Colors.grey),
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : m.Colors.grey[100],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: m.OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: m.BorderSide.none,
        ),
        enabledBorder: m.OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: m.BorderSide.none,
        ),
        focusedBorder: m.OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const m.BorderSide(color: m.Colors.blueAccent, width: 1.5),
        ),
      ),
    );
  }
}
