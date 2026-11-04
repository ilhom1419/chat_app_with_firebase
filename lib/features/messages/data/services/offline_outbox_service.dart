import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/cache/hive_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/outbox_message.dart';
import '../../domain/repositories/message_repository.dart';

/// Manages durable local queueing, optimistic updates, and automatic synchronization of offline messages.
class OfflineOutboxService {
  final MessageRepository _messageRepository;
  final Connectivity _connectivity;
  StreamSubscription? _connectivitySubscription;

  // Active chat processing locks to avoid concurrent duplicate workers
  final Set<String> _processingChatIds = {};

  // Broadcaster for real-time outbox updates per chat
  final _outboxUpdateController = StreamController<String>.broadcast();
  Stream<String> get onOutboxChanged => _outboxUpdateController.stream;

  // In-memory fallback if Hive box is not yet opened (e.g., in unit tests)
  final Map<String, Map<String, dynamic>> _inMemoryStore = {};

  OfflineOutboxService({
    required MessageRepository messageRepository,
    Connectivity? connectivity,
  })  : _messageRepository = messageRepository,
        _connectivity = connectivity ?? Connectivity();

  Box? get _box {
    try {
      if (Hive.isBoxOpen(HiveService.outboxBoxName)) {
        return HiveService.outboxBox;
      }
    } catch (_) {}
    return null;
  }

  /// Initializes connectivity listener to auto-sync pending messages when internet returns.
  void init(String Function() getCurrentUserId) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

      if (isConnected) {
        final currentUid = getCurrentUserId();
        if (currentUid.isNotEmpty) {
          processQueue(currentUid);
        }
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _outboxUpdateController.close();
  }

  void _notifyOutboxChanged(String chatId) {
    if (!_outboxUpdateController.isClosed) {
      _outboxUpdateController.add(chatId);
    }
  }

  /// Durably enqueues a new outgoing message.
  Future<void> enqueue(OutboxMessage message) async {
    final key = _makeKey(message.senderId, message.id);
    final box = _box;
    if (box != null) {
      await box.put(key, message.toMap());
    } else {
      _inMemoryStore[key] = message.toMap();
    }
    _notifyOutboxChanged(message.chatId);
  }

  /// Removes a message once confirmed sent by server.
  Future<void> remove(String senderId, String messageId, String chatId) async {
    final key = _makeKey(senderId, messageId);
    final box = _box;
    if (box != null) {
      await box.delete(key);
    } else {
      _inMemoryStore.remove(key);
    }
    _notifyOutboxChanged(chatId);
  }

  /// Updates status and error information for a queued message.
  Future<void> updateStatus(
    String senderId,
    String messageId,
    String chatId,
    MessageStatus status, {
    String? error,
  }) async {
    final key = _makeKey(senderId, messageId);
    final box = _box;
    Map<dynamic, dynamic>? raw;
    if (box != null) {
      raw = box.get(key) as Map?;
    } else {
      raw = _inMemoryStore[key];
    }

    if (raw != null) {
      final item = OutboxMessage.fromMap(raw);
      final updated = item.copyWith(
        status: status,
        lastError: error,
      );
      if (box != null) {
        await box.put(key, updated.toMap());
      } else {
        _inMemoryStore[key] = updated.toMap();
      }
      _notifyOutboxChanged(chatId);
    }
  }

  /// Retrieves pending outbox messages isolated strictly to the authenticated [currentUserId].
  List<OutboxMessage> getPendingMessages(String currentUserId, {String? chatId}) {
    final List<OutboxMessage> items = [];
    final box = _box;

    if (box != null) {
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw is Map) {
          try {
            final msg = OutboxMessage.fromMap(raw);
            if (msg.senderId == currentUserId) {
              if (chatId == null || msg.chatId == chatId) {
                items.add(msg);
              }
            }
          } catch (e) {
            debugPrint('Error parsing outbox message: $e');
          }
        }
      }
    } else {
      for (final raw in _inMemoryStore.values) {
        try {
          final msg = OutboxMessage.fromMap(raw);
          if (msg.senderId == currentUserId) {
            if (chatId == null || msg.chatId == chatId) {
              items.add(msg);
            }
          }
        } catch (_) {}
      }
    }

    // Preserve strict FIFO order by creation timestamp
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return items;
  }

  /// Stream of outbox changes for a specific conversation.
  Stream<List<OutboxMessage>> watchPendingMessages(String currentUserId, String chatId) async* {
    yield getPendingMessages(currentUserId, chatId: chatId);
    await for (final updatedChatId in _outboxUpdateController.stream) {
      if (updatedChatId == chatId) {
        yield getPendingMessages(currentUserId, chatId: chatId);
      }
    }
  }

  /// Manually retry a failed message with the same stable ID.
  Future<void> retryMessage(String currentUserId, String messageId, String chatId) async {
    final key = _makeKey(currentUserId, messageId);
    final box = _box;
    Map<dynamic, dynamic>? raw;
    if (box != null) {
      raw = box.get(key) as Map?;
    } else {
      raw = _inMemoryStore[key];
    }

    if (raw != null) {
      final item = OutboxMessage.fromMap(raw);
      final updated = item.copyWith(
        status: MessageStatus.queued,
        retryCount: item.retryCount + 1,
        lastError: null,
      );
      if (box != null) {
        await box.put(key, updated.toMap());
      } else {
        _inMemoryStore[key] = updated.toMap();
      }
      _notifyOutboxChanged(chatId);
      // Trigger queue processor
      await processQueue(currentUserId, targetChatId: chatId);
    }
  }

  /// Processes all pending messages for [currentUserId] sequentially in FIFO order per chat.
  Future<void> processQueue(String currentUserId, {String? targetChatId}) async {
    if (currentUserId.isEmpty) return;

    final allPending = getPendingMessages(currentUserId, chatId: targetChatId);
    if (allPending.isEmpty) return;

    // Group pending items by chatId
    final Map<String, List<OutboxMessage>> groupedByChat = {};
    for (final msg in allPending) {
      groupedByChat.putIfAbsent(msg.chatId, () => []).add(msg);
    }

    final List<Future<void>> tasks = [];
    for (final entry in groupedByChat.entries) {
      final chatId = entry.key;
      final messages = entry.value;

      // Prevent concurrent duplicate workers for the same chat
      if (_processingChatIds.contains(chatId)) continue;
      _processingChatIds.add(chatId);

      final task = _processChatQueue(currentUserId, chatId, messages).whenComplete(() {
        _processingChatIds.remove(chatId);
      });
      tasks.add(task);
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }
  }

  Future<void> _processChatQueue(
    String currentUserId,
    String chatId,
    List<OutboxMessage> messages,
  ) async {
    for (final msg in messages) {
      // If message is already marked as permanent failure, skip until explicit retry
      if (msg.status == MessageStatus.failed) continue;

      // Update to sending
      await updateStatus(currentUserId, msg.id, chatId, MessageStatus.sending);

      try {
        await _messageRepository.sendMessage(
          messageId: msg.id,
          chatId: chatId,
          senderId: currentUserId,
          text: msg.text,
          replyToMessageId: msg.replyToMessageId,
          isForwarded: msg.isForwarded,
          imageUrl: msg.imageUrl,
          latitude: msg.latitude,
          longitude: msg.longitude,
          address: msg.address,
          contactName: msg.contactName,
          contactPhone: msg.contactPhone,
          fileUrl: msg.fileUrl,
          fileName: msg.fileName,
          fileSize: msg.fileSize,
          senderTitle: msg.senderTitle,
          authorName: msg.authorName,
          isSilent: msg.isSilent,
          topicId: msg.topicId,
          type: msg.type,
        );

        // Success: remove from outbox queue
        await remove(currentUserId, msg.id, chatId);
      } catch (e) {
        debugPrint('Outbox delivery exception for message ${msg.id}: $e');

        final isPermanent = _isPermanentError(e);
        if (isPermanent) {
          await updateStatus(
            currentUserId,
            msg.id,
            chatId,
            MessageStatus.failed,
            error: e.toString(),
          );
        } else {
          // Transient network error: revert to queued and break FIFO queue for this chat
          await updateStatus(currentUserId, msg.id, chatId, MessageStatus.queued);
          break; // Stop further messages in this chat to preserve ordering
        }
      }
    }
  }

  bool _isPermanentError(dynamic error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied' ||
          error.code == 'not-found' ||
          error.code == 'invalid-argument') {
        return true;
      }
    }
    final str = error.toString().toLowerCase();
    if (str.contains('permission-denied') || str.contains('unauthorized')) {
      return true;
    }
    return false;
  }

  String _makeKey(String senderId, String messageId) => 'outbox_${senderId}_$messageId';
}
