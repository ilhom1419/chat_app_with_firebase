import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/voice_chat.dart';
import '../../domain/repositories/voice_chat_repository.dart';
import '../models/voice_chat_model.dart';

class VoiceChatRepositoryImpl implements VoiceChatRepository {
  final FirebaseFirestore _firestore;

  VoiceChatRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _voiceChatsCollection =>
      _firestore.collection('voice_chats');

  @override
  Stream<VoiceChat?> watchActiveVoiceChat(String chatId) {
    return _voiceChatsCollection.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final model = VoiceChatModel.fromFirestore(doc);
      return model.isActive ? model : null;
    });
  }

  @override
  Future<VoiceChat> startVoiceChat({
    required String chatId,
    required String title,
    required String hostId,
    required String hostName,
    String? hostPhoto,
    bool isChannel = false,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    final now = DateTime.now();

    final hostParticipant = VoiceChatParticipant(
      userId: hostId,
      name: hostName,
      photo: hostPhoto,
      isHost: true,
      canSpeak: true,
      isMuted: false,
      isSpeaking: false,
      isHandRaised: false,
      joinedAt: now,
    );

    final voiceChat = VoiceChatModel(
      id: chatId,
      chatId: chatId,
      title: title,
      hostId: hostId,
      hostName: hostName,
      hostPhoto: hostPhoto,
      isChannel: isChannel,
      isActive: true,
      startedAt: now,
      participants: {hostId: hostParticipant},
    );

    final batch = _firestore.batch();
    batch.set(docRef, voiceChat.toJson());
    // Update chat document to mark active live voice chat
    batch.update(_firestore.collection('chats').doc(chatId), {
      'hasActiveVoiceChat': true,
    });

    await batch.commit();
    return voiceChat;
  }

  @override
  Future<void> endVoiceChat(String chatId) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    final batch = _firestore.batch();

    batch.update(docRef, {
      'isActive': false,
      'endedAt': Timestamp.fromDate(DateTime.now()),
    });

    batch.update(_firestore.collection('chats').doc(chatId), {
      'hasActiveVoiceChat': false,
    });

    await batch.commit();
  }

  @override
  Future<void> joinVoiceChat({
    required String chatId,
    required String userId,
    required String userName,
    String? userPhoto,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    final participant = VoiceChatParticipant(
      userId: userId,
      name: userName,
      photo: userPhoto,
      isHost: false,
      canSpeak: false,
      isMuted: true,
      isSpeaking: false,
      isHandRaised: false,
      joinedAt: DateTime.now(),
    );

    await docRef.update({
      'participants.$userId': participant.toMap(),
    });
  }

  @override
  Future<void> leaveVoiceChat({
    required String chatId,
    required String userId,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$userId': FieldValue.delete(),
    });
  }

  @override
  Future<void> raiseHand({
    required String chatId,
    required String userId,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$userId.isHandRaised': true,
    });
  }

  @override
  Future<void> lowerHand({
    required String chatId,
    required String userId,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$userId.isHandRaised': false,
    });
  }

  @override
  Future<void> grantSpeakPermission({
    required String chatId,
    required String targetUserId,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$targetUserId.canSpeak': true,
      'participants.$targetUserId.isHandRaised': false,
      'participants.$targetUserId.isMuted': false,
    });
  }

  @override
  Future<void> revokeSpeakPermission({
    required String chatId,
    required String targetUserId,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$targetUserId.canSpeak': false,
      'participants.$targetUserId.isMuted': true,
      'participants.$targetUserId.isSpeaking': false,
    });
  }

  @override
  Future<void> toggleMute({
    required String chatId,
    required String userId,
    required bool isMuted,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$userId.isMuted': isMuted,
      if (isMuted) 'participants.$userId.isSpeaking': false,
    });
  }

  @override
  Future<void> setSpeaking({
    required String chatId,
    required String userId,
    required bool isSpeaking,
  }) async {
    final docRef = _voiceChatsCollection.doc(chatId);
    await docRef.update({
      'participants.$userId.isSpeaking': isSpeaking,
    });
  }
}
