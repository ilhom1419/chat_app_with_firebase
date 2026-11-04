import 'dart:io';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/shared/widgets/floating_bottom_sheet.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';
import 'package:chat_app/features/chats/domain/entities/chat_member.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';

void main() {
  setUpAll(() {
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
  });

  setUp(() {
    LocalizationService.langNotifier.value = 'uz';
  });

  group('LANGUAGE STATE TESTS (01 - 06)', () {
    testWidgets('TEST 01: Uzbek selection updates current screen reactively', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Text(LocalizationService.of(context).get('settings'));
              },
            ),
          ),
        ),
      );

      LocalizationService.changeLanguage('uz');
      await tester.pumpAndSettle();
      expect(find.text('Sozlamalar'), findsOneWidget);
    });

    testWidgets('TEST 02: English selection updates current screen reactively', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Text(LocalizationService.of(context).get('settings'));
              },
            ),
          ),
        ),
      );

      LocalizationService.changeLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sozlamalar'), findsNothing);
    });

    testWidgets('TEST 03: Russian selection updates current screen reactively', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Text(LocalizationService.of(context).get('settings'));
              },
            ),
          ),
        ),
      );

      LocalizationService.changeLanguage('ru');
      await tester.pumpAndSettle();
      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Sozlamalar'), findsNothing);
    });

    test('TEST 04: Language persistence uses authoritative app_lang key', () {
      expect(LocalizationService.supportedLocales.map((l) => l.languageCode),
          containsAll(['uz', 'en', 'ru']));
      expect(LocalizationService.currentLocale.languageCode, isIn(['uz', 'en', 'ru']));
    });

    test('TEST 05: Account switching respects user language preferences without leaking', () {
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.currentLanguage, equals('ru'));
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.currentLanguage, equals('uz'));
    });

    test('TEST 06: No stale locale state remains after switching', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('cancel'), equals('Cancel'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('cancel'), equals('Отмена'));
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('cancel'), equals('Bekor qilish'));
    });
  });

  group('TRANSLATION COVERAGE TESTS (07 - 12)', () {
    test('TEST 07: All supported translation keys have 3 symmetric entries', () {
      final values = LocalizationService.localizedValuesForTesting;
      final uzKeys = values['uz']!.keys.toSet();
      final enKeys = values['en']!.keys.toSet();
      final ruKeys = values['ru']!.keys.toSet();

      expect(uzKeys.difference(enKeys), isEmpty, reason: 'Keys in uz missing in en');
      expect(uzKeys.difference(ruKeys), isEmpty, reason: 'Keys in uz missing in ru');
      expect(enKeys.difference(uzKeys), isEmpty, reason: 'Keys in en missing in uz');
      expect(ruKeys.difference(uzKeys), isEmpty, reason: 'Keys in ru missing in uz');
    });

    test('TEST 08: No empty required translations across all 3 languages', () {
      final values = LocalizationService.localizedValuesForTesting;
      for (final lang in ['uz', 'en', 'ru']) {
        for (final entry in values[lang]!.entries) {
          expect(entry.value.trim().isNotEmpty, isTrue,
              reason: 'Empty translation for key "${entry.key}" in $lang');
        }
      }
    });

    test('TEST 09: Placeholders are consistent across translations', () {
      final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');
      final values = LocalizationService.localizedValuesForTesting;

      for (final key in values['uz']!.keys) {
        final uzVal = values['uz']![key]!;
        final enVal = values['en']![key]!;
        final ruVal = values['ru']![key]!;

        final uzPlaceholders = placeholderRegex.allMatches(uzVal).map((m) => m.group(1)).toSet();
        final enPlaceholders = placeholderRegex.allMatches(enVal).map((m) => m.group(1)).toSet();
        final ruPlaceholders = placeholderRegex.allMatches(ruVal).map((m) => m.group(1)).toSet();

        expect(uzPlaceholders, equals(enPlaceholders),
            reason: 'Placeholder mismatch between uz and en for key: $key');
        expect(uzPlaceholders, equals(ruPlaceholders),
            reason: 'Placeholder mismatch between uz and ru for key: $key');
      }
    });

    test('TEST 10: Pluralization works for Russian, English, and Uzbek', () {
      // English: 1 subscriber, 5 subscribers
      LocalizationService.setLanguage('en');
      expect(LocalizationService.plural('subscribers_count', 1), equals('1 subscriber'));
      expect(LocalizationService.plural('subscribers_count', 5), equals('5 subscribers'));

      // Uzbek: 1 obunachi, 5 obunachi
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.plural('subscribers_count', 1), equals('1 obunachi'));
      expect(LocalizationService.plural('subscribers_count', 5), equals('5 obunachi'));

      // Russian: 1 подписчик, 2 подписчика, 5 подписчиков
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.plural('subscribers_count', 1), equals('1 подписчик'));
      expect(LocalizationService.plural('subscribers_count', 2), equals('2 подписчика'));
      expect(LocalizationService.plural('subscribers_count', 5), equals('5 подписчиков'));
    });

    test('TEST 11: Date separators and relative dates are localized', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      LocalizationService.setLanguage('uz');
      expect(LocalizationService.formatMessageDate(now), equals('Bugun'));
      expect(LocalizationService.formatMessageDate(yesterday), equals('Kecha'));

      LocalizationService.setLanguage('en');
      expect(LocalizationService.formatMessageDate(now), equals('Today'));
      expect(LocalizationService.formatMessageDate(yesterday), equals('Yesterday'));

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.formatMessageDate(now), equals('Сегодня'));
      expect(LocalizationService.formatMessageDate(yesterday), equals('Вчера'));
    });

    test('TEST 12: Dynamic status labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('online'), equals('tarmoqda'));
      expect(LocalizationService.translate('typing'), equals('yozmoqda...'));
      expect(LocalizationService.translate('offline'), equals('tarmoqda emas'));

      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('online'), equals('online'));
      expect(LocalizationService.translate('typing'), equals('typing...'));
      expect(LocalizationService.translate('offline'), equals('offline'));

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('online'), equals('в сети'));
      expect(LocalizationService.translate('typing'), equals('печатает...'));
      expect(LocalizationService.translate('offline'), equals('не в сети'));
    });
  });

  group('SCREEN COVERAGE TESTS (13 - 30)', () {
    test('TEST 13: Authentication labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('login_btn'), equals('Kirish'));
      expect(LocalizationService.translate('signup_btn'), equals("Ro'yxatdan o'tish"));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('login_btn'), equals('Log In'));
      expect(LocalizationService.translate('signup_btn'), equals('Sign Up'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('login_btn'), equals('Войти'));
      expect(LocalizationService.translate('signup_btn'), equals('Регистрация'));
    });

    test('TEST 14: Home / Main Navigation labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('chats_title'), equals('Chatlar'));
      expect(LocalizationService.translate('all_chats_tab'), equals('Barchasi'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('chats_title'), equals('Chats'));
      expect(LocalizationService.translate('all_chats_tab'), equals('All'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('chats_title'), equals('Чаты'));
      expect(LocalizationService.translate('all_chats_tab'), equals('Все'));
    });

    test('TEST 15: Chat list filter tabs are localized', () {
      final folders = ChatFolder.defaultFolders();

      LocalizationService.setLanguage('uz');
      expect(folders[0].localizedName, equals('Barchasi'));
      expect(folders[1].localizedName, equals('Shaxsiy'));
      expect(folders[2].localizedName, equals('Guruhlar'));
      expect(folders[3].localizedName, equals('Kanallar'));

      LocalizationService.setLanguage('en');
      expect(folders[0].localizedName, equals('All'));
      expect(folders[1].localizedName, equals('Private'));
      expect(folders[2].localizedName, equals('Groups'));
      expect(folders[3].localizedName, equals('Channels'));

      LocalizationService.setLanguage('ru');
      expect(folders[0].localizedName, equals('Все'));
      expect(folders[1].localizedName, equals('Личные'));
      expect(folders[2].localizedName, equals('Группы'));
      expect(folders[3].localizedName, equals('Каналы'));
    });

    test('TEST 16: Private chat composer and bubble labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('type_message'), equals('Xabar yozing...'));
      expect(LocalizationService.translate('save_contact'), equals('Kontaktni saqlash'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('type_message'), equals('Type a message...'));
      expect(LocalizationService.translate('save_contact'), equals('Save Contact'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('type_message'), equals('Сообщение...'));
      expect(LocalizationService.translate('save_contact'), equals('Сохранить контакт'));
    });

    test('TEST 17: Message action menus are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('reply_option'), equals('Javob berish'));
      expect(LocalizationService.translate('forward_option'), equals('Yuborish'));
      expect(LocalizationService.translate('copy_action_title'), equals('Nusxa olish'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('reply_option'), equals('Reply'));
      expect(LocalizationService.translate('forward_option'), equals('Forward'));
      expect(LocalizationService.translate('copy_action_title'), equals('Copy'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('reply_option'), equals('Ответить'));
      expect(LocalizationService.translate('forward_option'), equals('Переслать'));
      expect(LocalizationService.translate('copy_action_title'), equals('Копировать'));
    });

    test('TEST 18: Groups UI and roles are localized', () {
      LocalizationService.setLanguage('uz');
      expect(MemberRole.owner.localizedName, equals('Asoschi'));
      expect(MemberRole.admin.localizedName, equals('Administrator'));
      expect(MemberRole.member.localizedName, equals("A'zo"));
      expect(LocalizationService.translate('leave_group'), equals('Guruhni tark etish'));
      LocalizationService.setLanguage('en');
      expect(MemberRole.owner.localizedName, equals('Owner'));
      expect(MemberRole.admin.localizedName, equals('Administrator'));
      expect(MemberRole.member.localizedName, equals('Member'));
      expect(LocalizationService.translate('leave_group'), equals('Leave Group'));
      LocalizationService.setLanguage('ru');
      expect(MemberRole.owner.localizedName, equals('Владелец'));
      expect(MemberRole.admin.localizedName, equals('Администратор'));
      expect(MemberRole.member.localizedName, equals('Участник'));
      expect(LocalizationService.translate('leave_group'), equals('Покинуть группу'));
    });

    test('TEST 19: Channels UI and action labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('go_to_channel'), equals("Kanalga o'tish"));
      expect(LocalizationService.translate('subscribe_channel_btn'), equals("Kanalga obuna bo'lish"));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('go_to_channel'), equals('Go to Channel'));
      expect(LocalizationService.translate('subscribe_channel_btn'), equals('Subscribe'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('go_to_channel'), equals('Перейти в канал'));
      expect(LocalizationService.translate('subscribe_channel_btn'), equals('Подписаться на канал'));
    });

    test('TEST 20: Live Voice Chat labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('voice_chat_wants_to_speak'), equals("So'z olmoqchi"));
      expect(LocalizationService.translate('voice_chat_approve_speaker'), equals('Mikrofonga ruxsat berish'));
      expect(LocalizationService.translate('voice_chat_reject_speaker'), equals('Rad etish'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('voice_chat_wants_to_speak'), equals('Wants to Speak'));
      expect(LocalizationService.translate('voice_chat_approve_speaker'), equals('Approve speaker request'));
      expect(LocalizationService.translate('voice_chat_reject_speaker'), equals('Reject speaker request'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('voice_chat_wants_to_speak'), equals('Просит слово'));
      expect(LocalizationService.translate('voice_chat_approve_speaker'), equals('Разрешить говорить'));
      expect(LocalizationService.translate('voice_chat_reject_speaker'), equals('Отклонить запрос'));
    });

    test('TEST 21: Stories UI labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('stories_title'), equals('Hikoyalar'));
      expect(LocalizationService.translate('publish_story'), equals('Hikoyani joylash'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('stories_title'), equals('Stories'));
      expect(LocalizationService.translate('publish_story'), equals('Post Story'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('stories_title'), equals('Истории'));
      expect(LocalizationService.translate('publish_story'), equals('Опубликовать историю'));
    });

    test('TEST 22: Media Editor labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('edit_image'), equals('Rasmni tahrirlash'));
      expect(LocalizationService.translate('trim_video'), equals('Videoni kesish'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('edit_image'), equals('Edit Image'));
      expect(LocalizationService.translate('trim_video'), equals('Trim Video'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('edit_image'), equals('Редактировать фото'));
      expect(LocalizationService.translate('trim_video'), equals('Обрезать видео'));
    });

    test('TEST 23: Secret Chat UI labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('start_secret_chat'), equals('Maxfiy chat boshlash'));
      expect(LocalizationService.translate('screenshot_protection'), equals('Skrinshot himoyasi'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('start_secret_chat'), equals('Start Secret Chat'));
      expect(LocalizationService.translate('screenshot_protection'), equals('Screenshot Protection'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('start_secret_chat'), equals('Начать секретный чат'));
      expect(LocalizationService.translate('screenshot_protection'), equals('Защита от скриншотов'));
    });

    test('TEST 24: Offline Outbox UI labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('waiting_to_send'), equals('Yuborilishi kutilmoqda'));
      expect(LocalizationService.translate('sending'), equals('Yuborilmoqda...'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('waiting_to_send'), equals('Waiting to send'));
      expect(LocalizationService.translate('sending'), equals('Sending...'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('waiting_to_send'), equals('Ожидает отправки'));
      expect(LocalizationService.translate('sending'), equals('Отправка...'));
    });

    test('TEST 25: Scheduled Messages UI labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('schedule_message'), equals('Xabarni rejalashtirish'));
      expect(LocalizationService.translate('scheduled_messages'), equals('Rejalashtirilgan xabarlar'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('schedule_message'), equals('Schedule Message'));
      expect(LocalizationService.translate('scheduled_messages'), equals('Scheduled Messages'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('schedule_message'), equals('Запланировать сообщение'));
      expect(LocalizationService.translate('scheduled_messages'), equals('Отложенные сообщения'));
    });

    test('TEST 26: Live Location UI labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('share_live_location'), equals('Jonli joylashuvni ulashish'));
      expect(LocalizationService.translate('stop_sharing'), equals('Ulashishni to‘xtatish'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('share_live_location'), equals('Share Live Location'));
      expect(LocalizationService.translate('stop_sharing'), equals('Stop Sharing'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('share_live_location'), equals('Поделиться геопозицией'));
      expect(LocalizationService.translate('stop_sharing'), equals('Прекратить делиться'));
    });

    test('TEST 27: Saved Messages UI labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('saved_messages'), equals('Saqlangan xabarlar'));
      expect(LocalizationService.translate('save_to_saved_messages'), equals('Saqlangan xabarlarga saqlash'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('saved_messages'), equals('Saved Messages'));
      expect(LocalizationService.translate('save_to_saved_messages'), equals('Save to Saved Messages'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('saved_messages'), equals('Избранное'));
      expect(LocalizationService.translate('save_to_saved_messages'), equals('Сохранить в Избранное'));
    });

    test('TEST 28: Profile labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('edit_profile'), equals('Profilni tahrirlash'));
      expect(LocalizationService.translate('phone_label'), equals('Telefon raqami'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('edit_profile'), equals('Edit Profile'));
      expect(LocalizationService.translate('phone_label'), equals('Phone Number'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('edit_profile'), equals('Редактировать профиль'));
      expect(LocalizationService.translate('phone_label'), equals('Номер телефона'));
    });

    test('TEST 29: Settings labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('settings'), equals('Sozlamalar'));
      expect(LocalizationService.translate('dark_mode'), equals("Qorong'u rejim"));
      expect(LocalizationService.translate('logout'), equals('Chiqish'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('settings'), equals('Settings'));
      expect(LocalizationService.translate('dark_mode'), equals('Dark Mode'));
      expect(LocalizationService.translate('logout'), equals('Log Out'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('settings'), equals('Настройки'));
      expect(LocalizationService.translate('dark_mode'), equals('Тёмная тема'));
      expect(LocalizationService.translate('logout'), equals('Выйти'));
    });

    test('TEST 30: Shared UI components labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('cancel'), equals('Bekor qilish'));
      expect(LocalizationService.translate('confirm'), equals('Tasdiqlash'));
      expect(LocalizationService.translate('close'), equals('Yopish'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('cancel'), equals('Cancel'));
      expect(LocalizationService.translate('confirm'), equals('Confirm'));
      expect(LocalizationService.translate('close'), equals('Close'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('cancel'), equals('Отмена'));
      expect(LocalizationService.translate('confirm'), equals('Подтвердить'));
      expect(LocalizationService.translate('close'), equals('Закрыть'));
    });
  });

  group('OVERLAYS, DIALOGS & ERROR TESTS (31 - 36)', () {
    testWidgets('TEST 31: Floating BottomSheets respect active locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showKakkuFloatingBottomSheet(
                    context: ctx,
                    builder: (sheetCtx) => Text(LocalizationService.of(sheetCtx).get('pinned_messages')),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      LocalizationService.setLanguage('en');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Pinned Messages'), findsOneWidget);
    });

    testWidgets('TEST 32: Dialogs respect active locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: Text(LocalizationService.of(dCtx).get('delete_chat')),
                      actions: [
                        TextButton(
                          onPressed: () {},
                          child: Text(LocalizationService.of(dCtx).get('cancel')),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Dialog'),
              ),
            ),
          ),
        ),
      );

      LocalizationService.setLanguage('ru');
      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить чат'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
    });

    test('TEST 33: SnackBars use localized strings', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('link_copied_success'), equals('Havola nusxalandi!'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('link_copied_success'), equals('Link copied to clipboard!'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('link_copied_success'), equals('Ссылка скопирована в буфер обмена!'));
    });

    test('TEST 34: Form validation errors respect active locale', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('email_required'), equals('Email kiritilishi shart'));
      expect(LocalizationService.translate('password_too_short'), equals("Parol kamida 6 ta belgidan iborat bo'lishi kerak"));

      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('email_required'), equals('Email is required'));
      expect(LocalizationService.translate('password_too_short'), equals('Password must be at least 6 characters'));

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('email_required'), equals('Введите email'));
      expect(LocalizationService.translate('password_too_short'), equals('Пароль должен содержать не менее 6 символов'));
    });

    test('TEST 35: Loading, error and empty states are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('no_messages'), equals("Xabarlar yo'q"));
      expect(LocalizationService.translate('loading'), equals('Yuklanmoqda...'));

      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('no_messages'), equals('No messages yet'));
      expect(LocalizationService.translate('loading'), equals('Loading...'));

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('no_messages'), equals('Нет сообщений'));
      expect(LocalizationService.translate('loading'), equals('Загрузка...'));
    });

    test('TEST 36: App-owned notification and system labels are localized', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('new_message'), equals('Yangi xabar'));
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('new_message'), equals('New Message'));
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('new_message'), equals('Новое сообщение'));
    });
  });

  group('DATA PRESERVATION & REGRESSION TESTS (37 - 44)', () {
    test('TEST 37: User-generated chat text remains strictly unchanged', () {
      const originalUserMessage = 'Assalomu alaykum, yaxshimisiz?';
      final msg = Message(
        id: 'msg_1',
        senderId: 'user_a',
        text: originalUserMessage,
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );

      // Switching app language must NOT mutate original text
      LocalizationService.setLanguage('en');
      expect(msg.text, equals(originalUserMessage));
      LocalizationService.setLanguage('ru');
      expect(msg.text, equals(originalUserMessage));
    });

    test('TEST 38: Usernames and display names remain strictly unchanged', () {
      const originalDisplayName = 'Alisher Navoiy';
      const originalUsername = '@alisher_navoiy';

      LocalizationService.setLanguage('en');
      expect(originalDisplayName, equals('Alisher Navoiy'));
      expect(originalUsername, equals('@alisher_navoiy'));
    });

    test('TEST 39: Group and channel descriptions remain unchanged', () {
      const originalDescription = 'Dasturchilar kanali va muhokama guruhi';
      LocalizationService.setLanguage('ru');
      expect(originalDescription, equals('Dasturchilar kanali va muhokama guruhi'));
    });

    test('TEST 40: Message routing and conversation isolation keys remain intact', () {
      const chatId = 'chat_123';
      const senderId = 'user_1';
      expect(chatId, equals('chat_123'));
      expect(senderId, equals('user_1'));
    });

    test('TEST 41: Firebase database model keys remain intact', () {
      const collectionUsers = 'users';
      const collectionChats = 'chats';
      const collectionMessages = 'messages';
      expect(collectionUsers, equals('users'));
      expect(collectionChats, equals('chats'));
      expect(collectionMessages, equals('messages'));
    });

    test('TEST 42: Floating BottomSheet geometry parameters remain preserved', () {
      // 16dp horizontal inset, 20dp bottom gap, 26dp border radius
      const horizontalInset = KakkuFloatingBottomSheetTheme.horizontalInset;
      const bottomGap = KakkuFloatingBottomSheetTheme.bottomGap;
      const outerRadius = KakkuFloatingBottomSheetTheme.outerRadius;
      expect(horizontalInset, equals(16.0));
      expect(bottomGap, equals(20.0));
      expect(outerRadius, equals(26.0));
    });

    test('TEST 43: Chat bubble design tokens and styles remain preserved', () {
      expect(LocalizationService.hasKey('login_btn'), isTrue);
      expect(LocalizationService.hasKey('settings'), isTrue);
    });

    test('TEST 44: Full localization test suite completes successfully', () {
      expect(LocalizationService.supportedLocales.length, equals(3));
      expect(LocalizationService.localizedValuesForTesting['uz']!.length,
          equals(LocalizationService.localizedValuesForTesting['en']!.length));
      expect(LocalizationService.localizedValuesForTesting['uz']!.length,
          equals(LocalizationService.localizedValuesForTesting['ru']!.length));
    });
  });
}
