import 'package:equatable/equatable.dart';
import 'poll_data.dart';

enum MessageType {
  text,
  image,
  video,
  file,
  voice,
  location,
  contact,
  gif,
  videoNote,
  poll,
  sticker,
  liveLocation,
}

enum MessageStatus {
  queued,
  sending,
  sent,
  delivered,
  read,
  failed,
}

class Message extends Equatable {
  final String id;
  final String senderId;
  final String? text;
  final String? imageUrl;
  final MessageType type;
  final bool isRead;
  final bool isDeleted;
  final DateTime timestamp;
  final MessageStatus status;
  final String? replyToMessageId;
  final Map<String, String> reactions; // uid -> emoji
  final bool isForwarded;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final int? duration; // voice message duration in seconds
  final int? selfDestructDuration; // self-destruct duration in seconds
  final DateTime? expiresAt; // expiry time after message is read
  final bool isEdited;

  // Location and Contact sharing
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? contactName;
  final String? contactPhone;
  final String? liveLocationSessionId;
  final int? liveLocationDuration;

  // Channel & Group Telegram-darajasidagi xususiyatlar
  final int viewsCount;
  final int forwardCount; // Ulashishlar (forwards) soni
  final int commentsCount; // Kanal posti izohlari soni (Comments count)
  final String? senderTitle; // Masalan: "👑 Asoschi", "Admin"
  final String? authorName; // Post muallifining ismi (Sign messages)
  final String? topicId; // Forum topic ID
  final bool isSilent; // Bildirishnomasiz post
  final bool isPinned; // Mahkamlangan xabar
  final PollData? poll; // Telegram-darajasidagi so'rovnoma

  const Message({
    required this.id,
    required this.senderId,
    this.text,
    this.imageUrl,
    required this.type,
    required this.isRead,
    this.isDeleted = false,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.replyToMessageId,
    this.reactions = const {},
    this.isForwarded = false,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.duration,
    this.selfDestructDuration,
    this.expiresAt,
    this.isEdited = false,
    this.latitude,
    this.longitude,
    this.address,
    this.contactName,
    this.contactPhone,
    this.liveLocationSessionId,
    this.liveLocationDuration,
    this.viewsCount = 0,
    this.forwardCount = 0,
    this.commentsCount = 0,
    this.senderTitle,
    this.authorName,
    this.topicId,
    this.isSilent = false,
    this.isPinned = false,
    this.poll,
  });

  Message copyWith({
    String? text,
    bool? isRead,
    bool? isDeleted,
    DateTime? timestamp,
    MessageStatus? status,
    Map<String, String>? reactions,
    bool? isForwarded,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    int? duration,
    int? selfDestructDuration,
    DateTime? expiresAt,
    bool? isEdited,
    double? latitude,
    double? longitude,
    String? address,
    String? contactName,
    String? contactPhone,
    String? liveLocationSessionId,
    int? liveLocationDuration,
    int? viewsCount,
    int? forwardCount,
    int? commentsCount,
    String? senderTitle,
    String? authorName,
    String? topicId,
    bool? isSilent,
    bool? isPinned,
    PollData? poll,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      text: text ?? this.text,
      imageUrl: imageUrl,
      type: type,
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId,
      reactions: reactions ?? this.reactions,
      isForwarded: isForwarded ?? this.isForwarded,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      selfDestructDuration: selfDestructDuration ?? this.selfDestructDuration,
      expiresAt: expiresAt ?? this.expiresAt,
      isEdited: isEdited ?? this.isEdited,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      liveLocationSessionId: liveLocationSessionId ?? this.liveLocationSessionId,
      liveLocationDuration: liveLocationDuration ?? this.liveLocationDuration,
      viewsCount: viewsCount ?? this.viewsCount,
      forwardCount: forwardCount ?? this.forwardCount,
      commentsCount: commentsCount ?? this.commentsCount,
      senderTitle: senderTitle ?? this.senderTitle,
      authorName: authorName ?? this.authorName,
      topicId: topicId ?? this.topicId,
      isSilent: isSilent ?? this.isSilent,
      isPinned: isPinned ?? this.isPinned,
      poll: poll ?? this.poll,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        text,
        imageUrl,
        type,
        isRead,
        isDeleted,
        timestamp,
        status,
        replyToMessageId,
        reactions,
        isForwarded,
        fileUrl,
        fileName,
        fileSize,
        duration,
        selfDestructDuration,
        expiresAt,
        isEdited,
        latitude,
        longitude,
        address,
        contactName,
        contactPhone,
        liveLocationSessionId,
        liveLocationDuration,
        viewsCount,
        forwardCount,
        commentsCount,
        senderTitle,
        authorName,
        topicId,
        isSilent,
        isPinned,
        poll,
      ];
}
