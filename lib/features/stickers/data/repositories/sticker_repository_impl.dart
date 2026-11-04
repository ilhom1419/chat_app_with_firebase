import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../../domain/entities/sticker.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../datasources/built_in_stickers_datasource.dart';

class StickerRepositoryImpl implements StickerRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const String _boxName = 'sticker_prefs';

  StickerRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  @override
  Future<List<StickerPack>> getStickerPacks() async {
    final box = await _getBox();
    final disabledPacks =
        List<String>.from(box.get('disabled_packs', defaultValue: <String>[]));

    final packs = BuiltInStickersDataSource.getAllPacks();
    return packs.map((pack) {
      final isInstalled = !disabledPacks.contains(pack.id);
      return pack.copyWith(isInstalled: isInstalled);
    }).toList();
  }

  @override
  Future<List<Sticker>> getStickersByPack(String packId) async {
    final allPacks = BuiltInStickersDataSource.getAllPacks();
    final pack = allPacks.firstWhere(
      (p) => p.id == packId,
      orElse: () => allPacks.first,
    );
    return pack.stickers;
  }

  @override
  Future<List<Sticker>> searchStickers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final all = BuiltInStickersDataSource.getAllStickers();
    return all.where((sticker) {
      if (sticker.title.toLowerCase().contains(q)) return true;
      for (final tag in sticker.tags) {
        if (tag.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  @override
  Future<List<Sticker>> getRecentStickers() async {
    final box = await _getBox();
    final recentIds =
        List<String>.from(box.get('recent_stickers', defaultValue: <String>[]));
    if (recentIds.isEmpty) return [];

    final allStickers = {
      for (var s in BuiltInStickersDataSource.getAllStickers()) s.id: s
    };

    final result = <Sticker>[];
    for (final id in recentIds) {
      final sticker = allStickers[id];
      if (sticker != null) {
        result.add(sticker);
      }
    }
    return result;
  }

  @override
  Future<void> addRecentSticker(Sticker sticker) async {
    final box = await _getBox();
    final list =
        List<String>.from(box.get('recent_stickers', defaultValue: <String>[]));

    list.remove(sticker.id);
    list.insert(0, sticker.id);
    if (list.length > 30) {
      list.removeRange(30, list.length);
    }
    await box.put('recent_stickers', list);
    _syncPrefsToFirestore(recentIds: list);
  }

  @override
  Future<List<Sticker>> getFavoriteStickers() async {
    final box = await _getBox();
    final favIds = List<String>.from(
        box.get('favorite_stickers', defaultValue: <String>[]));
    if (favIds.isEmpty) return [];

    final allStickers = {
      for (var s in BuiltInStickersDataSource.getAllStickers()) s.id: s
    };

    final result = <Sticker>[];
    for (final id in favIds) {
      final sticker = allStickers[id];
      if (sticker != null) {
        result.add(sticker);
      }
    }
    return result;
  }

  @override
  Future<bool> toggleFavoriteSticker(Sticker sticker) async {
    final box = await _getBox();
    final list = List<String>.from(
        box.get('favorite_stickers', defaultValue: <String>[]));

    final isFav = list.contains(sticker.id);
    if (isFav) {
      list.remove(sticker.id);
    } else {
      list.insert(0, sticker.id);
    }
    await box.put('favorite_stickers', list);
    _syncPrefsToFirestore(favIds: list);
    return !isFav;
  }

  @override
  Future<bool> isFavorite(String stickerId) async {
    final box = await _getBox();
    final list = List<String>.from(
        box.get('favorite_stickers', defaultValue: <String>[]));
    return list.contains(stickerId);
  }

  @override
  Future<void> togglePackInstalled(String packId, bool isInstalled) async {
    final box = await _getBox();
    final disabled =
        List<String>.from(box.get('disabled_packs', defaultValue: <String>[]));
    if (isInstalled) {
      disabled.remove(packId);
    } else {
      if (!disabled.contains(packId)) {
        disabled.add(packId);
      }
    }
    await box.put('disabled_packs', disabled);
  }

  void _syncPrefsToFirestore(
      {List<String>? recentIds, List<String>? favIds}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (recentIds != null) updates['recentStickers'] = recentIds;
      if (favIds != null) updates['favoriteStickers'] = favIds;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('sticker_prefs')
          .doc('prefs')
          .set(updates, SetOptions(merge: true));
    } catch (_) {
      // Offline yoki ruxsat yo'q bo'lsa mahalliy Hive kesh yetarli
    }
  }
}
