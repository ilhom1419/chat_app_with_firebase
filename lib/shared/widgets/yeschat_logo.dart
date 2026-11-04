import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';

class YesChatLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;
  final bool showBorder;

  const YesChatLogo({
    super.key,
    this.size = 64.0,
    this.borderRadius = 18.0,
    this.showShadow = true,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.5,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.35),
                  blurRadius: size * 0.25,
                  spreadRadius: 1,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/branding/yeschat_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
