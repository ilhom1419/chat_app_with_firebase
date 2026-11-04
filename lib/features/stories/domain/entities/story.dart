import 'package:equatable/equatable.dart';

class StoryViewer extends Equatable {
  final String userId;
  final String userName;
  final String? userPhoto;
  final DateTime viewedAt;
  final String? reaction;

  const StoryViewer({
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.viewedAt,
    this.reaction,
  });

  factory StoryViewer.fromMap(Map<String, dynamic> map, String userId) {
    return StoryViewer(
      userId: userId,
      userName: map['userName'] as String? ?? 'Foydalanuvchi',
      userPhoto: map['userPhoto'] as String?,
      viewedAt: map['viewedAt'] != null
          ? DateTime.tryParse(map['viewedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reaction: map['reaction'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'userPhoto': userPhoto,
      'viewedAt': viewedAt.toIso8601String(),
      'reaction': reaction,
    };
  }

  @override
  List<Object?> get props => [userId, userName, userPhoto, viewedAt, reaction];
}

class Story extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final bool isChannel;
  final bool isGroup;
  final String? mediaUrl;
  final String? caption;
  final String? textContent;
  final int gradientIndex;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic> viewersData;
  final Map<String, String> reactions;

  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.isChannel = false,
    this.isGroup = false,
    this.mediaUrl,
    this.caption,
    this.textContent,
    this.gradientIndex = 0,
    required this.createdAt,
    required this.expiresAt,
    this.viewersData = const {},
    this.reactions = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  int get viewsCount => viewersData.length;

  bool isViewedBy(String userId) => viewersData.containsKey(userId);

  List<StoryViewer> get viewersList {
    final list = <StoryViewer>[];
    viewersData.forEach((key, value) {
      if (value is Map) {
        list.add(StoryViewer.fromMap(Map<String, dynamic>.from(value), key));
      }
    });
    list.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return list;
  }

  Story copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    bool? isChannel,
    bool? isGroup,
    String? mediaUrl,
    String? caption,
    String? textContent,
    int? gradientIndex,
    DateTime? createdAt,
    DateTime? expiresAt,
    Map<String, dynamic>? viewersData,
    Map<String, String>? reactions,
  }) {
    return Story(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      isChannel: isChannel ?? this.isChannel,
      isGroup: isGroup ?? this.isGroup,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      textContent: textContent ?? this.textContent,
      gradientIndex: gradientIndex ?? this.gradientIndex,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewersData: viewersData ?? this.viewersData,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        authorAvatar,
        isChannel,
        isGroup,
        mediaUrl,
        caption,
        textContent,
        gradientIndex,
        createdAt,
        expiresAt,
        viewersData,
        reactions,
      ];
}
