import 'package:equatable/equatable.dart';
import '../../../../core/localization/localization_service.dart';

class VoiceChatParticipant extends Equatable {
  final String userId;
  final String name;
  final String? photo;
  final bool isHost;
  final bool canSpeak;
  final bool isMuted;
  final bool isSpeaking;
  final bool isHandRaised;
  final DateTime joinedAt;

  const VoiceChatParticipant({
    required this.userId,
    required this.name,
    this.photo,
    this.isHost = false,
    this.canSpeak = false,
    this.isMuted = true,
    this.isSpeaking = false,
    this.isHandRaised = false,
    required this.joinedAt,
  });

  VoiceChatParticipant copyWith({
    String? userId,
    String? name,
    String? photo,
    bool? isHost,
    bool? canSpeak,
    bool? isMuted,
    bool? isSpeaking,
    bool? isHandRaised,
    DateTime? joinedAt,
  }) {
    return VoiceChatParticipant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      photo: photo ?? this.photo,
      isHost: isHost ?? this.isHost,
      canSpeak: canSpeak ?? this.canSpeak,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory VoiceChatParticipant.fromMap(Map<String, dynamic> map, String userId) {
    return VoiceChatParticipant(
      userId: userId,
      name: map['name'] as String? ?? 'Ishtirokchi',
      photo: map['photo'] as String?,
      isHost: map['isHost'] as bool? ?? false,
      canSpeak: map['canSpeak'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? true,
      isSpeaking: map['isSpeaking'] as bool? ?? false,
      isHandRaised: map['isHandRaised'] as bool? ?? false,
      joinedAt: map['joinedAt'] != null
          ? DateTime.tryParse(map['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photo': photo,
      'isHost': isHost,
      'canSpeak': canSpeak,
      'isMuted': isMuted,
      'isSpeaking': isSpeaking,
      'isHandRaised': isHandRaised,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        photo,
        isHost,
        canSpeak,
        isMuted,
        isSpeaking,
        isHandRaised,
        joinedAt,
      ];
}

class VoiceChat extends Equatable {
  final String id;
  final String chatId;
  final String title;
  final String hostId;
  final String hostName;
  final String? hostPhoto;
  final bool isChannel;
  final bool isActive;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Map<String, VoiceChatParticipant> participants;

  const VoiceChat({
    required this.id,
    required this.chatId,
    required this.title,
    required this.hostId,
    required this.hostName,
    this.hostPhoto,
    this.isChannel = false,
    this.isActive = true,
    required this.startedAt,
    this.endedAt,
    this.participants = const {},
  });

  String get localizedTitle {
    final t = title.trim();
    if (t == 'Ovozli efir' ||
        t == 'Live Voice Chat' ||
        t == 'Голосовой чат' ||
        t == 'Голосовой эфир' ||
        t.isEmpty) {
      return LocalizationService.translate('live_voice_chat');
    }
    return title;
  }

  List<VoiceChatParticipant> get speakers =>
      participants.values.where((p) => p.canSpeak).toList();

  List<VoiceChatParticipant> get handRaised =>
      participants.values.where((p) => p.isHandRaised && !p.canSpeak).toList();

  List<VoiceChatParticipant> get listeners =>
      participants.values.where((p) => !p.canSpeak && !p.isHandRaised).toList();

  int get totalParticipants => participants.length;

  bool isUserHost(String userId) => hostId == userId;

  bool canUserSpeak(String userId) =>
      participants[userId]?.canSpeak ?? false;

  bool isUserHandRaised(String userId) =>
      participants[userId]?.isHandRaised ?? false;

  VoiceChat copyWith({
    String? id,
    String? chatId,
    String? title,
    String? hostId,
    String? hostName,
    String? hostPhoto,
    bool? isChannel,
    bool? isActive,
    DateTime? startedAt,
    DateTime? endedAt,
    Map<String, VoiceChatParticipant>? participants,
  }) {
    return VoiceChat(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhoto: hostPhoto ?? this.hostPhoto,
      isChannel: isChannel ?? this.isChannel,
      isActive: isActive ?? this.isActive,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      participants: participants ?? this.participants,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        title,
        hostId,
        hostName,
        hostPhoto,
        isChannel,
        isActive,
        startedAt,
        endedAt,
        participants,
      ];
}
