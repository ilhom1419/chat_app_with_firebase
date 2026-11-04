import 'package:equatable/equatable.dart';
import 'message.dart';

/// Represents a persistent queued outgoing message waiting to be synchronized with Firebase.
class OutboxMessage extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final String? replyToMessageId;
  final bool isForwarded;
  final String? imageUrl;
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
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;

  OutboxMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.queued,
    this.replyToMessageId,
    this.isForwarded = false,
    this.imageUrl,
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
    this.retryCount = 0,
    this.lastError,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts this outbox item to a domain [Message] for immediate optimistic UI display.
  Message toMessage() {
    return Message(
      id: id,
      senderId: senderId,
      text: text,
      type: type,
      isRead: false,
      isDeleted: false,
      timestamp: timestamp,
      status: status,
      replyToMessageId: replyToMessageId,
      isForwarded: isForwarded,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      contactName: contactName,
      contactPhone: contactPhone,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      senderTitle: senderTitle,
      authorName: authorName,
      isSilent: isSilent,
      topicId: topicId,
    );
  }

  OutboxMessage copyWith({
    MessageStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return OutboxMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: text,
      type: type,
      timestamp: timestamp,
      status: status ?? this.status,
      replyToMessageId: replyToMessageId,
      isForwarded: isForwarded,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      address: address,
      contactName: contactName,
      contactPhone: contactPhone,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      senderTitle: senderTitle,
      authorName: authorName,
      isSilent: isSilent,
      topicId: topicId,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.name,
      'replyToMessageId': replyToMessageId,
      'isForwarded': isForwarded,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'senderTitle': senderTitle,
      'authorName': authorName,
      'isSilent': isSilent,
      'topicId': topicId,
      'retryCount': retryCount,
      'lastError': lastError,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory OutboxMessage.fromMap(Map<dynamic, dynamic> map) {
    MessageType parsedType = MessageType.text;
    final typeStr = map['type'] as String?;
    if (typeStr != null) {
      for (final t in MessageType.values) {
        if (t.name == typeStr) {
          parsedType = t;
          break;
        }
      }
    }

    MessageStatus parsedStatus = MessageStatus.queued;
    final statusStr = map['status'] as String?;
    if (statusStr != null) {
      for (final s in MessageStatus.values) {
        if (s.name == statusStr) {
          parsedStatus = s;
          break;
        }
      }
    }

    return OutboxMessage(
      id: map['id'] as String,
      chatId: map['chatId'] as String,
      senderId: map['senderId'] as String,
      text: map['text'] as String? ?? '',
      type: parsedType,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      status: parsedStatus,
      replyToMessageId: map['replyToMessageId'] as String?,
      isForwarded: map['isForwarded'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      address: map['address'] as String?,
      contactName: map['contactName'] as String?,
      contactPhone: map['contactPhone'] as String?,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as String?,
      senderTitle: map['senderTitle'] as String?,
      authorName: map['authorName'] as String?,
      isSilent: map['isSilent'] as bool? ?? false,
      topicId: map['topicId'] as String?,
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        text,
        type,
        timestamp,
        status,
        replyToMessageId,
        isForwarded,
        imageUrl,
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
        retryCount,
        lastError,
        createdAt,
      ];
}
