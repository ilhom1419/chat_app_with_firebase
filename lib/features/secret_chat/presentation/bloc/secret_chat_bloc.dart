import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/secret_media_payload.dart';
import '../../domain/repositories/secret_chat_repository.dart';
import 'secret_chat_event.dart';
import 'secret_chat_state.dart';

class SecretChatBloc extends Bloc<SecretChatEvent, SecretChatState> {
  final SecretChatRepository _repository;
  final FirebaseAuth? _auth;
  final String? _currentUserId;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _messagesSubscription;

  SecretChatBloc({
    required SecretChatRepository repository,
    FirebaseAuth? auth,
    String? currentUserId,
  })  : _repository = repository,
        _auth = auth,
        _currentUserId = currentUserId,
        super(const SecretChatInitial()) {
    on<StartSecretChatSession>(_onStartSecretChatSession);
    on<LoadSecretChatSession>(_onLoadSecretChatSession);
    on<TerminateSecretChatSession>(_onTerminateSecretChatSession);
    on<ChangeSelfDestructTimer>(_onChangeSelfDestructTimer);
    on<SessionStreamUpdated>(_onSessionStreamUpdated);
    on<SendSecretMessage>(_onSendSecretMessage);
    on<SecretMessagesUpdated>(_onSecretMessagesUpdated);
    on<LoadSafetyNumber>(_onLoadSafetyNumber);
    on<CheckSessionStatus>(_onCheckSessionStatus);
    on<MarkSecretMessageRead>(_onMarkSecretMessageRead);
    on<DeleteSecretMessage>(_onDeleteSecretMessage);
    on<SendSecretImage>(_onSendSecretImage);
    on<SendSecretVoice>(_onSendSecretVoice);
    on<DownloadSecretMedia>(_onDownloadSecretMedia);
  }

  String get _myUid {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      return _currentUserId!;
    }
    try {
      return (_auth ?? FirebaseAuth.instance).currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _onStartSecretChatSession(
    StartSecretChatSession event,
    Emitter<SecretChatState> emit,
  ) async {
    emit(const SecretChatLoading());
    try {
      final session = await _repository.createSecretChatSession(
        recipientUid: event.recipientUid,
        selfDestructDuration: event.selfDestructDuration,
      );
      final myUid = _myUid;
      final isEstablished =
          await _repository.hasEstablishedSession(session: session);

      emit(SecretChatActive(
        session: session,
        isInitiator: session.initiatorUid == myUid,
        isSessionEstablished: isEstablished,
      ));

      _subscribeToStreams(session.chatId);
    } catch (e) {
      emit(SecretChatError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onLoadSecretChatSession(
    LoadSecretChatSession event,
    Emitter<SecretChatState> emit,
  ) async {
    emit(const SecretChatLoading());
    _subscribeToStreams(event.chatId);
  }

  void _subscribeToStreams(String chatId) {
    _sessionSubscription?.cancel();
    _sessionSubscription =
        _repository.watchSecretChatSession(chatId).listen((session) {
      add(SessionStreamUpdated(chatId: chatId, session: session));
    });

    _messagesSubscription?.cancel();
    _messagesSubscription =
        _repository.watchSecretMessages(chatId).listen((messages) {
      add(SecretMessagesUpdated(messages));
    });
  }

  Future<void> _onSessionStreamUpdated(
    SessionStreamUpdated event,
    Emitter<SecretChatState> emit,
  ) async {
    final session = event.session;
    if (session == null || session.isTerminated) {
      emit(SecretChatTerminated(event.chatId));
    } else {
      final myUid = _myUid;
      final isEstablished =
          await _repository.hasEstablishedSession(session: session);

      if (state is SecretChatActive) {
        final current = state as SecretChatActive;
        emit(current.copyWith(
          session: session,
          isInitiator: session.initiatorUid == myUid,
          isSessionEstablished: isEstablished,
        ));
      } else {
        emit(SecretChatActive(
          session: session,
          isInitiator: session.initiatorUid == myUid,
          isSessionEstablished: isEstablished,
        ));
      }
    }
  }

  Future<void> _onSecretMessagesUpdated(
    SecretMessagesUpdated event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is SecretChatActive) {
      final current = state as SecretChatActive;
      final isEstablished =
          await _repository.hasEstablishedSession(session: current.session);
      // Filter out any messages that have expired
      final unexpired = event.messages.where((m) => !m.isExpired).toList();
      emit(current.copyWith(
        messages: unexpired,
        isSessionEstablished: isEstablished,
      ));
    }
  }

  Future<void> _onSendSecretMessage(
    SendSecretMessage event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is! SecretChatActive) return;
    final current = state as SecretChatActive;

    emit(current.copyWith(isSending: true, sendError: null));

    try {
      await _repository.sendSecretMessage(
        session: current.session,
        plaintext: event.plaintext,
      );
      final isEstablished =
          await _repository.hasEstablishedSession(session: current.session);
      emit(current.copyWith(
        isSending: false,
        isSessionEstablished: isEstablished,
      ));
    } catch (e) {
      emit(current.copyWith(
        isSending: false,
        sendError: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLoadSafetyNumber(
    LoadSafetyNumber event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is! SecretChatActive) return;
    final current = state as SecretChatActive;

    try {
      final safetyNumber =
          await _repository.getSafetyNumber(session: current.session);
      emit(current.copyWith(safetyNumber: safetyNumber));
    } catch (_) {
      // In case keys cannot be fetched yet
    }
  }

  Future<void> _onCheckSessionStatus(
    CheckSessionStatus event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is! SecretChatActive) return;
    final current = state as SecretChatActive;
    final isEstablished =
        await _repository.hasEstablishedSession(session: current.session);
    emit(current.copyWith(isSessionEstablished: isEstablished));
  }

  Future<void> _onMarkSecretMessageRead(
    MarkSecretMessageRead event,
    Emitter<SecretChatState> emit,
  ) async {
    try {
      await _repository.markMessageAsRead(
        chatId: event.chatId,
        messageId: event.messageId,
      );
    } catch (_) {}
  }

  Future<void> _onDeleteSecretMessage(
    DeleteSecretMessage event,
    Emitter<SecretChatState> emit,
  ) async {
    try {
      await _repository.deleteSecretMessage(
        chatId: event.chatId,
        messageId: event.messageId,
      );
      if (state is SecretChatActive) {
        final current = state as SecretChatActive;
        final remaining = current.messages
            .where((m) => m.messageId != event.messageId)
            .toList();
        emit(current.copyWith(messages: remaining));
      }
    } catch (_) {}
  }

  Future<void> _onTerminateSecretChatSession(
    TerminateSecretChatSession event,
    Emitter<SecretChatState> emit,
  ) async {
    try {
      await _repository.terminateSecretChat(event.chatId);
      emit(SecretChatTerminated(event.chatId));
    } catch (e) {
      emit(SecretChatError(e.toString()));
    }
  }

  Future<void> _onChangeSelfDestructTimer(
    ChangeSelfDestructTimer event,
    Emitter<SecretChatState> emit,
  ) async {
    try {
      await _repository.updateSelfDestructDuration(
        event.chatId,
        event.durationInSeconds,
      );
    } catch (e) {
      emit(SecretChatError(e.toString()));
    }
  }

  Future<void> _onSendSecretImage(
    SendSecretImage event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is! SecretChatActive) return;
    final current = state as SecretChatActive;

    emit(current.copyWith(isSending: true, sendError: null));

    try {
      await _repository.sendSecretImage(
        session: current.session,
        imageBytes: event.imageBytes,
        caption: event.caption,
        width: event.width,
        height: event.height,
      );
      final isEstablished =
          await _repository.hasEstablishedSession(session: current.session);
      emit(current.copyWith(
        isSending: false,
        isSessionEstablished: isEstablished,
      ));
    } catch (e) {
      emit(current.copyWith(
        isSending: false,
        sendError: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onSendSecretVoice(
    SendSecretVoice event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is! SecretChatActive) return;
    final current = state as SecretChatActive;

    emit(current.copyWith(isSending: true, sendError: null));

    try {
      await _repository.sendSecretVoice(
        session: current.session,
        audioBytes: event.audioBytes,
        durationSeconds: event.durationSeconds,
      );
      final isEstablished =
          await _repository.hasEstablishedSession(session: current.session);
      emit(current.copyWith(
        isSending: false,
        isSessionEstablished: isEstablished,
      ));
    } catch (e) {
      emit(current.copyWith(
        isSending: false,
        sendError: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onDownloadSecretMedia(
    DownloadSecretMedia event,
    Emitter<SecretChatState> emit,
  ) async {
    if (state is! SecretChatActive) return;
    final current = state as SecretChatActive;

    final downloading = Map<String, bool>.from(current.downloadingMediaIds);
    downloading[event.messageId] = true;
    emit(current.copyWith(downloadingMediaIds: downloading));

    try {
      final payload = event.payload as SecretMediaPayload;
      final decryptedBytes = await _repository.downloadAndDecryptMedia(
        payload: payload,
      );
      final updatedMessages = current.messages.map((m) {
        if (m.messageId == event.messageId && m.mediaPayload != null) {
          return m.copyWith(
            mediaPayload: m.mediaPayload!.copyWith(
              decryptedBytes: Uint8List.fromList(decryptedBytes),
            ),
          );
        }
        return m;
      }).toList();

      downloading.remove(event.messageId);
      emit(current.copyWith(
        messages: updatedMessages,
        downloadingMediaIds: downloading,
      ));
    } catch (e) {
      downloading.remove(event.messageId);
      emit(current.copyWith(
        downloadingMediaIds: downloading,
        sendError: 'Media yuklab olishda xatolik: ${e.toString().replaceAll('Exception: ', '')}',
      ));
    }
  }

  @override
  Future<void> close() {
    _sessionSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }
}
