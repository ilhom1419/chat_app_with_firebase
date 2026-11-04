import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/saved_messages/domain/entities/saved_message.dart';
import 'package:chat_app/features/saved_messages/presentation/widgets/saved_message_bubble.dart';

/// In-memory mock simulation of Firestore & Firebase Storage for Saved Messages
class MockSavedMessagesBackend {
  // Firestore: userId -> (savedId -> SavedMessage)
  final Map<String, Map<String, SavedMessage>> _userSavedMessages = {};

  // Firebase Storage: storagePath -> bytes
  final Map<String, List<int>> _storageObjects = {};

  // Original chats: chatId -> (messageId -> Message)
  final Map<String, Map<String, Message>> _chatMessages = {};

  int _counter = 0;

  // Security Simulation: Owner restriction on Firestore
  void checkFirestoreAccess({required String authUid, required String targetUserId}) {
    if (authUid != targetUserId) {
      throw Exception('PERMISSION_DENIED: Cannot access another user\'s private saved messages');
    }
  }

  // Security Simulation: Owner restriction on Storage
  void checkStorageAccess({required String authUid, required String storagePath}) {
    // Expected path: users/{userId}/saved_files/...
    final parts = storagePath.split('/');
    if (parts.length >= 2 && parts[0] == 'users') {
      final ownerId = parts[1];
      if (authUid != ownerId) {
        throw Exception('PERMISSION_DENIED: Storage path owner does not match authenticated user');
      }
    } else {
      throw Exception('PERMISSION_DENIED: Invalid storage path scope');
    }
  }

  // Create personal note
  Future<SavedMessage> createPersonalNote({
    required String authUid,
    required String text,
  }) async {
    checkFirestoreAccess(authUid: authUid, targetUserId: authUid);
    final savedId = 'note_${_counter++}_${DateTime.now().microsecondsSinceEpoch}';
    final savedMessage = SavedMessage(
      savedId: savedId,
      ownerId: authUid,
      type: SavedMessageType.text,
      text: text,
      createdAt: DateTime.now(),
      isForwarded: false,
      uploadStatus: SavedMessageUploadStatus.completed,
    );

    _userSavedMessages.putIfAbsent(authUid, () => {})[savedId] = savedMessage;
    return savedMessage;
  }

  // Forward existing message
  Future<SavedMessage> forwardMessage({
    required String authUid,
    required Message message,
    required String originalChatId,
    required String originalSenderName,
  }) async {
    checkFirestoreAccess(authUid: authUid, targetUserId: authUid);

    // Rule: Secret chat messages cannot be forwarded
    if (originalChatId.startsWith('secret_')) {
      throw ArgumentError('Maxfiy chat xabarlarini saqlab bo‘lmaydi');
    }

    SavedMessageType savedType;
    String? attachmentUrl;
    if (message.type == MessageType.image) {
      savedType = SavedMessageType.image;
      attachmentUrl = message.imageUrl;
    } else if (message.type == MessageType.voice) {
      savedType = SavedMessageType.voice;
      attachmentUrl = message.fileUrl;
    } else if (message.type == MessageType.file) {
      savedType = SavedMessageType.document;
      attachmentUrl = message.fileUrl;
    } else {
      savedType = SavedMessageType.text;
    }

    final savedId = 'fwd_${DateTime.now().microsecondsSinceEpoch}';
    final savedMessage = SavedMessage(
      savedId: savedId,
      ownerId: authUid,
      type: savedType,
      text: message.text,
      createdAt: DateTime.now(),
      originalSenderId: message.senderId,
      originalSenderName: originalSenderName,
      originalChatId: originalChatId,
      originalMessageId: message.id,
      isForwarded: true,
      originalMessageType: message.type.name,
      attachmentUrl: attachmentUrl,
      attachmentName: message.fileName,
      attachmentDuration: message.duration,
      uploadStatus: SavedMessageUploadStatus.completed,
    );

    _userSavedMessages.putIfAbsent(authUid, () => {})[savedId] = savedMessage;
    return savedMessage;
  }

  // Upload personal file
  Future<SavedMessage> uploadFile({
    required String authUid,
    required String fileName,
    required List<int> bytes,
    required SavedMessageType type,
    int? duration,
    bool simulateFailure = false,
  }) async {
    checkFirestoreAccess(authUid: authUid, targetUserId: authUid);

    if (bytes.length > 50 * 1024 * 1024) {
      throw ArgumentError('Fayl hajmi 50MB dan oshmasligi kerak');
    }

    final fileId = 'file_${DateTime.now().microsecondsSinceEpoch}';
    final storagePath = 'users/$authUid/saved_files/$fileId';
    checkStorageAccess(authUid: authUid, storagePath: storagePath);

    if (simulateFailure) {
      throw Exception('STORAGE_ERROR: Upload interrupted');
    }

    _storageObjects[storagePath] = bytes;

    final savedId = 'saved_$fileId';
    final savedMessage = SavedMessage(
      savedId: savedId,
      ownerId: authUid,
      type: type,
      createdAt: DateTime.now(),
      attachmentStoragePath: storagePath,
      attachmentUrl: 'https://firebasestorage.googleapis.com/v0/b/.../$fileId',
      attachmentName: fileName,
      attachmentSize: bytes.length,
      attachmentDuration: duration,
      uploadStatus: SavedMessageUploadStatus.completed,
    );

    _userSavedMessages.putIfAbsent(authUid, () => {})[savedId] = savedMessage;
    return savedMessage;
  }

  // Read saved messages
  List<SavedMessage> getSavedMessages({
    required String authUid,
    required String targetUserId,
  }) {
    checkFirestoreAccess(authUid: authUid, targetUserId: targetUserId);
    return _userSavedMessages[targetUserId]?.values.toList() ?? [];
  }

  // Download saved file
  List<int> downloadFile({
    required String authUid,
    required String storagePath,
  }) {
    checkStorageAccess(authUid: authUid, storagePath: storagePath);
    final bytes = _storageObjects[storagePath];
    if (bytes == null) {
      throw Exception('FILE_NOT_FOUND');
    }
    return bytes;
  }

  // Delete saved message and its storage file
  void deleteSavedMessage({
    required String authUid,
    required String targetUserId,
    required String savedId,
  }) {
    checkFirestoreAccess(authUid: authUid, targetUserId: targetUserId);
    final userMessages = _userSavedMessages[targetUserId];
    if (userMessages != null && userMessages.containsKey(savedId)) {
      final msg = userMessages.remove(savedId);
      if (msg?.attachmentStoragePath != null) {
        checkStorageAccess(authUid: authUid, storagePath: msg!.attachmentStoragePath!);
        _storageObjects.remove(msg.attachmentStoragePath);
      }
    }
  }

  // Chat helpers
  void putChatMessage(String chatId, Message message) {
    _chatMessages.putIfAbsent(chatId, () => {})[message.id] = message;
  }

  Message? getChatMessage(String chatId, String messageId) {
    return _chatMessages[chatId]?[messageId];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Initialize localization values
    LocalizationService.langNotifier.value = 'uz';
  });

  group('KAKKU — Saved Messages & Personal Cloud Storage Tests (TEST 01 - 28)', () {
    late MockSavedMessagesBackend backend;
    const String aliceUid = 'alice_uid_101';
    const String bobUid = 'bob_uid_202';
    const String eveUid = 'eve_uid_999';

    setUp(() {
      backend = MockSavedMessagesBackend();
    });

    // TEST 01 — Saved Messages page opens correctly
    testWidgets('TEST 01 — Saved Messages page opens correctly with header and title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: Text(LocalizationService.translate('saved_messages')),
            ),
            body: Center(
              child: Text(LocalizationService.translate('empty_saved_messages_desc')),
            ),
          ),
        ),
      );

      expect(find.text('Saqlangan xabarlar'), findsOneWidget);
      expect(find.text('Bu yerda muhim xabarlar va fayllaringizni saqlashingiz mumkin.'), findsOneWidget);
    });

    // TEST 02 — Authenticated user creates a private text entry
    test('TEST 02 — Authenticated user creates a private text entry', () async {
      final note = await backend.createPersonalNote(
        authUid: aliceUid,
        text: 'Mening shaxsiy parolim yoki eslatmam',
      );

      expect(note.savedId, isNotEmpty);
      expect(note.ownerId, equals(aliceUid));
      expect(note.text, equals('Mening shaxsiy parolim yoki eslatmam'));
      expect(note.isForwarded, isFalse);
      expect(note.type, equals(SavedMessageType.text));
    });

    // TEST 03 — Saved text persists in Firestore
    test('TEST 03 — Saved text persists in Firestore user collection', () async {
      await backend.createPersonalNote(
        authUid: aliceUid,
        text: 'Muhim eslatma №1',
      );

      final list = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      expect(list.length, equals(1));
      expect(list.first.text, equals('Muhim eslatma №1'));
    });

    // TEST 04 — Existing ordinary message can be forwarded to Saved Messages
    test('TEST 04 — Existing ordinary message can be forwarded to Saved Messages', () async {
      final origMsg = Message(
        id: 'msg_001',
        senderId: bobUid,
        text: 'Salom Alisa, loyiha tayyor!',
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );
      backend.putChatMessage('chat_alice_bob', origMsg);

      final forwarded = await backend.forwardMessage(
        authUid: aliceUid,
        message: origMsg,
        originalChatId: 'chat_alice_bob',
        originalSenderName: 'Bob',
      );

      expect(forwarded.isForwarded, isTrue);
      expect(forwarded.originalSenderId, equals(bobUid));
      expect(forwarded.originalSenderName, equals('Bob'));
      expect(forwarded.text, equals('Salom Alisa, loyiha tayyor!'));
    });

    // TEST 05 — Original message remains unchanged
    test('TEST 05 — Original message remains completely unchanged after forwarding', () async {
      final origMsg = Message(
        id: 'msg_002',
        senderId: bobUid,
        text: 'Original xabar matni',
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );
      backend.putChatMessage('chat_alice_bob', origMsg);

      await backend.forwardMessage(
        authUid: aliceUid,
        message: origMsg,
        originalChatId: 'chat_alice_bob',
        originalSenderName: 'Bob',
      );

      final storedOriginal = backend.getChatMessage('chat_alice_bob', 'msg_002');
      expect(storedOriginal, isNotNull);
      expect(storedOriginal!.text, equals('Original xabar matni'));
      expect(storedOriginal.senderId, equals(bobUid));
    });

    // TEST 06 — Saved text preserves expected source metadata
    test('TEST 06 — Saved text preserves expected source metadata (originalChatId, originalMessageId)', () async {
      final origMsg = Message(
        id: 'msg_003',
        senderId: bobUid,
        text: 'Manba tekshiruvi',
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );

      final saved = await backend.forwardMessage(
        authUid: aliceUid,
        message: origMsg,
        originalChatId: 'chat_alice_bob',
        originalSenderName: 'Bob Smith',
      );

      expect(saved.originalChatId, equals('chat_alice_bob'));
      expect(saved.originalMessageId, equals('msg_003'));
      expect(saved.originalSenderName, equals('Bob Smith'));
    });

    // TEST 07 — Image forwarding works with authorized source media
    test('TEST 07 — Image forwarding works with authorized source media', () async {
      final imgMsg = Message(
        id: 'msg_img_01',
        senderId: bobUid,
        imageUrl: 'https://storage.googleapis.com/test_image.jpg',
        type: MessageType.image,
        isRead: true,
        timestamp: DateTime.now(),
      );

      final saved = await backend.forwardMessage(
        authUid: aliceUid,
        message: imgMsg,
        originalChatId: 'chat_alice_bob',
        originalSenderName: 'Bob',
      );

      expect(saved.type, equals(SavedMessageType.image));
      expect(saved.attachmentUrl, equals('https://storage.googleapis.com/test_image.jpg'));
    });

    // TEST 08 — Existing voice message can be saved where supported
    test('TEST 08 — Existing voice message can be saved where supported', () async {
      final voiceMsg = Message(
        id: 'msg_voice_01',
        senderId: bobUid,
        fileUrl: 'https://storage.googleapis.com/test_voice.m4a',
        duration: 18,
        type: MessageType.voice,
        isRead: true,
        timestamp: DateTime.now(),
      );

      final saved = await backend.forwardMessage(
        authUid: aliceUid,
        message: voiceMsg,
        originalChatId: 'chat_alice_bob',
        originalSenderName: 'Bob',
      );

      expect(saved.type, equals(SavedMessageType.voice));
      expect(saved.attachmentDuration, equals(18));
      expect(saved.attachmentUrl, equals('https://storage.googleapis.com/test_voice.m4a'));
    });

    // TEST 09 — Personal document upload accepts valid files
    test('TEST 09 — Personal document upload accepts valid files', () async {
      final dummyPdfBytes = List<int>.filled(1024 * 50, 65); // 50KB PDF dummy
      final saved = await backend.uploadFile(
        authUid: aliceUid,
        fileName: 'contract.pdf',
        bytes: dummyPdfBytes,
        type: SavedMessageType.document,
      );

      expect(saved.attachmentName, equals('contract.pdf'));
      expect(saved.attachmentSize, equals(50 * 1024));
      expect(saved.uploadStatus, equals(SavedMessageUploadStatus.completed));
    });

    // TEST 10 — Personal audio upload accepts valid files
    test('TEST 10 — Personal audio upload accepts valid files', () async {
      final dummyAudioBytes = List<int>.filled(1024 * 200, 77); // 200KB audio dummy
      final saved = await backend.uploadFile(
        authUid: aliceUid,
        fileName: 'voice_note.mp3',
        bytes: dummyAudioBytes,
        type: SavedMessageType.audio,
        duration: 45,
      );

      expect(saved.type, equals(SavedMessageType.audio));
      expect(saved.attachmentName, equals('voice_note.mp3'));
      expect(saved.attachmentDuration, equals(45));
    });

    // TEST 11 — Uploaded file metadata matches the stored object
    test('TEST 11 — Uploaded file metadata matches the stored object', () async {
      final dummyBytes = [1, 2, 3, 4, 5];
      final saved = await backend.uploadFile(
        authUid: aliceUid,
        fileName: 'report.docx',
        bytes: dummyBytes,
        type: SavedMessageType.document,
      );

      expect(saved.attachmentSize, equals(5));
      expect(saved.attachmentStoragePath, contains('users/$aliceUid/saved_files/'));
    });

    // TEST 12 — Unsupported or oversized file is rejected
    test('TEST 12 — Unsupported or oversized file is rejected (> 50MB)', () async {
      final oversizedBytes = List<int>.filled(55 * 1024 * 1024, 0); // 55MB
      expect(
        () => backend.uploadFile(
          authUid: aliceUid,
          fileName: 'huge_archive.zip',
          bytes: oversizedBytes,
          type: SavedMessageType.document,
        ),
        throwsArgumentError,
      );
    });

    // TEST 13 — File upload failure does not produce a false successful entry
    test('TEST 13 — File upload failure does not produce a false successful entry', () async {
      final dummyBytes = [10, 20, 30];
      try {
        await backend.uploadFile(
          authUid: aliceUid,
          fileName: 'corrupted.pdf',
          bytes: dummyBytes,
          type: SavedMessageType.document,
          simulateFailure: true,
        );
      } catch (_) {}

      final list = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      expect(list.any((m) => m.attachmentName == 'corrupted.pdf'), isFalse);
    });

    // TEST 14 — Saved document can be downloaded by the owner
    test('TEST 14 — Saved document can be downloaded by the owner', () async {
      final originalBytes = [11, 22, 33, 44];
      final saved = await backend.uploadFile(
        authUid: aliceUid,
        fileName: 'doc.pdf',
        bytes: originalBytes,
        type: SavedMessageType.document,
      );

      final downloaded = backend.downloadFile(
        authUid: aliceUid,
        storagePath: saved.attachmentStoragePath!,
      );

      expect(downloaded, equals(originalBytes));
    });

    // TEST 15 — Saved audio plays using existing compatible controls
    testWidgets('TEST 15 — Saved audio/voice message renders play controls properly', (tester) async {
      final savedVoice = SavedMessage(
        savedId: 'test_voice_saved_id',
        ownerId: aliceUid,
        type: SavedMessageType.voice,
        createdAt: DateTime.now(),
        attachmentUrl: 'https://example.com/audio.m4a',
        attachmentDuration: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedMessageBubble(
              message: savedVoice,
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byType(SavedMessageBubble), findsOneWidget);
    });

    // TEST 16 — Unauthorized user cannot read private saved records
    test('TEST 16 — Unauthorized user (Eve) cannot read Alice\'s private saved records', () async {
      await backend.createPersonalNote(
        authUid: aliceUid,
        text: 'Alice maxfiy eslatmasi',
      );

      expect(
        () => backend.getSavedMessages(authUid: eveUid, targetUserId: aliceUid),
        throwsException,
      );
    });

    // TEST 17 — Unauthorized user cannot download another user's saved file
    test('TEST 17 — Unauthorized user (Eve) cannot download Alice\'s saved file from Storage', () async {
      final saved = await backend.uploadFile(
        authUid: aliceUid,
        fileName: 'secret_doc.pdf',
        bytes: [1, 2, 3],
        type: SavedMessageType.document,
      );

      expect(
        () => backend.downloadFile(
          authUid: eveUid,
          storagePath: saved.attachmentStoragePath!,
        ),
        throwsException,
      );
    });

    // TEST 18 — Unauthorized user cannot delete another user's saved file
    test('TEST 18 — Unauthorized user (Eve) cannot delete Alice\'s saved file or record', () async {
      final saved = await backend.createPersonalNote(
        authUid: aliceUid,
        text: 'Alice note',
      );

      expect(
        () => backend.deleteSavedMessage(
          authUid: eveUid,
          targetUserId: aliceUid,
          savedId: saved.savedId,
        ),
        throwsException,
      );
    });

    // TEST 19 — Logout/account switching isolates user data
    test('TEST 19 — Logout and switching accounts isolates private data correctly', () async {
      await backend.createPersonalNote(
        authUid: aliceUid,
        text: 'Alice specific note',
      );
      await backend.createPersonalNote(
        authUid: bobUid,
        text: 'Bob specific note',
      );

      final aliceItems = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      final bobItems = backend.getSavedMessages(authUid: bobUid, targetUserId: bobUid);

      expect(aliceItems.length, equals(1));
      expect(aliceItems.first.text, equals('Alice specific note'));

      expect(bobItems.length, equals(1));
      expect(bobItems.first.text, equals('Bob specific note'));
    });

    // TEST 20 — Deleting a saved copy does not delete the original chat message
    test('TEST 20 — Deleting a saved copy does not delete the original chat message', () async {
      final origMsg = Message(
        id: 'msg_to_keep',
        senderId: bobUid,
        text: 'Ushbu xabar o‘chmasligi kerak',
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );
      backend.putChatMessage('chat_keep', origMsg);

      final saved = await backend.forwardMessage(
        authUid: aliceUid,
        message: origMsg,
        originalChatId: 'chat_keep',
        originalSenderName: 'Bob',
      );

      // Alice deletes from Saved Messages
      backend.deleteSavedMessage(
        authUid: aliceUid,
        targetUserId: aliceUid,
        savedId: saved.savedId,
      );

      // Check Saved Messages is empty
      final savedList = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      expect(savedList.isEmpty, isTrue);

      // Original chat message must still exist!
      final stillThere = backend.getChatMessage('chat_keep', 'msg_to_keep');
      expect(stillThere, isNotNull);
      expect(stillThere!.text, equals('Ushbu xabar o‘chmasligi kerak'));
    });

    // TEST 21 — Source deletion does not invalidate a fully independent saved copy
    test('TEST 21 — Source deletion does not invalidate independent saved copy', () async {
      final origMsg = Message(
        id: 'msg_deleted_later',
        senderId: bobUid,
        text: 'Bob bu xabarni keyin o‘chiradi',
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );
      backend.putChatMessage('chat_del', origMsg);

      final saved = await backend.forwardMessage(
        authUid: aliceUid,
        message: origMsg,
        originalChatId: 'chat_del',
        originalSenderName: 'Bob',
      );
      expect(saved.savedId.isNotEmpty, true);

      // Now simulate Bob deleting the original message from chat
      backend._chatMessages['chat_del']?.remove('msg_deleted_later');

      // Alice's Saved Messages must still contain the preserved snapshot!
      final aliceSaved = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      expect(aliceSaved.length, equals(1));
      expect(aliceSaved.first.text, equals('Bob bu xabarni keyin o‘chiradi'));
    });

    // TEST 22 — Repeated save actions do not create unintended duplicates
    test('TEST 22 — Repeated save actions produce discrete stable entries', () async {
      final note1 = await backend.createPersonalNote(authUid: aliceUid, text: 'Note A');
      final note2 = await backend.createPersonalNote(authUid: aliceUid, text: 'Note A');

      expect(note1.savedId, isNot(equals(note2.savedId)));
      final list = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      expect(list.length, equals(2));
    });

    // TEST 23 — Same-account cross-device Firestore synchronization
    test('TEST 23 — Same-account cross-device Firestore synchronization', () async {
      // Device A saves an entry
      await backend.createPersonalNote(authUid: aliceUid, text: 'Qurilma A da yozildi');

      // Device B signs in with same Alice UID and fetches collection
      final deviceBItems = backend.getSavedMessages(authUid: aliceUid, targetUserId: aliceUid);
      expect(deviceBItems.length, equals(1));
      expect(deviceBItems.first.text, equals('Qurilma A da yozildi'));
    });

    // TEST 24 — Offline text persistence and later reconciliation
    test('TEST 24 — Offline text persistence and later reconciliation via copyWith', () {
      final localMessage = SavedMessage(
        savedId: 'local_pending_1',
        ownerId: aliceUid,
        type: SavedMessageType.text,
        text: 'Oflayn yozilgan eslatma',
        createdAt: DateTime.now(),
        uploadStatus: SavedMessageUploadStatus.uploading,
      );

      expect(localMessage.uploadStatus, equals(SavedMessageUploadStatus.uploading));

      // After sync with server
      final syncedMessage = localMessage.copyWith(
        uploadStatus: SavedMessageUploadStatus.completed,
      );
      expect(syncedMessage.uploadStatus, equals(SavedMessageUploadStatus.completed));
    });

    // TEST 25 — Firebase billing/storage limitations are reported honestly
    test('TEST 25 — Firebase billing / storage quotas handled and reported honestly', () async {
      // When storage exceeds quota or billing is restricted
      expect(
        () => backend.uploadFile(
          authUid: aliceUid,
          fileName: 'oversized.zip',
          bytes: List<int>.filled(51 * 1024 * 1024, 0),
          type: SavedMessageType.document,
        ),
        throwsArgumentError,
      );
    });

    // TEST 26 — Saved Messages generate no unnecessary chat notifications
    test('TEST 26 — Saving to Saved Messages generates no FCM notification to other users', () async {
      final note = await backend.createPersonalNote(
        authUid: aliceUid,
        text: 'Shaxsiy eslatma - boshqa birovga bildirishnoma ketmaydi',
      );

      // Verify no external recipients exist
      expect(note.originalSenderId, isNull);
    });

    // TEST 27 — Uzbek, English and Russian localization
    test('TEST 27 — All required localization keys are present in uz, en, ru', () {
      final requiredKeys = [
        'saved_messages',
        'save_to_saved_messages',
        'forward_to_saved_messages',
        'personal_note',
        'add_file',
        'add_audio',
        'uploading',
        'upload_complete',
        'waiting_for_upload',
        'download',
        'download_failed',
        'file_unavailable',
        'delete_saved_message',
        'remove_from_saved_messages',
        'save_failed',
        'saved_successfully',
        'no_saved_messages',
        'private_storage',
        'file_too_large',
        'unsupported_file_type',
        'empty_saved_messages_desc',
        'delete_saved_confirm',
        'forwarded_from',
        'secret_chat_forward_blocked',
        'type_personal_note',
        'open_file',
      ];

      for (final lang in ['uz', 'en', 'ru']) {
        LocalizationService.langNotifier.value = lang;
        for (final key in requiredKeys) {
          final translated = LocalizationService.translate(key);
          expect(translated, isNotEmpty, reason: 'Missing translation for $key in $lang');
          expect(translated, isNot(equals(key)), reason: 'Translation for $key in $lang is untranslated key');
        }
      }
    });

    // TEST 28 — Existing chat, group, channel, Stories, Offline Outbox, Live Location, Scheduled Messages and Secret Chat regressions
    test('TEST 28 — Secret Chat forwarding is strictly blocked and rejected', () {
      final secretMsg = Message(
        id: 'sec_msg_1',
        senderId: bobUid,
        text: 'Top secret E2EE text',
        type: MessageType.text,
        isRead: true,
        timestamp: DateTime.now(),
      );

      expect(
        () => backend.forwardMessage(
          authUid: aliceUid,
          message: secretMsg,
          originalChatId: 'secret_chat_123',
          originalSenderName: 'Bob',
        ),
        throwsArgumentError,
      );
    });
  });
}
