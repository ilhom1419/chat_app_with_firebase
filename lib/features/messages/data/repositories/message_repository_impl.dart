import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/poll_data.dart';
import '../../domain/repositories/message_repository.dart';
import '../models/message_model.dart';

class MessageRepositoryImpl implements MessageRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final _uuid = const Uuid();

  @override
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList()
          .cast<Message>();
    });
  }

  @override
  Future<void> sendMessage({
    String? messageId,
    required String chatId,
    required String senderId,
    required String text,
    String? replyToMessageId,
    bool isForwarded = false,
    String? imageUrl,
    MessageType type = MessageType.text,
    int? selfDestructDuration,
    double? latitude,
    double? longitude,
    String? address,
    String? contactName,
    String? contactPhone,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    String? senderTitle,
    String? authorName,
    bool isSilent = false,
    String? topicId,
    String? liveLocationSessionId,
    int? liveLocationDuration,
  }) async {
    final msgId = messageId ?? _uuid.v4();
    final now = FieldValue.serverTimestamp();

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    batch.set(
      msgRef,
      {
        'id': msgId,
        'senderId': senderId,
        'text': text,
        'imageUrl': imageUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'type': type.name,
        'isRead': false,
        'isDeleted': false,
        'timestamp': now,
        'replyToMessageId': replyToMessageId,
        'isForwarded': isForwarded,
        'reactions': {},
        'selfDestructDuration': selfDestructDuration,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'liveLocationSessionId': liveLocationSessionId,
        'liveLocationDuration': liveLocationDuration,
        'senderTitle': senderTitle,
        'authorName': authorName,
        'isSilent': isSilent,
        'viewsCount': 0,
        'forwardCount': 0,
        'topicId': topicId,
      },
      SetOptions(merge: true),
    );

    if (topicId != null) {
      final topicRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('topics')
          .doc(topicId);
      batch.set(
        topicRef,
        {
          'messagesCount': FieldValue.increment(1),
          'lastMessage': text,
          'lastMessageTime': now,
        },
        SetOptions(merge: true),
      );
    }

    // Chat ma'lumotlarini keshdan tekshiramiz (offline vaqtida qotib qolmaslik uchun)
    Map<String, dynamic>? chatData;
    bool chatDocExists = false;
    try {
      final chatDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .get(const GetOptions(source: Source.cache));
      chatData = chatDoc.data();
      chatDocExists = chatDoc.exists;
    } catch (_) {
      try {
        final chatDoc = await _firestore
            .collection('chats')
            .doc(chatId)
            .get()
            .timeout(const Duration(milliseconds: 4000));
        chatData = chatDoc.data();
        chatDocExists = chatDoc.exists;
      } catch (_) {}
    }

    final participants = List<String>.from(chatData?['participants'] ?? []);
    final isGroup = chatData?['isGroup'] as bool? ?? false;
    final isChannel = chatData?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates = {};
    if (isGroup || isChannel) {
      for (final uid in participants) {
        if (uid != senderId) {
          unreadUpdates['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      List<String> effectiveParticipants = participants;
      if (effectiveParticipants.isEmpty && chatId.contains('_')) {
        final parts = chatId.split('_');
        if (parts.length == 2 && parts.every((p) => p.isNotEmpty)) {
          effectiveParticipants = parts;
        }
      }

      if (effectiveParticipants.isNotEmpty) {
        final recipientId = effectiveParticipants.firstWhere(
          (id) => id != senderId,
          orElse: () => '',
        );
        if (recipientId.isNotEmpty) {
          unreadUpdates['unreadCount.$recipientId'] = FieldValue.increment(1);
        }
      }
    }

    final chatMetaUpdate = <String, dynamic>{
      'lastMessage': text,
      'lastMessageTime': now,
      'lastMessageSenderId': senderId,
      ...unreadUpdates,
    };

    if (participants.isEmpty && !isGroup && !isChannel && chatId.contains('_')) {
      final parts = chatId.split('_');
      if (parts.length == 2 && parts.every((p) => p.isNotEmpty)) {
        chatMetaUpdate['participants'] = parts;
        chatMetaUpdate['type'] = 'direct';
        chatMetaUpdate['isGroup'] = false;
        chatMetaUpdate['isChannel'] = false;
      }
    }

    if (chatDocExists) {
      batch.update(
        _firestore.collection('chats').doc(chatId),
        chatMetaUpdate,
      );
    } else {
      batch.set(
        _firestore.collection('chats').doc(chatId),
        chatMetaUpdate,
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    // Trigger Notification safely
    try {
      _triggerNotification(chatId, senderId, text, isSilent: isSilent);
    } catch (_) {}
  }

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required File imageFile,
    bool isForwarded = false,
  }) async {
    final msgId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    // Rasmni siqamiz (yuqori tiniqlikda va sifatda)
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 1080,
      minHeight: 1080,
      quality: 75,
    );

    if (compressedBytes == null) {
      throw Exception("Image compression failed");
    }

    // Base64 formatga o'tkazamiz
    final base64Image = base64Encode(compressedBytes);
    final base64Url = "data:image/jpeg;base64,$base64Image";

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'imageUrl': base64Url,
      'type': 'image',
      'isRead': false,
      'isDeleted': false,
      'timestamp': now,
      'isForwarded': isForwarded,
      'reactions': {},
    });

    // Chat hujjatini o'qib, barcha ishtirokchilar uchun unreadCount yangilaymiz
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    final participants = List<String>.from(chatData?['participants'] ?? []);
    final isGroup = chatData?['isGroup'] as bool? ?? false;
    final isChannel = chatData?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates = {};
    if (isGroup || isChannel) {
      for (final uid in participants) {
        if (uid != senderId) {
          unreadUpdates['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      final recipientId =
          participants.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isNotEmpty) {
        unreadUpdates['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
    }

    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': '📷 Photo',
        'lastMessageTime': now,
        'lastMessageSenderId': senderId,
        ...unreadUpdates,
      },
    );

    await batch.commit();

    // Trigger Notification
    _triggerNotification(chatId, senderId, '📷 Photo');
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    batch.update(messageRef, {'isDeleted': true});

    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': '🚫 Message deleted',
    });

    await batch.commit();
  }

  @override
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    if (chatId.isEmpty || currentUserId.isEmpty) return;
    try {
      final unread = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .get();

      final foreignUnread = unread.docs.where((doc) {
        final data = doc.data();
        return data['senderId'] != currentUserId;
      }).toList();

      final batch = _firestore.batch();

      for (final doc in foreignUnread) {
        final data = doc.data();
        final selfDestructDuration = data['selfDestructDuration'] as int?;
        if (selfDestructDuration != null) {
          final expiresAt =
              DateTime.now().add(Duration(seconds: selfDestructDuration));
          batch.update(doc.reference, {
            'isRead': true,
            'expiresAt': Timestamp.fromDate(expiresAt),
          });
        } else {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      // Chat unread count ni har doim tozalaymiz (chat ochilganda)
      batch.update(
        _firestore.collection('chats').doc(chatId),
        {
          'unreadCount.$currentUserId': 0,
        },
      );

      await batch.commit();
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    }
  }

  @override
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

      if (reactions[userId] == emoji) {
        reactions.remove(userId);
      } else {
        reactions[userId] = emoji;
      }

      transaction.update(msgRef, {'reactions': reactions});
    });
  }

  @override
  Future<void> pinMessage(String chatId, String? messageId,
      {bool isUnpin = false}) async {
    final chatRef = _firestore.collection('chats').doc(chatId);

    if (messageId == null || isUnpin) {
      if (messageId != null) {
        await chatRef.update({
          'pinnedMessageIds': FieldValue.arrayRemove([messageId]),
        });
        await chatRef
            .collection('messages')
            .doc(messageId)
            .update({'isPinned': false});

        final chatDoc = await chatRef.get();
        final list =
            List<String>.from(chatDoc.data()?['pinnedMessageIds'] ?? []);
        await chatRef.update({
          'pinnedMessageId': list.isNotEmpty ? list.last : null,
        });
      } else {
        await chatRef.update({
          'pinnedMessageId': null,
          'pinnedMessageIds': [],
        });
      }
    } else {
      await chatRef.update({
        'pinnedMessageId': messageId,
        'pinnedMessageIds': FieldValue.arrayUnion([messageId]),
      });
      await chatRef
          .collection('messages')
          .doc(messageId)
          .update({'isPinned': true});
    }
  }

  @override
  Future<void> editMessage(
      String chatId, String messageId, String newText) async {
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final batch = _firestore.batch();

    batch.update(msgRef, {
      'text': newText,
      'isEdited': true,
    });

    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': newText,
      },
    );

    await batch.commit();
  }

  @override
  Future<void> sendPollMessage({
    required String chatId,
    required String senderId,
    required PollData poll,
    String? senderTitle,
    bool isSilent = false,
    String? topicId,
  }) async {
    final msgId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    final pollToSave = poll.copyWith(id: msgId, creatorId: senderId);

    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'text': '📊 ${poll.question}',
      'type': MessageType.poll.name,
      'isRead': false,
      'isDeleted': false,
      'timestamp': now,
      'reactions': {},
      'senderTitle': senderTitle,
      'isSilent': isSilent,
      'viewsCount': 0,
      'topicId': topicId,
      'poll': pollToSave.toMap(),
    });

    if (topicId != null) {
      final topicRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('topics')
          .doc(topicId);
      batch.update(topicRef, {
        'messagesCount': FieldValue.increment(1),
        'lastMessage': '📊 So\'rovnoma: ${poll.question}',
        'lastMessageTime': now,
      });
    }

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    final participants = List<String>.from(chatData?['participants'] ?? []);
    final isGroup = chatData?['isGroup'] as bool? ?? false;
    final isChannel = chatData?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates = {};
    if (isGroup || isChannel) {
      for (final uid in participants) {
        if (uid != senderId) {
          unreadUpdates['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      final recipientId =
          participants.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isNotEmpty) {
        unreadUpdates['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
    }

    final previewText = '📊 So\'rovnoma: ${poll.question}';
    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': previewText,
        'lastMessageTime': now,
        'lastMessageSenderId': senderId,
        ...unreadUpdates,
      },
    );

    await batch.commit();

    _triggerNotification(chatId, senderId, previewText);
  }

  @override
  Future<void> votePoll({
    required String chatId,
    required String messageId,
    required String userId,
    required List<int> selectedOptionIds,
  }) async {
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final rawPoll = data['poll'] as Map<String, dynamic>?;
      if (rawPoll == null) return;

      final poll = PollData.fromMap(rawPoll);
      if (poll.isClosed) return;

      final updatedOptions = poll.options.map((option) {
        final newVoters = List<String>.from(option.voterIds);
        newVoters.remove(userId);

        if (selectedOptionIds.contains(option.id)) {
          newVoters.add(userId);
        }

        return option.copyWith(voterIds: newVoters);
      }).toList();

      final updatedPoll = poll.copyWith(options: updatedOptions);
      transaction.update(msgRef, {'poll': updatedPoll.toMap()});
    });
  }

  @override
  Future<void> closePoll({
    required String chatId,
    required String messageId,
  }) async {
    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final rawPoll = data['poll'] as Map<String, dynamic>?;
      if (rawPoll == null) return;

      final poll = PollData.fromMap(rawPoll);
      final updatedPoll = poll.copyWith(isClosed: true);

      transaction.update(msgRef, {'poll': updatedPoll.toMap()});
    });
  }

  @override
  Future<void> incrementMessageViews(String chatId, String messageId) async {
    try {
      final msgRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await msgRef.update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("incrementMessageViews error: $e");
    }
  }

  @override
  Future<void> sendFileMessage({
    required String chatId,
    required String senderId,
    required File file,
  }) async {
    final msgId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    // Get file name and size
    final fileName = file.path.split('/').last.split('\\').last;
    final fileLength = await file.length();

    // Convert file size to human-readable format
    String fileSizeStr;
    if (fileLength < 1024) {
      fileSizeStr = '$fileLength B';
    } else if (fileLength < 1024 * 1024) {
      fileSizeStr = '${(fileLength / 1024).toStringAsFixed(1)} KB';
    } else {
      fileSizeStr = '${(fileLength / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    // Convert to Base64
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    final base64Url = "data:application/octet-stream;base64,$base64Data";

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'type': 'file',
      'isRead': false,
      'isDeleted': false,
      'timestamp': now,
      'fileUrl': base64Url,
      'fileName': fileName,
      'fileSize': fileSizeStr,
      'reactions': {},
    });

    final chatDoc2 = await _firestore.collection('chats').doc(chatId).get();
    final chatData2 = chatDoc2.data();
    final participants2 = List<String>.from(chatData2?['participants'] ?? []);
    final isGroup2 = chatData2?['isGroup'] as bool? ?? false;
    final isChannel2 = chatData2?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates2 = {};
    if (isGroup2 || isChannel2) {
      for (final uid in participants2) {
        if (uid != senderId) {
          unreadUpdates2['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      final recipientId =
          participants2.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isNotEmpty) {
        unreadUpdates2['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
    }

    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': '📄 $fileName',
        'lastMessageTime': now,
        'lastMessageSenderId': senderId,
        ...unreadUpdates2,
      },
    );

    await batch.commit();

    // Trigger Notification
    _triggerNotification(chatId, senderId, '📄 $fileName');
  }

  @override
  Future<void> sendVoiceMessage({
    required String chatId,
    required String senderId,
    required File voiceFile,
    required int durationSeconds,
  }) async {
    final msgId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    // Cache the original voice file locally right away for instantaneous local playback
    try {
      final tempDir = await getTemporaryDirectory();
      final cachedFile = File('${tempDir.path}/voice_$msgId.m4a');
      if (await voiceFile.exists()) {
        await voiceFile.copy(cachedFile.path);
      }
    } catch (e) {
      debugPrint("Local cache error for voice note: $e");
    }

    String voiceUrl = '';
    try {
      // 1. Attempt uploading directly to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chats')
          .child(chatId)
          .child('voices')
          .child('$msgId.m4a');

      final uploadTask = await storageRef.putFile(
        voiceFile,
        SettableMetadata(contentType: 'audio/m4a'),
      );
      voiceUrl = await uploadTask.ref.getDownloadURL();
    } catch (e) {
      // 2. Fallback to Base64
      final bytes = await voiceFile.readAsBytes();
      final base64Data = base64Encode(bytes);
      voiceUrl = "data:audio/m4a;base64,$base64Data";
    }

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'type': 'voice',
      'isRead': false,
      'isDeleted': false,
      'timestamp': now,
      'fileUrl': voiceUrl,
      'duration': durationSeconds,
      'reactions': {},
    });

    final chatDoc3 = await _firestore.collection('chats').doc(chatId).get();
    final chatData3 = chatDoc3.data();
    final participants3 = List<String>.from(chatData3?['participants'] ?? []);
    final isGroup3 = chatData3?['isGroup'] as bool? ?? false;
    final isChannel3 = chatData3?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates3 = {};
    if (isGroup3 || isChannel3) {
      for (final uid in participants3) {
        if (uid != senderId) {
          unreadUpdates3['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      final recipientId =
          participants3.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isNotEmpty) {
        unreadUpdates3['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
    }

    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': '🎤 Voice note',
        'lastMessageTime': now,
        'lastMessageSenderId': senderId,
        ...unreadUpdates3,
      },
    );

    await batch.commit();

    // Trigger Notification
    _triggerNotification(chatId, senderId, '🎤 Voice note');
  }

  @override
  Future<void> sendVideoNoteMessage({
    required String chatId,
    required String senderId,
    required File videoFile,
    required int durationSeconds,
  }) async {
    final msgId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    // Cache the original video locally right away for instantaneous local playback
    try {
      final tempDir = await getTemporaryDirectory();
      final cachedFile = File('${tempDir.path}/vnote_$msgId.mp4');
      if (await videoFile.exists()) {
        await videoFile.copy(cachedFile.path);
      }
    } catch (e) {
      debugPrint("Local cache error for video note: $e");
    }

    String videoUrl = '';
    try {
      // 1. Attempt uploading directly to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chats')
          .child(chatId)
          .child('video_notes')
          .child('$msgId.mp4');

      final uploadTask = await storageRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );
      videoUrl = await uploadTask.ref.getDownloadURL();
    } catch (e) {
      // 2. Fallback to base64 if Firebase Storage is not active/available
      final bytes = await videoFile.readAsBytes();
      final base64Data = base64Encode(bytes);
      videoUrl = "data:video/mp4;base64,$base64Data";
    }

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'type': 'videoNote',
      'isRead': false,
      'isDeleted': false,
      'timestamp': now,
      'fileUrl': videoUrl,
      'duration': durationSeconds,
      'reactions': {},
    });

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    final participants = List<String>.from(chatData?['participants'] ?? []);
    final isGroup = chatData?['isGroup'] as bool? ?? false;
    final isChannel = chatData?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates = {};
    if (isGroup || isChannel) {
      for (final uid in participants) {
        if (uid != senderId) {
          unreadUpdates['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      final recipientId =
          participants.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isNotEmpty) {
        unreadUpdates['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
    }

    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': '🎥 Video note',
        'lastMessageTime': now,
        'lastMessageSenderId': senderId,
        ...unreadUpdates,
      },
    );

    await batch.commit();

    _triggerNotification(chatId, senderId, '🎥 Video note');
  }

  @override
  Future<void> sendVideoMessage({
    required String chatId,
    required String senderId,
    required File videoFile,
    String? caption,
  }) async {
    final msgId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    // Cache original video locally immediately for zero-lag instant local playback
    try {
      final tempDir = await getTemporaryDirectory();
      final cachedFile = File('${tempDir.path}/video_$msgId.mp4');
      if (await videoFile.exists()) {
        await videoFile.copy(cachedFile.path);
      }
    } catch (e) {
      debugPrint("Local cache error for video message: $e");
    }

    // Get file name and size
    final fileName = videoFile.path.split('/').last.split('\\').last;
    final fileLength = await videoFile.length();

    String fileSizeStr;
    if (fileLength < 1024) {
      fileSizeStr = '$fileLength B';
    } else if (fileLength < 1024 * 1024) {
      fileSizeStr = '${(fileLength / 1024).toStringAsFixed(1)} KB';
    } else {
      fileSizeStr = '${(fileLength / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    String videoUrl = '';
    try {
      // 1. Attempt uploading directly to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chats')
          .child(chatId)
          .child('videos')
          .child('$msgId.mp4');

      final uploadTask = await storageRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );
      videoUrl = await uploadTask.ref.getDownloadURL();
    } catch (e) {
      // 2. Fallback to base64 if Firebase Storage is unavailable/offline
      final bytes = await videoFile.readAsBytes();
      final base64Data = base64Encode(bytes);
      videoUrl = "data:video/mp4;base64,$base64Data";
    }

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId);

    final batch = _firestore.batch();

    batch.set(msgRef, {
      'id': msgId,
      'senderId': senderId,
      'type': 'video',
      'text': caption,
      'isRead': false,
      'isDeleted': false,
      'timestamp': now,
      'fileUrl': videoUrl,
      'fileName': fileName,
      'fileSize': fileSizeStr,
      'reactions': {},
    });

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data();
    final participants = List<String>.from(chatData?['participants'] ?? []);
    final isGroup = chatData?['isGroup'] as bool? ?? false;
    final isChannel = chatData?['isChannel'] as bool? ?? false;

    final Map<String, dynamic> unreadUpdates = {};
    if (isGroup || isChannel) {
      for (final uid in participants) {
        if (uid != senderId) {
          unreadUpdates['unreadCount.$uid'] = FieldValue.increment(1);
        }
      }
    } else {
      final recipientId =
          participants.firstWhere((id) => id != senderId, orElse: () => '');
      if (recipientId.isNotEmpty) {
        unreadUpdates['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
    }

    final previewText = caption != null && caption.isNotEmpty
        ? '🎥 $caption'
        : '🎥 Video';

    batch.update(
      _firestore.collection('chats').doc(chatId),
      {
        'lastMessage': previewText,
        'lastMessageTime': now,
        'lastMessageSenderId': senderId,
        ...unreadUpdates,
      },
    );

    await batch.commit();

    _triggerNotification(chatId, senderId, previewText);
  }

  Future<void> _triggerNotification(
      String chatId, String senderId, String messageText, {bool isSilent = false}) async {
    try {
      // 1. Sender ismini olamiz
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final senderName =
          senderDoc.data()?['displayName'] as String? ?? 'Yangi xabar';

      // 2. Chat ma'lumotlarini olamiz
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final data = chatDoc.data();
      final isChannel = data?['isChannel'] as bool? ?? false;
      final isGroup = data?['isGroup'] as bool? ?? false;
      final groupName = data?['groupName'] as String?;

      List<String> participants = List<String>.from(data?['participants'] ?? []);
      if (participants.isEmpty && !isChannel && !isGroup && chatId.contains('_')) {
        final parts = chatId.split('_');
        if (parts.length == 2 && parts.every((p) => p.isNotEmpty)) {
          participants = parts;
        }
      }

      String title = senderName;
      if (isChannel) {
        title = groupName ?? 'Kanal';
      } else if (isGroup) {
        title = '${groupName ?? "Guruh"} - $senderName';
      }

      // 3. Barcha ishtirokchilarga yuboramiz (yuboruvchidan tashqari)
      for (final recipientId in participants) {
        if (recipientId == senderId) continue;

        // 3a. Firestore Real-time in-app notification yaratish
        try {
          await _firestore
              .collection('users')
              .doc(recipientId)
              .collection('notifications')
              .add({
            'title': title,
            'body': messageText,
            'chatId': chatId,
            'senderId': senderId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'isSilent': isSilent,
          });
        } catch (_) {}

        // 3b. FCM Push Notification yuborish
        try {
          final recipientDoc =
              await _firestore.collection('users').doc(recipientId).get();
          if (recipientDoc.exists) {
            final fcmToken = recipientDoc.data()?['fcmToken'] as String?;
            if (fcmToken != null && fcmToken.isNotEmpty) {
              await _sendFcmMessage(fcmToken, title, messageText, chatId, isSilent: isSilent);
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print("Notification triggering error: $e");
    }
  }

  Future<void> _sendFcmMessage(
      String token, String title, String body, String chatId, {bool isSilent = false}) async {
    try {
      // Firebase Cloud Messaging Server Key
      const String serverKey =
          "AAAAs_gSgBs:APA91bGq51uPqO9V8G2h8F-qT9LgP1dFm4S3qD7J";

      final client = HttpClient();
      final request = await client
          .postUrl(Uri.parse('https://fcm.googleapis.com/fcm/send'));

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'key=$serverKey');

      request.add(utf8.encode(jsonEncode({
        'notification': {
          'title': title,
          'body': body,
          if (!isSilent) 'sound': 'default',
          'android_channel_id': isSilent
              ? 'silent_chat_messages_channel'
              : 'chat_messages_channel',
        },
        'priority': isSilent ? 'normal' : 'high',
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'chatId': chatId,
          'title': title,
          'body': body,
          'isSilent': isSilent ? 'true' : 'false',
        },
        'to': token,
      })));

      final response = await request.close();
      print("FCM push status: ${response.statusCode}");
      client.close();
    } catch (e) {
      print("FCM send error: $e");
    }
  }

  Future<void> triggerNotificationForScheduled({
    required String chatId,
    required String senderId,
    required String text,
    bool isSilent = false,
  }) async {
    await _triggerNotification(chatId, senderId, text, isSilent: isSilent);
  }

  @override
  Stream<List<Message>> getComments(String chatId, String messageId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .where((m) => !m.isDeleted)
          .toList();
    });
  }

  @override
  Future<void> sendComment({
    required String chatId,
    required String messageId,
    required String senderId,
    required String text,
    String? imageUrl,
    String? replyToMessageId,
    String? authorName,
    String? senderTitle,
  }) async {
    final commentId = _uuid.v4();
    final now = FieldValue.serverTimestamp();

    final commentRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('comments')
        .doc(commentId);

    final postRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final batch = _firestore.batch();

    batch.set(commentRef, {
      'id': commentId,
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'type': imageUrl != null ? MessageType.image.name : MessageType.text.name,
      'isRead': true,
      'isDeleted': false,
      'timestamp': now,
      'replyToMessageId': replyToMessageId,
      'reactions': {},
      'authorName': authorName,
      'senderTitle': senderTitle,
      'viewsCount': 0,
      'forwardCount': 0,
      'commentsCount': 0,
    });

    batch.update(postRef, {
      'commentsCount': FieldValue.increment(1),
    });

    await batch.commit();

    // Agar kanalga munozara guruhi bog'langan bo'lsa, o'sha guruhga ham xabar qo'shish
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final linkedGroupId = chatDoc.data()?['linkedGroupId'] as String?;
      if (linkedGroupId != null && linkedGroupId.isNotEmpty) {
        final groupMsgId = _uuid.v4();
        await _firestore
            .collection('chats')
            .doc(linkedGroupId)
            .collection('messages')
            .doc(groupMsgId)
            .set({
          'id': groupMsgId,
          'senderId': senderId,
          'text': '💬 Izoh: $text',
          'imageUrl': imageUrl,
          'type': imageUrl != null ? MessageType.image.name : MessageType.text.name,
          'isRead': false,
          'isDeleted': false,
          'timestamp': now,
          'replyToMessageId': messageId,
          'isForwarded': true,
          'authorName': authorName,
          'senderTitle': senderTitle,
          'reactions': {},
          'viewsCount': 0,
        });

        await _firestore.collection('chats').doc(linkedGroupId).update({
          'lastMessage': '💬 Izoh: $text',
          'lastMessageTime': now,
        });
      }
    } catch (_) {}
  }

  @override
  Future<void> deleteComment(
      String chatId, String messageId, String commentId) async {
    final commentRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('comments')
        .doc(commentId);

    final postRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final batch = _firestore.batch();
    batch.update(commentRef, {'isDeleted': true});
    batch.update(postRef, {
      'commentsCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  @override
  Future<void> toggleCommentReaction({
    required String chatId,
    required String messageId,
    required String commentId,
    required String userId,
    required String emoji,
  }) async {
    final commentRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('comments')
        .doc(commentId);

    final doc = await commentRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      reactions[userId] = emoji;
    }

    await commentRef.update({'reactions': reactions});
  }
}
