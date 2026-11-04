import '../entities/sticker.dart';

abstract class StickerRepository {
  /// Barcha stiker to'plamlarini qaytaradi
  Future<List<StickerPack>> getStickerPacks();

  /// Berilgan to'plamga tegishli stikerlarni qaytaradi
  Future<List<Sticker>> getStickersByPack(String packId);

  /// Qidiruv so'rovi bo'yicha stikerlarni izlaydi (nomi va teglari bo'yicha)
  Future<List<Sticker>> searchStickers(String query);

  /// Oxirgi ishlatilgan stikerlar ro'yxatini qaytaradi
  Future<List<Sticker>> getRecentStickers();

  /// Yangi ishlatilgan stikerni 'Recents' ro'yxatiga qo'shadi
  Future<void> addRecentSticker(Sticker sticker);

  /// Sevimli stikerlar ro'yxatini qaytaradi
  Future<List<Sticker>> getFavoriteStickers();

  /// Stikerni sevimlilar ro'yxatiga qo'shadi yoki undan chiqaradi
  Future<bool> toggleFavoriteSticker(Sticker sticker);

  /// Stiker sevimli ekanligini tekshiradi
  Future<bool> isFavorite(String stickerId);

  /// To'plamni o'rnatilganlar ro'yxatiga qo'shish / olib tashlash
  Future<void> togglePackInstalled(String packId, bool isInstalled);
}
