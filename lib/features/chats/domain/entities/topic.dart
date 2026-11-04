import 'package:equatable/equatable.dart';

class Topic extends Equatable {
  final String id;
  final String chatId;
  final String title;
  final String iconEmoji;
  final String createdBy;
  final DateTime createdAt;
  final bool isClosed;
  final bool isPinned;
  final int messagesCount;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  const Topic({
    required this.id,
    required this.chatId,
    required this.title,
    this.iconEmoji = '💬',
    required this.createdBy,
    required this.createdAt,
    this.isClosed = false,
    this.isPinned = false,
    this.messagesCount = 0,
    this.lastMessage,
    this.lastMessageTime,
  });

  Topic copyWith({
    String? title,
    String? iconEmoji,
    bool? isClosed,
    bool? isPinned,
    int? messagesCount,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return Topic(
      id: id,
      chatId: chatId,
      title: title ?? this.title,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      createdBy: createdBy,
      createdAt: createdAt,
      isClosed: isClosed ?? this.isClosed,
      isPinned: isPinned ?? this.isPinned,
      messagesCount: messagesCount ?? this.messagesCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'title': title,
      'iconEmoji': iconEmoji,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isClosed': isClosed,
      'isPinned': isPinned,
      'messagesCount': messagesCount,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        title,
        iconEmoji,
        createdBy,
        createdAt,
        isClosed,
        isPinned,
        messagesCount,
        lastMessage,
        lastMessageTime,
      ];
}
