import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/voice_chat.dart';

class VoiceChatModel extends VoiceChat {
  const VoiceChatModel({
    required super.id,
    required super.chatId,
    required super.title,
    required super.hostId,
    required super.hostName,
    super.hostPhoto,
    super.isChannel,
    super.isActive,
    required super.startedAt,
    super.endedAt,
    super.participants,
  });

  factory VoiceChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final participantsMap = <String, VoiceChatParticipant>{};
    final rawParticipants = data['participants'] as Map<String, dynamic>? ?? {};
    rawParticipants.forEach((key, value) {
      if (value is Map) {
        participantsMap[key] = VoiceChatParticipant.fromMap(
          Map<String, dynamic>.from(value),
          key,
        );
      }
    });

    final startedAtTs = data['startedAt'] as Timestamp?;
    final endedAtTs = data['endedAt'] as Timestamp?;

    return VoiceChatModel(
      id: doc.id,
      chatId: data['chatId'] as String? ?? doc.id,
      title: data['title'] as String? ?? 'Ovozli efir',
      hostId: data['hostId'] as String? ?? '',
      hostName: data['hostName'] as String? ?? 'Host',
      hostPhoto: data['hostPhoto'] as String?,
      isChannel: data['isChannel'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      startedAt: startedAtTs?.toDate() ?? DateTime.now(),
      endedAt: endedAtTs?.toDate(),
      participants: participantsMap,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'chatId': chatId,
      'title': title,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhoto': hostPhoto,
      'isChannel': isChannel,
      'isActive': isActive,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'participants': participants.map((key, val) => MapEntry(key, val.toMap())),
    };
    return map;
  }
}
