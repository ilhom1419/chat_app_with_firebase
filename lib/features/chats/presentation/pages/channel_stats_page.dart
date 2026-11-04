import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/channel_stats.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../messages/domain/entities/message.dart';

class ChannelStatsPage extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isChannel;
  final int memberCount;
  final ChatRepository chatRepository;

  const ChannelStatsPage({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isChannel,
    required this.memberCount,
    required this.chatRepository,
  });

  @override
  State<ChannelStatsPage> createState() => _ChannelStatsPageState();
}

class _ChannelStatsPageState extends State<ChannelStatsPage> {
  late Future<ChannelStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _statsFuture = widget.chatRepository.getChannelStats(widget.chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isChannel ? 'Kanal statistikasi' : 'Guruh statistikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              widget.chatName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: LocalizationService.translate('refresh'),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: FutureBuilder<ChannelStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(LocalizationService.translate('stats_calculating')),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(LocalizationService.formatError(snapshot.error)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadStats,
                    child: Text(LocalizationService.translate('retry')),
                  ),
                ],
              ),
            );
          }

          final stats = snapshot.data!;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Summary Cards Grid
                _buildKpiGrid(stats, isDark),
                const SizedBox(height: 20),

                // Views Over Time Chart Section
                _buildDailyViewsSection(stats, isDark),
                const SizedBox(height: 20),

                // Reactions Breakdown Section
                if (stats.reactionsBreakdown.isNotEmpty) ...[
                  _buildReactionsBreakdownSection(stats, isDark),
                  const SizedBox(height: 20),
                ],

                // Top Posts Ranking Section
                _buildTopPostsSection(stats, isDark),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid(ChannelStats stats, bool isDark) {
    final avgViews = stats.totalMessages > 0
        ? (stats.totalViews / stats.totalMessages).round()
        : stats.totalViews;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildKpiCard(
          title: widget.isChannel
              ? LocalizationService.translate('subscribers_title')
              : LocalizationService.translate('members'),
          value: '${stats.totalMembers}',
          subtitle: LocalizationService.translate('active_members_subtitle'),
          icon: Icons.people_alt_rounded,
          gradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          isDark: isDark,
        ),
        _buildKpiCard(
          title: LocalizationService.translate('views_count_title'),
          value: '${stats.totalViews}',
          subtitle: LocalizationService.translate('avg_views_per_post',
              params: {'count': avgViews}),
          icon: Icons.visibility_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF047857)],
          isDark: isDark,
        ),
        _buildKpiCard(
          title: LocalizationService.translate('shares_title'),
          value: '${stats.totalShares}',
          subtitle: LocalizationService.translate('to_other_chats'),
          icon: Icons.shortcut_rounded,
          gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          isDark: isDark,
        ),
        _buildKpiCard(
          title: LocalizationService.translate('engagement_title'),
          value: '${stats.engagementRate}%',
          subtitle: LocalizationService.translate('reactions_count_param',
              params: {'count': stats.totalReactions}),
          icon: Icons.bolt_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyViewsSection(ChannelStats stats, bool isDark) {
    int maxDaily = 1;
    for (final m in stats.dailyViews) {
      if (m.value > maxDaily) maxDaily = m.value;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationService.translate('views_dynamics'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LocalizationService.translate('last_7_days_activity'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      LocalizationService.translate('weekly'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Painted Bar Chart
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.dailyViews.map((day) {
                final double fraction = (day.value / maxDaily).clamp(0.08, 1.0);
                final isPeak = day.value == maxDaily && maxDaily > 0;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      day.value > 0 ? '${day.value}' : '0',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                        color: isPeak
                            ? (isDark ? Colors.amber : Colors.blue)
                            : (isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 24,
                      height: 80 * fraction,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPeak
                              ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                              : (isDark
                                  ? [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]
                                  : [const Color(0xFF60A5FA), const Color(0xFF2563EB)]),
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day.dateLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsBreakdownSection(ChannelStats stats, bool isDark) {
    final total = stats.totalReactions > 0 ? stats.totalReactions : 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationService.translate('reactions_breakdown'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            LocalizationService.translate('reactions_percentage_desc'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),

          // Horizontal Distribution Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: stats.reactionsBreakdown.entries.map((e) {
                  final flex = ((e.value / total) * 100).round().clamp(1, 100);
                  final color = _getReactionColor(e.key);
                  return Expanded(
                    flex: flex,
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Emoji Chips with Percentage
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats.reactionsBreakdown.entries.map((e) {
              final pct = ((e.value / total) * 100).toStringAsFixed(0);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '${e.value} ($pct%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getReactionColor(String emoji) {
    switch (emoji) {
      case '❤️':
        return Colors.redAccent;
      case '🔥':
        return Colors.orangeAccent;
      case '👍':
        return Colors.blueAccent;
      case '🎉':
        return Colors.purpleAccent;
      case '👏':
        return Colors.teal;
      case '😂':
        return Colors.amber;
      default:
        return Colors.indigoAccent;
    }
  }

  Widget _buildTopPostsSection(ChannelStats stats, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D31) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationService.translate('top_posts_title'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Top ${stats.topMessages.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (stats.topMessages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  LocalizationService.translate('no_posts_yet'),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              itemCount: stats.topMessages.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (ctx, i) => const Divider(height: 20),
              itemBuilder: (context, index) {
                final msg = stats.topMessages[index];
                return _buildTopPostItem(index + 1, msg, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopPostItem(int rank, Message msg, bool isDark) {
    String contentSnippet = msg.text ?? '';
    if (contentSnippet.isEmpty) {
      if (msg.imageUrl != null) {
        contentSnippet = LocalizationService.translate('photo_snippet');
      } else if (msg.poll != null) {
        contentSnippet =
            '${LocalizationService.translate('poll_snippet')}: ${msg.poll!.question}';
      } else if (msg.fileUrl != null) {
        contentSnippet =
            '${LocalizationService.translate('file_snippet')}: ${msg.fileName ?? ""}';
      } else {
        contentSnippet =
            LocalizationService.translate('media_message_snippet');
      }
    }

    final totalReactions = msg.reactions.length;
    final dateStr = DateFormat('dd.MM HH:mm').format(msg.timestamp);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rank Badge
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: rank == 1
                ? Colors.amber.withOpacity(0.2)
                : (rank == 2
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.12)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rank == 1
                    ? Colors.amber
                    : (rank == 2 ? Colors.grey : Colors.blue),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Message text snippet and metrics
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contentSnippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const Spacer(),
                  // Views
                  _buildMiniBadge(
                    icon: Icons.visibility_rounded,
                    label: '${msg.viewsCount > 0 ? msg.viewsCount : 1}',
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  // Reactions
                  if (totalReactions > 0) ...[
                    _buildMiniBadge(
                      icon: Icons.favorite_rounded,
                      label: '$totalReactions',
                      color: Colors.redAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Shares
                  if (msg.forwardCount > 0)
                    _buildMiniBadge(
                      icon: Icons.shortcut_rounded,
                      label: '${msg.forwardCount}',
                      color: Colors.purpleAccent,
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
