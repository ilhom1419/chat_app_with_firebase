import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/scheduled_message.dart';
import '../repositories/message_repository_impl.dart';

class ScheduledMessageService {
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  ScheduledMessageService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  /// Schedules a one-time message for future delivery.
  Future<ScheduledMessage> scheduleMessage({
    required String chatId,
    required String senderId,
    required String text,
    required DateTime scheduledAt,
    bool isSilent = false,
    String? timezoneId,
  }) async {
    final now = DateTime.now();
    if (!scheduledAt.isAfter(now)) {
      throw ArgumentError('Scheduled time must be in the future');
    }

    if (text.trim().isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }

    final scheduledMessageId = 'sched_${_uuid.v4()}';
    final stableMessageId = 'msg_${_uuid.v4()}';

    final scheduled = ScheduledMessage(
      scheduledMessageId: scheduledMessageId,
      messageId: stableMessageId,
      senderId: senderId,
      chatId: chatId,
      text: text.trim(),
      scheduledAt: scheduledAt,
      createdAt: now,
      timezoneId: timezoneId ?? DateTime.now().timeZoneName,
      isSilent: isSilent,
      status: ScheduledMessageStatus.pending,
    );

    await _firestore
        .collection('users')
        .doc(senderId)
        .collection('scheduled_messages')
        .doc(scheduledMessageId)
        .set(scheduled.toMap());

    return scheduled;
  }

  /// Real-time stream of the user's pending scheduled messages.
  Stream<List<ScheduledMessage>> watchPendingScheduledMessages(
    String userId, {
    String? chatId,
  }) {
    Query query = _firestore
        .collection('users')
        .doc(userId)
        .collection('scheduled_messages')
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledAt');

    if (chatId != null && chatId.isNotEmpty) {
      query = query.where('chatId', isEqualTo: chatId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ScheduledMessage.fromFirestore(doc))
          .toList();
    });
  }

  /// Cancels a pending scheduled message.
  Future<bool> cancelScheduledMessage({
    required String userId,
    required String scheduledMessageId,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('scheduled_messages')
        .doc(scheduledMessageId);

    return await _firestore.runTransaction<bool>((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) {
        throw Exception('Scheduled message not found');
      }

      final statusStr = doc.data()?['status'] as String? ?? '';
      if (statusStr == 'sent') {
        // Cannot cancel an already delivered message
        return false;
      }

      transaction.update(docRef, {
        'status': 'canceled',
        'canceledAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Idempotent delivery of a due scheduled message into the chat.
  Future<bool> executeDueMessage({
    required String userId,
    required String scheduledMessageId,
    bool forceSend = false,
  }) async {
    final schedRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('scheduled_messages')
        .doc(scheduledMessageId);

    late String chatId;
    late String senderId;
    late String text;
    late String messageId;
    late bool isSilent;

    final delivered = await _firestore.runTransaction<bool>((transaction) async {
      final schedDoc = await transaction.get(schedRef);
      if (!schedDoc.exists) return false;

      final data = schedDoc.data()!;
      final status = data['status'] as String? ?? '';
      if (status != 'pending') return false;

      final scheduledTimestamp = data['scheduledAt'] as Timestamp?;
      final scheduledAt = scheduledTimestamp?.toDate() ?? DateTime.now();

      if (!forceSend && DateTime.now().isBefore(scheduledAt)) {
        // Not due yet
        return false;
      }

      chatId = data['chatId'] as String;
      senderId = data['senderId'] as String;
      text = data['text'] as String;
      messageId = data['messageId'] as String;
      isSilent = data['isSilent'] as bool? ?? false;

      // Revalidate that senderId matches userId to prevent any impersonation
      if (senderId != userId) {
        return false;
      }

      // 1. Write the final chat message
      final msgRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      transaction.set(msgRef, {
        'id': messageId,
        'senderId': senderId,
        'text': text,
        'type': 'text',
        'isRead': false,
        'isDeleted': false,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'sent',
        'isSilent': isSilent,
        'reactions': {},
        'isForwarded': false,
        'isEdited': false,
        'viewsCount': 0,
        'forwardCount': 0,
      });

      // 2. Update chat metadata
      final chatRef = _firestore.collection('chats').doc(chatId);
      transaction.set(
        chatRef,
        {
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': senderId,
        },
        SetOptions(merge: true),
      );

      // 3. Mark scheduled message as sent
      transaction.update(schedRef, {
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });

      return true;
    });

    if (delivered) {
      // Trigger notification using the existing notification pipeline with isSilent
      try {
        final messageRepo = MessageRepositoryImpl();
        // ignore: invalid_use_of_visible_for_testing_member
        await messageRepo.triggerNotificationForScheduled(
          chatId: chatId,
          senderId: senderId,
          text: text,
          isSilent: isSilent,
        );
      } catch (_) {}
    }

    return delivered;
  }

  /// Scans and executes any due messages for the given user.
  Future<int> processDueMessagesForUser(String userId, {String? chatId}) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('scheduled_messages')
          .where('status', isEqualTo: 'pending')
          .where('scheduledAt', isLessThanOrEqualTo: Timestamp.now());

      if (chatId != null && chatId.isNotEmpty) {
        query = query.where('chatId', isEqualTo: chatId);
      }

      final snapshot = await query.get();
      int executedCount = 0;
      for (final doc in snapshot.docs) {
        final ok = await executeDueMessage(
          userId: userId,
          scheduledMessageId: doc.id,
        );
        if (ok) executedCount++;
      }
      return executedCount;
    } catch (_) {
      return 0;
    }
  }
}
