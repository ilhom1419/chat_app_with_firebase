import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/stickers/data/datasources/built_in_stickers_datasource.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';

void main() {
  group('Sticker Library Specification Tests', () {
    test('Total usable stickers count must be at least 300', () {
      final allStickers = BuiltInStickersDataSource.getAllStickers();
      expect(allStickers.length, greaterThanOrEqualTo(300),
          reason: 'Initial target requirement: at least 300 usable stickers');
    });

    test('All sticker IDs must be strictly unique', () {
      final allStickers = BuiltInStickersDataSource.getAllStickers();
      final idSet = <String>{};
      for (final sticker in allStickers) {
        final added = idSet.add(sticker.id);
        expect(added, isTrue,
            reason: 'Duplicate sticker id found: ${sticker.id}');
      }
      expect(idSet.length, equals(allStickers.length));
    });

    test('Must contain all 12 required categories with at least 25 stickers each',
        () {
      final requiredCategories = [
        'happy',
        'love',
        'funny',
        'sad',
        'angry',
        'greetings',
        'congrats',
        'animals',
        'characters',
        'reactions',
        'work',
        'uzbek',
      ];

      final allPacks = BuiltInStickersDataSource.getAllPacks();
      final packCategories = allPacks.map((p) => p.category).toSet();

      for (final cat in requiredCategories) {
        expect(packCategories.contains(cat), isTrue,
            reason: 'Category $cat is missing from sticker packs');

        final pack = allPacks.firstWhere((p) => p.category == cat);
        expect(pack.stickers.length, greaterThanOrEqualTo(25),
            reason:
                'Pack for $cat must contain at least 25 distinct graphic stickers');
      }
    });

    test('Every sticker must have a valid transparent PNG image URL and title',
        () {
      final allStickers = BuiltInStickersDataSource.getAllStickers();
      for (final s in allStickers) {
        expect(s.id, isNotEmpty);
        expect(s.title, isNotEmpty);
        expect(s.imageUrl, startsWith('http'));
        expect(s.imageUrl, endsWith('.png'));
        expect(s.category, isNotEmpty);
        expect(s.tags, isNotEmpty);
        expect(s.format, equals('png'));
      }
    });

    test('Uzbek Expressions category contains 26 authentic Uzbek expressions',
        () {
      final allPacks = BuiltInStickersDataSource.getAllPacks();
      final uzbekPack =
          allPacks.firstWhere((p) => p.category == 'uzbek');

      expect(uzbekPack.name, equals('Uzbek Expressions'));
      expect(uzbekPack.stickers.length, equals(26));

      final titles = uzbekPack.stickers.map((s) => s.title.toLowerCase()).toList();
      expect(titles.any((t) => t.contains('assalomu alaykum')), isTrue);
      expect(titles.any((t) => t.contains('rahmat')), isTrue);
      expect(titles.any((t) => t.contains('zo\'r')), isTrue);
      expect(titles.any((t) => t.contains('barakalla')), isTrue);
      expect(titles.any((t) => t.contains('jonim') || t.contains('jonajonim')), isTrue);
      expect(titles.any((t) => t.contains('choy')), isTrue);
    });
  });

  group('Message with MessageType.sticker Tests', () {
    test('Can create a Message entity with MessageType.sticker', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg_stk_1',
        senderId: 'user_1',
        text: 'Zo\'r, gap yo\'q!',
        imageUrl:
            'https://cdn.jsdelivr.net/gh/shuding/fluentui-emoji-unicode/assets/1f525_3d.png',
        type: MessageType.sticker,
        isRead: false,
        timestamp: now,
      );

      expect(message.type, equals(MessageType.sticker));
      expect(message.text, equals('Zo\'r, gap yo\'q!'));
      expect(message.imageUrl, isNotEmpty);
      expect(message.type.name, equals('sticker'));
    });
  });
}
