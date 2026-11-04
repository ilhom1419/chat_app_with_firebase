import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../stickers/domain/entities/sticker.dart';
import '../../../stickers/domain/repositories/sticker_repository.dart';
import '../../../stickers/data/repositories/sticker_repository_impl.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';

/// Modal bottom sheet to select stickers and emojis for placement on the image.
class EditorStickerEmojiPicker extends StatefulWidget {
  final Function(Sticker sticker) onStickerSelected;
  final Function(String emoji) onEmojiSelected;

  const EditorStickerEmojiPicker({
    super.key,
    required this.onStickerSelected,
    required this.onEmojiSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(Sticker sticker) onStickerSelected,
    required Function(String emoji) onEmojiSelected,
  }) {
    return showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (ctx) => EditorStickerEmojiPicker(
        onStickerSelected: onStickerSelected,
        onEmojiSelected: onEmojiSelected,
      ),
    );
  }

  @override
  State<EditorStickerEmojiPicker> createState() => _EditorStickerEmojiPickerState();
}

class _EditorStickerEmojiPickerState extends State<EditorStickerEmojiPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StickerRepository _stickerRepository = StickerRepositoryImpl();

  List<StickerPack> _packs = [];
  bool _isLoadingPacks = true;
  String? _selectedPackId;

  // Curated emoji catalog
  final List<String> _emojis = const [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥹', '😊',
    '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙',
    '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
    '🫡', '🤐', '🤨', '😐', '😑', '😶', '🫥', '😏', '😒', '🙄',
    '😬', '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕',
    '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳',
    '🥸', '😎', '🤓', '🧐', '😕', '😟', '🙁', '😮', '😯', '😲',
    '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱',
    '😖', '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠',
    '🤬', '😈', '👿', '💀', '☠️', '💩', '🤡', '👹', '👺', '👻',
    '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽',
    '🙀', '😿', '😾', '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤',
    '🤍', '🤎', '💔', '❤️‍🔥', '❤️‍🩹', '💖', '💗', '💓', '💞', '💕',
    '🔥', '✨', '⚡', '💥', '🎉', '🎊', '🎈', '🎂', '🎁', '🏆',
    '⭐', '🌟', '💫', '💯', '👍', '👎', '👏', '🙌', '🤝', '✌️',
    '🤞', '🤟', '🤘', '🤙', '👋', '👊', '✊', '🤛', '🤜', '💪',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStickers();
  }

  Future<void> _loadStickers() async {
    try {
      final packs = await _stickerRepository.getStickerPacks();
      if (mounted) {
        setState(() {
          _packs = packs;
          if (packs.isNotEmpty) {
            _selectedPackId = packs.first.id;
          }
          _isLoadingPacks = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPacks = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Tabs: Stickers & Emojis
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(
                icon: const Icon(Icons.sticky_note_2_rounded),
                text: LocalizationService.translate('add_sticker'),
              ),
              Tab(
                icon: const Icon(Icons.emoji_emotions_rounded),
                text: LocalizationService.translate('add_emoji'),
              ),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStickersTab(),
                _buildEmojisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickersTab() {
    if (_isLoadingPacks) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_packs.isEmpty) {
      return Center(
        child: Text(
          'Stikerlar topilmadi',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      );
    }

    final activePack = _packs.firstWhere(
      (p) => p.id == _selectedPackId,
      orElse: () => _packs.first,
    );

    return Column(
      children: [
        // Pack Horizontal Bar
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _packs.length,
            itemBuilder: (ctx, i) {
              final pack = _packs[i];
              final isSelected = pack.id == _selectedPackId;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPackId = pack.id;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      pack.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Stickers Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: activePack.stickers.length,
            itemBuilder: (ctx, idx) {
              final sticker = activePack.stickers[idx];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onStickerSelected(sticker);
                },
                child: Image.network(
                  sticker.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white24,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmojisTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _emojis.length,
      itemBuilder: (ctx, idx) {
        final emoji = _emojis[idx];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            widget.onEmojiSelected(emoji);
          },
          child: Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }
}
