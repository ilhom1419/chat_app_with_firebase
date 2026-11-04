import 'package:flutter/material.dart';

/// Canonical constants for Kakku Universal Floating BottomSheet.
class KakkuFloatingBottomSheetTheme {
  /// Horizontal left and right insets from active app/page content boundary.
  static const double horizontalInset = 16.0;

  /// Bottom floating gap relative to current safe content boundary.
  static const double bottomGap = 20.0;

  /// External corner radius applied to all four corners.
  static const double outerRadius = 26.0;
}

const double kBottomSheetHorizontalInset = 16.0;
const double kBottomSheetBottomGap = 20.0;
const double kBottomSheetOuterRadius = 26.0;

/// Reusable outer shell widget implementing the universal Kakku Floating BottomSheet design.
///
/// Owns:
/// - 16 logical pixels left inset
/// - 16 logical pixels right inset
/// - 20 logical pixels bottom floating gap (above Android safe content bottom)
/// - 26 logical pixels corner radius on all four corners
/// - Outer clipping via ClipRRect(26.0)
/// - Bounded height constraints preventing screen overflow
/// - Keyboard avoidance
class KakkuFloatingBottomSheetShell extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double maxWidth;
  final double? maxHeight;
  final bool enableKeyboardAvoidance;

  const KakkuFloatingBottomSheetShell({
    super.key,
    required this.child,
    this.backgroundColor,
    this.maxWidth = 600.0,
    this.maxHeight,
    this.enableKeyboardAvoidance = true,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = backgroundColor ??
        (isDark ? const Color(0xFF0F172A) : Colors.white);

    // Calculate safe boundaries
    final safeBottom = mediaQuery.viewPadding.bottom > 0
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;
    final keyboardBottom = enableKeyboardAvoidance
        ? mediaQuery.viewInsets.bottom
        : 0.0;
    final safeTop = mediaQuery.viewPadding.top > 0
        ? mediaQuery.viewPadding.top
        : mediaQuery.padding.top;

    // Bottom floating gap calculation:
    // When keyboard is open, float above the keyboard.
    // When keyboard is closed, float 20dp above the safe bottom content boundary.
    final effectiveBottomGap = keyboardBottom > 0
        ? (keyboardBottom + KakkuFloatingBottomSheetTheme.bottomGap)
        : (safeBottom + KakkuFloatingBottomSheetTheme.bottomGap);

    final availableHeight = mediaQuery.size.height;
    final computedMaxHeight = maxHeight ??
        (availableHeight - safeTop - 20.0 - effectiveBottomGap);
    final effectiveMaxHeight = computedMaxHeight > 100.0
        ? computedMaxHeight
        : availableHeight * 0.7;

    final outerBorderRadius = BorderRadius.circular(
      KakkuFloatingBottomSheetTheme.outerRadius,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: KakkuFloatingBottomSheetTheme.horizontalInset,
        right: KakkuFloatingBottomSheetTheme.horizontalInset,
        bottom: effectiveBottomGap,
      ),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: effectiveMaxHeight,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: outerBorderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: outerBorderRadius,
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    padding: mediaQuery.padding.copyWith(bottom: 0),
                    viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
                    viewInsets: mediaQuery.viewInsets.copyWith(bottom: 0),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Universal Floating BottomSheet modal presenter for Kakku Messenger.
///
/// Opens any existing BottomSheet content inside the standardized floating shell:
/// - 16dp horizontal insets
/// - 20dp bottom floating gap above Android safe content boundary
/// - 26dp outer corner radius on all 4 corners
/// - Native bottom-origin slide-up transition
Future<T?> showKakkuFloatingBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  Color? barrierColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  double maxWidth = 600.0,
  double? maxHeight,
  bool enableKeyboardAvoidance = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    elevation: 0,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    builder: (modalContext) {
      return KakkuFloatingBottomSheetShell(
        backgroundColor: backgroundColor,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        enableKeyboardAvoidance: enableKeyboardAvoidance,
        child: builder(modalContext),
      );
    },
  );
}
