import 'package:equatable/equatable.dart';

class DeviceIdentity extends Equatable {
  final String deviceId;
  final int registrationId;
  final String identityPublicKey;
  final DateTime createdAt;
  final bool revoked;
  final DateTime? lastSeen;

  const DeviceIdentity({
    required this.deviceId,
    required this.registrationId,
    required this.identityPublicKey,
    required this.createdAt,
    this.revoked = false,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'registrationId': registrationId,
      'identityPublicKey': identityPublicKey,
      'createdAt': createdAt.toIso8601String(),
      'revoked': revoked,
      if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
    };
  }

  factory DeviceIdentity.fromFirestore(Map<String, dynamic> data, String id) {
    return DeviceIdentity(
      deviceId: id,
      registrationId: data['registrationId'] as int? ?? 0,
      identityPublicKey: data['identityPublicKey'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      revoked: data['revoked'] as bool? ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as dynamic).toDate()
          : null,
    );
  }

  @override
  List<Object?> get props => [
        deviceId,
        registrationId,
        identityPublicKey,
        createdAt,
        revoked,
        lastSeen,
      ];
}
