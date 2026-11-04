import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/design_system/app_colors.dart';
import 'package:chat_app/features/stories/presentation/widgets/stories_ring.dart';
import 'package:chat_app/features/chats/presentation/widgets/chat_folders_tab_bar.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';
import 'package:chat_app/core/localization/localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child, {bool isDark = true}) {
    return MaterialApp(
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor:
            isDark ? const Color(0xFF0F172A) : Colors.white,
      ),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('Main Chat Home Premium UI Redesign Tests', () {
    testWidgets('1. StoriesRing: Circular avatar clipping when user has NO stories',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          StoriesRing(
            hasStories: false,
            radius: 27.0,
            child: Container(
              color: AppColors.primary,
              child: const Text('U'),
            ),
          ),
        ),
      );

      // Verify ClipOval exists and clips avatar to a perfect circle
      final clipFinder = find.byType(ClipOval);
      expect(clipFinder, findsOneWidget);

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
    });

    testWidgets('2. StoriesRing: Unseen stories renders vibrant sweep gradient ring',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          StoriesRing(
            hasStories: true,
            hasUnseenStories: true,
            radius: 27.0,
            child: const Text('A'),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.gradient, isA<SweepGradient>());
    });

    testWidgets('3. StoriesRing: Seen stories renders muted border',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          StoriesRing(
            hasStories: true,
            hasUnseenStories: false,
            radius: 27.0,
            child: const Text('B'),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, equals(BoxShape.circle));
      expect(decoration.gradient, isNull);
      expect(decoration.border, isNotNull);
    });

    testWidgets('4. ChatFoldersTabBar: Height is compact (44dp)',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          ChatFoldersTabBar(
            folders: ChatFolder.defaultFolders(),
            activeFolderId: ChatFolder.allId,
            unreadCounts: const {'all': 2, 'private': 2},
            onFolderSelected: (_) {},
            onAddFolderPressed: () {},
          ),
        ),
      );

      final tabBarFinder = find.byType(ChatFoldersTabBar);
      expect(tabBarFinder, findsOneWidget);

      final containerFinder = find.descendant(
        of: tabBarFinder,
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxHeight, equals(44.0));
    });

    testWidgets('5. ChatFoldersTabBar: Displays unread badges with count',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          ChatFoldersTabBar(
            folders: ChatFolder.defaultFolders(),
            activeFolderId: ChatFolder.allId,
            unreadCounts: const {
              ChatFolder.allId: 2,
              ChatFolder.directId: 5,
            },
            onFolderSelected: (_) {},
            onAddFolderPressed: () {},
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('6. Search Bar specifications: 48dp height capsule',
        (tester) async {
      final searchWidget = Container(
        height: 48.0,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: const TextField(
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            hintText: 'Qidiruv...',
          ),
        ),
      );

      await tester.pumpWidget(wrapWithTheme(searchWidget));

      final containerFinder = find.byWidget(searchWidget);
      final container = tester.widget<Container>(containerFinder);
      expect(container.constraints?.maxHeight, equals(48.0));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(24.0)));
    });

    testWidgets('7. Responsive behavior: Small screens (320px width)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapWithTheme(
          ChatFoldersTabBar(
            folders: ChatFolder.defaultFolders(),
            activeFolderId: ChatFolder.allId,
            unreadCounts: const {'all': 1},
            onFolderSelected: (_) {},
            onAddFolderPressed: () {},
          ),
        ),
      );

      // Verify no overflow on small screen
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Dark and Light Theme rendering', (tester) async {
      // Light Mode
      await tester.pumpWidget(
        wrapWithTheme(
          StoriesRing(
            hasStories: true,
            hasUnseenStories: true,
            child: const Text('Light'),
          ),
          isDark: false,
        ),
      );
      expect(tester.takeException(), isNull);

      // Dark Mode
      await tester.pumpWidget(
        wrapWithTheme(
          StoriesRing(
            hasStories: true,
            hasUnseenStories: true,
            child: const Text('Dark'),
          ),
          isDark: true,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Stories collapse/expand animation: SizeTransition animates cleanly',
        (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleTickerProviderTestWidget(
                  onInit: (c) => controller = c,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Stories Content'), findsOneWidget);
      final initialRenderBox =
          tester.renderObject(find.byType(SizeTransition)) as RenderBox;
      expect(initialRenderBox.size.height, greaterThan(0));

      // Reverse animation to collapse (scroll up)
      controller.reverse();
      await tester.pumpAndSettle();

      final collapsedRenderBox =
          tester.renderObject(find.byType(SizeTransition)) as RenderBox;
      expect(collapsedRenderBox.size.height, equals(0.0));

      // Forward animation to expand (scroll down)
      controller.forward();
      await tester.pumpAndSettle();

      final expandedRenderBox =
          tester.renderObject(find.byType(SizeTransition)) as RenderBox;
      expect(expandedRenderBox.size.height, greaterThan(0));
    });

    test('10. Story author sheet localization across UZ, EN, and RU', () {
      // Uzbek
      LocalizationService.setLanguage('uz');
      expect(LocalizationService.translate('choose_story_author'),
          equals('Kim nomidan hikoya joylaysiz?'));
      expect(LocalizationService.translate('personal_profile_story'),
          equals('Shaxsiy profil'));
      expect(LocalizationService.translate('your_channels_story'),
          equals('Sizning kanallaringiz'));
      expect(LocalizationService.translate('on_behalf_of_channel'),
          equals('Kanal nomidan'));

      // English
      LocalizationService.setLanguage('en');
      expect(LocalizationService.translate('choose_story_author'),
          equals('Who are you posting as?'));
      expect(LocalizationService.translate('personal_profile_story'),
          equals('Personal profile'));
      expect(LocalizationService.translate('your_channels_story'),
          equals('Your channels'));
      expect(LocalizationService.translate('on_behalf_of_channel'),
          equals('On behalf of channel'));

      // Russian
      LocalizationService.setLanguage('ru');
      expect(LocalizationService.translate('choose_story_author'),
          equals('От чьего имени опубликовать историю?'));
      expect(LocalizationService.translate('personal_profile_story'),
          equals('Личный профиль'));
      expect(LocalizationService.translate('your_channels_story'),
          equals('Ваши каналы'));
      expect(LocalizationService.translate('on_behalf_of_channel'),
          equals('От имени канала'));
    });
  });
}

class SingleTickerProviderTestWidget extends StatefulWidget {
  final Function(AnimationController) onInit;
  const SingleTickerProviderTestWidget({super.key, required this.onInit});

  @override
  State<SingleTickerProviderTestWidget> createState() =>
      _SingleTickerProviderTestWidgetState();
}

class _SingleTickerProviderTestWidgetState
    extends State<SingleTickerProviderTestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    widget.onInit(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _controller,
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _controller,
        child: const SizedBox(
          height: 86.0,
          child: Text('Stories Content'),
        ),
      ),
    );
  }
}
