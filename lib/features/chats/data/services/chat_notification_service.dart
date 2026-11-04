import 'package:cloud_firestore/cloud_firestore.dart';

class ChatNotificationService {
  final FirebaseFirestore _firestore;
  static final Map<String, bool> _localMutedMap = {};

  ChatNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static String _key(String? userId, String chatId) {
    if (userId != null && userId.isNotEmpty) {
      return '$userId:$chatId';
    }
    return chatId;
  }

  /// Fast synchronous check for NotificationService
  static bool isChatMuted(String chatId, {String? userId}) {
    if (userId != null && userId.isNotEmpty) {
      return _localMutedMap[_key(userId, chatId)] ?? false;
    }
    return _localMutedMap[chatId] ?? false;
  }

  /// Sets local cache value directly (e.g. for testing)
  static void setLocalMutedForTesting(String chatId, bool isMuted, {String? userId}) {
    if (userId != null && userId.isNotEmpty) {
      _localMutedMap[_key(userId, chatId)] = isMuted;
    } else {
      _localMutedMap[chatId] = isMuted;
    }
  }

  /// Clears cache for testing isolation
  static void clearCacheForTesting() {
    _localMutedMap.clear();
  }

  DocumentReference<Map<String, dynamic>> _muteDoc(String userId, String chatId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('muted_chats')
        .doc(chatId);
  }

  /// Real-time stream of mute status for a specific chat and user
  Stream<bool> watchMuteStatus(String userId, String chatId) {
    if (userId.isEmpty || chatId.isEmpty) {
      return Stream.value(false);
    }

    return _muteDoc(userId, chatId).snapshots().map((doc) {
      final isMuted = doc.exists && (doc.data()?['isMuted'] as bool? ?? false);
      _localMutedMap[_key(userId, chatId)] = isMuted;
      _localMutedMap[chatId] = isMuted;
      return isMuted;
    });
  }

  /// Get one-shot mute status
  Future<bool> getMuteStatus(String userId, String chatId) async {
    if (userId.isEmpty || chatId.isEmpty) return false;
    try {
      final doc = await _muteDoc(userId, chatId).get();
      final isMuted = doc.exists && (doc.data()?['isMuted'] as bool? ?? false);
      _localMutedMap[_key(userId, chatId)] = isMuted;
      _localMutedMap[chatId] = isMuted;
      return isMuted;
    } catch (_) {
      return false;
    }
  }

  /// Toggle mute status
  Future<bool> toggleMute(String userId, String chatId) async {
    final currentStatus = await getMuteStatus(userId, chatId);
    final newStatus = !currentStatus;
    await setMuted(userId, chatId, newStatus);
    return newStatus;
  }

  /// Explicitly set mute status
  Future<void> setMuted(String userId, String chatId, bool isMuted) async {
    if (userId.isEmpty || chatId.isEmpty) return;

    _localMutedMap[_key(userId, chatId)] = isMuted;
    _localMutedMap[chatId] = isMuted;
    await _muteDoc(userId, chatId).set({
      'chatId': chatId,
      'isMuted': isMuted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
