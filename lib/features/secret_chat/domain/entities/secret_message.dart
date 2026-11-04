import 'package:equatable/equatable.dart';
import 'secret_media_payload.dart';

class SecretMessage extends Equatable {
  final String messageId;
  final String chatId;
  final String senderId;
  final String senderDeviceId;
  final String recipientDeviceId;
  final String payload; // Base64 serialized Signal message
  final int envelopeType; // 1: PreKeySignalMessage, 2: SignalMessage
  final int selfDestructDuration;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  // Transient in-memory decrypted fields (NEVER uploaded to Firestore)
  final String? decryptedText;
  final String? decryptionError;
  final bool isOutgoing;
  final SecretMediaPayload? mediaPayload;

  const SecretMessage({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.payload,
    required this.envelopeType,
    required this.selfDestructDuration,
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.decryptedText,
    this.decryptionError,
    this.isOutgoing = false,
    this.mediaPayload,
  });

  bool get isDecrypted => (decryptedText != null || mediaPayload != null) && decryptionError == null;
  bool get hasError => decryptionError != null;
  bool get isMedia => mediaPayload != null;
  bool get isImage => mediaPayload?.isImage ?? false;
  bool get isVoice => mediaPayload?.isVoice ?? false;

  /// Expiration deadline calculated from readAt + selfDestructDuration
  DateTime? get expiresAt {
    if (selfDestructDuration <= 0 || !isRead || readAt == null) {
      return null;
    }
    return readAt!.add(Duration(seconds: selfDestructDuration));
  }

  /// Whether the message has exceeded its self-destruct deadline
  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// Remaining duration before self-destruction
  Duration? get remainingTime {
    final exp = expiresAt;
    if (exp == null) return null;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Whether this message has an active countdown running
  bool get isCountdownActive =>
      selfDestructDuration > 0 && isRead && readAt != null && !isExpired;

  factory SecretMessage.fromFirestore(
    Map<String, dynamic> data,
    String id, {
    String currentUserId = '',
  }) {
    final sender = data['senderId'] as String? ?? '';
    return SecretMessage(
      messageId: id,
      chatId: data['chatId'] as String? ?? '',
      senderId: sender,
      senderDeviceId: data['senderDeviceId'] as String? ?? '',
      recipientDeviceId: data['recipientDeviceId'] as String? ?? '',
      payload: data['payload'] as String? ?? '',
      envelopeType: data['envelopeType'] as int? ?? 1,
      selfDestructDuration: data['selfDestructDuration'] as int? ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      readAt: data['readAt'] != null
          ? (data['readAt'] as dynamic).toDate()
          : null,
      isOutgoing: currentUserId.isNotEmpty && sender == currentUserId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'protocolVersion': 1,
      'envelopeType': envelopeType,
      'senderId': senderId,
      'senderDeviceId': senderDeviceId,
      'recipientDeviceId': recipientDeviceId,
      'payload': payload,
      'selfDestructDuration': selfDestructDuration,
      'createdAt': createdAt,
      'isRead': isRead,
      'readAt': readAt,
    };
  }

  SecretMessage copyWith({
    String? messageId,
    String? chatId,
    String? senderId,
    String? senderDeviceId,
    String? recipientDeviceId,
    String? payload,
    int? envelopeType,
    int? selfDestructDuration,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? decryptedText,
    String? decryptionError,
    bool? isOutgoing,
    SecretMediaPayload? mediaPayload,
  }) {
    return SecretMessage(
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      recipientDeviceId: recipientDeviceId ?? this.recipientDeviceId,
      payload: payload ?? this.payload,
      envelopeType: envelopeType ?? this.envelopeType,
      selfDestructDuration: selfDestructDuration ?? this.selfDestructDuration,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      decryptedText: decryptedText ?? this.decryptedText,
      decryptionError: decryptionError ?? this.decryptionError,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      mediaPayload: mediaPayload ?? this.mediaPayload,
    );
  }

  @override
  List<Object?> get props => [
        messageId,
        chatId,
        senderId,
        senderDeviceId,
        recipientDeviceId,
        payload,
        envelopeType,
        selfDestructDuration,
        createdAt,
        isRead,
        readAt,
        decryptedText,
        decryptionError,
        isOutgoing,
        mediaPayload,
      ];
}
