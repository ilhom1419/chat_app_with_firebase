import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/poll_data.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.senderId,
    super.text,
    super.imageUrl,
    required super.type,
    required super.isRead,
    super.isDeleted,
    required super.timestamp,
    super.status,
    super.replyToMessageId,
    super.reactions,
    super.isForwarded,
    super.fileUrl,
    super.fileName,
    super.fileSize,
    super.duration,
    super.selfDestructDuration,
    super.expiresAt,
    super.isEdited,
    super.latitude,
    super.longitude,
    super.address,
    super.contactName,
    super.contactPhone,
    super.liveLocationSessionId,
    super.liveLocationDuration,
    super.viewsCount,
    super.forwardCount,
    super.commentsCount,
    super.senderTitle,
    super.authorName,
    super.topicId,
    super.isSilent,
    super.isPinned,
    super.poll,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    MessageType mType = MessageType.text;
    final typeStr = data['type'] as String?;
    if (typeStr == 'image') {
      mType = MessageType.image;
    } else if (typeStr == 'video') {
      mType = MessageType.video;
    } else if (typeStr == 'file') {
      mType = MessageType.file;
    } else if (typeStr == 'voice') {
      mType = MessageType.voice;
    } else if (typeStr == 'location') {
      mType = MessageType.location;
    } else if (typeStr == 'contact') {
      mType = MessageType.contact;
    } else if (typeStr == 'gif') {
      mType = MessageType.gif;
    } else if (typeStr == 'videoNote') {
      mType = MessageType.videoNote;
    } else if (typeStr == 'poll') {
      mType = MessageType.poll;
    } else if (typeStr == 'sticker') {
      mType = MessageType.sticker;
    } else if (typeStr == 'liveLocation') {
      mType = MessageType.liveLocation;
    }

    final reactionsRaw = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactionsMap =
        reactionsRaw.map((key, value) => MapEntry(key, value.toString()));

    PollData? pollData;
    if (data['poll'] != null && data['poll'] is Map) {
      pollData = PollData.fromMap(Map<String, dynamic>.from(data['poll'] as Map));
    }

    final isRead = data['isRead'] as bool? ?? false;
    final hasPendingWrites = doc.metadata.hasPendingWrites;
    final statusStr = data['status'] as String?;
    MessageStatus status;
    if (hasPendingWrites) {
      status = MessageStatus.queued;
    } else if (isRead) {
      status = MessageStatus.read;
    } else if (statusStr == 'failed') {
      status = MessageStatus.failed;
    } else if (statusStr == 'sending') {
      status = MessageStatus.sending;
    } else if (statusStr == 'delivered') {
      status = MessageStatus.delivered;
    } else {
      status = MessageStatus.sent;
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      type: mType,
      isRead: isRead,
      isDeleted: data['isDeleted'] as bool? ?? false,
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      status: status,
      replyToMessageId: data['replyToMessageId'] as String?,
      reactions: reactionsMap,
      isForwarded: data['isForwarded'] as bool? ?? false,
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      fileSize: data['fileSize'] as String?,
      duration: data['duration'] as int?,
      selfDestructDuration: data['selfDestructDuration'] as int?,
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isEdited: data['isEdited'] as bool? ?? false,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      contactName: data['contactName'] as String?,
      contactPhone: data['contactPhone'] as String?,
      liveLocationSessionId: data['liveLocationSessionId'] as String?,
      liveLocationDuration: (data['liveLocationDuration'] as num?)?.toInt(),
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
      forwardCount: (data['forwardCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      senderTitle: data['senderTitle'] as String?,
      authorName: data['authorName'] as String?,
      topicId: data['topicId'] as String?,
      isSilent: data['isSilent'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      poll: pollData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'type': type.name,
      'isRead': isRead,
      'status': status.name,
      'isDeleted': isDeleted,
      'timestamp': Timestamp.fromDate(timestamp),
      'replyToMessageId': replyToMessageId,
      'reactions': reactions,
      'isForwarded': isForwarded,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration,
      'selfDestructDuration': selfDestructDuration,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isEdited': isEdited,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'liveLocationSessionId': liveLocationSessionId,
      'liveLocationDuration': liveLocationDuration,
      'viewsCount': viewsCount,
      'forwardCount': forwardCount,
      'commentsCount': commentsCount,
      'senderTitle': senderTitle,
      'authorName': authorName,
      'topicId': topicId,
      'isSilent': isSilent,
      'isPinned': isPinned,
      'poll': poll?.toMap(),
    };
  }
}
