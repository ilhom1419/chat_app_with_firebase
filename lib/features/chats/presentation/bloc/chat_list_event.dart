import 'package:equatable/equatable.dart';
import '../../domain/entities/chat.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object?> get props => [];
}

class LoadChats extends ChatListEvent {
  final String userId;

  const LoadChats(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ChatsUpdated extends ChatListEvent {
  final List<Chat> chats;
  final String userId;

  const ChatsUpdated(this.chats, {this.userId = ''});

  @override
  List<Object?> get props => [chats, userId];
}

class ClearChats extends ChatListEvent {}
