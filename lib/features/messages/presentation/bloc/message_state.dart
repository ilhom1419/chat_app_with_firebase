import 'package:equatable/equatable.dart';
import '../../domain/entities/message.dart';

abstract class MessageState extends Equatable {
  const MessageState();

  @override
  List<Object?> get props => [];
}

class MessageInitial extends MessageState {}

class MessageLoading extends MessageState {
  final String? chatId;
  const MessageLoading({this.chatId});

  @override
  List<Object?> get props => [chatId];
}

class MessageLoaded extends MessageState {
  final List<Message> messages;
  final String chatId;

  const MessageLoaded(this.messages, {this.chatId = ''});

  @override
  List<Object?> get props => [messages, chatId];
}

class MessageFailure extends MessageState {
  final String error;
  final String? chatId;

  const MessageFailure(this.error, {this.chatId});

  @override
  List<Object?> get props => [error, chatId];
}
