import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/topic.dart';

class TopicModel extends Topic {
  const TopicModel({
    required super.id,
    required super.chatId,
    required super.title,
    super.iconEmoji,
    required super.createdBy,
    required super.createdAt,
    super.isClosed,
    super.isPinned,
    super.messagesCount,
    super.lastMessage,
    super.lastMessageTime,
  });

  factory TopicModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return TopicModel(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      iconEmoji: data['iconEmoji'] as String? ?? '💬',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      isClosed: data['isClosed'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      messagesCount: (data['messagesCount'] as num?)?.toInt() ?? 0,
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: data['lastMessageTime'] != null
          ? parseDate(data['lastMessageTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'title': title,
      'iconEmoji': iconEmoji,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isClosed': isClosed,
      'isPinned': isPinned,
      'messagesCount': messagesCount,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
    };
  }
}
