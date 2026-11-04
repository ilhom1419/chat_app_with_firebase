import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/drawing_stroke.dart';
import '../../domain/entities/editable_layer.dart';
import '../../data/services/media_export_service.dart';
import '../painters/drawing_painter.dart';
import '../widgets/layer_transform_gesture_detector.dart';
import '../widgets/text_edit_dialog.dart';
import '../widgets/editor_sticker_emoji_picker.dart';

/// Full-featured interactive media editor for Stories and Chat attachments.
class MediaEditorPage extends StatefulWidget {
  final File imageFile;
  final bool isStoryMode;

  const MediaEditorPage({
    super.key,
    required this.imageFile,
    this.isStoryMode = false,
  });

  static Future<File?> open(
    BuildContext context, {
    required File imageFile,
    bool isStoryMode = false,
  }) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => MediaEditorPage(
          imageFile: imageFile,
          isStoryMode: isStoryMode,
        ),
      ),
    );
  }

  @override
  State<MediaEditorPage> createState() => _MediaEditorPageState();
}

class _MediaEditorPageState extends State<MediaEditorPage> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // Layers & Drawing state
  final List<EditableLayer> _layers = [];
  final List<DrawingStroke> _strokes = [];
  final List<DrawingStroke> _redoStrokes = [];
  DrawingStroke? _currentStroke;

  // Editor mode
  bool _isDrawingMode = false;
  bool _isEraserMode = false;
  Color _selectedBrushColor = Colors.white;
  double _brushThickness = 6.0;

  bool _isExporting = false;

  final List<Color> _brushPalette = const [
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
  ];

  bool get _hasEdits => _layers.isNotEmpty || _strokes.isNotEmpty;

  void _unselectAllLayers() {
    setState(() {
      for (int i = 0; i < _layers.length; i++) {
        final l = _layers[i];
        if (l is StickerLayer) {
          _layers[i] = l.copyWithBase(isSelected: false);
        } else if (l is EmojiLayer) {
          _layers[i] = l.copyWithBase(isSelected: false);
        } else if (l is TextLayer) {
          _layers[i] = l.copyWithBase(isSelected: false);
        }
      }
    });
  }

  void _undo() {
    setState(() {
      if (_isDrawingMode) {
        if (_strokes.isNotEmpty) {
          _redoStrokes.add(_strokes.removeLast());
        }
      } else {
        if (_layers.isNotEmpty) {
          _layers.removeLast();
        } else if (_strokes.isNotEmpty) {
          _redoStrokes.add(_strokes.removeLast());
        }
      }
    });
  }

  void _redo() {
    setState(() {
      if (_redoStrokes.isNotEmpty) {
        _strokes.add(_redoStrokes.removeLast());
      }
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasEdits) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          LocalizationService.translate('discard_changes'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          LocalizationService.translate('discard_confirm_desc'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              LocalizationService.translate('cancel'),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(LocalizationService.translate('discard_changes')),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _exportAndFinish() async {
    _unselectAllLayers();

    setState(() {
      _isExporting = true;
    });

    try {
      // Small frame delay to let selection outlines clear
      await Future.delayed(const Duration(milliseconds: 50));

      final exportedFile = await MediaExportService.captureAndExport(
        repaintBoundaryKey: _repaintBoundaryKey,
        pixelRatio: 2.5,
      );

      if (mounted) {
        Navigator.of(context).pop(exportedFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LocalizationService.translate('export_failed')}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openTextEditor({TextLayer? layer}) async {
    _unselectAllLayers();
    final result = await TextEditDialog.show(context, initialLayer: layer);
    if (result != null && mounted) {
      setState(() {
        if (layer != null) {
          final idx = _layers.indexWhere((l) => l.id == layer.id);
          if (idx != -1) {
            _layers[idx] = result;
          }
        } else {
          _layers.add(result);
        }
      });
    }
  }

  void _openStickerEmojiPicker() {
    _unselectAllLayers();
    EditorStickerEmojiPicker.show(
      context,
      onStickerSelected: (sticker) {
        setState(() {
          _layers.add(
            StickerLayer(
              id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
              position: const Offset(120, 240),
              stickerId: sticker.id,
              imageUrl: sticker.imageUrl,
              title: sticker.title,
              isSelected: true,
            ),
          );
        });
      },
      onEmojiSelected: (emoji) {
        setState(() {
          _layers.add(
            EmojiLayer(
              id: 'emj_${DateTime.now().millisecondsSinceEpoch}',
              position: const Offset(140, 260),
              emoji: emoji,
              isSelected: true,
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // 1. Center Interactive Canvas Area
              GestureDetector(
                onTap: _unselectAllLayers,
                child: Center(
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Base Image
                        Image.file(
                          widget.imageFile,
                          fit: BoxFit.contain,
                        ),

                        // Drawing Strokes Canvas
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DrawingPainter(
                              strokes: _strokes,
                              currentStroke: _currentStroke,
                            ),
                          ),
                        ),

                        // Editable Layers (Stickers, Emojis, Text)
                        ..._layers.map((layer) => _buildLayerWidget(layer)),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Touch Interceptor for Brush Drawing
              if (_isDrawingMode)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      setState(() {
                        _currentStroke = DrawingStroke(
                          points: [details.localPosition],
                          color: _selectedBrushColor,
                          strokeWidth: _brushThickness,
                          isEraser: _isEraserMode,
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      if (_currentStroke != null) {
                        setState(() {
                          _currentStroke = _currentStroke!.copyWith(
                            points: List.from(_currentStroke!.points)
                              ..add(details.localPosition),
                          );
                        });
                      }
                    },
                    onPanEnd: (_) {
                      if (_currentStroke != null) {
                        setState(() {
                          _strokes.add(_currentStroke!);
                          _currentStroke = null;
                          _redoStrokes.clear();
                        });
                      }
                    },
                  ),
                ),

              // 3. Top Action Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Cancel Button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () async {
                          if (await _onWillPop()) {
                            if (mounted) Navigator.of(context).pop();
                          }
                        },
                      ),
                      const Spacer(),

                      // Undo Button
                      IconButton(
                        icon: Icon(
                          Icons.undo_rounded,
                          color: (_strokes.isNotEmpty || _layers.isNotEmpty)
                              ? Colors.white
                              : Colors.white30,
                        ),
                        onPressed: (_strokes.isNotEmpty || _layers.isNotEmpty) ? _undo : null,
                      ),

                      // Redo Button
                      IconButton(
                        icon: Icon(
                          Icons.redo_rounded,
                          color: _redoStrokes.isNotEmpty ? Colors.white : Colors.white30,
                        ),
                        onPressed: _redoStrokes.isNotEmpty ? _redo : null,
                      ),
                      const SizedBox(width: 8),

                      // Confirm / Done Button
                      ElevatedButton.icon(
                        onPressed: _exportAndFinish,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          widget.isStoryMode
                              ? LocalizationService.translate('publish_story')
                              : LocalizationService.translate('send'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Toolbar or Brush Sub-Toolbar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: _isDrawingMode ? _buildBrushSubToolbar() : _buildMainToolbar(),
                ),
              ),

              // 5. Export Loading Overlay
              if (_isExporting)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          LocalizationService.translate('processing'),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerWidget(EditableLayer layer) {
    Widget content;

    if (layer is StickerLayer) {
      content = Image.network(
        layer.imageUrl,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image_rounded,
          color: Colors.white30,
          size: 60,
        ),
      );
    } else if (layer is EmojiLayer) {
      content = Text(
        layer.emoji,
        style: TextStyle(fontSize: layer.fontSize),
      );
    } else if (layer is TextLayer) {
      content = GestureDetector(
        onDoubleTap: () => _openTextEditor(layer: layer),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: layer.backgroundColor != null
              ? BoxDecoration(
                  color: layer.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            layer.text,
            textAlign: layer.textAlign,
            style: layer.getTextStyle(),
          ),
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return LayerTransformGestureDetector(
      position: layer.position,
      scale: layer.scale,
      rotation: layer.rotation,
      isSelected: layer.isSelected && !_isExporting && !_isDrawingMode,
      onTap: () {
        setState(() {
          for (int i = 0; i < _layers.length; i++) {
            final isTarget = _layers[i].id == layer.id;
            _layers[i] = _layers[i].copyWithBase(isSelected: isTarget);
          }
        });
      },
      onPositionChanged: (newPos) {
        setState(() {
          final idx = _layers.indexWhere((l) => l.id == layer.id);
          if (idx != -1) {
            _layers[idx] = _layers[idx].copyWithBase(position: newPos);
          }
        });
      },
      onScaleAndRotationChanged: (newScale, newRotation) {
        setState(() {
          final idx = _layers.indexWhere((l) => l.id == layer.id);
          if (idx != -1) {
            _layers[idx] = _layers[idx].copyWithBase(
              scale: newScale,
              rotation: newRotation,
            );
          }
        });
      },
      onDelete: () {
        setState(() {
          _layers.removeWhere((l) => l.id == layer.id);
        });
      },
      child: content,
    );
  }

  Widget _buildMainToolbar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToolButton(
          icon: Icons.sticky_note_2_rounded,
          label: LocalizationService.translate('add_sticker'),
          onTap: _openStickerEmojiPicker,
        ),
        _buildToolButton(
          icon: Icons.emoji_emotions_rounded,
          label: LocalizationService.translate('add_emoji'),
          onTap: _openStickerEmojiPicker,
        ),
        _buildToolButton(
          icon: Icons.text_fields_rounded,
          label: LocalizationService.translate('add_text'),
          onTap: () => _openTextEditor(),
        ),
        _buildToolButton(
          icon: Icons.brush_rounded,
          label: LocalizationService.translate('draw'),
          onTap: () {
            _unselectAllLayers();
            setState(() {
              _isDrawingMode = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildBrushSubToolbar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thickness & Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Eraser Button
              IconButton(
                icon: Icon(
                  Icons.auto_fix_normal_rounded,
                  color: _isEraserMode ? AppColors.primary : Colors.white,
                ),
                tooltip: LocalizationService.translate('erase'),
                onPressed: () {
                  setState(() {
                    _isEraserMode = !_isEraserMode;
                  });
                },
              ),

              // Clear All Strokes
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
                tooltip: LocalizationService.translate('clear_canvas'),
                onPressed: () {
                  setState(() {
                    _strokes.clear();
                    _redoStrokes.clear();
                  });
                },
              ),

              // Brush Thickness Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    thumbColor: Colors.white,
                    overlayColor: AppColors.primary.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _brushThickness,
                    min: 2.0,
                    max: 28.0,
                    onChanged: (val) {
                      setState(() {
                        _brushThickness = val;
                      });
                    },
                  ),
                ),
              ),

              // Close Brush Mode
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isDrawingMode = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
                child: const Icon(Icons.check_rounded, size: 20),
              ),
            ],
          ),
        ),

        // Color Palette Selector
        if (!_isEraserMode)
          Container(
            height: 40,
            margin: const EdgeInsets.only(top: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _brushPalette.length,
              itemBuilder: (ctx, idx) {
                final color = _brushPalette[idx];
                final isSelected = _selectedBrushColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBrushColor = color;
                    });
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.black26,
                        width: isSelected ? 2.5 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 6,
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
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
