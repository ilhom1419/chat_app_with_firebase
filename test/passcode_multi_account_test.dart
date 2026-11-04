import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:chat_app/core/services/passcode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Box settingsBox;

  setUpAll(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('passcode_multi_acc_test');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox(PasscodeService.settingsBoxName);
  });

  setUp(() async {
    await settingsBox.clear();
  });

  group('Passcode Multi-Account Isolation Tests', () {
    test('1. Two accounts have completely independent PIN codes', () async {
      const userA = 'user_account_A';
      const userB = 'user_account_B';

      // User A sets PIN 1111
      await PasscodeService.setPasscode('1111', uid: userA, box: settingsBox);

      // User B sets PIN 0000
      await PasscodeService.setPasscode('0000', uid: userB, box: settingsBox);

      // Verify User A's passcode is 1111 and enabled
      expect(PasscodeService.isPasscodeEnabled(uid: userA, box: settingsBox), isTrue);
      expect(PasscodeService.getPasscode(uid: userA, box: settingsBox), equals('1111'));

      // Verify User B's passcode is 0000 and enabled
      expect(PasscodeService.isPasscodeEnabled(uid: userB, box: settingsBox), isTrue);
      expect(PasscodeService.getPasscode(uid: userB, box: settingsBox), equals('0000'));
    });

    test('2. A new account (User C) does not inherit any PIN code from User A or B', () async {
      const userA = 'user_account_A';
      const userC = 'user_account_C_new';

      await PasscodeService.setPasscode('1111', uid: userA, box: settingsBox);

      // User C has not set a PIN
      expect(PasscodeService.isPasscodeEnabled(uid: userC, box: settingsBox), isFalse);
      expect(PasscodeService.getPasscode(uid: userC, box: settingsBox), isNull);
    });

    test('3. Disabling passcode for User A does NOT affect User B', () async {
      const userA = 'user_account_A';
      const userB = 'user_account_B';

      await PasscodeService.setPasscode('1111', uid: userA, box: settingsBox);
      await PasscodeService.setPasscode('0000', uid: userB, box: settingsBox);

      // User A disables passcode
      await PasscodeService.disablePasscode(uid: userA, box: settingsBox);

      expect(PasscodeService.isPasscodeEnabled(uid: userA, box: settingsBox), isFalse);
      expect(PasscodeService.getPasscode(uid: userA, box: settingsBox), isNull);

      // User B is still enabled with 0000
      expect(PasscodeService.isPasscodeEnabled(uid: userB, box: settingsBox), isTrue);
      expect(PasscodeService.getPasscode(uid: userB, box: settingsBox), equals('0000'));
    });

    test('4. Auto-lock duration and biometrics are isolated per account', () async {
      const userA = 'user_account_A';
      const userB = 'user_account_B';

      await PasscodeService.setAutoLockDuration(300, uid: userA, box: settingsBox);
      await PasscodeService.setBiometricEnabled(true, uid: userA, box: settingsBox);

      await PasscodeService.setAutoLockDuration(600, uid: userB, box: settingsBox);
      await PasscodeService.setBiometricEnabled(false, uid: userB, box: settingsBox);

      expect(PasscodeService.getAutoLockDuration(uid: userA, box: settingsBox), equals(300));
      expect(PasscodeService.isBiometricEnabled(uid: userA, box: settingsBox), isTrue);

      expect(PasscodeService.getAutoLockDuration(uid: userB, box: settingsBox), equals(600));
      expect(PasscodeService.isBiometricEnabled(uid: userB, box: settingsBox), isFalse);
    });

    test('5. Legacy migration migrates to logged-in user and clears global key', () async {
      const legacyUser = 'legacy_logged_in_user';
      const newUser = 'second_user';

      // Simulate old version with global keys
      await settingsBox.put('app_passcode', '7777');
      await settingsBox.put('is_passcode_enabled', true);

      // Legacy user accesses their passcode
      expect(PasscodeService.isPasscodeEnabled(uid: legacyUser, box: settingsBox), isTrue);
      expect(PasscodeService.getPasscode(uid: legacyUser, box: settingsBox), equals('7777'));

      // Verify global keys were cleared
      expect(settingsBox.get('app_passcode'), isNull);
      expect(settingsBox.get('is_passcode_enabled'), isNull);

      // New second user must NOT have a passcode
      expect(PasscodeService.isPasscodeEnabled(uid: newUser, box: settingsBox), isFalse);
      expect(PasscodeService.getPasscode(uid: newUser, box: settingsBox), isNull);
    });
  });
}

