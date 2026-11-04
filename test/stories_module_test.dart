import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/stories/domain/entities/story.dart';
import 'package:chat_app/features/stories/presentation/widgets/stories_ring.dart';
import 'package:chat_app/features/stories/presentation/widgets/stories_tray.dart';
import 'package:chat_app/features/stories/presentation/pages/story_viewer_page.dart';

void main() {
  group('Story Entity Tests', () {
    test('Story expiration and viewing logic works correctly', () {
      final now = DateTime.now();
      final story = Story(
        id: 'story_1',
        authorId: 'user_1',
        authorName: 'Ali Valiyev',
        createdAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.add(const Duration(hours: 23)),
        viewersData: {
          'user_2': {
            'userName': 'Olim',
            'viewedAt': now.toIso8601String(),
            'reaction': '🔥',
          }
        },
        reactions: const {'user_2': '🔥'},
      );

      expect(story.isExpired, isFalse);
      expect(story.viewsCount, equals(1));
      expect(story.isViewedBy('user_2'), isTrue);
      expect(story.isViewedBy('user_3'), isFalse);
      expect(story.viewersList.length, equals(1));
      expect(story.viewersList.first.reaction, equals('🔥'));
    });

    test('Expired story correctly identifies isExpired as true', () {
      final now = DateTime.now();
      final expiredStory = Story(
        id: 'story_old',
        authorId: 'user_1',
        authorName: 'Ali Valiyev',
        createdAt: now.subtract(const Duration(hours: 26)),
        expiresAt: now.subtract(const Duration(hours: 2)),
      );

      expect(expiredStory.isExpired, isTrue);
    });
  });

  group('StoriesRing Widget Tests', () {
    testWidgets('StoriesRing renders properly with unseen gradient',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StoriesRing(
                hasStories: true,
                hasUnseenStories: true,
                radius: 28,
                child: CircleAvatar(child: Text('A')),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StoriesRing), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('StoriesRing renders properly without stories', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StoriesRing(
                hasStories: false,
                hasUnseenStories: false,
                radius: 28,
                child: Text('Add'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('StoriesTray Route Tests', () {
    test('createStoryViewerRoute produces non-opaque fullscreen route with black barrier', () {
      final now = DateTime.now();
      final story = Story(
        id: 's1',
        authorId: 'u1',
        authorName: 'Tester',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      final route = StoriesTray.createStoryViewerRoute(
        stories: [story],
        currentUserId: 'me',
        currentUserName: 'My Name',
      ) as PageRouteBuilder;

      expect(route.opaque, isFalse);
      expect(route.barrierColor, equals(Colors.black));
      expect(route.transitionDuration, const Duration(milliseconds: 280));
    });
  });

  group('StoryViewerPage Widget Tests', () {
    testWidgets('StoryViewerPage renders fullscreen layout elements correctly',
        (tester) async {
      final now = DateTime.now();
      final story = Story(
        id: 'story_gradient',
        authorId: 'user_author',
        authorName: 'Sardor',
        textContent: 'Salom, do\'stlar! Bu matnli hikoya.',
        gradientIndex: 1,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StoryViewerPage(
            stories: [story],
            currentUserId: 'viewer_user',
            currentUserName: 'Viewer Name',
          ),
        ),
      );

      // Verify header author name
      expect(find.text('Sardor'), findsOneWidget);

      // Verify text story content
      expect(find.text('Salom, do\'stlar! Bu matnli hikoya.'), findsOneWidget);

      // Verify close button exists
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify reaction emojis row exists for other user's story
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('😂'), findsOneWidget);

      // Verify reply input exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Xabar yozing...'), findsOneWidget);
    });
  });
}
