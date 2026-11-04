import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/poll_data.dart';

abstract class MessageEvent extends Equatable {
  const MessageEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends MessageEvent {
  final String chatId;
  final String? currentUserId;

  const LoadMessages(this.chatId, {this.currentUserId});

  @override
  List<Object?> get props => [chatId, currentUserId];
}

class OutboxUpdated extends MessageEvent {
  final String chatId;

  const OutboxUpdated(this.chatId);

  @override
  List<Object?> get props => [chatId];
}

class MessagesUpdated extends MessageEvent {
  final List<Message> messages;
  final String? chatId;

  const MessagesUpdated(this.messages, {this.chatId});

  @override
  List<Object?> get props => [messages, chatId];
}

class LeaveChat extends MessageEvent {
  final String chatId;

  const LeaveChat([this.chatId = '']);

  @override
  List<Object?> get props => [chatId];
}

class SendTextMessage extends MessageEvent {
  final String? messageId;
  final String chatId;
  final String senderId;
  final String text;
  final String? replyToMessageId;
  final bool isForwarded;
  final String? imageUrl;
  final MessageType type;
  final int? selfDestructDuration;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? contactName;
  final String? contactPhone;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final String? senderTitle;
  final String? authorName;
  final bool isSilent;
  final String? topicId;
  final String? liveLocationSessionId;
  final int? liveLocationDuration;

  const SendTextMessage({
    this.messageId,
    required this.chatId,
    required this.senderId,
    required this.text,
    this.replyToMessageId,
    this.isForwarded = false,
    this.imageUrl,
    this.type = MessageType.text,
    this.selfDestructDuration,
    this.latitude,
    this.longitude,
    this.address,
    this.contactName,
    this.contactPhone,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.senderTitle,
    this.authorName,
    this.isSilent = false,
    this.topicId,
    this.liveLocationSessionId,
    this.liveLocationDuration,
  });

  @override
  List<Object?> get props => [
        messageId,
        chatId,
        senderId,
        text,
        replyToMessageId,
        isForwarded,
        imageUrl,
        type,
        selfDestructDuration,
        latitude,
        longitude,
        address,
        contactName,
        contactPhone,
        fileUrl,
        fileName,
        fileSize,
        senderTitle,
        authorName,
        isSilent,
        topicId,
        liveLocationSessionId,
        liveLocationDuration,
      ];
}

class RetryOutboxMessage extends MessageEvent {
  final String messageId;
  final String chatId;
  final String senderId;

  const RetryOutboxMessage({
    required this.messageId,
    required this.chatId,
    required this.senderId,
  });

  @override
  List<Object?> get props => [messageId, chatId, senderId];
}

class SendImageMessage extends MessageEvent {
  final String chatId;
  final String senderId;
  final File imageFile;
  final bool isForwarded;

  const SendImageMessage({
    required this.chatId,
    required this.senderId,
    required this.imageFile,
    this.isForwarded = false,
  });

  @override
  List<Object?> get props => [chatId, senderId, imageFile, isForwarded];
}

class DeleteMessageRequested extends MessageEvent {
  final String chatId;
  final String messageId;

  const DeleteMessageRequested(this.chatId, this.messageId);

  @override
  List<Object?> get props => [chatId, messageId];
}

class ToggleReactionRequested extends MessageEvent {
  final String chatId;
  final String messageId;
  final String userId;
  final String emoji;

  const ToggleReactionRequested({
    required this.chatId,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  @override
  List<Object?> get props => [chatId, messageId, userId, emoji];
}

class PinMessageRequested extends MessageEvent {
  final String chatId;
  final String? messageId;
  final bool isUnpin;

  const PinMessageRequested({
    required this.chatId,
    this.messageId,
    this.isUnpin = false,
  });

  @override
  List<Object?> get props => [chatId, messageId, isUnpin];
}

class SendFileMessageRequested extends MessageEvent {
  final String chatId;
  final String senderId;
  final File file;

  const SendFileMessageRequested({
    required this.chatId,
    required this.senderId,
    required this.file,
  });

  @override
  List<Object?> get props => [chatId, senderId, file];
}

class SendVoiceMessageRequested extends MessageEvent {
  final String chatId;
  final String senderId;
  final File voiceFile;
  final int durationSeconds;

  const SendVoiceMessageRequested({
    required this.chatId,
    required this.senderId,
    required this.voiceFile,
    required this.durationSeconds,
  });

  @override
  List<Object?> get props => [chatId, senderId, voiceFile, durationSeconds];
}

class SendVideoNoteRequested extends MessageEvent {
  final String chatId;
  final String senderId;
  final File videoFile;
  final int durationSeconds;

  const SendVideoNoteRequested({
    required this.chatId,
    required this.senderId,
    required this.videoFile,
    required this.durationSeconds,
  });

  @override
  List<Object?> get props => [chatId, senderId, videoFile, durationSeconds];
}

class SendVideoMessageRequested extends MessageEvent {
  final String chatId;
  final String senderId;
  final File videoFile;
  final String? caption;

  const SendVideoMessageRequested({
    required this.chatId,
    required this.senderId,
    required this.videoFile,
    this.caption,
  });

  @override
  List<Object?> get props => [chatId, senderId, videoFile, caption];
}

class EditMessageRequested extends MessageEvent {
  final String chatId;
  final String messageId;
  final String newText;

  const EditMessageRequested({
    required this.chatId,
    required this.messageId,
    required this.newText,
  });

  @override
  List<Object?> get props => [chatId, messageId, newText];
}

class SendPollRequested extends MessageEvent {
  final String chatId;
  final String senderId;
  final PollData poll;
  final String? senderTitle;
  final bool isSilent;
  final String? topicId;

  const SendPollRequested({
    required this.chatId,
    required this.senderId,
    required this.poll,
    this.senderTitle,
    this.isSilent = false,
    this.topicId,
  });

  @override
  List<Object?> get props => [chatId, senderId, poll, senderTitle, isSilent, topicId];
}

class VotePollRequested extends MessageEvent {
  final String chatId;
  final String messageId;
  final String userId;
  final List<int> selectedOptionIds;

  const VotePollRequested({
    required this.chatId,
    required this.messageId,
    required this.userId,
    required this.selectedOptionIds,
  });

  @override
  List<Object?> get props => [chatId, messageId, userId, selectedOptionIds];
}

class ClosePollRequested extends MessageEvent {
  final String chatId;
  final String messageId;

  const ClosePollRequested({
    required this.chatId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [chatId, messageId];
}

class IncrementMessageViewRequested extends MessageEvent {
  final String chatId;
  final String messageId;

  const IncrementMessageViewRequested({
    required this.chatId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [chatId, messageId];
}

