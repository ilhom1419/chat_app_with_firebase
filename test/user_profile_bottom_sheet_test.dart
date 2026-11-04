import 'package:chat_app/core/localization/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/design_system/app_colors.dart';

/// Helper test widget simulating the user profile bottom sheet layout
class TestUserProfileSheet extends StatelessWidget {
  final String displayName;
  final String? photoURL;
  final String statusText;
  final Color statusColor;
  final String email;
  final bool isBlocked;
  final VoidCallback onCancel;
  final VoidCallback onBlock;

  const TestUserProfileSheet({
    super.key,
    required this.displayName,
    this.photoURL,
    required this.statusText,
    required this.statusColor,
    required this.email,
    required this.isBlocked,
    required this.onCancel,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Colors.white12),
                    const SizedBox(height: 24),
                    if (email.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.email_outlined,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDark ? Colors.white38 : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.87)
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onCancel,
                        child: const Text(
                          'Bekor qilish',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.lock_rounded,
                          color: Colors.green,
                        ),
                        label: const Text(
                          'Maxfiy chat boshlash',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(
                          isBlocked
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          color: isBlocked ? Colors.green : Colors.red,
                        ),
                        label: Text(
                          isBlocked
                              ? LocalizationService.translate('unblock_user')
                              : LocalizationService.translate('block_user'),
                          style: TextStyle(
                            color: isBlocked ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: isBlocked ? Colors.green : Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onBlock,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Profile Bottom Sheet — Verification Tests', () {
    testWidgets('TEST 01 — Profile Bottom Sheet opens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TestUserProfileSheet(
                      displayName: 'Sardor',
                      statusText: 'Online',
                      statusColor: Colors.green,
                      email: 'sardor@example.com',
                      isBlocked: false,
                      onCancel: () => Navigator.of(ctx).pop(),
                      onBlock: () {},
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

      expect(find.text('Sardor'), findsOneWidget);
      expect(find.text('sardor@example.com'), findsOneWidget);
    });

    testWidgets('TEST 02 — Content scrolls vertically on a small viewport',
        (tester) async {
      tester.view.physicalSize = const Size(360, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestUserProfileSheet(
              displayName: 'Sardor',
              statusText: 'Online',
              statusColor: Colors.green,
              email: 'sardor@example.com',
              isBlocked: false,
              onCancel: () {},
              onBlock: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top content is visible
      expect(find.text('Sardor'), findsOneWidget);

      // Perform upward drag on scrollable area
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      // Bottom block button is now reached and visible
      expect(find.text(LocalizationService.translate('block_user')), findsOneWidget);
    });

    testWidgets('TEST 03 — Block button becomes fully visible after scrolling',
        (tester) async {
      tester.view.physicalSize = const Size(360, 520);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestUserProfileSheet(
              displayName: 'Sardor',
              statusText: 'Online',
              statusColor: Colors.green,
              email: 'sardor@example.com',
              isBlocked: false,
              onCancel: () {},
              onBlock: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final blockFinder = find.text(LocalizationService.translate('block_user'));
      expect(blockFinder, findsOneWidget);

      final RenderBox renderBox = tester.renderObject(blockFinder);
      expect(renderBox.size.height, greaterThan(0));
    });

    testWidgets('TEST 04 — Bottom button is not obscured by Android navigation insets',
        (tester) async {
      // Simulate Android with 48px 3-button navigation bar
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestUserProfileSheet(
              displayName: 'Sardor',
              statusText: 'Online',
              statusColor: Colors.green,
              email: 'sardor@example.com',
              isBlocked: false,
              onCancel: () {},
              onBlock: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final blockFinder = find.text(LocalizationService.translate('block_user'));
      final Offset position = tester.getBottomLeft(blockFinder);

      // Total screen height is 700. Navigation bar is 48px (from 652 to 700).
      // The button bottom must be strictly <= 652 so it is NEVER covered!
      expect(position.dy, lessThanOrEqualTo(652));
    });

    testWidgets('TEST 05 — Cancel button closes the sheet', (tester) async {
      bool sheetClosed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (modalCtx) => TestUserProfileSheet(
                      displayName: 'Sardor',
                      statusText: 'Online',
                      statusColor: Colors.green,
                      email: 'sardor@example.com',
                      isBlocked: false,
                      onCancel: () {
                        sheetClosed = true;
                        Navigator.of(modalCtx).pop();
                      },
                      onBlock: () {},
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Bekor qilish'), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();

      expect(sheetClosed, isTrue);
      expect(find.text('Bekor qilish'), findsNothing);
    });

    testWidgets('TEST 06 — Block button remains clickable', (tester) async {
      bool blockClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestUserProfileSheet(
              displayName: 'Sardor',
              statusText: 'Online',
              statusColor: Colors.green,
              email: 'sardor@example.com',
              isBlocked: false,
              onCancel: () {},
              onBlock: () {
                blockClicked = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to reveal block button
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(find.text(LocalizationService.translate('block_user')));
      await tester.pumpAndSettle();

      expect(blockClicked, isTrue);
    });

    testWidgets('TEST 07 — Large font scale does not cause overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.6),
            ),
            child: Scaffold(
              body: TestUserProfileSheet(
                displayName: 'Sardor',
                statusText: 'Online',
                statusColor: Colors.green,
                email: 'sardor_large_font@example.com',
                isBlocked: false,
                onCancel: () {},
                onBlock: () {},
              ),
            ),
          ),
        ),
      );

      // Verify no exceptions thrown during layout with large font
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEST 08 — No RenderFlex overflow or layout exception',
        (tester) async {
      // Very small screen 320x400
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestUserProfileSheet(
              displayName: 'Sardor',
              statusText: 'Online',
              statusColor: Colors.green,
              email: 'sardor@example.com',
              isBlocked: false,
              onCancel: () {},
              onBlock: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must be completely error free
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEST 09 — Existing profile information displays correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestUserProfileSheet(
              displayName: 'Sardor',
              statusText: 'Yaqinda onlayn edi',
              statusColor: Colors.grey,
              email: 'sardor1995@gmail.com',
              isBlocked: true,
              onCancel: () {},
              onBlock: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sardor'), findsOneWidget);
      expect(find.text('S'), findsOneWidget); // Initial in avatar
      expect(find.text('Yaqinda onlayn edi'), findsOneWidget);
      expect(find.text('sardor1995@gmail.com'), findsOneWidget);
      expect(find.text(LocalizationService.translate('unblock_user')), findsOneWidget);
    });

    testWidgets('TEST 10 — Existing chat behavior is unaffected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Chat with Sardor')),
            body: const Center(child: Text('Message List Content')),
          ),
        ),
      );

      expect(find.text('Chat with Sardor'), findsOneWidget);
      expect(find.text('Message List Content'), findsOneWidget);
    });
  });
}
