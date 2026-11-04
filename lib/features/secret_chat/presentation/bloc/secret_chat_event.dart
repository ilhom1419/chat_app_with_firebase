import 'package:equatable/equatable.dart';
import '../../domain/entities/secret_message.dart';

abstract class SecretChatEvent extends Equatable {
  const SecretChatEvent();

  @override
  List<Object?> get props => [];
}

class StartSecretChatSession extends SecretChatEvent {
  final String recipientUid;
  final int selfDestructDuration;

  const StartSecretChatSession({
    required this.recipientUid,
    this.selfDestructDuration = 0,
  });

  @override
  List<Object?> get props => [recipientUid, selfDestructDuration];
}

class LoadSecretChatSession extends SecretChatEvent {
  final String chatId;

  const LoadSecretChatSession(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class TerminateSecretChatSession extends SecretChatEvent {
  final String chatId;

  const TerminateSecretChatSession(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class ChangeSelfDestructTimer extends SecretChatEvent {
  final String chatId;
  final int durationInSeconds;

  const ChangeSelfDestructTimer({
    required this.chatId,
    required this.durationInSeconds,
  });

  @override
  List<Object?> get props => [chatId, durationInSeconds];
}

class SessionStreamUpdated extends SecretChatEvent {
  final String chatId;
  final dynamic session; // SecretChatSession?

  const SessionStreamUpdated({
    required this.chatId,
    required this.session,
  });

  @override
  List<Object?> get props => [chatId, session];
}

class SendSecretMessage extends SecretChatEvent {
  final String plaintext;

  const SendSecretMessage(this.plaintext);

  @override
  List<Object?> get props => [plaintext];
}

class SecretMessagesUpdated extends SecretChatEvent {
  final List<SecretMessage> messages;

  const SecretMessagesUpdated(this.messages);

  @override
  List<Object?> get props => [messages];
}

class LoadSafetyNumber extends SecretChatEvent {
  const LoadSafetyNumber();

  @override
  List<Object?> get props => [];
}

class CheckSessionStatus extends SecretChatEvent {
  const CheckSessionStatus();

  @override
  List<Object?> get props => [];
}

class MarkSecretMessageRead extends SecretChatEvent {
  final String chatId;
  final String messageId;

  const MarkSecretMessageRead({
    required this.chatId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [chatId, messageId];
}

class DeleteSecretMessage extends SecretChatEvent {
  final String chatId;
  final String messageId;

  const DeleteSecretMessage({
    required this.chatId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [chatId, messageId];
}

class SendSecretImage extends SecretChatEvent {
  final List<int> imageBytes;
  final String? caption;
  final int? width;
  final int? height;

  const SendSecretImage({
    required this.imageBytes,
    this.caption,
    this.width,
    this.height,
  });

  @override
  List<Object?> get props => [imageBytes, caption, width, height];
}

class SendSecretVoice extends SecretChatEvent {
  final List<int> audioBytes;
  final int durationSeconds;

  const SendSecretVoice({
    required this.audioBytes,
    required this.durationSeconds,
  });

  @override
  List<Object?> get props => [audioBytes, durationSeconds];
}

class DownloadSecretMedia extends SecretChatEvent {
  final String messageId;
  final dynamic payload; // SecretMediaPayload

  const DownloadSecretMedia({
    required this.messageId,
    required this.payload,
  });

  @override
  List<Object?> get props => [messageId, payload];
}
