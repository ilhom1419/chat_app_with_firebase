import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/device_identity.dart';
import '../../domain/entities/secret_chat_session.dart';
import '../../domain/entities/secret_message.dart';
import '../../domain/entities/secret_media_payload.dart';
import '../../domain/repositories/secret_chat_repository.dart';
import '../services/secret_chat_crypto_service.dart';
import '../services/secret_chat_key_service.dart';
import '../services/secret_media_crypto_service.dart';

class SecretChatRepositoryImpl implements SecretChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SecretChatKeyService _keyService;
  final FlutterSecureStorage _secureStorage;
  final FirebaseStorage? _storage;
  late final SecretChatCryptoService _cryptoService;

  // In-memory cache for decrypted messages to prevent duplicate ratchet calls
  final Map<String, String> _decryptedCache = {};
  final Map<String, String> _errorCache = {};
  final Map<String, Uint8List> _mediaBytesCache = {};

  // Set of expired message IDs to prevent them from ever reappearing
  final Set<String> _expiredMessageIds = {};
  // Pending read receipts to avoid duplicate Firestore writes
  final Set<String> _pendingReadReceipts = {};

  SecretChatRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SecretChatKeyService? keyService,
    FlutterSecureStorage? secureStorage,
    SecretChatCryptoService? cryptoService,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _keyService = keyService ?? SecretChatKeyService(firestore: firestore),
        _secureStorage = secureStorage ??
            (keyService?.secureStorage ?? const FlutterSecureStorage()),
        _storage = storage {
    _cryptoService = cryptoService ??
        SecretChatCryptoService(
          firestore: _firestore,
          protocolStore: _keyService.protocolStore,
        );
  }

  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  SecretChatKeyService get keyService => _keyService;
  SecretChatCryptoService get cryptoService => _cryptoService;

  String? get _myUid => _auth.currentUser?.uid;

  @override
  Future<DeviceIdentity> getOrCreateLocalDeviceIdentity(String userId) async {
    return await _keyService.initializeDeviceKeys(userId);
  }

  @override
  Future<DeviceIdentity?> getRecipientDevice(String recipientUid) async {
    final query = await _firestore
        .collection('users')
        .doc(recipientUid)
        .collection('devices')
        .where('revoked', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    return DeviceIdentity.fromFirestore(doc.data(), doc.id);
  }

  @override
  Future<SecretChatSession> createSecretChatSession({
    required String recipientUid,
    required int selfDestructDuration,
  }) async {
    final myUid = _myUid;
    if (myUid == null) {
      throw Exception('Foydalanuvchi tizimga kirmagan');
    }

    if (myUid == recipientUid) {
      throw Exception('O\'zingiz bilan maxfiy chat boshlay olmaysiz');
    }

    // 1. My device identity
    final myDevice = await _keyService.initializeDeviceKeys(myUid);

    // 2. Recipient device identity
    final recipientDevice = await getRecipientDevice(recipientUid);
    if (recipientDevice == null) {
      throw Exception('Foydalanuvchida faol maxfiy chat qurilmasi yo‘q');
    }

    // 3. Generate unique secret chatId
    final chatId = 'secret_${const Uuid().v4()}';
    final chatDocRef = _firestore.collection('secret_chats').doc(chatId);

    final session = SecretChatSession(
      chatId: chatId,
      initiatorUid: myUid,
      initiatorDeviceId: myDevice.deviceId,
      recipientUid: recipientUid,
      recipientDeviceId: recipientDevice.deviceId,
      participants: [myUid, recipientUid],
      selfDestructDuration: selfDestructDuration,
      status: 'active',
      createdAt: DateTime.now(),
    );

    await chatDocRef.set({
      'chatId': chatId,
      'initiatorUid': session.initiatorUid,
      'initiatorDeviceId': session.initiatorDeviceId,
      'recipientUid': session.recipientUid,
      'recipientDeviceId': session.recipientDeviceId,
      'participants': session.participants,
      'selfDestructDuration': session.selfDestructDuration,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return session;
  }

  @override
  Stream<SecretChatSession?> watchSecretChatSession(String chatId) {
    return _firestore
        .collection('secret_chats')
        .doc(chatId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return SecretChatSession.fromFirestore(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Future<void> terminateSecretChat(String chatId) async {
    await _firestore.collection('secret_chats').doc(chatId).update({
      'status': 'terminated',
    });
  }

  @override
  Future<void> updateSelfDestructDuration(
      String chatId, int durationInSeconds) async {
    await _firestore.collection('secret_chats').doc(chatId).update({
      'selfDestructDuration': durationInSeconds,
    });
  }

  @override
  Stream<List<SecretMessage>> watchSecretMessages(String chatId) {
    return _firestore
        .collection('secret_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final myUid = _myUid ?? '';
      final List<SecretMessage> result = [];

      for (final doc in snapshot.docs) {
        // 1. If already marked as expired locally, trigger delete and skip
        if (_expiredMessageIds.contains(doc.id)) {
          _deleteFromServerSilently(chatId, doc.id);
          continue;
        }

        final isExpStored =
            await _secureStorage.read(key: 'expired_${doc.id}');
        if (isExpStored != null) {
          _expiredMessageIds.add(doc.id);
          _deleteFromServerSilently(chatId, doc.id);
          continue;
        }

        var msg = SecretMessage.fromFirestore(
          doc.data(),
          doc.id,
          currentUserId: myUid,
        );

        // 2. Check if message has already expired according to readAt + duration
        if (msg.isExpired) {
          _expiredMessageIds.add(msg.messageId);
          await _secureStorage.write(
              key: 'expired_${msg.messageId}', value: '1');
          _decryptedCache.remove(msg.messageId);
          await _secureStorage.delete(key: 'decrypted_${msg.messageId}');
          _deleteFromServerSilently(chatId, msg.messageId);
          continue;
        }

        // Check local decrypted cache or storage first
        String? cachedText = _decryptedCache[msg.messageId];
        if (cachedText == null) {
          cachedText =
              await _secureStorage.read(key: 'decrypted_${msg.messageId}');
          if (cachedText != null) {
            _decryptedCache[msg.messageId] = cachedText;
          }
        }

        if (cachedText != null) {
          if (SecretMediaCryptoService.isMediaPayload(cachedText)) {
            final payload = SecretMediaCryptoService.parseMediaPayload(cachedText);
            if (payload != null) {
              final decryptedBytes = _mediaBytesCache[payload.mediaId];
              msg = msg.copyWith(
                mediaPayload: payload.copyWith(decryptedBytes: decryptedBytes),
              );
            }
          } else {
            msg = msg.copyWith(decryptedText: cachedText);
          }
        } else if (msg.isOutgoing) {
          // Outgoing message with no cached text
        } else if (_errorCache.containsKey(msg.messageId)) {
          msg = msg.copyWith(decryptionError: _errorCache[msg.messageId]);
        } else {
          // Incoming message needing decryption via Signal Protocol
          try {
            final plaintext = await _cryptoService.decryptMessage(
              remoteUid: msg.senderId,
              remoteDeviceId: msg.senderDeviceId,
              payload: msg.payload,
              envelopeType: msg.envelopeType,
            );
            _decryptedCache[msg.messageId] = plaintext;
            await _secureStorage.write(
              key: 'decrypted_${msg.messageId}',
              value: plaintext,
            );
            if (SecretMediaCryptoService.isMediaPayload(plaintext)) {
              final payload = SecretMediaCryptoService.parseMediaPayload(plaintext);
              if (payload != null) {
                final decryptedBytes = _mediaBytesCache[payload.mediaId];
                msg = msg.copyWith(
                  mediaPayload: payload.copyWith(decryptedBytes: decryptedBytes),
                );
              }
            } else {
              msg = msg.copyWith(decryptedText: plaintext);
            }
          } catch (e) {
            final errMsg = e.toString();
            _errorCache[msg.messageId] = errMsg;
            msg = msg.copyWith(decryptionError: errMsg);
          }
        }

        result.add(msg);
      }

      return result;
    });
  }

  @override
  Future<void> sendSecretMessage({
    required SecretChatSession session,
    required String plaintext,
  }) async {
    final myUid = _myUid;
    if (myUid == null) {
      throw Exception('Foydalanuvchi tizimga kirmagan');
    }

    if (session.isTerminated) {
      throw Exception(
          'Ushbu maxfiy chat yakunlangan. Yangi xabar yuborib bo‘lmaydi.');
    }

    final otherUid = session.getOtherUserId(myUid);
    final otherDeviceId = session.getOtherDeviceId(myUid);
    final myDeviceId = session.getMyDeviceId(myUid);

    // 1. Encrypt message locally using Signal Protocol SessionCipher
    final encryptedData = await _cryptoService.encryptMessage(
      remoteUid: otherUid,
      remoteDeviceId: otherDeviceId,
      plaintext: plaintext,
    );

    final payload = encryptedData['payload'] as String;
    final envelopeType = encryptedData['envelopeType'] as int;
    final messageId = 'msg_${const Uuid().v4()}';

    // 2. Cache plaintext locally before sending
    _decryptedCache[messageId] = plaintext;
    await _secureStorage.write(
      key: 'decrypted_$messageId',
      value: plaintext,
    );

    // 3. Upload only encrypted ciphertext envelope to Firestore
    await _firestore
        .collection('secret_chats')
        .doc(session.chatId)
        .collection('messages')
        .doc(messageId)
        .set({
      'messageId': messageId,
      'chatId': session.chatId,
      'protocolVersion': 1,
      'envelopeType': envelopeType,
      'senderId': myUid,
      'senderDeviceId': myDeviceId,
      'recipientDeviceId': otherDeviceId,
      'payload': payload,
      'selfDestructDuration': session.selfDestructDuration,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'readAt': null,
    });
  }

  @override
  Future<String> decryptSecretMessage({
    required SecretMessage message,
    required SecretChatSession session,
  }) async {
    if (_decryptedCache.containsKey(message.messageId)) {
      return _decryptedCache[message.messageId]!;
    }

    final cached =
        await _secureStorage.read(key: 'decrypted_${message.messageId}');
    if (cached != null) {
      _decryptedCache[message.messageId] = cached;
      return cached;
    }

    if (message.isOutgoing) {
      return message.decryptedText ?? '';
    }

    try {
      final plaintext = await _cryptoService.decryptMessage(
        remoteUid: message.senderId,
        remoteDeviceId: message.senderDeviceId,
        payload: message.payload,
        envelopeType: message.envelopeType,
      );
      _decryptedCache[message.messageId] = plaintext;
      await _secureStorage.write(
        key: 'decrypted_${message.messageId}',
        value: plaintext,
      );
      return plaintext;
    } catch (e) {
      _errorCache[message.messageId] = e.toString();
      rethrow;
    }
  }

  @override
  Future<bool> hasEstablishedSession({
    required SecretChatSession session,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return false;
    final otherUid = session.getOtherUserId(myUid);
    final otherDeviceId = session.getOtherDeviceId(myUid);
    final address = _cryptoService.getAddress(otherUid, otherDeviceId);
    return await _cryptoService.protocolStore.containsSession(address);
  }

  @override
  Future<String> getSafetyNumber({
    required SecretChatSession session,
  }) async {
    final myUid = _myUid;
    if (myUid == null) {
      throw Exception('Foydalanuvchi tizimga kirmagan');
    }
    final otherUid = session.getOtherUserId(myUid);
    final otherDeviceId = session.getOtherDeviceId(myUid);
    return await _cryptoService.generateSafetyNumber(
      myUid: myUid,
      remoteUid: otherUid,
      remoteDeviceId: otherDeviceId,
    );
  }

  @override
  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return;

    if (_pendingReadReceipts.contains(messageId)) return;
    _pendingReadReceipts.add(messageId);

    try {
      final docRef = _firestore
          .collection('secret_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data();
      if (data == null) return;

      // Only recipient can mark as read, and only if not already marked
      if (data['senderId'] != myUid && data['isRead'] != true) {
        await docRef.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Ignore network errors gracefully
    }
  }

  @override
  Future<void> deleteSecretMessage({
    required String chatId,
    required String messageId,
  }) async {
    _expiredMessageIds.add(messageId);
    String? cached = _decryptedCache.remove(messageId);
    cached ??= await _secureStorage.read(key: 'decrypted_$messageId');
    await _secureStorage.write(key: 'expired_$messageId', value: '1');
    await _secureStorage.delete(key: 'decrypted_$messageId');

    // If this was an encrypted media message, clean up Storage and in-memory cache
    if (cached != null && SecretMediaCryptoService.isMediaPayload(cached)) {
      final payload = SecretMediaCryptoService.parseMediaPayload(cached);
      if (payload != null) {
        _mediaBytesCache.remove(payload.mediaId);
        try {
          await storage.ref().child(payload.storagePath).delete();
        } catch (_) {}
      }
    }

    try {
      await _firestore
          .collection('secret_chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (_) {
      // Safe if already deleted
    }
  }

  @override
  Future<void> sendSecretImage({
    required SecretChatSession session,
    required List<int> imageBytes,
    String? caption,
    int? width,
    int? height,
    String mimeType = 'image/jpeg',
  }) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Foydalanuvchi tizimga kirmagan');
    if (session.isTerminated) {
      throw Exception('Ushbu maxfiy chat yakunlangan. Yangi xabar yuborib bo‘lmaydi.');
    }

    final rawBytes = Uint8List.fromList(imageBytes);
    final mediaId = 'media_${const Uuid().v4()}';
    final key = SecretMediaCryptoService.generateKey();
    final nonce = SecretMediaCryptoService.generateNonce();
    final associatedData = Uint8List.fromList(utf8.encode(mediaId));

    // 1. Encrypt image locally with AES-256-GCM
    final encryptedBytes = SecretMediaCryptoService.encryptMedia(
      plaintextBytes: rawBytes,
      key: key,
      nonce: nonce,
      associatedData: associatedData,
    );

    // 2. Upload ONLY encrypted bytes to Firebase Storage
    final storagePath = 'secret_chats/${session.chatId}/media/$mediaId';
    String downloadUrl = '';
    try {
      final storageRef = storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/octet-stream',
        customMetadata: {
          'encrypted': 'true',
          'cipher': 'AES-256-GCM',
          'mediaId': mediaId,
        },
      );
      final uploadTask = await storageRef.putData(encryptedBytes, metadata);
      downloadUrl = await uploadTask.ref.getDownloadURL();
    } catch (_) {
      downloadUrl = 'https://firebasestorage.local/v0/b/default/o/$storagePath';
    }

    // Cache local plaintext bytes in memory for sender
    _mediaBytesCache[mediaId] = rawBytes;

    // 3. Assemble SecretMediaPayload
    final payload = SecretMediaPayload(
      type: SecretMediaType.image,
      mediaId: mediaId,
      storagePath: storagePath,
      mediaUrl: downloadUrl,
      keyBase64: base64Encode(key),
      nonceBase64: base64Encode(nonce),
      caption: caption,
      width: width,
      height: height,
      size: encryptedBytes.length,
      mimeType: mimeType,
      decryptedBytes: rawBytes,
    );

    // 4. Encrypt payload JSON using Signal Protocol
    final payloadJson = SecretMediaCryptoService.encodeMediaPayload(payload);
    await sendSecretMessage(
      session: session,
      plaintext: payloadJson,
    );
  }

  @override
  Future<void> sendSecretVoice({
    required SecretChatSession session,
    required List<int> audioBytes,
    required int durationSeconds,
    String mimeType = 'audio/m4a',
  }) async {
    final myUid = _myUid;
    if (myUid == null) throw Exception('Foydalanuvchi tizimga kirmagan');
    if (session.isTerminated) {
      throw Exception('Ushbu maxfiy chat yakunlangan. Yangi xabar yuborib bo‘lmaydi.');
    }

    final rawBytes = Uint8List.fromList(audioBytes);
    final mediaId = 'media_${const Uuid().v4()}';
    final key = SecretMediaCryptoService.generateKey();
    final nonce = SecretMediaCryptoService.generateNonce();
    final associatedData = Uint8List.fromList(utf8.encode(mediaId));

    // 1. Encrypt audio locally with AES-256-GCM
    final encryptedBytes = SecretMediaCryptoService.encryptMedia(
      plaintextBytes: rawBytes,
      key: key,
      nonce: nonce,
      associatedData: associatedData,
    );

    // 2. Upload ONLY encrypted bytes to Firebase Storage
    final storagePath = 'secret_chats/${session.chatId}/media/$mediaId';
    String downloadUrl = '';
    try {
      final storageRef = storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'application/octet-stream',
        customMetadata: {
          'encrypted': 'true',
          'cipher': 'AES-256-GCM',
          'mediaId': mediaId,
        },
      );
      final uploadTask = await storageRef.putData(encryptedBytes, metadata);
      downloadUrl = await uploadTask.ref.getDownloadURL();
    } catch (_) {
      downloadUrl = 'https://firebasestorage.local/v0/b/default/o/$storagePath';
    }

    _mediaBytesCache[mediaId] = rawBytes;

    // 3. Assemble SecretMediaPayload
    final payload = SecretMediaPayload(
      type: SecretMediaType.voice,
      mediaId: mediaId,
      storagePath: storagePath,
      mediaUrl: downloadUrl,
      keyBase64: base64Encode(key),
      nonceBase64: base64Encode(nonce),
      durationSeconds: durationSeconds,
      size: encryptedBytes.length,
      mimeType: mimeType,
      decryptedBytes: rawBytes,
    );

    // 4. Encrypt payload JSON using Signal Protocol
    final payloadJson = SecretMediaCryptoService.encodeMediaPayload(payload);
    await sendSecretMessage(
      session: session,
      plaintext: payloadJson,
    );
  }

  @override
  Future<List<int>> downloadAndDecryptMedia({
    required SecretMediaPayload payload,
  }) async {
    // 1. Return in-memory cached decrypted bytes if available
    if (_mediaBytesCache.containsKey(payload.mediaId)) {
      return _mediaBytesCache[payload.mediaId]!;
    }

    // 2. Fetch encrypted bytes from Firebase Storage
    Uint8List? encryptedBytes;
    try {
      final storageRef = storage.ref().child(payload.storagePath);
      encryptedBytes = await storageRef.getData(SecretMediaCryptoService.maxMediaSizeBytes);
    } catch (_) {}

    if (encryptedBytes == null || encryptedBytes.isEmpty) {
      throw Exception('Shifrlangan media faylni yuklab bo‘lmadi');
    }

    // 3. Decrypt locally with AES-256-GCM
    final key = base64Decode(payload.keyBase64);
    final nonce = base64Decode(payload.nonceBase64);
    final associatedData = Uint8List.fromList(utf8.encode(payload.mediaId));

    final decrypted = SecretMediaCryptoService.decryptMedia(
      ciphertextAndTag: encryptedBytes,
      key: key,
      nonce: nonce,
      associatedData: associatedData,
    );

    _mediaBytesCache[payload.mediaId] = decrypted;
    return decrypted;
  }

  void _deleteFromServerSilently(String chatId, String messageId) {
    _firestore
        .collection('secret_chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete()
        .catchError((_) {});
  }
}
