import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/story.dart';

class StoryModel extends Story {
  const StoryModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    super.authorAvatar,
    super.isChannel = false,
    super.isGroup = false,
    super.mediaUrl,
    super.caption,
    super.textContent,
    super.gradientIndex = 0,
    required super.createdAt,
    required super.expiresAt,
    super.viewersData = const {},
    super.reactions = const {},
  });

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final createdAt = parseDate(data['createdAt'], DateTime.now());
    final expiresAt = parseDate(
      data['expiresAt'],
      createdAt.add(const Duration(hours: 24)),
    );

    return StoryModel(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'User',
      authorAvatar: data['authorAvatar'] as String?,
      isChannel: data['isChannel'] as bool? ?? (data['entityType'] == 'channel'),
      isGroup: data['isGroup'] as bool? ?? (data['entityType'] == 'group'),
      mediaUrl: data['mediaUrl'] as String?,
      caption: data['caption'] as String?,
      textContent: data['textContent'] as String?,
      gradientIndex: (data['gradientIndex'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      expiresAt: expiresAt,
      viewersData: Map<String, dynamic>.from(data['viewersData'] ?? {}),
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
    );
  }

  factory StoryModel.fromEntity(Story entity) {
    return StoryModel(
      id: entity.id,
      authorId: entity.authorId,
      authorName: entity.authorName,
      authorAvatar: entity.authorAvatar,
      isChannel: entity.isChannel,
      isGroup: entity.isGroup,
      mediaUrl: entity.mediaUrl,
      caption: entity.caption,
      textContent: entity.textContent,
      gradientIndex: entity.gradientIndex,
      createdAt: entity.createdAt,
      expiresAt: entity.expiresAt,
      viewersData: entity.viewersData,
      reactions: entity.reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'isChannel': isChannel,
      'isGroup': isGroup,
      'entityType': isChannel ? 'channel' : (isGroup ? 'group' : 'user'),
      'mediaUrl': mediaUrl,
      'caption': caption,
      'textContent': textContent,
      'gradientIndex': gradientIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewersData': viewersData,
      'reactions': reactions,
    };
  }
}
