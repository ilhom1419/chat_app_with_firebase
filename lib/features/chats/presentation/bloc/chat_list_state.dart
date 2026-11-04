import 'package:equatable/equatable.dart';
import '../../domain/entities/chat.dart';

abstract class ChatListState extends Equatable {
  const ChatListState();

  @override
  List<Object?> get props => [];
}

class ChatListInitial extends ChatListState {}

class ChatListLoading extends ChatListState {}

class ChatListLoaded extends ChatListState {
  final List<Chat> chats;

  const ChatListLoaded(this.chats);

  @override
  List<Object?> get props => [chats];
}

class ChatListFailure extends ChatListState {
  final String error;

  const ChatListFailure(this.error);

  @override
  List<Object?> get props => [error];
}
