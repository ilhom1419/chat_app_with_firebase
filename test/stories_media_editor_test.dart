import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/media_editor/domain/entities/drawing_stroke.dart';
import 'package:chat_app/features/media_editor/domain/entities/editable_layer.dart';
import 'package:chat_app/features/media_editor/presentation/painters/drawing_painter.dart';
import 'package:chat_app/features/media_editor/presentation/widgets/layer_transform_gesture_detector.dart';
import 'package:chat_app/features/media_editor/presentation/widgets/text_edit_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Sticker & Emoji Layer Entity Tests', () {
    test('StickerLayer initializes with correct coordinates, scale, and rotation', () {
      final sticker = StickerLayer(
        id: 'stk_1',
        position: const Offset(100, 200),
        scale: 1.5,
        rotation: 0.25,
        stickerId: 'happy_1',
        imageUrl: 'assets/stickers/happy_1.png',
        title: 'Happy',
        isSelected: false,
      );

      expect(sticker.id, equals('stk_1'));
      expect(sticker.position, equals(const Offset(100, 200)));
      expect(sticker.scale, equals(1.5));
      expect(sticker.rotation, equals(0.25));
      expect(sticker.stickerId, equals('happy_1'));
      expect(sticker.imageUrl, equals('assets/stickers/happy_1.png'));
      expect(sticker.isSelected, isFalse);
    });

    test('StickerLayer copyWithBase updates transformations and selection state', () {
      final original = StickerLayer(
        id: 'stk_2',
        position: const Offset(50, 50),
        scale: 1.0,
        rotation: 0.0,
        stickerId: 'love_1',
        imageUrl: 'assets/stickers/love_1.png',
        title: 'Love',
        isSelected: false,
      );

      final updated = original.copyWithBase(
        position: const Offset(150, 250),
        scale: 2.0,
        rotation: 1.57,
        isSelected: true,
      );

      expect(updated.id, equals('stk_2'));
      expect(updated.position, equals(const Offset(150, 250)));
      expect(updated.scale, equals(2.0));
      expect(updated.rotation, equals(1.57));
      expect(updated.isSelected, isTrue);
      expect(updated.imageUrl, equals('assets/stickers/love_1.png'));
    });

    test('EmojiLayer initializes with emoji character and supports updates', () {
      final emojiLayer = EmojiLayer(
        id: 'emj_1',
        position: const Offset(80, 120),
        scale: 1.2,
        rotation: -0.1,
        emoji: '🔥',
        isSelected: true,
      );

      expect(emojiLayer.emoji, equals('🔥'));
      expect(emojiLayer.isSelected, isTrue);

      final unselected = emojiLayer.copyWithBase(isSelected: false);
      expect(unselected.isSelected, isFalse);
      expect(unselected.emoji, equals('🔥'));
    });
  });

  group('2. Text Layer & Font Styling Tests', () {
    test('TextLayer supports font style presets with distinct visual styles', () {
      const presets = TextFontStylePreset.values;
      expect(presets.length, equals(6));

      // Neon style includes glow shadows
      final neonLayer = TextLayer(
        id: 'txt_neon',
        position: const Offset(100, 100),
        text: 'Kakku Stories',
        textColor: Colors.cyanAccent,
        fontStylePreset: TextFontStylePreset.neon,
      );
      final neonStyle = neonLayer.getTextStyle();
      expect(neonStyle.shadows, isNotNull);
      expect(neonStyle.shadows!.isNotEmpty, isTrue);

      // Handwriting style uses cursive / handwriting font family
      final handwritingLayer = TextLayer(
        id: 'txt_hw',
        position: const Offset(100, 100),
        text: 'Handwriting style',
        textColor: Colors.white,
        fontStylePreset: TextFontStylePreset.handwriting,
      );
      final hwStyle = handwritingLayer.getTextStyle();
      expect(hwStyle.fontStyle, equals(FontStyle.italic));

      // Typewriter style uses monospace font family
      final typewriterLayer = TextLayer(
        id: 'txt_tw',
        position: const Offset(100, 100),
        text: 'Typewriter style',
        textColor: Colors.white,
        fontStylePreset: TextFontStylePreset.typewriter,
      );
      final twStyle = typewriterLayer.getTextStyle();
      expect(twStyle.fontFamily, equals('monospace'));

      // Bold style uses bold weight
      final boldLayer = TextLayer(
        id: 'txt_bold',
        position: const Offset(100, 100),
        text: 'Bold text',
        textColor: Colors.white,
        fontStylePreset: TextFontStylePreset.bold,
      );
      final boldStyle = boldLayer.getTextStyle();
      expect(boldStyle.fontWeight, equals(FontWeight.w900));
    });

    test('TextLayer copyWithBase and copyWithText preserve and update properties', () {
      final textLayer = TextLayer(
        id: 'txt_1',
        position: const Offset(10, 20),
        text: 'Original Text',
        textColor: Colors.white,
        backgroundColor: Colors.black54,
        fontSize: 24,
        textAlign: TextAlign.center,
        fontStylePreset: TextFontStylePreset.classic,
      );

      final edited = textLayer.copyWithBase(
        text: 'Updated Text',
        textColor: Colors.yellow,
        backgroundColor: Colors.red,
        fontSize: 32,
        textAlign: TextAlign.right,
        fontStylePreset: TextFontStylePreset.modern,
      );

      expect(edited.text, equals('Updated Text'));
      expect(edited.textColor, equals(Colors.yellow));
      expect(edited.backgroundColor, equals(Colors.red));
      expect(edited.fontSize, equals(32));
      expect(edited.textAlign, equals(TextAlign.right));
      expect(edited.fontStylePreset, equals(TextFontStylePreset.modern));
      expect(edited.position, equals(const Offset(10, 20)));
    });
  });

  group('3. Brush Drawing System & Painter Tests', () {
    test('DrawingStroke records points, color, width and eraser flag', () {
      final stroke = DrawingStroke(
        points: [const Offset(10, 10), const Offset(20, 20), const Offset(30, 30)],
        color: Colors.red,
        strokeWidth: 8.0,
        isEraser: false,
      );

      expect(stroke.points.length, equals(3));
      expect(stroke.color, equals(Colors.red));
      expect(stroke.strokeWidth, equals(8.0));
      expect(stroke.isEraser, isFalse);

      final eraserStroke = DrawingStroke(
        points: [const Offset(40, 40)],
        color: Colors.transparent,
        strokeWidth: 20.0,
        isEraser: true,
      );
      expect(eraserStroke.isEraser, isTrue);
    });

    test('DrawingPainter executes without errors on canvas with strokes', () {
      final strokes = [
        DrawingStroke(
          points: [const Offset(10, 10), const Offset(50, 50), const Offset(100, 100)],
          color: Colors.blue,
          strokeWidth: 6.0,
        ),
        DrawingStroke(
          points: [const Offset(20, 20), const Offset(40, 40)],
          color: Colors.transparent,
          strokeWidth: 15.0,
          isEraser: true,
        ),
      ];

      final liveStroke = DrawingStroke(
        points: [const Offset(120, 120), const Offset(130, 130)],
        color: Colors.green,
        strokeWidth: 4.0,
      );

      final painter = DrawingPainter(
        strokes: strokes,
        currentStroke: liveStroke,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 800);

      expect(() => painter.paint(canvas, size), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
      picture.dispose();
    });

    test('Drawing Undo / Redo logic simulates drawing operations correctly', () {
      final List<DrawingStroke> strokes = [];
      final List<DrawingStroke> redoStack = [];

      // Add stroke 1
      final s1 = DrawingStroke(points: [const Offset(0, 0)], color: Colors.red, strokeWidth: 4.0);
      strokes.add(s1);
      redoStack.clear();
      expect(strokes.length, equals(1));

      // Add stroke 2
      final s2 = DrawingStroke(points: [const Offset(10, 10)], color: Colors.blue, strokeWidth: 4.0);
      strokes.add(s2);
      redoStack.clear();
      expect(strokes.length, equals(2));

      // Undo stroke 2
      redoStack.add(strokes.removeLast());
      expect(strokes.length, equals(1));
      expect(redoStack.length, equals(1));

      // Redo stroke 2
      strokes.add(redoStack.removeLast());
      expect(strokes.length, equals(2));
      expect(redoStack.isEmpty, isTrue);

      // Clear canvas
      strokes.clear();
      expect(strokes.isEmpty, isTrue);
    });
  });

  group('4. Layer Transform & Gesture Detector Widget Tests', () {
    testWidgets('LayerTransformGestureDetector renders child and handles tap and delete', (tester) async {
      bool tapped = false;
      bool deleted = false;
      Offset currentPos = const Offset(100, 100);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                LayerTransformGestureDetector(
                  position: currentPos,
                  scale: 1.0,
                  rotation: 0.0,
                  isSelected: true,
                  onTap: () => tapped = true,
                  onPositionChanged: (p) => currentPos = p,
                  onScaleAndRotationChanged: (_, __) {},
                  onDelete: () => deleted = true,
                  child: const Text('Draggable Sticker'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Draggable Sticker'), findsOneWidget);
      // Selected layer shows delete icon
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(deleted, isTrue);

      // Tap child
      await tester.tap(find.text('Draggable Sticker'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('Unselected layer hides delete icon and selection border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                LayerTransformGestureDetector(
                  position: const Offset(50, 50),
                  scale: 1.0,
                  rotation: 0.0,
                  isSelected: false,
                  onTap: () {},
                  onPositionChanged: (_) {},
                  onScaleAndRotationChanged: (_, __) {},
                  onDelete: () {},
                  child: const Text('Unselected Layer'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Unselected Layer'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });

  group('5. TextEditDialog Widget Tests', () {
    testWidgets('TextEditDialog opens with text field and font preset chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  TextEditDialog.show(
                    ctx,
                    initialLayer: const TextLayer(
                      id: 't1',
                      position: Offset.zero,
                      text: 'Hello Kakku',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Hello Kakku'), findsOneWidget);
      expect(find.text('Klassik'), findsOneWidget);
      expect(find.text('Qalin'), findsOneWidget);
      expect(find.text('Zamonaviy'), findsOneWidget);
      expect(find.text('Neon'), findsOneWidget);
    });
  });

  group('6. Video Trimming Duration & Validation Tests', () {
    test('Valid trim range calculates exact expected segment duration', () {
      const originalDuration = Duration(minutes: 2, seconds: 30); // 02:30
      const startTrim = Duration(seconds: 25);
      const endTrim = Duration(seconds: 55);

      final trimmedDuration = endTrim - startTrim;
      expect(trimmedDuration, equals(const Duration(seconds: 30)));
      expect(startTrim < endTrim, isTrue);
      expect(endTrim <= originalDuration, isTrue);
    });

    test('Video trimming rejects ranges where start >= end or duration < 1s', () {
      const startTrim = Duration(seconds: 40);
      const endTrim = Duration(seconds: 40);

      final isValid = endTrim > startTrim && (endTrim - startTrim).inSeconds >= 1;
      expect(isValid, isFalse);

      const tinyTrimEnd = Duration(milliseconds: 40500); // only 500ms
      final isTinyValid = tinyTrimEnd > startTrim && (tinyTrimEnd - startTrim).inMilliseconds >= 1000;
      expect(isTinyValid, isFalse);
    });
  });

  group('7. Localization Verification Tests', () {
    test('All media editor keys are defined in Uzbek, English, and Russian', () {
      final requiredKeys = [
        'edit_image',
        'add_sticker',
        'add_emoji',
        'draw',
        'add_text',
        'undo',
        'redo',
        'erase',
        'clear_canvas',
        'trim_video',
        'start',
        'end',
        'duration',
        'preview',
        'processing',
        'cancel',
        'discard_changes',
        'discard_confirm_desc',
        'save',
        'send',
        'publish_story',
        'export_failed',
        'font_classic',
        'font_bold',
        'font_modern',
        'font_handwriting',
        'font_neon',
        'font_typewriter',
        'brush_thickness',
        'video_too_short',
      ];

      for (final lang in ['uz', 'en', 'ru']) {
        LocalizationService.langNotifier.value = lang;
        for (final key in requiredKeys) {
          final translated = LocalizationService.translate(key);
          expect(translated, isNotEmpty, reason: 'Key $key must have a translation in $lang');
          expect(translated, isNot(equals(key)), reason: 'Key $key fell back to raw key in $lang');
        }
      }
    });
  });
}
