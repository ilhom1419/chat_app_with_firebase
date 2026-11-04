import 'package:equatable/equatable.dart';

class SecretChatSession extends Equatable {
  final String chatId;
  final String initiatorUid;
  final String initiatorDeviceId;
  final String recipientUid;
  final String recipientDeviceId;
  final List<String> participants;
  final int selfDestructDuration;
  final String status; // 'active' | 'terminated'
  final DateTime createdAt;

  const SecretChatSession({
    required this.chatId,
    required this.initiatorUid,
    required this.initiatorDeviceId,
    required this.recipientUid,
    required this.recipientDeviceId,
    required this.participants,
    required this.selfDestructDuration,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isTerminated => status == 'terminated';

  String getOtherUserId(String myUid) {
    return initiatorUid == myUid ? recipientUid : initiatorUid;
  }

  String getMyDeviceId(String myUid) {
    return initiatorUid == myUid ? initiatorDeviceId : recipientDeviceId;
  }

  String getOtherDeviceId(String myUid) {
    return initiatorUid == myUid ? recipientDeviceId : initiatorDeviceId;
  }

  factory SecretChatSession.fromFirestore(
      Map<String, dynamic> data, String id) {
    return SecretChatSession(
      chatId: id,
      initiatorUid: data['initiatorUid'] as String? ?? '',
      initiatorDeviceId: data['initiatorDeviceId'] as String? ?? '',
      recipientUid: data['recipientUid'] as String? ?? '',
      recipientDeviceId: data['recipientDeviceId'] as String? ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      selfDestructDuration: data['selfDestructDuration'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'initiatorUid': initiatorUid,
      'initiatorDeviceId': initiatorDeviceId,
      'recipientUid': recipientUid,
      'recipientDeviceId': recipientDeviceId,
      'participants': participants,
      'selfDestructDuration': selfDestructDuration,
      'status': status,
      'createdAt': createdAt,
    };
  }

  SecretChatSession copyWith({
    String? chatId,
    String? initiatorUid,
    String? initiatorDeviceId,
    String? recipientUid,
    String? recipientDeviceId,
    List<String>? participants,
    int? selfDestructDuration,
    String? status,
    DateTime? createdAt,
  }) {
    return SecretChatSession(
      chatId: chatId ?? this.chatId,
      initiatorUid: initiatorUid ?? this.initiatorUid,
      initiatorDeviceId: initiatorDeviceId ?? this.initiatorDeviceId,
      recipientUid: recipientUid ?? this.recipientUid,
      recipientDeviceId: recipientDeviceId ?? this.recipientDeviceId,
      participants: participants ?? this.participants,
      selfDestructDuration: selfDestructDuration ?? this.selfDestructDuration,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        chatId,
        initiatorUid,
        initiatorDeviceId,
        recipientUid,
        recipientDeviceId,
        participants,
        selfDestructDuration,
        status,
        createdAt,
      ];
}
