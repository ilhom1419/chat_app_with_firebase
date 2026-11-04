import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Channel Information Screen — Localization & Terminology Tests', () {
    test('1. Every visible label strictly obeys selected language without mixing', () {
      // 1.1 English (en)
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('channel_info'), equals('Channel Information'));
      expect(LocalizationService.plural('subscribers_count', 2), equals('2 subscribers'));
      expect(LocalizationService.translate('badge_public'), equals('Public'));
      expect(LocalizationService.translate('badge_private'), equals('Private'));
      expect(LocalizationService.translate('setup_action'), equals('Configure'));
      expect(LocalizationService.translate('you_suffix'), equals(' (You)'));
      expect(LocalizationService.translate('channel_owner'), equals('Channel Owner'));
      expect(LocalizationService.translate('mute_channel'), equals('Mute Channel'));
      expect(LocalizationService.translate('unmute_channel'), equals('Unmute Channel'));
      expect(LocalizationService.translate('share_channel'), equals('Share Channel'));
      expect(LocalizationService.translate('channel_description'), equals('Channel Description'));
      expect(LocalizationService.translate('edit_description'), equals('Edit Description'));
      expect(LocalizationService.translate('delete_channel_permanently'), equals('Delete Channel Permanently'));
      expect(LocalizationService.translate('discussion_group_title'), equals('Discussion Group'));
      expect(LocalizationService.translate('discussion_group_active'), equals('Active linked'));

      // 1.2 Russian (ru)
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('channel_info'), equals('Информация о канале'));
      expect(LocalizationService.plural('subscribers_count', 2), equals('2 подписчика'));
      expect(LocalizationService.plural('subscribers_count', 5), equals('5 подписчиков'));
      expect(LocalizationService.translate('badge_public'), equals('Публичный'));
      expect(LocalizationService.translate('badge_private'), equals('Частный'));
      expect(LocalizationService.translate('setup_action'), equals('Настроить'));
      expect(LocalizationService.translate('you_suffix'), equals(' (Вы)'));
      expect(LocalizationService.translate('channel_owner'), equals('Владелец канала'));
      expect(LocalizationService.translate('mute_channel'), equals('Отключить уведомления'));
      expect(LocalizationService.translate('unmute_channel'), equals('Включить уведомления'));
      expect(LocalizationService.translate('share_channel'), equals('Поделиться каналом'));
      expect(LocalizationService.translate('channel_description'), equals('Описание канала'));
      expect(LocalizationService.translate('edit_description'), equals('Изменить описание'));
      expect(LocalizationService.translate('delete_channel_permanently'), equals('Удалить канал навсегда'));
      expect(LocalizationService.translate('discussion_group_active'), equals('Активно связано'));

      // 1.3 Uzbek (uz)
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('channel_info'), equals("Kanal ma'lumotlari"));
      expect(LocalizationService.plural('subscribers_count', 2), equals('2 obunachi'));
      expect(LocalizationService.translate('badge_public'), equals('Ommaviy'));
      expect(LocalizationService.translate('badge_private'), equals('Xususiy'));
      expect(LocalizationService.translate('setup_action'), equals('Sozlash'));
      expect(LocalizationService.translate('you_suffix'), equals(' (Siz)'));
      expect(LocalizationService.translate('channel_owner'), equals('Kanal egasi'));
      expect(LocalizationService.translate('mute_channel'), equals('Kanal ovozini o‘chirish'));
      expect(LocalizationService.translate('share_channel'), equals('Kanalni ulashish'));
      expect(LocalizationService.translate('channel_description'), equals('Kanal tavsifi'));
      expect(LocalizationService.translate('edit_description'), equals('Tavsifni tahrirlash'));
      expect(LocalizationService.translate('delete_channel_permanently'), equals('Kanalni butunlay o‘chirish'));
      expect(LocalizationService.translate('discussion_group_active'), equals('Faol bog‘langan'));
    });

    test('2. Channel vs Group terminology distinctions', () {
      LocalizationService.setLanguage('en');
      // Channel specific terms must NOT contain "Group"
      expect(LocalizationService.translate('channel_owner'), equals('Channel Owner'));
      expect(LocalizationService.translate('channel_owner').contains('Group'), isFalse);
      expect(LocalizationService.translate('mute_channel'), equals('Mute Channel'));
      expect(LocalizationService.translate('mute_channel').contains('Group'), isFalse);
      expect(LocalizationService.translate('share_channel'), equals('Share Channel'));
      expect(LocalizationService.translate('share_channel').contains('Group'), isFalse);
      expect(LocalizationService.translate('channel_description'), equals('Channel Description'));
      expect(LocalizationService.translate('channel_description').contains('Group'), isFalse);

      // Group context retains Group terms
      expect(LocalizationService.translate('group_owner'), equals('Group Owner'));
      expect(LocalizationService.translate('mute_group'), equals('Mute Group'));
      expect(LocalizationService.translate('share_group'), equals('Share Group'));
      expect(LocalizationService.translate('group_description'), equals('Group Description'));
    });

    test('3. Dynamic named delete channel confirmation message preserves channel name', () {
      LocalizationService.setLanguage('en');
      final confirmMsgEn = LocalizationService.translate(
        'delete_channel_confirm_named',
        params: {'name': 'Namangan'},
      );
      expect(confirmMsgEn, contains('Namangan'));
      expect(confirmMsgEn, contains('channel'));

      LocalizationService.setLanguage('uz');
      final confirmMsgUz = LocalizationService.translate(
        'delete_channel_confirm_named',
        params: {'name': 'Namangan'},
      );
      expect(confirmMsgUz, contains('Namangan'));
      expect(confirmMsgUz, contains('kanalini'));
    });
  });

  group('Channel Information Screen — Horizontal Scrolling Widget Tests', () {
    testWidgets('Action buttons row scrolls smoothly horizontally and reveals the last action button', (tester) async {
      LocalizationService.setLanguage('en');
      bool lastActionTapped = false;

      // Build action row in a constrained screen size (360x640 - typical mobile device)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 86,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _testQuickActionButton(
                      icon: Icons.mic_rounded,
                      label: LocalizationService.translate('live_voice_chat'),
                      onTap: () {},
                    ),
                    _testQuickActionButton(
                      icon: Icons.notifications_off_outlined,
                      label: LocalizationService.translate('mute_channel'),
                      onTap: () {},
                    ),
                    _testQuickActionButton(
                      icon: Icons.share_rounded,
                      label: LocalizationService.translate('share_channel'),
                      onTap: () {},
                    ),
                    _testQuickActionButton(
                      icon: Icons.bar_chart_rounded,
                      label: LocalizationService.translate('stats_title'),
                      onTap: () {},
                    ),
                    _testQuickActionButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: LocalizationService.translate('add_participant'),
                      onTap: () {
                        lastActionTapped = true;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First action button is visible
      expect(find.text('Live Voice Chat'), findsOneWidget);
      expect(find.text('Mute Channel'), findsOneWidget);

      // Drag horizontally to the left by 300px to reveal the last action
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Find the last action button ('Add Member')
      final addMemberFinder = find.text('Add Member');
      expect(addMemberFinder, findsOneWidget);

      // Tap the last action
      await tester.tap(addMemberFinder);
      await tester.pumpAndSettle();

      expect(lastActionTapped, isTrue);
    });
  });

  group('Channel Information Screen — BUG 1 & BUG 2 Tests (+ Add & Discussion Group Buttons)', () {
    test('BUG 1: Add action translates strictly into EN, RU, UZ', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('add'), equals('Add'));

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('add'), equals('Добавить'));

      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('add'), equals('Qo‘shish'));
    });

    test('BUG 2: Discussion group buttons and members header translate strictly into EN, RU, UZ', () {
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('create_new_group'), equals('Create New Group'));
      expect(LocalizationService.translate('existing_group'), equals('Existing Group'));
      expect(LocalizationService.translate('members_and_administrators'), equals('Members and Administrators'));

      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('create_new_group'), equals('Создать новую группу'));
      expect(LocalizationService.translate('existing_group'), equals('Существующая группа'));
      expect(LocalizationService.translate('members_and_administrators'), equals('Участники и администраторы'));

      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('create_new_group'), equals('Yangi guruh yaratish'));
      expect(LocalizationService.translate('existing_group'), equals('Mavjud guruh'));
      expect(LocalizationService.translate('members_and_administrators'), equals('A\'zolar va Administratorlar'));
    });

    testWidgets('BUG 1 Widget Test: + Add button renders localized text and triggers tap without row overflow', (tester) async {
      bool addTapped = false;
      LocalizationService.setLanguage('ru');

      tester.view.physicalSize = const Size(320, 600); // narrow screen
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Widget buildHeader() {
        return MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: LocalizationService.langNotifier,
              builder: (context, _, __) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${LocalizationService.translate('members_and_administrators')} (2)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          LocalizationService.translate('add'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          addTapped = true;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHeader());
      await tester.pumpAndSettle();

      // Russian: verify "+ Добавить"
      expect(find.text('Добавить'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Tap action
      await tester.tap(find.text('Добавить'));
      expect(addTapped, isTrue);

      // Reactive switch to English
      LocalizationService.setLanguage('en');
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsOneWidget);

      // Reactive switch to Uzbek
      LocalizationService.setLanguage('uz');
      await tester.pumpAndSettle();
      expect(find.text('Qo‘shish'), findsOneWidget);
    });

    testWidgets('BUG 2 Widget Test: Discussion Group buttons layout responsively on regular, narrow, and high text scale', (tester) async {
      bool createTapped = false;
      bool existingTapped = false;
      LocalizationService.setLanguage('ru');

      Widget buildDiscussionButtons() {
        return MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 330 ||
                      MediaQuery.textScalerOf(context).scale(12) > 13.5;

                  final createBtn = ElevatedButton.icon(
                    onPressed: () {
                      createTapped = true;
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: Text(
                      LocalizationService.translate('create_new_group'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.2),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      alignment: Alignment.center,
                    ),
                  );

                  final existingBtn = OutlinedButton.icon(
                    onPressed: () {
                      existingTapped = true;
                    },
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: Text(
                      LocalizationService.translate('existing_group'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.2),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      alignment: Alignment.center,
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        createBtn,
                        const SizedBox(height: 8),
                        existingBtn,
                      ],
                    );
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: createBtn),
                        const SizedBox(width: 8),
                        Expanded(child: existingBtn),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }

      // Test regular 380px width
      tester.view.physicalSize = const Size(380, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildDiscussionButtons());
      await tester.pumpAndSettle();

      // Russian: both buttons are visible in Row without overflow
      expect(find.text('Создать новую группу'), findsOneWidget);
      expect(find.text('Существующая группа'), findsOneWidget);

      // Test tap
      await tester.tap(find.text('Создать новую группу'));
      expect(createTapped, isTrue);
      await tester.tap(find.text('Существующая группа'));
      expect(existingTapped, isTrue);

      // Test narrow screen (300px) -> falls back to Column without overflow
      tester.view.physicalSize = const Size(300, 700);
      await tester.pumpWidget(buildDiscussionButtons());
      await tester.pumpAndSettle();
      expect(find.text('Создать новую группу'), findsOneWidget);
      expect(find.text('Существующая группа'), findsOneWidget);

      // Test large text scale
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: buildDiscussionButtons(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Создать новую группу'), findsOneWidget);
      expect(find.text('Существующая группа'), findsOneWidget);
    });
  });
}

Widget _testQuickActionButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.blue, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
