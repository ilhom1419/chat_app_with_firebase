import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/chats/domain/entities/chat.dart';
import 'package:chat_app/features/chats/domain/entities/chat_folder.dart';
import 'package:chat_app/features/chats/domain/repositories/chat_repository.dart';
import 'package:chat_app/features/chats/presentation/pages/folders_management_page.dart';

class MockChatRepository implements ChatRepository {
  final List<ChatFolder> folders;
  MockChatRepository(this.folders);

  @override
  Stream<List<ChatFolder>> getUserFolders(String userId) {
    return Stream.value(folders);
  }

  @override
  Future<void> createFolder(String userId, ChatFolder folder) async {}

  @override
  Future<void> updateFolder(String userId, ChatFolder folder) async {}

  @override
  Future<void> deleteFolder(String userId, String folderId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('FoldersManagementPage has AlwaysScrollableScrollPhysics and scrolls smoothly in embedMode', (tester) async {
    final mockRepo = MockChatRepository([
      const ChatFolder(id: '1', name: 'Work', icon: '💼'),
      const ChatFolder(id: '2', name: 'Study', icon: '🎓'),
      const ChatFolder(id: '3', name: 'Personal', icon: '👤'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoldersManagementPage(
            currentUserId: 'test_user',
            chatRepository: mockRepo,
            allChats: const <Chat>[],
            embedMode: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);

    final listView = tester.widget<ListView>(listViewFinder);
    expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());

    // Test dragging / scrolling
    await tester.drag(listViewFinder, const Offset(0, -300));
    await tester.pumpAndSettle();

    // Verify it scrolled and can drag back
    await tester.drag(listViewFinder, const Offset(0, 300));
    await tester.pumpAndSettle();
  });

  testWidgets('FoldersManagementPage renders in standalone mode with AppBar and scrolls', (tester) async {
    final mockRepo = MockChatRepository([
      const ChatFolder(id: '1', name: 'Work', icon: '💼'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: FoldersManagementPage(
          currentUserId: 'test_user',
          chatRepository: mockRepo,
          allChats: const <Chat>[],
          embedMode: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);

    final listView = tester.widget<ListView>(listViewFinder);
    expect(listView.physics, isA<AlwaysScrollableScrollPhysics>());

    await tester.drag(listViewFinder, const Offset(0, -200));
    await tester.pumpAndSettle();
  });
}
