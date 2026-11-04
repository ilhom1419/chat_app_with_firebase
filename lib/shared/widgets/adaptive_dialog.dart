import 'package:flutter/material.dart' as m;
import 'package:flutter/cupertino.dart' as c;
import 'package:flutter/widgets.dart';
import '../../../core/platform/platform_info.dart';

class AdaptiveDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String content,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) async {
    if (PlatformInfo.isIOS) {
      return c.showCupertinoDialog(
        context: context,
        builder: (context) => c.CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(content),
          ),
          actions: [
            c.CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                if (onPressed != null) onPressed();
              },
              child: Text(buttonText),
            ),
          ],
        ),
      );
    }
    return m.showDialog(
      context: context,
      builder: (context) => m.AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          m.TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onPressed != null) onPressed();
            },
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
