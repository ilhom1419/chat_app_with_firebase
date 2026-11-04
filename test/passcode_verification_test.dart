import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chat_app/features/auth/presentation/pages/passcode_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('passcode_test_hive');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  Widget buildTestWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        home: child,
      ),
    );
  }

  void setTestDeviceSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (int i = 0; i < pin.length; i++) {
      final digit = pin[i];
      await tester.tap(find.text(digit));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('Initial PIN setup from scratch: creates PIN successfully', (tester) async {
    setTestDeviceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final box = Hive.box('settings');
    await tester.runAsync(() async {
      await box.putAll({'app_passcode': null, 'is_passcode_enabled': false});
    });

    bool successCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        PasscodePage(
          mode: PasscodeMode.setup,
          onSuccess: (ctx) {
            successCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter initial PIN 0000
    await enterPin(tester, '0000');

    // Confirm PIN 0000
    await enterPin(tester, '0000');

    expect(successCalled, isTrue);
    expect(box.get('app_passcode'), equals('0000'));
    expect(box.get('is_passcode_enabled'), isTrue);
  });

  testWidgets('Changing PIN: entering WRONG existing PIN rejects change and retains old PIN', (tester) async {
    setTestDeviceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final box = Hive.box('settings');
    await tester.runAsync(() async {
      await box.putAll({'app_passcode': '0000', 'is_passcode_enabled': true});
    });

    bool successCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        PasscodePage(
          mode: PasscodeMode.change,
          onSuccess: (ctx) {
            successCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // First prompt asks for current PIN. User tries to enter 2222 (wrong)
    await enterPin(tester, '2222');

    // Verification must have failed
    expect(successCalled, isFalse);
    expect(box.get('app_passcode'), equals('0000')); // still 0000!
  });

  testWidgets('Changing PIN: entering CORRECT existing PIN 0000 then 1111 successfully changes PIN', (tester) async {
    setTestDeviceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final box = Hive.box('settings');
    await tester.runAsync(() async {
      await box.putAll({'app_passcode': '0000', 'is_passcode_enabled': true});
    });

    bool successCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        PasscodePage(
          mode: PasscodeMode.change,
          onSuccess: (ctx) {
            successCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Enter current PIN: 0000
    await enterPin(tester, '0000');

    // 2. Enter new PIN: 1111
    await enterPin(tester, '1111');

    // 3. Confirm new PIN: 1111
    await enterPin(tester, '1111');

    expect(successCalled, isTrue);
    expect(box.get('app_passcode'), equals('1111'));
    expect(box.get('is_passcode_enabled'), isTrue);
  });

  testWidgets('Setup mode when passcode already active also requires verifying old PIN', (tester) async {
    setTestDeviceSize(tester);
    addTearDown(tester.view.resetPhysicalSize);

    final box = Hive.box('settings');
    await tester.runAsync(() async {
      await box.putAll({'app_passcode': '0000', 'is_passcode_enabled': true});
    });

    bool successCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        PasscodePage(
          mode: PasscodeMode.setup,
          onSuccess: (ctx) {
            successCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Should prompt for old PIN first. Entering wrong PIN (9999) fails.
    await enterPin(tester, '9999');
    expect(box.get('app_passcode'), equals('0000'));
    expect(successCalled, isFalse);

    // Entering correct old PIN (0000) advances
    await enterPin(tester, '0000');

    // Enter new PIN (1111)
    await enterPin(tester, '1111');

    // Confirm new PIN (1111)
    await enterPin(tester, '1111');

    expect(successCalled, isTrue);
    expect(box.get('app_passcode'), equals('1111'));
  });
}
