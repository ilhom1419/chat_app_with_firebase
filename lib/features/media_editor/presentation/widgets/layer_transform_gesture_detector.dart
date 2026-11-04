import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';

/// Wraps an editable layer with drag, scale, rotate, selection border, and delete controls.
class LayerTransformGestureDetector extends StatefulWidget {
  final Widget child;
  final Offset position;
  final double scale;
  final double rotation;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Offset newPosition) onPositionChanged;
  final Function(double newScale, double newRotation) onScaleAndRotationChanged;
  final VoidCallback onDelete;

  const LayerTransformGestureDetector({
    super.key,
    required this.child,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isSelected = false,
    required this.onTap,
    required this.onPositionChanged,
    required this.onScaleAndRotationChanged,
    required this.onDelete,
  });

  @override
  State<LayerTransformGestureDetector> createState() =>
      _LayerTransformGestureDetectorState();
}

class _LayerTransformGestureDetectorState
    extends State<LayerTransformGestureDetector> {
  late Offset _startPosition;
  late double _baseScale;
  late double _baseRotation;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: Transform.rotate(
        angle: widget.rotation,
        child: Transform.scale(
          scale: widget.scale,
          child: GestureDetector(
            onTap: widget.onTap,
            onScaleStart: (details) {
              _startPosition = widget.position;
              _baseScale = widget.scale;
              _baseRotation = widget.rotation;
              widget.onTap();
            },
            onScaleUpdate: (details) {
              // Position translation
              final newPos = _startPosition + details.focalPointDelta;
              _startPosition = newPos;
              widget.onPositionChanged(newPos);

              // Multi-touch scale & rotation
              if (details.pointerCount > 1) {
                final newScale = (_baseScale * details.scale).clamp(0.4, 4.0);
                final newRotation = _baseRotation + details.rotation;
                widget.onScaleAndRotationChanged(newScale, newRotation);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: widget.isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: widget.child,
                ),
                if (widget.isSelected) ...[
                  // Delete handle on top right
                  Positioned(
                    top: -10,
                    right: -10,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
