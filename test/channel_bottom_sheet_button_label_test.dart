import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/chats/presentation/widgets/join_preview_sheet.dart';

// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalizationService.langNotifier.value = 'uz';
  });

  group('Channel BottomSheet Button Label Tests', () {
    testWidgets('Channel BottomSheet displays "Kanalga o\'tish" in Uzbek when already subscribed', (tester) async {
      LocalizationService.langNotifier.value = 'uz';
      const userId = 'user_123';
      final channelDoc = FakeDocumentSnapshot('channel_1', {
        'groupName': 'Yangiliklar Kanali',
        'isChannel': true,
        'isGroup': false,
        'participants': [userId, 'other_user'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: channelDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Kanalga o'tish"), findsOneWidget);
      expect(find.text("Chatga o'tish"), findsNothing);
    });

    testWidgets('Channel BottomSheet displays "Go to Channel" in English when already subscribed', (tester) async {
      LocalizationService.langNotifier.value = 'en';
      const userId = 'user_123';
      final channelDoc = FakeDocumentSnapshot('channel_1', {
        'groupName': 'News Channel',
        'isChannel': true,
        'isGroup': false,
        'participants': [userId],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: channelDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Go to Channel'), findsOneWidget);
    });

    testWidgets('Channel BottomSheet displays "Перейти в канал" in Russian when already subscribed', (tester) async {
      LocalizationService.langNotifier.value = 'ru';
      const userId = 'user_123';
      final channelDoc = FakeDocumentSnapshot('channel_1', {
        'groupName': 'Канал Новостей',
        'isChannel': true,
        'isGroup': false,
        'participants': [userId],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: channelDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Перейти в канал'), findsOneWidget);
    });

    testWidgets('Group BottomSheet displays "Guruhga o\'tish" in Uzbek when already joined', (tester) async {
      LocalizationService.langNotifier.value = 'uz';
      const userId = 'user_123';
      final groupDoc = FakeDocumentSnapshot('group_1', {
        'groupName': 'Dasturchilar Guruhi',
        'isChannel': false,
        'isGroup': true,
        'participants': [userId, 'other_user'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: groupDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Guruhga o'tish"), findsOneWidget);
      expect(find.text("Kanalga o'tish"), findsNothing);
      expect(find.text("Chatga o'tish"), findsNothing);
    });

    testWidgets('Group BottomSheet displays "Go to Group" in English when already joined', (tester) async {
      LocalizationService.langNotifier.value = 'en';
      const userId = 'user_123';
      final groupDoc = FakeDocumentSnapshot('group_1', {
        'groupName': 'Developers Group',
        'isChannel': false,
        'isGroup': true,
        'participants': [userId],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: groupDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Go to Group'), findsOneWidget);
    });

    testWidgets('Group BottomSheet displays "Перейти в группу" in Russian when already joined', (tester) async {
      LocalizationService.langNotifier.value = 'ru';
      const userId = 'user_123';
      final groupDoc = FakeDocumentSnapshot('group_1', {
        'groupName': 'Группа Разработчиков',
        'isChannel': false,
        'isGroup': true,
        'participants': [userId],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: groupDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Перейти в группу'), findsOneWidget);
    });

    testWidgets('Private Chat preserves "Chatga o\'tish" in Uzbek when already member', (tester) async {
      LocalizationService.langNotifier.value = 'uz';
      const userId = 'user_123';
      final privateChatDoc = FakeDocumentSnapshot('direct_1', {
        'type': 'direct',
        'isChannel': false,
        'isGroup': false,
        'participants': [userId, 'other_user'],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TelegramJoinPreviewSheet(
              chatDoc: privateChatDoc,
              currentUserId: userId,
              currentUserName: 'Test User',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Chatga o'tish"), findsOneWidget);
      expect(find.text("Kanalga o'tish"), findsNothing);
    });
  });
}
