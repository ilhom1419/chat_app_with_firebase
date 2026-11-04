import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/sticker.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../../data/repositories/sticker_repository_impl.dart';
import '../../../../shared/widgets/floating_bottom_sheet.dart';

class StickerPickerSheet extends StatefulWidget {
  final Function(Sticker) onStickerSelected;
  final Function(String) onGifSelected;

  const StickerPickerSheet({
    super.key,
    required this.onStickerSelected,
    required this.onGifSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(Sticker) onStickerSelected,
    required Function(String) onGifSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showKakkuFloatingBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      builder: (ctx) => StickerPickerSheet(
        onStickerSelected: onStickerSelected,
        onGifSelected: onGifSelected,
      ),
    );
  }

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StickerRepository _repository = StickerRepositoryImpl();

  // Sticker State
  List<StickerPack> _packs = [];
  String _selectedPackId = 'recent'; // 'recent', 'favorite', or packId
  List<Sticker> _displayedStickers = [];
  List<Sticker> _recentStickers = [];
  List<Sticker> _favoriteStickers = [];
  bool _isLoadingStickers = true;
  final TextEditingController _stickerSearchController =
      TextEditingController();
  String _searchQuery = '';

  // GIF State
  final TextEditingController _gifSearchController = TextEditingController();
  List<String> _gifs = [];
  bool _isLoadingGifs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stickerSearchController.dispose();
    _gifSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingStickers = true);
    final packs = await _repository.getStickerPacks();
    final recents = await _repository.getRecentStickers();
    final favorites = await _repository.getFavoriteStickers();

    if (!mounted) return;

    setState(() {
      _packs = packs;
      _recentStickers = recents;
      _favoriteStickers = favorites;
      _isLoadingStickers = false;

      // Agar recents bo'lsa recents'dan boshlaymiz, bo'lmasa birinchi to'plamdan
      if (_recentStickers.isNotEmpty) {
        _selectedPackId = 'recent';
        _displayedStickers = _recentStickers;
      } else if (packs.isNotEmpty) {
        _selectedPackId = packs.first.id;
        _displayedStickers = packs.first.stickers;
      }
    });

    _loadGifs('');
  }

  void _onPackSelected(String packId) {
    setState(() {
      _selectedPackId = packId;
      _searchQuery = '';
      _stickerSearchController.clear();

      if (packId == 'recent') {
        _displayedStickers = _recentStickers;
      } else if (packId == 'favorite') {
        _displayedStickers = _favoriteStickers;
      } else {
        final pack = _packs.firstWhere(
          (p) => p.id == packId,
          orElse: () => _packs.first,
        );
        _displayedStickers = pack.stickers;
      }
    });
  }

  void _onSearchStickers(String query) async {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_searchQuery.isEmpty) {
      _onPackSelected(_selectedPackId);
      return;
    }

    final results = await _repository.searchStickers(_searchQuery);
    if (mounted) {
      setState(() {
        _displayedStickers = results;
      });
    }
  }

  void _handleStickerTap(Sticker sticker) async {
    await _repository.addRecentSticker(sticker);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onStickerSelected(sticker);
  }

  void _showStickerPreview(Sticker sticker) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isFav = await _repository.isFavorite(sticker.id);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview Image
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Image.network(
                          sticker.imageUrl,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (c, o, s) => const Icon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        sticker.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${sticker.category} • ${sticker.format.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          // Favorite Toggle
                          IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: isFav ? Colors.amber : Colors.grey,
                              size: 28,
                            ),
                            onPressed: () async {
                              final newStatus = await _repository
                                  .toggleFavoriteSticker(sticker);
                              final favs =
                                  await _repository.getFavoriteStickers();
                              setDialogState(() {
                                isFav = newStatus;
                              });
                              if (mounted) {
                                setState(() {
                                  _favoriteStickers = favs;
                                  if (_selectedPackId == 'favorite') {
                                    _displayedStickers = _favoriteStickers;
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          // Send Button
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _handleStickerTap(sticker);
                              },
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                LocalizationService.translate('send_btn_label'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // GIF Search
  void _loadGifs(String query) async {
    setState(() => _isLoadingGifs = true);
    final results = await _searchGifsFromApi(query);
    if (mounted) {
      setState(() {
        _gifs = results;
        _isLoadingGifs = false;
      });
    }
  }

  Future<List<String>> _searchGifsFromApi(String query) async {
    try {
      const apiKey = 'dc6zaTOxFJmzC';
      final client = HttpClient();
      final url = query.trim().isEmpty
          ? 'https://api.giphy.com/v1/gifs/trending?api_key=$apiKey&limit=30'
          : 'https://api.giphy.com/v1/gifs/search?api_key=$apiKey&q=${Uri.encodeComponent(query)}&limit=30';

      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final data = json['data'] as List<dynamic>? ?? [];
        return data.map((item) {
          final images = item['images'] as Map<String, dynamic>;
          final fixedWidth = images['fixed_width'] as Map<String, dynamic>;
          return fixedWidth['url'] as String;
        }).toList();
      }
    } catch (_) {}
    return [
      'https://media.giphy.com/media/l3q2zVr6cu95nF6O4/giphy.gif',
      'https://media.giphy.com/media/l2JhORT5IFnj6ioko/giphy.gif',
      'https://media.giphy.com/media/3o7qE1YN7aBOFPRw8E/giphy.gif',
      'https://media.giphy.com/media/26AHONQ79uqx894eQ/giphy.gif',
      'https://media.giphy.com/media/xT39CXg70n42o5tSMU/giphy.gif',
      'https://media.giphy.com/media/l0ExdPMcAd99Z5t84/giphy.gif',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle Bar
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Top Primary Tabs: Stickers & GIFs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.primary,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(
                    icon: const Icon(Icons.sticky_note_2_rounded, size: 20),
                    text: LocalizationService.translate('stickers_tab'),
                  ),
                  Tab(
                    icon: const Icon(Icons.gif_rounded, size: 24),
                    text: LocalizationService.translate('gifs_tab'),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Stickers Section
                  _buildStickersSection(isDark),

                  // 2. GIFs Section
                  _buildGifsSection(isDark),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- STICKERS SECTION ---
  Widget _buildStickersSection(bool isDark) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _stickerSearchController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: LocalizationService.translate('search_stickers_hint'),
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _stickerSearchController.clear();
                        _onSearchStickers('');
                      },
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: _onSearchStickers,
          ),
        ),

        // Sticker Pack Selector Strip
        if (_searchQuery.isEmpty) _buildPacksStrip(isDark),

        // Stickers Grid
        Expanded(
          child: _isLoadingStickers
              ? const Center(child: CircularProgressIndicator())
              : _displayedStickers.isEmpty
                  ? _buildEmptyState(isDark)
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _displayedStickers.length,
                      itemBuilder: (context, index) {
                        final sticker = _displayedStickers[index];
                        return GestureDetector(
                          onTap: () => _handleStickerTap(sticker),
                          onLongPress: () => _showStickerPreview(sticker),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.grey.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Image.network(
                              sticker.imageUrl,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (ctx, error, stack) => Icon(
                                Icons.sentiment_satisfied_rounded,
                                size: 36,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPacksStrip(bool isDark) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // 1. Recents Tab
          _packTabItem(
            id: 'recent',
            icon: Icons.history_rounded,
            label: LocalizationService.translate('recents_pack'),
            isSelected: _selectedPackId == 'recent',
            isDark: isDark,
          ),
          // 2. Favorites Tab
          _packTabItem(
            id: 'favorite',
            icon: Icons.star_rounded,
            label: LocalizationService.translate('favorites_pack'),
            isSelected: _selectedPackId == 'favorite',
            isDark: isDark,
            activeColor: Colors.amber,
          ),
          // 3. Built-in Packs
          ..._packs.map((pack) {
            return _packTabImageItem(
              pack: pack,
              isSelected: _selectedPackId == pack.id,
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _packTabItem({
    required String id,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    Color? activeColor,
  }) {
    final color = isSelected
        ? (activeColor ?? AppColors.primary)
        : (isDark ? Colors.white60 : Colors.black54);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _onPackSelected(id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (activeColor ?? AppColors.primary).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (activeColor ?? AppColors.primary).withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _packTabImageItem({
    required StickerPack pack,
    required bool isSelected,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _onPackSelected(pack.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Image.network(
                  pack.coverImageUrl,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (c, o, s) => const Icon(
                      Icons.emoji_emotions_rounded,
                      size: 18,
                      color: Colors.grey),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                pack.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    String msg = LocalizationService.translate('no_stickers_found');
    IconData icon = Icons.search_off_rounded;

    if (_searchQuery.isNotEmpty) {
      msg = '"$_searchQuery" (${LocalizationService.translate('no_stickers_found')})';
    } else if (_selectedPackId == 'recent') {
      msg = LocalizationService.translate('no_recent_stickers');
      icon = Icons.history_rounded;
    } else if (_selectedPackId == 'favorite') {
      msg = LocalizationService.translate('no_favorite_stickers');
      icon = Icons.star_border_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: isDark ? Colors.white30 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- GIFS SECTION ---
  Widget _buildGifsSection(bool isDark) {
    return Column(
      children: [
        // GIF search input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _gifSearchController,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: LocalizationService.translate('search_gifs_hint'),
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
                size: 20,
              ),
              suffixIcon: _gifSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _gifSearchController.clear();
                        _loadGifs('');
                      },
                    )
                  : null,
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onSubmitted: _loadGifs,
          ),
        ),

        // GIF Grid
        Expanded(
          child: _isLoadingGifs
              ? const Center(child: CircularProgressIndicator())
              : _gifs.isEmpty
                  ? Center(
                      child: Text(
                        LocalizationService.translate('no_gifs_found'),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: _gifs.length,
                      itemBuilder: (context, index) {
                        final url = _gifs[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onGifSelected(url);
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (c, o, s) => Container(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey.shade200,
                                child: const Icon(Icons.gif_rounded,
                                    color: Colors.grey, size: 36),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
