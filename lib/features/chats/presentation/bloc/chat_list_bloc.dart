import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/chat.dart';
import 'chat_list_event.dart';
import 'chat_list_state.dart';

class ChatListBloc extends Bloc<ChatListEvent, ChatListState> {
  final ChatRepository _chatRepository;
  StreamSubscription<List<Chat>>? _chatsSubscription;
  String _currentUserId = '';

  ChatListBloc({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(ChatListInitial()) {
    on<LoadChats>(_onLoadChats);
    on<ChatsUpdated>(_onChatsUpdated);
    on<ClearChats>(_onClearChats);
  }

  Future<void> _onLoadChats(
      LoadChats event, Emitter<ChatListState> emit) async {
    if (_currentUserId == event.userId && _chatsSubscription != null) {
      return;
    }

    // Cancel old subscription before starting a new one to prevent cross-account leak
    await _chatsSubscription?.cancel();
    _chatsSubscription = null;
    _currentUserId = event.userId;
    emit(ChatListLoading());

    _chatsSubscription = _chatRepository.getChats(event.userId).listen(
      (chats) {
        if (_currentUserId == event.userId) {
          add(ChatsUpdated(chats, userId: event.userId));
        }
      },
      onError: (error) {
        if (_currentUserId == event.userId) {
          emit(ChatListFailure(error.toString()));
        }
      },
    );
  }

  void _onChatsUpdated(ChatsUpdated event, Emitter<ChatListState> emit) {
    if (_currentUserId == event.userId || event.userId.isEmpty) {
      emit(ChatListLoaded(event.chats));
    }
  }

  void _onClearChats(ClearChats event, Emitter<ChatListState> emit) {
    _chatsSubscription?.cancel();
    _chatsSubscription = null;
    _currentUserId = '';
    emit(ChatListInitial());
  }

  @override
  Future<void> close() {
    _chatsSubscription?.cancel();
    _chatsSubscription = null;
    return super.close();
  }
}
