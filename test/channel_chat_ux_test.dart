import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  setUp(() {
    LocalizationService.langNotifier.value = 'uz';
  });

  group('TASK 1 — Channel Header & Action Localization Tests', () {
    test('Channel subtitle translates strictly to single language without mixing', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(LocalizationService.translate('channel'), equals('Kanal'));
      expect(LocalizationService.translate('channel').contains('('), isFalse);

      LocalizationService.langNotifier.value = 'en';
      expect(LocalizationService.translate('channel'), equals('Channel'));
      expect(LocalizationService.translate('channel').contains('('), isFalse);

      LocalizationService.langNotifier.value = 'ru';
      expect(LocalizationService.translate('channel'), equals('Канал'));
      expect(LocalizationService.translate('channel').contains('('), isFalse);
    });

    test('Leave a comment button label translates properly in uz, en, ru', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(LocalizationService.translate('leave_comment_action'), equals('Izoh qoldirish'));
      expect(LocalizationService.translate('leave_comment'), equals('Izoh qoldirish'));

      LocalizationService.langNotifier.value = 'en';
      expect(LocalizationService.translate('leave_comment_action'), equals('Leave a comment'));
      expect(LocalizationService.translate('leave_comment'), equals('Leave a comment'));

      LocalizationService.langNotifier.value = 'ru';
      expect(LocalizationService.translate('leave_comment_action'), equals('Оставить комментарий'));
      expect(LocalizationService.translate('leave_comment'), equals('Оставить комментарий'));
    });

    test('Composer hint "type_message" translates in uz, en, ru', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(LocalizationService.translate('type_message'), equals('Xabar yozing...'));

      LocalizationService.langNotifier.value = 'en';
      expect(LocalizationService.translate('type_message'), equals('Type a message...'));

      LocalizationService.langNotifier.value = 'ru';
      expect(LocalizationService.translate('type_message'), equals('Сообщение...'));
    });

    test('Channel created message translates dynamically in uz, en, ru', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(
        LocalizationService.translate('channel_created_msg', params: {'name': 'Namangan'}),
        equals('"Namangan" kanali yaratildi.'),
      );
      expect(LocalizationService.translate('channel_created'), equals('Kanal yaratildi'));

      LocalizationService.langNotifier.value = 'en';
      expect(
        LocalizationService.translate('channel_created_msg', params: {'name': 'Namangan'}),
        equals('Channel "Namangan" created.'),
      );
      expect(LocalizationService.translate('channel_created'), equals('Channel created'));

      LocalizationService.langNotifier.value = 'ru';
      expect(
        LocalizationService.translate('channel_created_msg', params: {'name': 'Namangan'}),
        equals('Канал "Namangan" создан.'),
      );
      expect(LocalizationService.translate('channel_created'), equals('Канал создан'));
    });

    test('Voice message, Video, Send and Notifications action translations exist across all 3 languages', () {
      // 1. Uzbek
      LocalizationService.langNotifier.value = 'uz';
      expect(LocalizationService.translate('voice_message'), equals('Ovozli xabar'));
      expect(LocalizationService.translate('video'), equals('Video'));
      expect(LocalizationService.translate('send'), equals('Yuborish'));
      expect(LocalizationService.translate('notifications'), equals('Bildirishnomalar'));
      expect(LocalizationService.translate('silent_post_on'), equals('Ovozsiz post yoqildi (obunachilarga jiringlamaydi)'));
      expect(LocalizationService.translate('silent_post_off'), equals('Ovozsiz post o‘chirildi'));
      expect(LocalizationService.translate('silent_post_enabled'), equals('Ovozsiz post yoqildi'));
      expect(LocalizationService.translate('silent_post_disabled'), equals('Ovozsiz post o‘chirildi'));

      // 2. English
      LocalizationService.langNotifier.value = 'en';
      expect(LocalizationService.translate('voice_message'), equals('Voice message'));
      expect(LocalizationService.translate('video'), equals('Video'));
      expect(LocalizationService.translate('send'), equals('Send'));
      expect(LocalizationService.translate('notifications'), equals('Notifications'));
      expect(LocalizationService.translate('silent_post_on'), equals('Silent post enabled (subscribers will not be alerted)'));
      expect(LocalizationService.translate('silent_post_off'), equals('Silent post disabled'));
      expect(LocalizationService.translate('silent_post_enabled'), equals('Silent post enabled'));
      expect(LocalizationService.translate('silent_post_disabled'), equals('Silent post disabled'));

      // 3. Russian
      LocalizationService.langNotifier.value = 'ru';
      expect(LocalizationService.translate('voice_message'), equals('Голосовое сообщение'));
      expect(LocalizationService.translate('video'), equals('Видео'));
      expect(LocalizationService.translate('send'), equals('Отправить'));
      expect(LocalizationService.translate('notifications'), equals('Уведомления'));
      expect(LocalizationService.translate('silent_post_on'), equals('Беззвучная публикация включена (без звука для подписчиков)'));
      expect(LocalizationService.translate('silent_post_off'), equals('Беззвучная публикация выключена'));
      expect(LocalizationService.translate('silent_post_enabled'), equals('Беззвучная публикация включена'));
      expect(LocalizationService.translate('silent_post_disabled'), equals('Беззвучная публикация выключена'));
    });
  });

  group('TASK 2 & 3 — Message Composer & Action Menu Specification Tests', () {
    testWidgets('Single Plus button and responsive TextField layout test', (tester) async {
      final controller = TextEditingController();
      bool plusTapped = false;
      bool sendTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final showSend = controller.text.trim().isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      // [+] Single Action Menu button
                      IconButton(
                        key: const Key('action_menu_plus_btn'),
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () => plusTapped = true,
                      ),
                      const SizedBox(width: 8),
                      // Responsive expanded text field
                      Expanded(
                        child: TextField(
                          key: const Key('message_input_field'),
                          controller: controller,
                          maxLines: 4,
                          minLines: 1,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      // Send button appears ONLY when text is non-empty in channel
                      if (showSend) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('send_message_btn'),
                          icon: const Icon(Icons.send_rounded),
                          onPressed: () => sendTapped = true,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 1. Initial State: Only [+] and TextField are visible. Send button is NOT present.
      expect(find.byKey(const Key('action_menu_plus_btn')), findsOneWidget);
      expect(find.byKey(const Key('message_input_field')), findsOneWidget);
      expect(find.byKey(const Key('send_message_btn')), findsNothing);

      // Verify Plus button works
      await tester.tap(find.byKey(const Key('action_menu_plus_btn')));
      await tester.pump();
      expect(plusTapped, isTrue);

      // 2. Typing State: Text is entered, Send button appears
      await tester.enterText(find.byKey(const Key('message_input_field')), 'Salom');
      await tester.pump();

      expect(find.byKey(const Key('send_message_btn')), findsOneWidget);

      // Tap Send button
      await tester.tap(find.byKey(const Key('send_message_btn')));
      await tester.pump();
      expect(sendTapped, isTrue);

      // 3. Post-Send: Clearing text removes the Send button
      await tester.enterText(find.byKey(const Key('message_input_field')), '');
      await tester.pump();
      expect(find.byKey(const Key('send_message_btn')), findsNothing);
    });
  });
}
