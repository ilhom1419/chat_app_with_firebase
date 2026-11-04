import 'package:equatable/equatable.dart';
import '../../domain/entities/secret_chat_session.dart';
import '../../domain/entities/secret_message.dart';

abstract class SecretChatState extends Equatable {
  const SecretChatState();

  @override
  List<Object?> get props => [];
}

class SecretChatInitial extends SecretChatState {
  const SecretChatInitial();
}

class SecretChatLoading extends SecretChatState {
  const SecretChatLoading();
}

class SecretChatActive extends SecretChatState {
  final SecretChatSession session;
  final bool isInitiator;
  final List<SecretMessage> messages;
  final bool isSending;
  final bool isSessionEstablished;
  final String? safetyNumber;
  final String? sendError;
  final Map<String, bool> downloadingMediaIds;

  const SecretChatActive({
    required this.session,
    required this.isInitiator,
    this.messages = const [],
    this.isSending = false,
    this.isSessionEstablished = false,
    this.safetyNumber,
    this.sendError,
    this.downloadingMediaIds = const {},
  });

  SecretChatActive copyWith({
    SecretChatSession? session,
    bool? isInitiator,
    List<SecretMessage>? messages,
    bool? isSending,
    bool? isSessionEstablished,
    String? safetyNumber,
    String? sendError,
    Map<String, bool>? downloadingMediaIds,
  }) {
    return SecretChatActive(
      session: session ?? this.session,
      isInitiator: isInitiator ?? this.isInitiator,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isSessionEstablished:
          isSessionEstablished ?? this.isSessionEstablished,
      safetyNumber: safetyNumber ?? this.safetyNumber,
      sendError: sendError,
      downloadingMediaIds: downloadingMediaIds ?? this.downloadingMediaIds,
    );
  }

  @override
  List<Object?> get props => [
        session,
        isInitiator,
        messages,
        isSending,
        isSessionEstablished,
        safetyNumber,
        sendError,
        downloadingMediaIds,
      ];
}

class SecretChatTerminated extends SecretChatState {
  final String chatId;

  const SecretChatTerminated(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class SecretChatError extends SecretChatState {
  final String message;

  const SecretChatError(this.message);

  @override
  List<Object?> get props => [message];
}
