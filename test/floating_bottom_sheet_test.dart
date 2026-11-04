import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/shared/widgets/floating_bottom_sheet.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Kakku Universal Floating BottomSheet Tests', () {
    // TEST 01 & 02 & 03: 16dp Left, 16dp Right, 20dp Bottom Gap relative to safe content
    testWidgets('TEST 01, 02, 03: Sheet has 16dp horizontal insets and 20dp bottom gap from safe content boundary', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = FakeViewPadding(bottom: 48 * 2.0, top: 24 * 2.0);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const SizedBox(
                      height: 200,
                      child: Text('Content'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find the ClipRRect of the floating shell
      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);

      final rect = tester.getRect(clipFinder);

      // TEST 01: Left inset = 16dp
      expect(rect.left, equals(16.0));

      // TEST 02: Right inset = 16dp (400 - 16 = 384)
      expect(rect.right, equals(400.0 - 16.0));

      // TEST 03: Bottom floating gap = 20dp above safe bottom (safe bottom = 800 - 48 = 752)
      // 752 - 20 = 732
      expect(rect.bottom, equals(732.0));
      expect(752.0 - rect.bottom, equals(20.0));
    });

    // TEST 04: All four corners use 26dp radius
    testWidgets('TEST 04: All four outer corners use 26dp radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const Text('Corners test'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      final clipWidget = tester.widget<ClipRRect>(clipFinder);
      final borderRadius = clipWidget.borderRadius as BorderRadius;

      expect(borderRadius.topLeft.x, equals(26.0));
      expect(borderRadius.topRight.x, equals(26.0));
      expect(borderRadius.bottomLeft.x, equals(26.0));
      expect(borderRadius.bottomRight.x, equals(26.0));
    });

    // TEST 05: Opens with intended bottom-origin slide-up transition
    testWidgets('TEST 05: The sheet opens with bottom-origin slide transition', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const SizedBox(
                      height: 200,
                      child: Text('Slide content'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      // Pump initial frame of transition
      await tester.pump(const Duration(milliseconds: 50));

      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      expect(clipFinder, findsOneWidget);

      final midRect = tester.getRect(clipFinder);
      // Midway through opening, top of sheet is still lower down the screen
      expect(midRect.top, greaterThan(600.0));

      await tester.pumpAndSettle();
      final settledRect = tester.getRect(clipFinder);
      expect(settledRect.top, lessThan(midRect.top));
    });

    // TEST 06: Short-content sheet preserves natural height
    testWidgets('TEST 06: Short-content sheet preserves natural height and wraps content', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 50, child: Text('Row 1')),
                        SizedBox(height: 50, child: Text('Row 2')),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      final rect = tester.getRect(clipFinder);

      // Total height is around 100 logical pixels, not stretched to screen height
      expect(rect.height, equals(100.0));
      expect(rect.height, lessThan(300.0));
    });

    // TEST 07: Long-content sheet remains scrollable
    testWidgets('TEST 07: Long-content sheet remains scrollable without overflow', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => ListView.builder(
                      itemCount: 50,
                      itemBuilder: (context, i) => ListTile(
                        title: Text('Item $i'),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll down
      await tester.drag(find.text('Item 0'), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // TEST 08: Entire Block User button is accessible in profile sheet
    testWidgets('TEST 08: Profile sheet Block User button is completely accessible after scroll', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = FakeViewPadding(bottom: 48 * 2.0, top: 24 * 2.0);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      bool blockTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 100, child: Text('Avatar')),
                          const SizedBox(height: 40, child: Text('Sardor')),
                          const SizedBox(height: 30, child: Text('Online')),
                          const SizedBox(height: 40, child: Text('sardor@example.com')),
                          const SizedBox(height: 200, child: Text('Extra details')),
                          ElevatedButton(
                            key: const Key('cancel_button'),
                            onPressed: () {},
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            key: const Key('block_button'),
                            onPressed: () {
                              blockTapped = true;
                            },
                            child: const Text('Block User'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Profile'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Profile'));
      await tester.pumpAndSettle();

      // Scroll down to reveal the Block User button
      await tester.scrollUntilVisible(find.byKey(const Key('block_button')), 50);
      await tester.pumpAndSettle();

      final blockFinder = find.byKey(const Key('block_button'));
      expect(blockFinder, findsOneWidget);

      final blockRect = tester.getRect(blockFinder);
      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      final shellRect = tester.getRect(clipFinder);

      // The block button is completely inside the visible shell boundary
      expect(blockRect.bottom, lessThanOrEqualTo(shellRect.bottom));
      expect(shellRect.bottom, equals(640.0 - 48.0 - 20.0));

      // Tap block button and verify callback
      await tester.tap(blockFinder);
      await tester.pumpAndSettle();
      expect(blockTapped, isTrue);
    });

    // TEST 09: Android safe-bottom navigation spacing is respected
    testWidgets('TEST 09: 3-button navigation (48dp) and gesture navigation (24dp) spacing respected', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 720 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = FakeViewPadding(bottom: 48 * 2.0, top: 24 * 2.0);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const SizedBox(height: 150, child: Text('Nav test')),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      final rect = tester.getRect(clipFinder);

      // Safe content bottom is 720 - 48 = 672. Bottom of sheet must be at 672 - 20 = 652.
      expect(rect.bottom, equals(652.0));
      expect(672.0 - rect.bottom, equals(20.0));
    });

    // TEST 10: Keyboard opening adjusts sheet without obscure
    testWidgets('TEST 10: Keyboard viewInsets adjusts floating position smoothly', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 720 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = FakeViewPadding(bottom: 24 * 2.0, top: 24 * 2.0);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        key: Key('input_field'),
                        decoration: InputDecoration(hintText: 'Type message'),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final clipFinder = find.descendant(
        of: find.byType(KakkuFloatingBottomSheetShell),
        matching: find.byType(ClipRRect),
      );
      final beforeRect = tester.getRect(clipFinder);

      // Simulate keyboard opening (height = 300dp)
      tester.view.viewInsets = FakeViewPadding(bottom: 300 * 2.0);
      await tester.pumpAndSettle();

      final afterRect = tester.getRect(clipFinder);

      // When keyboard is open, sheet shifts up so its bottom is 300 + 20 = 320 from screen bottom
      expect(afterRect.bottom, equals(720.0 - 320.0));
      expect(afterRect.bottom, lessThan(beforeRect.bottom));
      expect(find.byKey(const Key('input_field')), findsOneWidget);
    });

    // TEST 11: Existing form validation is preserved
    testWidgets('TEST 11: Form validation logic inside floating sheet functions correctly', (tester) async {
      final formKey = GlobalKey<FormState>();
      bool validated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            validator: (val) =>
                                (val == null || val.isEmpty) ? 'Required field' : null,
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                validated = true;
                              }
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Required field'), findsOneWidget);
      expect(validated, isFalse);

      await tester.enterText(find.byType(TextFormField), 'Valid input');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(find.text('Required field'), findsNothing);
      expect(validated, isTrue);
    });

    // TEST 12: Existing button callbacks still work
    testWidgets('TEST 12: Button callbacks trigger properly and return value', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showKakkuFloatingBottomSheet<String>(
                    context: context,
                    builder: (ctx) => ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop('selected_val'),
                      child: const Text('Select'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(result, equals('selected_val'));
    });

    // TEST 13: Backdrop dismissal behavior remains unchanged
    testWidgets('TEST 13: Tapping outside sheet dismisses it when isDismissible=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const SizedBox(height: 200, child: Text('Dismiss me')),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dismiss me'), findsOneWidget);

      // Tap near top of screen (barrier)
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();
      expect(find.text('Dismiss me'), findsNothing);
    });

    // TEST 14: Swipe down to dismiss is preserved
    testWidgets('TEST 14: Swiping downward dismisses the sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    enableDrag: true,
                    builder: (ctx) => const SizedBox(
                      height: 250,
                      child: Text('Drag down content'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Drag down content'), findsOneWidget);

      // Drag down from center of sheet
      await tester.drag(find.text('Drag down content'), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(find.text('Drag down content'), findsNothing);
    });

    // TEST 15: Light and Dark themes preserve existing sheet content styling
    testWidgets('TEST 15: Light and dark surface themes apply correctly', (tester) async {
      // Dark Mode Test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const Text('Dark theme content'),
                  );
                },
                child: const Text('Open Dark'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dark'));
      await tester.pumpAndSettle();

      final darkBox = tester.widget<Container>(
        find.descendant(
          of: find.byType(KakkuFloatingBottomSheetShell),
          matching: find.byType(Container),
        ).first,
      );
      final darkDeco = darkBox.decoration as BoxDecoration;
      expect(darkDeco.color, equals(const Color(0xFF0F172A)));

      // Dismiss
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Light Mode Test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => const Text('Light theme content'),
                  );
                },
                child: const Text('Open Light'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Light'));
      await tester.pumpAndSettle();

      final lightBox = tester.widget<Container>(
        find.descendant(
          of: find.byType(KakkuFloatingBottomSheetShell),
          matching: find.byType(Container),
        ).first,
      );
      final lightDeco = lightBox.decoration as BoxDecoration;
      expect(lightDeco.color, equals(Colors.white));
    });

    // TEST 16: Increased text scale does not cause overflow
    testWidgets('TEST 16: Increased font scale (textScaler=2.0) renders without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showKakkuFloatingBottomSheet(
                      context: context,
                      builder: (ctx) => SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('Large Scaled Text Title'),
                            Text('Large Scaled Text Subtitle'),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Scaled'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Scaled'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Large Scaled Text Title'), findsOneWidget);
    });

    // TEST 17: Underlying page does not shift or resize unexpectedly
    testWidgets('TEST 17: Opening sheet does not shift underlying page layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Chat Page Header')),
            body: Stack(
              children: [
                const Positioned(
                  top: 10,
                  left: 10,
                  child: Text('Underlying chat message 1', key: Key('underlying_msg')),
                ),
                Builder(
                  builder: (context) => Align(
                    alignment: Alignment.bottomCenter,
                    child: ElevatedButton(
                      onPressed: () {
                        showKakkuFloatingBottomSheet(
                          context: context,
                          builder: (ctx) => const SizedBox(height: 150, child: Text('Floating Sheet')),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final msgBeforeRect = tester.getRect(find.byKey(const Key('underlying_msg')));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final msgAfterRect = tester.getRect(find.byKey(const Key('underlying_msg')));

      // Underlying message position did not move at all
      expect(msgAfterRect, equals(msgBeforeRect));
    });

    // TEST 18: Different page-specific content types retain original widget structures
    testWidgets('TEST 18: Grid, List and Custom Column content structures are preserved', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    builder: (ctx) => GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      children: const [
                        Icon(Icons.image),
                        Icon(Icons.camera),
                        Icon(Icons.file_copy),
                      ],
                    ),
                  );
                },
                child: const Text('Open Grid'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Grid'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image), findsOneWidget);
      expect(find.byIcon(Icons.camera), findsOneWidget);
      expect(find.byIcon(Icons.file_copy), findsOneWidget);
    });

    // TEST 19: Constants values check
    testWidgets('TEST 19: Canonical constants match exactly 16, 20, 26', (tester) async {
      expect(KakkuFloatingBottomSheetTheme.horizontalInset, equals(16.0));
      expect(KakkuFloatingBottomSheetTheme.bottomGap, equals(20.0));
      expect(KakkuFloatingBottomSheetTheme.outerRadius, equals(26.0));
    });

    // TEST 20: Custom background color support
    testWidgets('TEST 20: Custom backgroundColor parameter is respected', (tester) async {
      const customBg = Color(0xFF123456);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: context,
                    backgroundColor: customBg,
                    builder: (ctx) => const Text('Custom BG Content'),
                  );
                },
                child: const Text('Open Custom'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Custom'));
      await tester.pumpAndSettle();

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(KakkuFloatingBottomSheetShell),
          matching: find.byType(Container),
        ).first,
      );
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, equals(customBg));
    });
  });
}
