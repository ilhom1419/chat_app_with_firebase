import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum ScheduledMessageStatus {
  pending,
  sending,
  sent,
  canceled,
  failed,
}

class ScheduledMessage extends Equatable {
  final String scheduledMessageId;
  final String messageId;
  final String senderId;
  final String chatId;
  final String text;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final String? timezoneId;
  final bool isSilent;
  final ScheduledMessageStatus status;
  final DateTime? sentAt;
  final String? lastError;

  const ScheduledMessage({
    required this.scheduledMessageId,
    required this.messageId,
    required this.senderId,
    required this.chatId,
    required this.text,
    required this.scheduledAt,
    required this.createdAt,
    this.timezoneId,
    this.isSilent = false,
    this.status = ScheduledMessageStatus.pending,
    this.sentAt,
    this.lastError,
  });

  bool get isPending => status == ScheduledMessageStatus.pending;
  bool get isDue => DateTime.now().isAfter(scheduledAt) || DateTime.now().isAtSameMomentAs(scheduledAt);
  bool get isSent => status == ScheduledMessageStatus.sent;
  bool get isCanceled => status == ScheduledMessageStatus.canceled;

  ScheduledMessage copyWith({
    String? scheduledMessageId,
    String? messageId,
    String? senderId,
    String? chatId,
    String? text,
    DateTime? scheduledAt,
    DateTime? createdAt,
    String? timezoneId,
    bool? isSilent,
    ScheduledMessageStatus? status,
    DateTime? sentAt,
    String? lastError,
  }) {
    return ScheduledMessage(
      scheduledMessageId: scheduledMessageId ?? this.scheduledMessageId,
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      chatId: chatId ?? this.chatId,
      text: text ?? this.text,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      timezoneId: timezoneId ?? this.timezoneId,
      isSilent: isSilent ?? this.isSilent,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduledMessageId': scheduledMessageId,
      'messageId': messageId,
      'senderId': senderId,
      'chatId': chatId,
      'text': text,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'timezoneId': timezoneId,
      'isSilent': isSilent,
      'status': status.name,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'lastError': lastError,
    };
  }

  factory ScheduledMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ScheduledMessage.fromMap(data, id: doc.id);
  }

  factory ScheduledMessage.fromMap(Map<String, dynamic> data, {String? id}) {
    final statusStr = data['status'] as String? ?? 'pending';
    ScheduledMessageStatus status = ScheduledMessageStatus.pending;
    for (final s in ScheduledMessageStatus.values) {
      if (s.name == statusStr) {
        status = s;
        break;
      }
    }

    DateTime scheduled = DateTime.now();
    if (data['scheduledAt'] is Timestamp) {
      scheduled = (data['scheduledAt'] as Timestamp).toDate();
    } else if (data['scheduledAt'] is int) {
      scheduled = DateTime.fromMillisecondsSinceEpoch(data['scheduledAt'] as int);
    } else if (data['scheduledAt'] is String) {
      scheduled = DateTime.tryParse(data['scheduledAt'] as String) ?? scheduled;
    } else if (data['scheduledAt'] is DateTime) {
      scheduled = data['scheduledAt'] as DateTime;
    }

    DateTime created = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is int) {
      created = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String) ?? created;
    } else if (data['createdAt'] is DateTime) {
      created = data['createdAt'] as DateTime;
    }

    DateTime? sent;
    if (data['sentAt'] is Timestamp) {
      sent = (data['sentAt'] as Timestamp).toDate();
    } else if (data['sentAt'] is int) {
      sent = DateTime.fromMillisecondsSinceEpoch(data['sentAt'] as int);
    } else if (data['sentAt'] is String) {
      sent = DateTime.tryParse(data['sentAt'] as String);
    } else if (data['sentAt'] is DateTime) {
      sent = data['sentAt'] as DateTime;
    }

    return ScheduledMessage(
      scheduledMessageId: id ?? (data['scheduledMessageId'] as String? ?? ''),
      messageId: data['messageId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      chatId: data['chatId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      scheduledAt: scheduled,
      createdAt: created,
      timezoneId: data['timezoneId'] as String?,
      isSilent: data['isSilent'] as bool? ?? false,
      status: status,
      sentAt: sent,
      lastError: data['lastError'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        scheduledMessageId,
        messageId,
        senderId,
        chatId,
        text,
        scheduledAt,
        createdAt,
        timezoneId,
        isSilent,
        status,
        sentAt,
        lastError,
      ];
}
