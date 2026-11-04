import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/security/screen_protector_service.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> methodCalls = [];
  bool simulateFailure = false;

  setUp(() {
    methodCalls.clear();
    simulateFailure = false;
    ScreenProtectorService.resetForTesting();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      ScreenProtectorService.channelForTesting,
      (MethodCall call) async {
        if (simulateFailure) {
          throw PlatformException(
            code: 'PLATFORM_ERROR',
            message: 'Window manager flag modification failed',
          );
        }
        methodCalls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      ScreenProtectorService.channelForTesting,
      null,
    );
    ScreenProtectorService.resetForTesting();
  });

  group('PHASE E — Screen Protection Service & MethodChannel Integration', () {
    test('1. Secure mode is enabled when Secret Chat opens (enableSecure)', () async {
      expect(ScreenProtectorService.activeSecureCount, equals(0));
      expect(ScreenProtectorService.isSecureActive, isFalse);

      await ScreenProtectorService.enableSecure();

      expect(ScreenProtectorService.activeSecureCount, equals(1));
      expect(ScreenProtectorService.isSecureActive, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.first.method, equals('enableSecure'));
    });

    test('2. Secure mode is disabled appropriately after leaving (disableSecure)', () async {
      await ScreenProtectorService.enableSecure();
      expect(ScreenProtectorService.isSecureActive, isTrue);
      expect(methodCalls.length, equals(1));
      expect(methodCalls.last.method, equals('enableSecure'));

      await ScreenProtectorService.disableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(0));
      expect(ScreenProtectorService.isSecureActive, isFalse);
      expect(methodCalls.length, equals(2));
      expect(methodCalls.last.method, equals('disableSecure'));
    });

    test('3. Reference counting: Nested routes preserve protection until last route exits', () async {
      // 1. Root secret chat opened
      await ScreenProtectorService.enableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(1));
      expect(methodCalls.length, equals(1));
      expect(methodCalls.last.method, equals('enableSecure'));

      // 2. Nested protected modal (e.g. Safety Number sheet or child secure route) opened
      await ScreenProtectorService.enableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(2));
      // No duplicate enableSecure call sent to native platform
      expect(methodCalls.length, equals(1));

      // 3. Nested modal popped
      await ScreenProtectorService.disableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(1));
      expect(ScreenProtectorService.isSecureActive, isTrue);
      // disableSecure must NOT be called while parent secret chat is still visible
      expect(methodCalls.length, equals(1));

      // 4. Root secret chat popped
      await ScreenProtectorService.disableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(0));
      expect(ScreenProtectorService.isSecureActive, isFalse);
      // Now disableSecure is dispatched to native window
      expect(methodCalls.length, equals(2));
      expect(methodCalls.last.method, equals('disableSecure'));
    });

    test('4. Rapid navigation & concurrency: operations are queued and consistent', () async {
      // Rapid sequential enables and disables
      final f1 = ScreenProtectorService.enableSecure();
      final f2 = ScreenProtectorService.enableSecure();
      final f3 = ScreenProtectorService.disableSecure();
      final f4 = ScreenProtectorService.disableSecure();

      await Future.wait([f1, f2, f3, f4]);

      expect(ScreenProtectorService.activeSecureCount, equals(0));
      expect(ScreenProtectorService.isSecureActive, isFalse);
      expect(methodCalls.map((c) => c.method).toList(), equals(['enableSecure', 'disableSecure']));
    });

    test('5. Lifecycle resume re-asserts FLAG_SECURE if active', () async {
      // With active secret chat
      await ScreenProtectorService.enableSecure();
      expect(methodCalls.length, equals(1));

      // App resumed from background
      await ScreenProtectorService.reapplyIfActive();
      expect(methodCalls.length, equals(2));
      expect(methodCalls.last.method, equals('enableSecure'));

      // If no active secret chat, reapplyIfActive does not invoke native
      await ScreenProtectorService.disableSecure();
      expect(methodCalls.length, equals(3));
      expect(methodCalls.last.method, equals('disableSecure'));

      await ScreenProtectorService.reapplyIfActive();
      expect(methodCalls.length, equals(3)); // unchanged
    });

    test('6. Native MethodChannel failures do not crash service or break counter state', () async {
      simulateFailure = true;

      // enableSecure with platform failure
      await expectLater(ScreenProtectorService.enableSecure(), completes);
      expect(ScreenProtectorService.activeSecureCount, equals(1));
      expect(ScreenProtectorService.isSecureActive, isTrue);

      // disableSecure with platform failure
      await expectLater(ScreenProtectorService.disableSecure(), completes);
      expect(ScreenProtectorService.activeSecureCount, equals(0));
      expect(ScreenProtectorService.isSecureActive, isFalse);
    });

    test('7. Force disable resets state and invokes native disableSecure', () async {
      await ScreenProtectorService.enableSecure();
      await ScreenProtectorService.enableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(2));

      await ScreenProtectorService.forceDisableSecure();
      expect(ScreenProtectorService.activeSecureCount, equals(0));
      expect(ScreenProtectorService.isSecureActive, isFalse);
      expect(methodCalls.last.method, equals('disableSecure'));
    });

    test('8. Localization keys for Phase E screenshot protection are present in uz, en, ru', () {
      final uz = LocalizationService.localizedValuesForTesting['uz']!;
      final en = LocalizationService.localizedValuesForTesting['en']!;
      final ru = LocalizationService.localizedValuesForTesting['ru']!;

      for (final key in [
        'screenshot_protection',
        'screenshot_protection_badge',
        'screenshot_protection_desc',
        'screenshot_protection_active',
      ]) {
        expect(uz.containsKey(key), isTrue, reason: 'uz missing $key');
        expect(en.containsKey(key), isTrue, reason: 'en missing $key');
        expect(ru.containsKey(key), isTrue, reason: 'ru missing $key');
        expect(uz[key]!.isNotEmpty, isTrue);
        expect(en[key]!.isNotEmpty, isTrue);
        expect(ru[key]!.isNotEmpty, isTrue);
      }
    });
  });
}
