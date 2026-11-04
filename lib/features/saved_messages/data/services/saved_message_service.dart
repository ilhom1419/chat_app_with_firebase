import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../messages/domain/entities/message.dart';
import '../../domain/entities/saved_message.dart';

class SavedMessageService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Uuid _uuid;

  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB max limit

  SavedMessageService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _uuid = uuid ?? const Uuid();

  CollectionReference<Map<String, dynamic>> _savedMessagesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_messages');
  }

  /// Real-time stream of user's private saved messages
  Stream<List<SavedMessage>> watchSavedMessages({
    required String uid,
    int limit = 100,
  }) {
    return _savedMessagesRef(uid)
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SavedMessage.fromFirestore(doc)).toList();
    });
  }

  /// Get one-shot list of saved messages
  Future<List<SavedMessage>> getSavedMessages({
    required String uid,
    int limit = 100,
  }) async {
    final query = await _savedMessagesRef(uid)
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .get();

    return query.docs.map((doc) => SavedMessage.fromFirestore(doc)).toList();
  }

  /// Save personal text note directly
  Future<SavedMessage> savePersonalNote({
    required String uid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Personal note text cannot be empty');
    }

    final savedId = _uuid.v4();
    final now = DateTime.now();

    final savedMessage = SavedMessage(
      savedId: savedId,
      ownerId: uid,
      type: SavedMessageType.text,
      text: trimmed,
      createdAt: now,
      isForwarded: false,
      uploadStatus: SavedMessageUploadStatus.completed,
    );

    await _savedMessagesRef(uid).doc(savedId).set(savedMessage.toMap(forFirestore: true));
    return savedMessage;
  }

  /// Forward an existing ordinary chat message to Saved Messages
  Future<SavedMessage> saveForwardedMessage({
    required String uid,
    required Message message,
    String? originalSenderName,
    String? originalChatId,
  }) async {
    // Restriction: Never allow secret chat messages to be forwarded
    if (originalChatId != null && originalChatId.startsWith('secret_')) {
      throw ArgumentError('Maxfiy chat xabarlarini saqlab bo‘lmaydi (Secret Chat E2EE protected)');
    }

    final savedId = _uuid.v4();
    final now = DateTime.now();

    // Map MessageType to SavedMessageType
    SavedMessageType savedType;
    String? attachmentUrl;
    String? attachmentName = message.fileName;
    int? attachmentDuration = message.duration;
    int? attachmentSize;

    if (message.fileSize != null) {
      final sizeInt = int.tryParse(message.fileSize!);
      if (sizeInt != null) {
        attachmentSize = sizeInt;
      }
    }

    switch (message.type) {
      case MessageType.image:
        savedType = SavedMessageType.image;
        attachmentUrl = message.imageUrl;
        break;
      case MessageType.voice:
        savedType = SavedMessageType.voice;
        attachmentUrl = message.fileUrl;
        break;
      case MessageType.file:
        savedType = SavedMessageType.document;
        attachmentUrl = message.fileUrl;
        break;
      default:
        savedType = SavedMessageType.text;
        break;
    }

    final savedMessage = SavedMessage(
      savedId: savedId,
      ownerId: uid,
      type: savedType,
      text: message.text,
      createdAt: now,
      originalSenderId: message.senderId,
      originalSenderName: originalSenderName ?? message.authorName ?? 'User',
      originalChatId: originalChatId,
      originalMessageId: message.id,
      isForwarded: true,
      originalMessageType: message.type.name,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentDuration: attachmentDuration,
      attachmentSize: attachmentSize,
      uploadStatus: SavedMessageUploadStatus.completed,
    );

    await _savedMessagesRef(uid).doc(savedId).set(savedMessage.toMap(forFirestore: true));
    return savedMessage;
  }

  /// Upload personal file (document, audio, image) to private Storage
  Future<SavedMessage> uploadPersonalFile({
    required String uid,
    required File file,
    required SavedMessageType type,
    String? customFileName,
    int? duration,
    void Function(double progress)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw ArgumentError('Tanlangan fayl mavjud emas');
    }

    final fileSizeBytes = await file.length();
    if (fileSizeBytes > maxFileSizeBytes) {
      throw ArgumentError('Fayl hajmi 50MB dan oshmasligi kerak (Maksimal hajm 50MB)');
    }

    final savedId = _uuid.v4();
    final fileId = _uuid.v4();
    final rawName = file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'file';
    final originalName = customFileName ?? rawName;
    final dotIndex = originalName.lastIndexOf('.');
    final ext = (dotIndex != -1 && dotIndex < originalName.length - 1)
        ? originalName.substring(dotIndex).toLowerCase()
        : '';
    final storagePath = 'users/$uid/saved_files/$fileId$ext';

    // Guess MIME type
    final mimeType = _resolveMimeType(ext, type);

    // Initial pending doc
    final initialSavedMessage = SavedMessage(
      savedId: savedId,
      ownerId: uid,
      type: type,
      text: null,
      createdAt: DateTime.now(),
      isForwarded: false,
      attachmentStoragePath: storagePath,
      attachmentName: originalName,
      attachmentMimeType: mimeType,
      attachmentSize: fileSizeBytes,
      attachmentDuration: duration,
      uploadStatus: SavedMessageUploadStatus.uploading,
    );

    // Save preliminary record so UI can show uploading state immediately
    await _savedMessagesRef(uid).doc(savedId).set(initialSavedMessage.toMap(forFirestore: true));

    try {
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'ownerId': uid,
          'savedId': savedId,
          'originalName': originalName,
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((taskSnapshot) {
          if (taskSnapshot.totalBytes > 0) {
            final progress = taskSnapshot.bytesTransferred / taskSnapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final completedMessage = initialSavedMessage.copyWith(
        attachmentUrl: downloadUrl,
        uploadStatus: SavedMessageUploadStatus.completed,
        updatedAt: DateTime.now(),
      );

      await _savedMessagesRef(uid).doc(savedId).update({
        'attachmentUrl': downloadUrl,
        'uploadStatus': SavedMessageUploadStatus.completed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return completedMessage;
    } catch (e) {
      debugPrint('Firebase Storage upload failed for saved file: $e. Attempting Base64 fallback...');
      
      // Fallback: If file is within reasonable size (< 7MB for Firestore document limit), convert to base64 Data URI
      if (fileSizeBytes <= 7 * 1024 * 1024) {
        try {
          final bytes = await file.readAsBytes();
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:$mimeType;base64,$base64String';

          final fallbackMessage = initialSavedMessage.copyWith(
            attachmentUrl: dataUrl,
            uploadStatus: SavedMessageUploadStatus.completed,
            updatedAt: DateTime.now(),
          );

          await _savedMessagesRef(uid).doc(savedId).update({
            'attachmentUrl': dataUrl,
            'uploadStatus': SavedMessageUploadStatus.completed.name,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return fallbackMessage;
        } catch (fallbackError) {
          debugPrint('Base64 fallback failed: $fallbackError');
        }
      }

      // Mark as failed in Firestore if fallback not applicable or failed
      await _savedMessagesRef(uid).doc(savedId).update({
        'uploadStatus': SavedMessageUploadStatus.failed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});

      debugPrint('Error uploading personal saved file: $e');
      rethrow;
    }
  }

  /// Delete an individual saved message and its private storage object if applicable
  Future<void> deleteSavedMessage({
    required String uid,
    required String savedId,
    String? storagePath,
  }) async {
    // 1. Delete Firestore record
    await _savedMessagesRef(uid).doc(savedId).delete();

    // 2. If storagePath is owned by this user, delete the Storage object
    if (storagePath != null && storagePath.startsWith('users/$uid/saved_files/')) {
      try {
        final ref = _storage.ref(storagePath);
        await ref.delete();
      } catch (e) {
        debugPrint('Warning: Could not delete private storage object $storagePath: $e');
      }
    }
  }

  /// Helper to determine MIME type from extension
  String _resolveMimeType(String ext, SavedMessageType type) {
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.txt':
        return 'text/plain';
      case '.zip':
        return 'application/zip';
      case '.rar':
        return 'application/x-rar-compressed';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.ogg':
        return 'audio/ogg';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        if (type == SavedMessageType.image) return 'image/jpeg';
        if (type == SavedMessageType.audio || type == SavedMessageType.voice) return 'audio/mpeg';
        return 'application/octet-stream';
    }
  }
}
