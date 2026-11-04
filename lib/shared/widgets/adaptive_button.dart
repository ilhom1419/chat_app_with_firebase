import 'package:flutter/material.dart' as m;
import 'package:flutter/cupertino.dart' as c;
import 'package:flutter/widgets.dart';
import '../../../core/platform/platform_info.dart';

class AdaptiveButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color? color;

  const AdaptiveButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return c.CupertinoButton(
        color: color ?? m.Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        borderRadius: BorderRadius.circular(12),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const c.CupertinoActivityIndicator(color: m.Colors.white)
            : Text(
                text,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: m.Colors.white),
              ),
      );
    }
    return m.ElevatedButton(
      style: m.ElevatedButton.styleFrom(
        backgroundColor: color ?? m.Theme.of(context).primaryColor,
        foregroundColor: m.Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: m.CircularProgressIndicator(
                color: m.Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}
