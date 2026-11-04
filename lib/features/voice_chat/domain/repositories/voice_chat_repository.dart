import '../../domain/entities/voice_chat.dart';

abstract class VoiceChatRepository {
  /// Guruh yoki kanal uchun faol ovozli efirni kuzatish
  Stream<VoiceChat?> watchActiveVoiceChat(String chatId);

  /// Yangi ovozli efir boshlash
  Future<VoiceChat> startVoiceChat({
    required String chatId,
    required String title,
    required String hostId,
    required String hostName,
    String? hostPhoto,
    bool isChannel = false,
  });

  /// Ovozli efirni yakunlash (Host)
  Future<void> endVoiceChat(String chatId);

  /// Efirga tinglovchi sifatida qo'shilish
  Future<void> joinVoiceChat({
    required String chatId,
    required String userId,
    required String userName,
    String? userPhoto,
  });

  /// Efirni tark etish
  Future<void> leaveVoiceChat({
    required String chatId,
    required String userId,
  });

  /// So'z olish uchun qo'l ko'tarish (Raise Hand)
  Future<void> raiseHand({
    required String chatId,
    required String userId,
  });

  /// Qo'lni tushirish (Lower Hand)
  Future<void> lowerHand({
    required String chatId,
    required String userId,
  });

  /// Admin tomonidan so'z berish (Mikrofonga ruxsat berish)
  Future<void> grantSpeakPermission({
    required String chatId,
    required String targetUserId,
  });

  /// Spikerlik huquqini qaytarib olish (Tinglovchi qilish)
  Future<void> revokeSpeakPermission({
    required String chatId,
    required String targetUserId,
  });

  /// Mikrofonni yoqish / o'chirish (Mute / Unmute)
  Future<void> toggleMute({
    required String chatId,
    required String userId,
    required bool isMuted,
  });

  /// Foydalanuvchining gapirayotgani holatini belgilash
  Future<void> setSpeaking({
    required String chatId,
    required String userId,
    required bool isSpeaking,
  });
}
