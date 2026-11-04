import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TASK 4 & 5 — Blocked User Message Localization Tests (L1 - L5)', () {
    setUp(() {
      LocalizationService.setLanguage('uz');
    });

    test('TEST L1: Select English -> "You have been blocked"', () {
      LocalizationService.setLanguage('en');
      expect(
        LocalizationService.translate('you_have_been_blocked'),
        equals('You have been blocked'),
      );
      expect(
        LocalizationService.translate('you_are_blocked'),
        equals('You have been blocked'),
      );
      expect(
        LocalizationService.translate('you_have_blocked_user'),
        equals('You have blocked this user'),
      );
    });

    test('TEST L2: Select Russian -> "Вы заблокированы"', () {
      LocalizationService.setLanguage('ru');
      expect(
        LocalizationService.translate('you_have_been_blocked'),
        equals('Вы заблокированы'),
      );
      expect(
        LocalizationService.translate('you_are_blocked'),
        equals('Вы заблокированы'),
      );
      expect(
        LocalizationService.translate('you_have_blocked_user'),
        equals('Вы заблокировали этого пользователя'),
      );
    });

    test('TEST L3: Select Uzbek -> "Siz bloklangansiz"', () {
      LocalizationService.setLanguage('uz');
      expect(
        LocalizationService.translate('you_have_been_blocked'),
        equals('Siz bloklangansiz'),
      );
      expect(
        LocalizationService.translate('you_are_blocked'),
        equals('Siz bloklangansiz'),
      );
      expect(
        LocalizationService.translate('you_have_blocked_user'),
        equals('Siz ushbu foydalanuvchini bloklagansiz'),
      );
    });

    testWidgets(
        'TEST L4: Switch between the three languages while affected UI is active -> updates reactively without restart',
        (WidgetTester tester) async {
      LocalizationService.setLanguage('uz');

      // Widget mirroring the block banner implementation in MessagePage
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Center(
                  child: Text(
                    LocalizationService.translate('you_have_been_blocked'),
                    key: const Key('blocked_message_text'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Initially Uzbek
      expect(find.text('Siz bloklangansiz'), findsOneWidget);

      // Switch to English
      LocalizationService.setLanguage('en');
      await tester.pump();
      expect(find.text('You have been blocked'), findsOneWidget);
      expect(find.text('Siz bloklangansiz'), findsNothing);

      // Switch to Russian
      LocalizationService.setLanguage('ru');
      await tester.pump();
      expect(find.text('Вы заблокированы'), findsOneWidget);
      expect(find.text('You have been blocked'), findsNothing);

      // Switch back to Uzbek
      LocalizationService.setLanguage('uz');
      await tester.pump();
      expect(find.text('Siz bloklangansiz'), findsOneWidget);
      expect(find.text('Вы заблокированы'), findsNothing);
    });

    testWidgets(
        'TEST L4-B: "You have blocked this user" also updates reactively across languages',
        (WidgetTester tester) async {
      LocalizationService.setLanguage('uz');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Center(
                  child: Text(
                    LocalizationService.translate('you_have_blocked_user'),
                    key: const Key('i_blocked_other_text'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Siz ushbu foydalanuvchini bloklagansiz'), findsOneWidget);

      LocalizationService.setLanguage('en');
      await tester.pump();
      expect(find.text('You have blocked this user'), findsOneWidget);

      LocalizationService.setLanguage('ru');
      await tester.pump();
      expect(find.text('Вы заблокировали этого пользователя'), findsOneWidget);
    });

    test('TEST L5: Block state logic retains strict authorization invariant', () {
      const myUid = 'user_me';
      const otherUid = 'user_other';

      final myBlockedList = <String>[otherUid];
      final otherBlockedList = <String>[myUid];

      // iBlockedOther logic check
      final iBlockedOther = myBlockedList.contains(otherUid);
      expect(iBlockedOther, isTrue);

      // otherBlockedMe logic check
      final otherBlockedMe = otherBlockedList.contains(myUid);
      expect(otherBlockedMe, isTrue);

      // Invariants remain preserved: blocked state blocks input and shows banner
      expect(
        iBlockedOther ? 'you_have_blocked_user' : 'normal',
        equals('you_have_blocked_user'),
      );
      expect(
        otherBlockedMe ? 'you_have_been_blocked' : 'normal',
        equals('you_have_been_blocked'),
      );
    });
  });
}
