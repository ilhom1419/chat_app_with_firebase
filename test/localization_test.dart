import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';
import 'package:chat_app/features/chats/domain/entities/chat_member.dart';

void main() {
  setUp(() {
    LocalizationService.langNotifier.value = 'uz';
  });

  group('Localization Architecture & Supported Locales', () {
    test('Supported locales include uz, en, ru', () {
      final localeCodes =
          LocalizationService.supportedLocales.map((l) => l.languageCode).toList();
      expect(localeCodes, containsAll(['uz', 'en', 'ru']));
      expect(localeCodes.length, equals(3));
    });

    test('Current locale reflects langNotifier value', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(LocalizationService.currentLocale, equals(const Locale('uz')));

      LocalizationService.langNotifier.value = 'en';
      expect(LocalizationService.currentLocale, equals(const Locale('en')));

      LocalizationService.langNotifier.value = 'ru';
      expect(LocalizationService.currentLocale, equals(const Locale('ru')));
    });

    test('Dictionary key parity across uz, en, and ru', () {
      final values = LocalizationService.localizedValuesForTesting;
      final uzKeys = values['uz']!.keys.toSet();
      final enKeys = values['en']!.keys.toSet();
      final ruKeys = values['ru']!.keys.toSet();

      final missingInEn = uzKeys.difference(enKeys);
      final missingInRu = uzKeys.difference(ruKeys);
      final extraInEn = enKeys.difference(uzKeys);
      final extraInRu = ruKeys.difference(uzKeys);

      expect(missingInEn, isEmpty,
          reason: 'Keys present in uz but missing in en: $missingInEn');
      expect(missingInRu, isEmpty,
          reason: 'Keys present in uz but missing in ru: $missingInRu');
      expect(extraInEn, isEmpty,
          reason: 'Keys present in en but missing in uz: $extraInEn');
      expect(extraInRu, isEmpty,
          reason: 'Keys present in ru but missing in uz: $extraInRu');

      // Ensure no empty strings
      for (final lang in ['uz', 'en', 'ru']) {
        for (final entry in values[lang]!.entries) {
          expect(entry.value.trim().isNotEmpty, isTrue,
              reason: 'Empty translation for key "${entry.key}" in $lang');
        }
      }
    });
  });

  group('String Interpolation & Translation', () {
    test('Basic string translations without parameters', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(LocalizationService.translate('login_btn'), equals('Kirish'));
      expect(LocalizationService.translate('chats_title'), equals('Chatlar'));
      expect(LocalizationService.translate('dark_mode'), equals("Qorong'u rejim"));
      expect(LocalizationService.translate('go_to_channel'), equals("Kanalga o'tish"));
      expect(LocalizationService.translate('go_to_group'), equals("Guruhga o'tish"));
      expect(LocalizationService.translate('go_to_chat'), equals("Chatga o'tish"));
      expect(LocalizationService.translate('voice_chat_approve_speaker'), equals("Mikrofonga ruxsat berish"));
      expect(LocalizationService.translate('voice_chat_reject_speaker'), equals("Rad etish"));

      LocalizationService.langNotifier.value = 'en';
      expect(LocalizationService.translate('login_btn'), equals('Log In'));
      expect(LocalizationService.translate('chats_title'), equals('Chats'));
      expect(LocalizationService.translate('dark_mode'), equals('Dark Mode'));
      expect(LocalizationService.translate('go_to_channel'), equals('Go to Channel'));
      expect(LocalizationService.translate('go_to_group'), equals('Go to Group'));
      expect(LocalizationService.translate('go_to_chat'), equals('Open Chat'));
      expect(LocalizationService.translate('voice_chat_approve_speaker'), equals("Approve speaker request"));
      expect(LocalizationService.translate('voice_chat_reject_speaker'), equals("Reject speaker request"));

      LocalizationService.langNotifier.value = 'ru';
      expect(LocalizationService.translate('login_btn'), equals('Войти'));
      expect(LocalizationService.translate('chats_title'), equals('Чаты'));
      expect(LocalizationService.translate('dark_mode'), equals('Тёмная тема'));
      expect(LocalizationService.translate('go_to_channel'), equals('Перейти в канал'));
      expect(LocalizationService.translate('go_to_group'), equals('Перейти в группу'));
      expect(LocalizationService.translate('go_to_chat'), equals('Перейти в чат'));
      expect(LocalizationService.translate('voice_chat_approve_speaker'), equals("Разрешить говорить"));
      expect(LocalizationService.translate('voice_chat_reject_speaker'), equals("Отклонить запрос"));
    });

    test('Parameter replacement in translations', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(
        LocalizationService.translate('folder_created_success',
            params: {'name': 'Ish'}),
        equals('"Ish" papkasi muvaffaqiyatli yaratildi!'),
      );

      LocalizationService.langNotifier.value = 'en';
      expect(
        LocalizationService.translate('folder_created_success',
            params: {'name': 'Work'}),
        equals('Folder "Work" created successfully!'),
      );

      LocalizationService.langNotifier.value = 'ru';
      expect(
        LocalizationService.translate('folder_created_success',
            params: {'name': 'Работа'}),
        equals('Папка "Работа" успешно создана!'),
      );
    });

    test('Graceful fallback for unknown translation keys', () {
      expect(LocalizationService.translate('non_existent_key_xyz'),
          equals('non_existent_key_xyz'));
    });
  });

  group('ICU Pluralization Rules', () {
    test('Russian pluralization rules (1, 2-4, 5+)', () {
      LocalizationService.langNotifier.value = 'ru';

      // 1 -> one
      expect(LocalizationService.plural('members_count', 1), equals('1 участник'));
      expect(LocalizationService.plural('subscribers_count', 1),
          equals('1 подписчик'));
      expect(LocalizationService.plural('chats_count', 1), equals('1 чат'));

      // 2, 3, 4 -> few
      expect(LocalizationService.plural('members_count', 2), equals('2 участника'));
      expect(LocalizationService.plural('members_count', 4), equals('4 участника'));
      expect(LocalizationService.plural('subscribers_count', 3),
          equals('3 подписчика'));
      expect(LocalizationService.plural('chats_count', 2), equals('2 чата'));

      // 5..20 -> many
      expect(LocalizationService.plural('members_count', 5), equals('5 участников'));
      expect(LocalizationService.plural('members_count', 11),
          equals('11 участников'));
      expect(LocalizationService.plural('subscribers_count', 20),
          equals('20 подписчиков'));
      expect(LocalizationService.plural('chats_count', 5), equals('5 чатов'));

      // 21 -> one
      expect(LocalizationService.plural('members_count', 21),
          equals('21 участник'));

      // 24 -> few
      expect(LocalizationService.plural('members_count', 24),
          equals('24 участника'));

      // 25 -> many
      expect(LocalizationService.plural('members_count', 25),
          equals('25 участников'));
    });

    test('English pluralization rules (1 vs other)', () {
      LocalizationService.langNotifier.value = 'en';

      expect(LocalizationService.plural('members_count', 1), equals('1 member'));
      expect(LocalizationService.plural('members_count', 2), equals('2 members'));
      expect(LocalizationService.plural('members_count', 10), equals('10 members'));

      expect(LocalizationService.plural('subscribers_count', 1),
          equals('1 subscriber'));
      expect(LocalizationService.plural('subscribers_count', 5),
          equals('5 subscribers'));

      expect(LocalizationService.plural('chats_count', 1), equals('1 chat'));
      expect(LocalizationService.plural('chats_count', 3), equals('3 chats'));
    });

    test('Uzbek pluralization rules', () {
      LocalizationService.langNotifier.value = 'uz';

      expect(LocalizationService.plural('members_count', 1), equals("1 a'zo"));
      expect(LocalizationService.plural('members_count', 5), equals("5 a'zo"));

      expect(LocalizationService.plural('subscribers_count', 1),
          equals('1 obunachi'));
      expect(LocalizationService.plural('subscribers_count', 10),
          equals('10 obunachi'));

      expect(LocalizationService.plural('chats_count', 1), equals('1 ta chat'));
      expect(LocalizationService.plural('chats_count', 4), equals('4 ta chat'));
    });
  });

  group('Entity Dynamic Localization', () {
    test('Default ChatFolder localizedName responds to locale changes', () {
      const allFolder = ChatFolder(id: ChatFolder.allId, name: 'Barchasi');
      const directFolder = ChatFolder(id: ChatFolder.directId, name: 'Shaxsiy');
      const groupsFolder = ChatFolder(id: ChatFolder.groupsId, name: 'Guruhlar');
      const channelsFolder =
          ChatFolder(id: ChatFolder.channelsId, name: 'Kanallar');
      const unreadFolder =
          ChatFolder(id: ChatFolder.unreadId, name: 'O‘qilmaganlar');
      const customFolder = ChatFolder(id: 'custom_123', name: 'Mening papkam');

      // Uzbek
      LocalizationService.langNotifier.value = 'uz';
      expect(allFolder.localizedName, equals('Barchasi'));
      expect(directFolder.localizedName, equals('Shaxsiy'));
      expect(groupsFolder.localizedName, equals('Guruhlar'));
      expect(channelsFolder.localizedName, equals('Kanallar'));
      expect(unreadFolder.localizedName, equals('O‘qilmaganlar'));
      expect(customFolder.localizedName, equals('Mening papkam'));

      // English
      LocalizationService.langNotifier.value = 'en';
      expect(allFolder.localizedName, equals('All'));
      expect(directFolder.localizedName, equals('Private'));
      expect(groupsFolder.localizedName, equals('Groups'));
      expect(channelsFolder.localizedName, equals('Channels'));
      expect(unreadFolder.localizedName, equals('Unread'));
      expect(customFolder.localizedName, equals('Mening papkam')); // Preserved custom name!

      // Russian
      LocalizationService.langNotifier.value = 'ru';
      expect(allFolder.localizedName, equals('Все'));
      expect(directFolder.localizedName, equals('Личные'));
      expect(groupsFolder.localizedName, equals('Группы'));
      expect(channelsFolder.localizedName, equals('Каналы'));
      expect(unreadFolder.localizedName, equals('Непрочитанные'));
      expect(customFolder.localizedName, equals('Mening papkam'));
    });

    test('MemberRole localizedName responds to locale changes', () {
      LocalizationService.langNotifier.value = 'uz';
      expect(MemberRole.owner.localizedName, equals('Asoschi'));
      expect(MemberRole.admin.localizedName, equals('Administrator'));
      expect(MemberRole.member.localizedName, equals("A'zo"));

      LocalizationService.langNotifier.value = 'en';
      expect(MemberRole.owner.localizedName, equals('Owner'));
      expect(MemberRole.admin.localizedName, equals('Administrator'));
      expect(MemberRole.member.localizedName, equals('Member'));

      LocalizationService.langNotifier.value = 'ru';
      expect(MemberRole.owner.localizedName, equals('Владелец'));
      expect(MemberRole.admin.localizedName, equals('Администратор'));
      expect(MemberRole.member.localizedName, equals('Участник'));
    });
  });

  group('Reactive UI Language Switching Widget Tests', () {
    testWidgets('UI elements update immediately on language switch without restart',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Column(
                  children: [
                    Text(LocalizationService.translate('chats_title')),
                    Text(LocalizationService.translate('folder_all')),
                    Text(LocalizationService.translate('folder_groups')),
                    Text(LocalizationService.translate('folder_channels')),
                    Text(LocalizationService.translate('my_story')),
                    Text(LocalizationService.translate('settings_title')),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initial state: Uzbek
      expect(find.text('Chatlar'), findsOneWidget);
      expect(find.text('Barchasi'), findsOneWidget);
      expect(find.text('Guruhlar'), findsOneWidget);
      expect(find.text('Kanallar'), findsOneWidget);
      expect(find.text('Tarixim'), findsOneWidget);
      expect(find.text('Sozlamalar'), findsOneWidget);

      // Switch to English
      LocalizationService.langNotifier.value = 'en';
      await tester.pumpAndSettle();

      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('My Story'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Switch to Russian
      LocalizationService.langNotifier.value = 'ru';
      await tester.pumpAndSettle();

      expect(find.text('Чаты'), findsOneWidget);
      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Группы'), findsOneWidget);
      expect(find.text('Каналы'), findsOneWidget);
      expect(find.text('Моя история'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);

      // Switch back to Uzbek
      LocalizationService.langNotifier.value = 'uz';
      await tester.pumpAndSettle();

      expect(find.text('Chatlar'), findsOneWidget);
      expect(find.text('Barchasi'), findsOneWidget);
      expect(find.text('Guruhlar'), findsOneWidget);
      expect(find.text('Kanallar'), findsOneWidget);
      expect(find.text('Tarixim'), findsOneWidget);
      expect(find.text('Sozlamalar'), findsOneWidget);
    });
  });
}
