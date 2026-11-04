import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum LiveLocationStatus {
  active,
  stopped,
  expired,
}

/// Represents a voluntary real-time live location sharing session between chat participants.
class LiveLocationSession extends Equatable {
  final String sessionId;
  final String chatId;
  final String senderId;
  final String senderName;
  final int durationSeconds; // 900 (15m) or 3600 (1h)
  final DateTime startedAt;
  final DateTime expiresAt;
  final LiveLocationStatus status;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? heading;
  final DateTime lastUpdatedAt;

  const LiveLocationSession({
    required this.sessionId,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.durationSeconds,
    required this.startedAt,
    required this.expiresAt,
    this.status = LiveLocationStatus.active,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.heading,
    required this.lastUpdatedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => status == LiveLocationStatus.active && !isExpired;

  int get remainingSeconds {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return 0;
    return expiresAt.difference(now).inSeconds;
  }

  LiveLocationSession copyWith({
    LiveLocationStatus? status,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? heading,
    DateTime? lastUpdatedAt,
  }) {
    return LiveLocationSession(
      sessionId: sessionId,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      durationSeconds: durationSeconds,
      startedAt: startedAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      heading: heading ?? this.heading,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'durationSeconds': durationSeconds,
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': status.name,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'heading': heading,
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
    };
  }

  factory LiveLocationSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LiveLocationSession.fromMap(data, id: doc.id);
  }

  factory LiveLocationSession.fromMap(Map<String, dynamic> data, {String? id}) {
    final statusStr = data['status'] as String? ?? 'active';
    LiveLocationStatus s = LiveLocationStatus.active;
    if (statusStr == 'stopped') {
      s = LiveLocationStatus.stopped;
    } else if (statusStr == 'expired') {
      s = LiveLocationStatus.expired;
    }

    DateTime started = DateTime.now();
    if (data['startedAt'] is Timestamp) {
      started = (data['startedAt'] as Timestamp).toDate();
    } else if (data['startedAt'] is int) {
      started = DateTime.fromMillisecondsSinceEpoch(data['startedAt'] as int);
    } else if (data['startedAt'] is String) {
      started = DateTime.tryParse(data['startedAt'] as String) ?? DateTime.now();
    } else if (data['startedAt'] is DateTime) {
      started = data['startedAt'] as DateTime;
    }

    DateTime expires = started.add(Duration(
        seconds: (data['durationSeconds'] as num?)?.toInt() ?? 900));
    if (data['expiresAt'] is Timestamp) {
      expires = (data['expiresAt'] as Timestamp).toDate();
    } else if (data['expiresAt'] is int) {
      expires = DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int);
    } else if (data['expiresAt'] is String) {
      expires = DateTime.tryParse(data['expiresAt'] as String) ?? expires;
    } else if (data['expiresAt'] is DateTime) {
      expires = data['expiresAt'] as DateTime;
    }

    DateTime updated = started;
    if (data['lastUpdatedAt'] is Timestamp) {
      updated = (data['lastUpdatedAt'] as Timestamp).toDate();
    } else if (data['lastUpdatedAt'] is int) {
      updated = DateTime.fromMillisecondsSinceEpoch(data['lastUpdatedAt'] as int);
    } else if (data['lastUpdatedAt'] is String) {
      updated = DateTime.tryParse(data['lastUpdatedAt'] as String) ?? updated;
    } else if (data['lastUpdatedAt'] is DateTime) {
      updated = data['lastUpdatedAt'] as DateTime;
    }

    if (s == LiveLocationStatus.active && DateTime.now().isAfter(expires)) {
      s = LiveLocationStatus.expired;
    }

    return LiveLocationSession(
      sessionId: id ?? (data['sessionId'] as String? ?? ''),
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 900,
      startedAt: started,
      expiresAt: expires,
      status: s,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      heading: (data['heading'] as num?)?.toDouble(),
      lastUpdatedAt: updated,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        chatId,
        senderId,
        senderName,
        durationSeconds,
        startedAt,
        expiresAt,
        status,
        latitude,
        longitude,
        accuracy,
        heading,
        lastUpdatedAt,
      ];
}
