import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../../domain/entities/secret_media_payload.dart';

/// SecretMediaCryptoService handles local symmetric AEAD (AES-256-GCM) encryption
/// and decryption of Secret Chat media files (Images and Voice messages).
///
/// Plaintext media is never uploaded to Firebase Storage.
/// Media encryption keys and nonces are never stored in plaintext in Firestore;
/// they are transmitted exclusively inside authenticated Signal Protocol messages.
class SecretMediaCryptoService {
  SecretMediaCryptoService._();

  static const int keySizeBytes = 32; // 256-bit key
  static const int nonceSizeBytes = 12; // 96-bit GCM nonce
  static const int tagSizeBits = 128; // 128-bit authentication tag
  static const int maxMediaSizeBytes = 25 * 1024 * 1024; // 25MB max limit

  /// Generates a cryptographically secure random 256-bit (32 bytes) key
  static Uint8List generateKey() {
    final random = Random.secure();
    final key = Uint8List(keySizeBytes);
    for (int i = 0; i < keySizeBytes; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  /// Generates a cryptographically secure random 96-bit (12 bytes) nonce
  static Uint8List generateNonce() {
    final random = Random.secure();
    final nonce = Uint8List(nonceSizeBytes);
    for (int i = 0; i < nonceSizeBytes; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  /// Encrypts raw media bytes locally using AES-256-GCM.
  ///
  /// Appends the 16-byte (128-bit) authentication tag directly to the ciphertext.
  /// Binds [associatedData] (e.g. mediaId) to the authenticated ciphertext.
  static Uint8List encryptMedia({
    required Uint8List plaintextBytes,
    required Uint8List key,
    required Uint8List nonce,
    Uint8List? associatedData,
  }) {
    if (plaintextBytes.length > maxMediaSizeBytes) {
      throw ArgumentError(
        'Media size (${plaintextBytes.length} bytes) exceeds maximum allowable limit ($maxMediaSizeBytes bytes)',
      );
    }
    if (key.length != keySizeBytes) {
      throw ArgumentError(
        'AES-256 key must be exactly $keySizeBytes bytes (received ${key.length})',
      );
    }
    if (nonce.length != nonceSizeBytes) {
      throw ArgumentError(
        'AES-GCM nonce must be exactly $nonceSizeBytes bytes (received ${nonce.length})',
      );
    }

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagSizeBits,
      nonce,
      associatedData ?? Uint8List(0),
    );

    cipher.init(true, params);
    return cipher.process(plaintextBytes);
  }

  /// Decrypts AES-256-GCM ciphertext bytes and verifies the authentication tag.
  ///
  /// Rejects modified, corrupted, or replayed ciphertext with an Exception.
  static Uint8List decryptMedia({
    required Uint8List ciphertextAndTag,
    required Uint8List key,
    required Uint8List nonce,
    Uint8List? associatedData,
  }) {
    if (key.length != keySizeBytes) {
      throw ArgumentError(
        'AES-256 key must be exactly $keySizeBytes bytes (received ${key.length})',
      );
    }
    if (nonce.length != nonceSizeBytes) {
      throw ArgumentError(
        'AES-GCM nonce must be exactly $nonceSizeBytes bytes (received ${nonce.length})',
      );
    }
    if (ciphertextAndTag.length < 16) {
      throw ArgumentError('Ciphertext is too short to contain authentication tag');
    }

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(key),
      tagSizeBits,
      nonce,
      associatedData ?? Uint8List(0),
    );

    cipher.init(false, params);
    try {
      return cipher.process(ciphertextAndTag);
    } catch (e) {
      throw Exception(
        'Media decryption failed: Invalid ciphertext or corrupted authentication tag ($e)',
      );
    }
  }

  /// Checks if a decrypted Signal payload represents an encrypted media message
  static bool isMediaPayload(String decryptedText) {
    final trimmed = decryptedText.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return false;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        return (type == 'image' || type == 'voice') &&
            decoded.containsKey('key') &&
            decoded.containsKey('nonce') &&
            decoded.containsKey('storagePath');
      }
    } catch (_) {
      // Not a valid JSON payload -> treat as text
    }
    return false;
  }

  /// Parses a decrypted Signal text payload into a [SecretMediaPayload]
  static SecretMediaPayload? parseMediaPayload(String decryptedText) {
    if (!isMediaPayload(decryptedText)) return null;
    try {
      final decoded = jsonDecode(decryptedText.trim()) as Map<String, dynamic>;
      return SecretMediaPayload.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Encodes a [SecretMediaPayload] into a JSON string to be encrypted by Signal Protocol
  static String encodeMediaPayload(SecretMediaPayload payload) {
    return jsonEncode(payload.toJson());
  }
}
