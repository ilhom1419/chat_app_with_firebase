import '../entities/device_identity.dart';
import '../entities/secret_chat_session.dart';
import '../entities/secret_message.dart';
import '../entities/secret_media_payload.dart';

abstract class SecretChatRepository {
  /// Local device identity (generates keys if not present, registers on Firestore)
  Future<DeviceIdentity> getOrCreateLocalDeviceIdentity(String userId);

  /// Fetch recipient's active device
  Future<DeviceIdentity?> getRecipientDevice(String recipientUid);

  /// Create a new secret chat session in Firestore
  Future<SecretChatSession> createSecretChatSession({
    required String recipientUid,
    required int selfDestructDuration,
  });

  /// Listen to secret chat session state
  Stream<SecretChatSession?> watchSecretChatSession(String chatId);

  /// Terminate a secret chat session
  Future<void> terminateSecretChat(String chatId);

  /// Update self-destruct timer
  Future<void> updateSelfDestructDuration(String chatId, int durationInSeconds);

  /// Realtime stream of messages in the secret chat
  Stream<List<SecretMessage>> watchSecretMessages(String chatId);

  /// Encrypt and send message via Signal Protocol
  Future<void> sendSecretMessage({
    required SecretChatSession session,
    required String plaintext,
  });

  /// Decrypt a single received message
  Future<String> decryptSecretMessage({
    required SecretMessage message,
    required SecretChatSession session,
  });

  /// Check if a cryptographic session is already established
  Future<bool> hasEstablishedSession({
    required SecretChatSession session,
  });

  /// Calculate 60-digit Safety Number for identity key verification
  Future<String> getSafetyNumber({
    required SecretChatSession session,
  });

  /// Mark an incoming secret message as read (starts self-destruct countdown)
  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
  });

  /// Delete an expired secret message permanently from local storage and Firestore
  Future<void> deleteSecretMessage({
    required String chatId,
    required String messageId,
  });

  /// Encrypt and send an image via AES-256-GCM + Signal Protocol
  Future<void> sendSecretImage({
    required SecretChatSession session,
    required List<int> imageBytes,
    String? caption,
    int? width,
    int? height,
    String mimeType = 'image/jpeg',
  });

  /// Encrypt and send a voice message via AES-256-GCM + Signal Protocol
  Future<void> sendSecretVoice({
    required SecretChatSession session,
    required List<int> audioBytes,
    required int durationSeconds,
    String mimeType = 'audio/m4a',
  });

  /// Download and decrypt media (images / voice) using AES-256-GCM
  Future<List<int>> downloadAndDecryptMedia({
    required SecretMediaPayload payload,
  });
}
