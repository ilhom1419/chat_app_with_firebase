import 'dart:io';
import '../entities/message.dart';
import '../entities/poll_data.dart';

abstract class MessageRepository {
  Stream<List<Message>> getMessages(String chatId);
  Future<void> sendMessage({
    String? messageId,
    required String chatId,
    required String senderId,
    required String text,
    String? replyToMessageId,
    bool isForwarded = false,
    String? imageUrl,
    MessageType type = MessageType.text,
    int? selfDestructDuration,
    double? latitude,
    double? longitude,
    String? address,
    String? contactName,
    String? contactPhone,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    String? senderTitle,
    String? authorName,
    bool isSilent = false,
    String? topicId,
    String? liveLocationSessionId,
    int? liveLocationDuration,
  });
  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required File imageFile,
    bool isForwarded = false,
  });
  Future<void> sendFileMessage({
    required String chatId,
    required String senderId,
    required File file,
  });
  Future<void> sendVoiceMessage({
    required String chatId,
    required String senderId,
    required File voiceFile,
    required int durationSeconds,
  });
  Future<void> sendVideoNoteMessage({
    required String chatId,
    required String senderId,
    required File videoFile,
    required int durationSeconds,
  });
  Future<void> sendVideoMessage({
    required String chatId,
    required String senderId,
    required File videoFile,
    String? caption,
  });
  Future<void> sendPollMessage({
    required String chatId,
    required String senderId,
    required PollData poll,
    String? senderTitle,
    bool isSilent = false,
    String? topicId,
  });
  Future<void> votePoll({
    required String chatId,
    required String messageId,
    required String userId,
    required List<int> selectedOptionIds,
  });
  Future<void> closePoll({
    required String chatId,
    required String messageId,
  });
  Future<void> incrementMessageViews(String chatId, String messageId);
  Future<void> deleteMessage(String chatId, String messageId);
  Future<void> markMessagesAsRead(String chatId, String currentUserId);
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  });
  Future<void> pinMessage(String chatId, String? messageId, {bool isUnpin = false});
  Future<void> editMessage(String chatId, String messageId, String newText);

  // Kanal postlari ostidagi Izohlar (Channel Post Comments)
  Stream<List<Message>> getComments(String chatId, String messageId);
  Future<void> sendComment({
    required String chatId,
    required String messageId,
    required String senderId,
    required String text,
    String? imageUrl,
    String? replyToMessageId,
    String? authorName,
    String? senderTitle,
  });
  Future<void> deleteComment(String chatId, String messageId, String commentId);
  Future<void> toggleCommentReaction({
    required String chatId,
    required String messageId,
    required String commentId,
    required String userId,
    required String emoji,
  });
}
