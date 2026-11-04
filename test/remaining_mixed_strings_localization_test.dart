import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';

void main() {
  setUp(() {
    LocalizationService.setLanguage('en');
  });

  tearDown(() {
    LocalizationService.setLanguage('uz');
  });

  group('Remaining Mixed-Language UI Strings Verification Tests', () {
    test('TEST 01: English selected — comments heading displays "Comments"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('comments'), equals('Comments'));
    });

    test('TEST 02: English selected — 1 comment displays "1 comment"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.formatCommentsCount(1), equals('1 comment'));
      expect(LocalizationService.plural('comments_count', 1), equals('1 comment'));
    });

    test('TEST 03: English selected — 5 comments displays "5 comments"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.formatCommentsCount(5), equals('5 comments'));
      expect(LocalizationService.plural('comments_count', 5), equals('5 comments'));
      expect(LocalizationService.formatCommentsCount(2), equals('2 comments'));
    });

    test('TEST 04: Group/Channel Information shows "Link and Username"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('link_and_username'), equals('Link and Username'));
    });

    test('TEST 05: Voice Chat displays "Live Voice Chat"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('live_voice_chat'), equals('Live Voice Chat'));
    });

    test('TEST 06: Members section displays "Members and Administrators"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('members_and_administrators'), equals('Members and Administrators'));
    });

    test('TEST 07: Create New Folder displays "Work"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('recommended_work'), equals('Work'));
      const folder = ChatFolder(id: 'f1', name: 'Ish');
      expect(folder.localizedName, equals('Work'));
    });

    test('TEST 08: Create New Folder displays "Study"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('recommended_study'), equals('Study'));
      const folder = ChatFolder(id: 'f2', name: 'O\'qish');
      expect(folder.localizedName, equals('Study'));
    });

    test('TEST 09: Create New Folder displays "Friends"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('recommended_friends'), equals('Friends'));
      const folder = ChatFolder(id: 'f3', name: 'Do\'stlar');
      expect(folder.localizedName, equals('Friends'));
    });

    test('TEST 10: Create New Folder displays "Family"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('recommended_family'), equals('Family'));
      const folder = ChatFolder(id: 'f4', name: 'Oila');
      expect(folder.localizedName, equals('Family'));
    });

    test('TEST 11: Create New Folder displays "Important"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('recommended_important'), equals('Important'));
      const folder = ChatFolder(id: 'f5', name: 'Muhim');
      expect(folder.localizedName, equals('Important'));
    });

    test('TEST 12: Create New Folder displays "Projects"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('recommended_projects'), equals('Projects'));
      const folder = ChatFolder(id: 'f6', name: 'Loyihalar');
      expect(folder.localizedName, equals('Projects'));
    });

    test('TEST 13: Existing user-created folder names remain unchanged', () {
      LocalizationService.setLanguage('en');
      const userFolder1 = ChatFolder(id: 'custom_1', name: 'Mening Shaxsiy Papkam');
      expect(userFolder1.localizedName, equals('Mening Shaxsiy Papkam'));

      const userFolder2 = ChatFolder(id: 'custom_2', name: 'Crypto & Forex');
      expect(userFolder2.localizedName, equals('Crypto & Forex'));

      LocalizationService.setLanguage('ru');
      expect(userFolder1.localizedName, equals('Mening Shaxsiy Papkam'));
      expect(userFolder2.localizedName, equals('Crypto & Forex'));

      LocalizationService.setLanguage('uz');
      expect(userFolder1.localizedName, equals('Mening Shaxsiy Papkam'));
      expect(userFolder2.localizedName, equals('Crypto & Forex'));
    });

    test('TEST 14: Image/photo picker uses the correct English label', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('photo_label'), equals('Photo'));
      expect(LocalizationService.translate('text_label'), equals('Text'));
      expect(LocalizationService.translate('image_fallback'), equals('Image'));
      expect(LocalizationService.translate('photo_snippet'), equals('📷 Photo'));
    });

    test('TEST 15: Voice Chat connection/join action uses the correct contextual label', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('connect'), equals('Connect'));
      expect(LocalizationService.translate('join'), equals('Join'));
      expect(LocalizationService.translate('lower_hand'), equals('Lower Hand'));
      expect(LocalizationService.translate('raise_hand_btn'), equals('Raise Hand ✋'));
      expect(LocalizationService.translate('all_members_became_speakers'),
          equals('All members have become speakers'));
    });

    test('TEST 16: Channel action displays "Join Channel"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('join_channel'), equals('Join Channel'));
    });

    test('TEST 17: Group action displays "Join Group"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('join_group'), equals('Join Group'));
    });

    test('TEST 18: Channel-related UI displays "Channel"', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('channel_badge'), equals('Channel'));
      expect(LocalizationService.translate('channel_fallback'), equals('Channel'));
      expect(LocalizationService.translate('group_badge'), equals('Group'));
      expect(LocalizationService.translate('group_fallback'), equals('Group'));
      expect(
          LocalizationService.translate('public_channel_with_count',
              params: {'count': '150'}),
          equals('Public Channel (150)'));
      expect(
          LocalizationService.translate('public_group_with_count',
              params: {'count': '42'}),
          equals('Public Group (42)'));
    });

    test('TEST 19: All corrected labels return to Uzbek after language switching', () {
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('comments'), equals('Izohlar'));
      expect(LocalizationService.formatCommentsCount(1), equals('1 ta izoh'));
      expect(LocalizationService.formatCommentsCount(5), equals('5 ta izoh'));
      expect(LocalizationService.translate('link_and_username'), equals('Havola va Username'));
      expect(LocalizationService.translate('live_voice_chat'), equals('Ovozli efir'));
      expect(LocalizationService.translate('members_and_administrators'), equals('A\'zolar va Administratorlar'));
      expect(LocalizationService.translate('recommended_work'), equals('Ish'));
      expect(LocalizationService.translate('recommended_study'), equals('O\'qish'));
      expect(LocalizationService.translate('recommended_friends'), equals('Do\'stlar'));
      expect(LocalizationService.translate('recommended_family'), equals('Oila'));
      expect(LocalizationService.translate('recommended_important'), equals('Muhim'));
      expect(LocalizationService.translate('recommended_projects'), equals('Loyihalar'));
      expect(LocalizationService.translate('photo_label'), equals('Rasm'));
      expect(LocalizationService.translate('join_channel'), equals('Kanalga qo\'shilish'));
      expect(LocalizationService.translate('join_group'), equals('Guruhga qo\'shilish'));
      expect(LocalizationService.translate('channel_badge'), equals('Kanal'));
    });

    test('TEST 20: All corrected labels translate correctly into Russian', () {
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('comments'), equals('Комментарии'));
      expect(LocalizationService.formatCommentsCount(1), equals('1 комментарий'));
      expect(LocalizationService.formatCommentsCount(3), equals('3 комментария'));
      expect(LocalizationService.formatCommentsCount(5), equals('5 комментариев'));
      expect(LocalizationService.translate('link_and_username'), equals('Ссылка и имя пользователя'));
      expect(LocalizationService.translate('live_voice_chat'), equals('Голосовой эфир'));
      expect(LocalizationService.translate('members_and_administrators'), equals('Участники и администраторы'));
      expect(LocalizationService.translate('recommended_work'), equals('Работа'));
      expect(LocalizationService.translate('recommended_study'), equals('Учёба'));
      expect(LocalizationService.translate('recommended_friends'), equals('Друзья'));
      expect(LocalizationService.translate('recommended_family'), equals('Семья'));
      expect(LocalizationService.translate('recommended_important'), equals('Важное'));
      expect(LocalizationService.translate('recommended_projects'), equals('Проекты'));
      expect(LocalizationService.translate('photo_label'), equals('Фото'));
      expect(LocalizationService.translate('join_channel'), equals('Присоединиться к каналу'));
      expect(LocalizationService.translate('join_group'), equals('Присоединиться к группе'));
      expect(LocalizationService.translate('channel_badge'), equals('Канал'));
    });

    testWidgets('TEST 21 & 22: Widget rendering with ValueListenableBuilder reflects live locale changes',
        (tester) async {
      LocalizationService.setLanguage('en');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, lang, _) {
                return Column(
                  children: [
                    Text(LocalizationService.translate('comments'),
                        key: const Key('comments_heading')),
                    Text(LocalizationService.formatCommentsCount(5),
                        key: const Key('comments_count')),
                    Text(LocalizationService.translate('live_voice_chat'),
                        key: const Key('voice_chat_label')),
                    Text(LocalizationService.translate('join_channel'),
                        key: const Key('join_channel_btn')),
                    Text(LocalizationService.translate('recommended_work'),
                        key: const Key('preset_work')),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify English
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('5 comments'), findsOneWidget);
      expect(find.text('Live Voice Chat'), findsOneWidget);
      expect(find.text('Join Channel'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);

      // Switch to Russian dynamically
      LocalizationService.setLanguage('ru');
      await tester.pumpAndSettle();

      expect(find.text('Комментарии'), findsOneWidget);
      expect(find.text('5 комментариев'), findsOneWidget);
      expect(find.text('Голосовой эфир'), findsOneWidget);
      expect(find.text('Присоединиться к каналу'), findsOneWidget);
      expect(find.text('Работа'), findsOneWidget);

      // Switch back to Uzbek dynamically
      LocalizationService.setLanguage('uz');
      await tester.pumpAndSettle();

      expect(find.text('Izohlar'), findsOneWidget);
      expect(find.text('5 ta izoh'), findsOneWidget);
      expect(find.text('Ovozli efir'), findsOneWidget);
      expect(find.text('Kanalga qo\'shilish'), findsOneWidget);
      expect(find.text('Ish'), findsOneWidget);
    });
  });
}
