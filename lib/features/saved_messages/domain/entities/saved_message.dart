import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum SavedMessageType {
  text,
  image,
  audio,
  voice,
  document,
}

enum SavedMessageUploadStatus {
  completed,
  uploading,
  failed,
}

class SavedMessage extends Equatable {
  final String savedId;
  final String ownerId;
  final SavedMessageType type;
  final String? text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? originalSenderId;
  final String? originalSenderName;
  final String? originalChatId;
  final String? originalMessageId;
  final bool isForwarded;
  final String? originalMessageType;
  final String? attachmentStoragePath;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSize;
  final int? attachmentDuration; // for audio / voice in seconds
  final SavedMessageUploadStatus uploadStatus;

  const SavedMessage({
    required this.savedId,
    required this.ownerId,
    required this.type,
    this.text,
    required this.createdAt,
    this.updatedAt,
    this.originalSenderId,
    this.originalSenderName,
    this.originalChatId,
    this.originalMessageId,
    this.isForwarded = false,
    this.originalMessageType,
    this.attachmentStoragePath,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSize,
    this.attachmentDuration,
    this.uploadStatus = SavedMessageUploadStatus.completed,
  });

  SavedMessage copyWith({
    String? savedId,
    String? ownerId,
    SavedMessageType? type,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? originalSenderId,
    String? originalSenderName,
    String? originalChatId,
    String? originalMessageId,
    bool? isForwarded,
    String? originalMessageType,
    String? attachmentStoragePath,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentMimeType,
    int? attachmentSize,
    int? attachmentDuration,
    SavedMessageUploadStatus? uploadStatus,
  }) {
    return SavedMessage(
      savedId: savedId ?? this.savedId,
      ownerId: ownerId ?? this.ownerId,
      type: type ?? this.type,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      originalSenderId: originalSenderId ?? this.originalSenderId,
      originalSenderName: originalSenderName ?? this.originalSenderName,
      originalChatId: originalChatId ?? this.originalChatId,
      originalMessageId: originalMessageId ?? this.originalMessageId,
      isForwarded: isForwarded ?? this.isForwarded,
      originalMessageType: originalMessageType ?? this.originalMessageType,
      attachmentStoragePath: attachmentStoragePath ?? this.attachmentStoragePath,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      attachmentDuration: attachmentDuration ?? this.attachmentDuration,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }

  Map<String, dynamic> toMap({bool forFirestore = true}) {
    return {
      'savedId': savedId,
      'ownerId': ownerId,
      'type': type.name,
      'text': text,
      'createdAt': forFirestore ? FieldValue.serverTimestamp() : createdAt.toIso8601String(),
      'updatedAt': forFirestore ? FieldValue.serverTimestamp() : (updatedAt?.toIso8601String()),
      'originalSenderId': originalSenderId,
      'originalSenderName': originalSenderName,
      'originalChatId': originalChatId,
      'originalMessageId': originalMessageId,
      'isForwarded': isForwarded,
      'originalMessageType': originalMessageType,
      'attachmentStoragePath': attachmentStoragePath,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentMimeType': attachmentMimeType,
      'attachmentSize': attachmentSize,
      'attachmentDuration': attachmentDuration,
      'uploadStatus': uploadStatus.name,
    };
  }

  factory SavedMessage.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    SavedMessageType parseType(String? val) {
      switch (val) {
        case 'image':
          return SavedMessageType.image;
        case 'audio':
          return SavedMessageType.audio;
        case 'voice':
          return SavedMessageType.voice;
        case 'document':
          return SavedMessageType.document;
        case 'text':
        default:
          return SavedMessageType.text;
      }
    }

    SavedMessageUploadStatus parseStatus(String? val) {
      switch (val) {
        case 'uploading':
          return SavedMessageUploadStatus.uploading;
        case 'failed':
          return SavedMessageUploadStatus.failed;
        case 'completed':
        default:
          return SavedMessageUploadStatus.completed;
      }
    }

    return SavedMessage(
      savedId: (map['savedId'] as String?) ?? id ?? '',
      ownerId: (map['ownerId'] as String?) ?? '',
      type: parseType(map['type'] as String?),
      text: map['text'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      originalSenderId: map['originalSenderId'] as String?,
      originalSenderName: map['originalSenderName'] as String?,
      originalChatId: map['originalChatId'] as String?,
      originalMessageId: map['originalMessageId'] as String?,
      isForwarded: (map['isForwarded'] as bool?) ?? false,
      originalMessageType: map['originalMessageType'] as String?,
      attachmentStoragePath: map['attachmentStoragePath'] as String?,
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      attachmentMimeType: map['attachmentMimeType'] as String?,
      attachmentSize: (map['attachmentSize'] as num?)?.toInt(),
      attachmentDuration: (map['attachmentDuration'] as num?)?.toInt(),
      uploadStatus: parseStatus(map['uploadStatus'] as String?),
    );
  }

  factory SavedMessage.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return SavedMessage.fromMap(data, id: doc.id);
  }

  @override
  List<Object?> get props => [
        savedId,
        ownerId,
        type,
        text,
        createdAt,
        updatedAt,
        originalSenderId,
        originalSenderName,
        originalChatId,
        originalMessageId,
        isForwarded,
        originalMessageType,
        attachmentStoragePath,
        attachmentUrl,
        attachmentName,
        attachmentMimeType,
        attachmentSize,
        attachmentDuration,
        uploadStatus,
      ];
}
