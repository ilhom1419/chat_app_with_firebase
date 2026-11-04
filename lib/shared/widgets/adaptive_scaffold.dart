import 'package:flutter/material.dart' as m;
import 'package:flutter/cupertino.dart' as c;
import 'package:flutter/widgets.dart';
import '../../core/platform/platform_info.dart';

class AdaptiveScaffold extends StatelessWidget {
  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final Widget? bottomBar;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS) {
      return c.CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar: c.CupertinoNavigationBar(
          middle: title,
          leading: leading,
          trailing: actions != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: body),
              if (bottomBar != null) bottomBar!,
            ],
          ),
        ),
      );
    }
    return m.Scaffold(
      backgroundColor: backgroundColor,
      appBar: m.AppBar(
        title: title,
        leading: leading,
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: body),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
    );
  }
}
