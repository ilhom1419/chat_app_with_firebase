import 'package:equatable/equatable.dart';

class Sticker extends Equatable {
  final String id;
  final String packId;
  final String title;
  final String category;
  final List<String> tags;
  final String imageUrl;
  final String? thumbnailUrl;
  final String format;
  final bool isAnimated;
  final int fileSize;
  final DateTime? createdAt;

  const Sticker({
    required this.id,
    required this.packId,
    required this.title,
    required this.category,
    required this.tags,
    required this.imageUrl,
    this.thumbnailUrl,
    this.format = 'png',
    this.isAnimated = false,
    this.fileSize = 0,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packId': packId,
      'title': title,
      'category': category,
      'tags': tags,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'format': format,
      'isAnimated': isAnimated,
      'fileSize': fileSize,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Sticker.fromMap(Map<String, dynamic> map) {
    return Sticker(
      id: map['id'] as String? ?? '',
      packId: map['packId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      tags: List<String>.from(map['tags'] as List? ?? []),
      imageUrl: map['imageUrl'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      format: map['format'] as String? ?? 'png',
      isAnimated: map['isAnimated'] as bool? ?? false,
      fileSize: map['fileSize'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, packId, title, category, imageUrl];
}

class StickerPack extends Equatable {
  final String id;
  final String name;
  final String description;
  final String coverImageUrl;
  final int stickerCount;
  final String category;
  final int sortOrder;
  final bool isInstalled;
  final List<Sticker> stickers;

  const StickerPack({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.stickerCount,
    required this.category,
    this.sortOrder = 0,
    this.isInstalled = true,
    this.stickers = const [],
  });

  StickerPack copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImageUrl,
    int? stickerCount,
    String? category,
    int? sortOrder,
    bool? isInstalled,
    List<Sticker>? stickers,
  }) {
    return StickerPack(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      stickerCount: stickerCount ?? this.stickerCount,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      isInstalled: isInstalled ?? this.isInstalled,
      stickers: stickers ?? this.stickers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImageUrl': coverImageUrl,
      'stickerCount': stickerCount,
      'category': category,
      'sortOrder': sortOrder,
      'isInstalled': isInstalled,
    };
  }

  factory StickerPack.fromMap(Map<String, dynamic> map,
      {List<Sticker> stickers = const []}) {
    return StickerPack(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      coverImageUrl: map['coverImageUrl'] as String? ?? '',
      stickerCount: map['stickerCount'] as int? ?? stickers.length,
      category: map['category'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      isInstalled: map['isInstalled'] as bool? ?? true,
      stickers: stickers,
    );
  }

  @override
  List<Object?> get props => [id, name, category, stickerCount, isInstalled];
}
