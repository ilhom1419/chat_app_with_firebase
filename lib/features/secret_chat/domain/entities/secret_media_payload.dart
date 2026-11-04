import 'dart:typed_data';
import 'package:equatable/equatable.dart';

enum SecretMediaType {
  image,
  voice,
}

class SecretMediaPayload extends Equatable {
  final SecretMediaType type;
  final String mediaId;
  final String storagePath;
  final String mediaUrl;
  final String keyBase64;
  final String nonceBase64;
  final String? caption;
  final int? width;
  final int? height;
  final int? durationSeconds;
  final int size;
  final String mimeType;

  // In-memory transient decrypted fields (never stored in DB)
  final Uint8List? decryptedBytes;
  final String? localFilePath;
  final bool isDownloading;
  final String? downloadError;

  const SecretMediaPayload({
    required this.type,
    required this.mediaId,
    required this.storagePath,
    required this.mediaUrl,
    required this.keyBase64,
    required this.nonceBase64,
    this.caption,
    this.width,
    this.height,
    this.durationSeconds,
    required this.size,
    required this.mimeType,
    this.decryptedBytes,
    this.localFilePath,
    this.isDownloading = false,
    this.downloadError,
  });

  bool get isImage => type == SecretMediaType.image;
  bool get isVoice => type == SecretMediaType.voice;
  bool get isDecrypted => decryptedBytes != null;

  Map<String, dynamic> toJson() {
    return {
      'type': type == SecretMediaType.image ? 'image' : 'voice',
      'mediaId': mediaId,
      'storagePath': storagePath,
      'mediaUrl': mediaUrl,
      'key': keyBase64,
      'nonce': nonceBase64,
      if (caption != null) 'caption': caption,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'size': size,
      'mimeType': mimeType,
    };
  }

  factory SecretMediaPayload.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'image';
    return SecretMediaPayload(
      type: typeStr == 'voice' ? SecretMediaType.voice : SecretMediaType.image,
      mediaId: json['mediaId'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String? ?? '',
      keyBase64: json['key'] as String? ?? '',
      nonceBase64: json['nonce'] as String? ?? '',
      caption: json['caption'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationSeconds: json['durationSeconds'] as int?,
      size: json['size'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ??
          (typeStr == 'voice' ? 'audio/m4a' : 'image/jpeg'),
    );
  }

  SecretMediaPayload copyWith({
    SecretMediaType? type,
    String? mediaId,
    String? storagePath,
    String? mediaUrl,
    String? keyBase64,
    String? nonceBase64,
    String? caption,
    int? width,
    int? height,
    int? durationSeconds,
    int? size,
    String? mimeType,
    Uint8List? decryptedBytes,
    String? localFilePath,
    bool? isDownloading,
    String? downloadError,
  }) {
    return SecretMediaPayload(
      type: type ?? this.type,
      mediaId: mediaId ?? this.mediaId,
      storagePath: storagePath ?? this.storagePath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      keyBase64: keyBase64 ?? this.keyBase64,
      nonceBase64: nonceBase64 ?? this.nonceBase64,
      caption: caption ?? this.caption,
      width: width ?? this.width,
      height: height ?? this.height,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      decryptedBytes: decryptedBytes ?? this.decryptedBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadError: downloadError ?? this.downloadError,
    );
  }

  @override
  List<Object?> get props => [
        type,
        mediaId,
        storagePath,
        mediaUrl,
        keyBase64,
        nonceBase64,
        caption,
        width,
        height,
        durationSeconds,
        size,
        mimeType,
        decryptedBytes,
        localFilePath,
        isDownloading,
        downloadError,
      ];
}
