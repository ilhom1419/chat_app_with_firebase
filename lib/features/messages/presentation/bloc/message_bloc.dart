import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/outbox_message.dart';
import '../../data/services/offline_outbox_service.dart';
import 'message_event.dart';
import 'message_state.dart';

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final MessageRepository _messageRepository;
  final OfflineOutboxService _outboxService;
  final Uuid _uuid = const Uuid();
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<String>? _outboxSubscription;
  String _currentChatId = '';
  String _currentUserId = '';

  MessageBloc({
    required MessageRepository messageRepository,
    OfflineOutboxService? outboxService,
  })  : _messageRepository = messageRepository,
        _outboxService = outboxService ??
            OfflineOutboxService(messageRepository: messageRepository),
        super(MessageInitial()) {
    // Listen for outbox changes to update UI immediately
    _outboxService.init(() => FirebaseAuth.instance.currentUser?.uid ?? '');
    _outboxSubscription = _outboxService.onOutboxChanged.listen((chatId) {
      if (_currentChatId == chatId) {
        add(OutboxUpdated(chatId));
      }
    });

    on<LoadMessages>(_onLoadMessages);
    on<MessagesUpdated>(_onMessagesUpdated);
    on<LeaveChat>(_onLeaveChat);
    on<OutboxUpdated>(_onOutboxUpdated);
    on<RetryOutboxMessage>(_onRetryOutboxMessage);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendImageMessage>(_onSendImageMessage);
    on<DeleteMessageRequested>(_onDeleteMessage);
    on<ToggleReactionRequested>(_onToggleReaction);
    on<PinMessageRequested>(_onPinMessage);
    on<SendFileMessageRequested>(_onSendFileMessage);
    on<SendVoiceMessageRequested>(_onSendVoiceMessage);
    on<SendVideoNoteRequested>(_onSendVideoNote);
    on<SendVideoMessageRequested>(_onSendVideoMessage);
    on<EditMessageRequested>(_onEditMessage);
    on<SendPollRequested>(_onSendPoll);
    on<VotePollRequested>(_onVotePoll);
    on<ClosePollRequested>(_onClosePoll);
    on<IncrementMessageViewRequested>(_onIncrementMessageView);
  }

  Future<void> _onLoadMessages(
      LoadMessages event, Emitter<MessageState> emit) async {
    // Cancel previous stream subscription immediately to isolate conversation
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _currentChatId = event.chatId;
    _currentUserId = event.currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    emit(MessageLoading(chatId: event.chatId));

    _messagesSubscription = _messageRepository.getMessages(event.chatId).listen(
      (messages) {
        if (_currentChatId == event.chatId) {
          add(MessagesUpdated(messages, chatId: event.chatId));
        }
      },
      onError: (error, stackTrace) {
        if (_currentChatId == event.chatId) {
          emit(MessageFailure(error.toString(), chatId: event.chatId));
        }
      },
    );
  }

  void _onMessagesUpdated(
      MessagesUpdated event, Emitter<MessageState> emit) {
    final targetChatId = event.chatId ?? _currentChatId;
    if (_currentChatId != targetChatId) return;

    final uid = _currentUserId.isNotEmpty
        ? _currentUserId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    final reconciled = _reconcileMessages(targetChatId, uid, event.messages);
    emit(MessageLoaded(reconciled, chatId: targetChatId));
  }

  void _onLeaveChat(
      LeaveChat event, Emitter<MessageState> emit) {
    if (event.chatId.isEmpty || event.chatId == _currentChatId) {
      _messagesSubscription?.cancel();
      _messagesSubscription = null;
      _currentChatId = '';
      emit(MessageInitial());
    }
  }

  void _onOutboxUpdated(OutboxUpdated event, Emitter<MessageState> emit) {
    if (_currentChatId == event.chatId && state is MessageLoaded) {
      final current = state as MessageLoaded;
      if (current.chatId == event.chatId) {
        final uid = _currentUserId.isNotEmpty
            ? _currentUserId
            : (FirebaseAuth.instance.currentUser?.uid ?? '');
        final reconciled = _reconcileMessages(event.chatId, uid, current.messages);
        emit(MessageLoaded(reconciled, chatId: event.chatId));
      }
    }
  }

  Future<void> _onRetryOutboxMessage(
      RetryOutboxMessage event, Emitter<MessageState> emit) async {
    try {
      if (state is MessageLoaded) {
        final current = state as MessageLoaded;
        if (current.chatId == event.chatId) {
          final updated = current.messages.map((m) {
            if (m.id == event.messageId) {
              return m.copyWith(status: MessageStatus.queued);
            }
            return m;
          }).toList();
          emit(MessageLoaded(updated, chatId: event.chatId));
        }
      }
      await _outboxService.retryMessage(event.senderId, event.messageId, event.chatId);
    } catch (e) {
      emit(MessageFailure(e.toString(), chatId: event.chatId));
    }
  }

  Future<void> _onSendTextMessage(
      SendTextMessage event, Emitter<MessageState> emit) async {
    final msgId = event.messageId ?? _uuid.v4();
    final now = DateTime.now();

    // Live Location messages are real-time sessions and must NOT enter ordinary text outbox
    if (event.type == MessageType.liveLocation) {
      try {
        await _messageRepository.sendMessage(
          messageId: msgId,
          chatId: event.chatId,
          senderId: event.senderId,
          text: event.text,
          type: event.type,
          latitude: event.latitude,
          longitude: event.longitude,
          liveLocationSessionId: event.liveLocationSessionId,
          liveLocationDuration: event.liveLocationDuration,
          topicId: event.topicId,
        );
      } catch (e) {
        emit(MessageFailure(e.toString()));
      }
      return;
    }

    final outboxMsg = OutboxMessage(
      id: msgId,
      chatId: event.chatId,
      senderId: event.senderId,
      text: event.text,
      type: event.type,
      timestamp: now,
      replyToMessageId: event.replyToMessageId,
      isForwarded: event.isForwarded,
      imageUrl: event.imageUrl,
      latitude: event.latitude,
      longitude: event.longitude,
      address: event.address,
      contactName: event.contactName,
      contactPhone: event.contactPhone,
      fileUrl: event.fileUrl,
      fileName: event.fileName,
      fileSize: event.fileSize,
      senderTitle: event.senderTitle,
      authorName: event.authorName,
      isSilent: event.isSilent,
      topicId: event.topicId,
      status: MessageStatus.queued,
    );

    try {
      // 1. Durably save into local outbox queue
      await _outboxService.enqueue(outboxMsg);

      // 2. Optimistic UI insertion immediately (strictly scoped to target chatId)
      if (state is MessageLoaded) {
        final current = state as MessageLoaded;
        if (current.chatId == event.chatId) {
          final optimistic = outboxMsg.toMessage();
          if (!current.messages.any((m) => m.id == optimistic.id)) {
            final updated = List<Message>.from(current.messages)..add(optimistic);
            emit(MessageLoaded(updated, chatId: event.chatId));
          }
        }
      }

      // 3. Trigger queue synchronization in background
      unawaited(_outboxService.processQueue(event.senderId, targetChatId: event.chatId));
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  List<Message> _reconcileMessages(
    String chatId,
    String currentUserId,
    List<Message> remoteMessages,
  ) {
    final outboxItems = _outboxService.getPendingMessages(currentUserId, chatId: chatId);
    if (outboxItems.isEmpty) {
      return remoteMessages;
    }

    final Map<String, Message> map = {};
    for (final m in remoteMessages) {
      map[m.id] = m;
    }

    for (final item in outboxItems) {
      final remote = map[item.id];
      if (remote != null) {
        // If remote has reached server confirmation, purge from local outbox
        if (remote.status == MessageStatus.sent ||
            remote.status == MessageStatus.read ||
            remote.status == MessageStatus.delivered) {
          _outboxService.remove(currentUserId, item.id, chatId);
        } else if (item.status == MessageStatus.failed) {
          // Explicit local failure overrides pending write status
          map[item.id] = remote.copyWith(status: MessageStatus.failed);
        } else if (item.status == MessageStatus.sending) {
          map[item.id] = remote.copyWith(status: MessageStatus.sending);
        }
      } else {
        // Not in remote snapshot yet (e.g. offline or pending), add from outbox
        map[item.id] = item.toMessage();
      }
    }

    final result = map.values.toList();
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  Future<void> _onSendImageMessage(
      SendImageMessage event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.sendImageMessage(
        chatId: event.chatId,
        senderId: event.senderId,
        imageFile: event.imageFile,
        isForwarded: event.isForwarded,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onDeleteMessage(
      DeleteMessageRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.deleteMessage(event.chatId, event.messageId);
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onToggleReaction(
      ToggleReactionRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.toggleReaction(
        chatId: event.chatId,
        messageId: event.messageId,
        userId: event.userId,
        emoji: event.emoji,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onPinMessage(
      PinMessageRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.pinMessage(
        event.chatId,
        event.messageId,
        isUnpin: event.isUnpin,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onSendFileMessage(
      SendFileMessageRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.sendFileMessage(
        chatId: event.chatId,
        senderId: event.senderId,
        file: event.file,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onSendVoiceMessage(
      SendVoiceMessageRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.sendVoiceMessage(
        chatId: event.chatId,
        senderId: event.senderId,
        voiceFile: event.voiceFile,
        durationSeconds: event.durationSeconds,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onSendVideoNote(
      SendVideoNoteRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.sendVideoNoteMessage(
        chatId: event.chatId,
        senderId: event.senderId,
        videoFile: event.videoFile,
        durationSeconds: event.durationSeconds,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onSendVideoMessage(
      SendVideoMessageRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.sendVideoMessage(
        chatId: event.chatId,
        senderId: event.senderId,
        videoFile: event.videoFile,
        caption: event.caption,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onEditMessage(
      EditMessageRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.editMessage(
        event.chatId,
        event.messageId,
        event.newText,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onSendPoll(
      SendPollRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.sendPollMessage(
        chatId: event.chatId,
        senderId: event.senderId,
        poll: event.poll,
        senderTitle: event.senderTitle,
        isSilent: event.isSilent,
        topicId: event.topicId,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onVotePoll(
      VotePollRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.votePoll(
        chatId: event.chatId,
        messageId: event.messageId,
        userId: event.userId,
        selectedOptionIds: event.selectedOptionIds,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onClosePoll(
      ClosePollRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.closePoll(
        chatId: event.chatId,
        messageId: event.messageId,
      );
    } catch (e) {
      emit(MessageFailure(e.toString()));
    }
  }

  Future<void> _onIncrementMessageView(
      IncrementMessageViewRequested event, Emitter<MessageState> emit) async {
    try {
      await _messageRepository.incrementMessageViews(
        event.chatId,
        event.messageId,
      );
    } catch (e) {
      // Background counter, no need to fail state
    }
  }

  @override
  Future<void> close() {
    _outboxSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }
}
