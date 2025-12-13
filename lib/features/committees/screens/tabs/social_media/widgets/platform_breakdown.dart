import 'package:flutter/material.dart';
import '../models/social_media_account.dart';
import '../models/social_media_stats.dart';
import '../theme/communications_committee_theme.dart';

/// Displays a breakdown of stats by platform with enhanced visualization
class PlatformBreakdown extends StatelessWidget {
  final List<SocialMediaAccount> accounts;
  final Map<String, SocialMediaStats> latestStats;
  final Set<String> selectedAccountIds;

  const PlatformBreakdown({
    super.key,
    required this.accounts,
    required this.latestStats,
    required this.selectedAccountIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedAccounts = accounts.where((a) => selectedAccountIds.contains(a.id)).toList();

    if (selectedAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CommunicationsCommitteeTheme.primary.withOpacity(0.1),
                  CommunicationsCommitteeTheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CommunicationsCommitteeTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.dashboard_rounded,
                    color: CommunicationsCommitteeTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Breakdown',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${selectedAccounts.length} connected account${selectedAccounts.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Platform cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;

                if (isWide) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: selectedAccounts.map((account) {
                      final stats = latestStats[account.id];
                      return SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: _PlatformCard(
                          account: account,
                          stats: stats,
                          isDark: isDark,
                        ),
                      );
                    }).toList(),
                  );
                }

                return Column(
                  children: selectedAccounts.map((account) {
                    final stats = latestStats[account.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlatformCard(
                        account: account,
                        stats: stats,
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final SocialMediaAccount account;
  final SocialMediaStats? stats;
  final bool isDark;

  const _PlatformCard({
    required this.account,
    this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformColor = CommunicationsCommitteeTheme.getPlatformColor(account.platform);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: platformColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Platform header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: platformColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _getPlatformIcon(account.platform),
                    color: platformColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.accountName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: platformColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        account.platform.toUpperCase(),
                        style: TextStyle(
                          color: platformColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Followers',
                  value: _formatNumber(stats?.followersCount ?? 0),
                  icon: Icons.people_outline,
                  color: platformColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  label: 'Engagement',
                  value: '${stats?.engagementRate.toStringAsFixed(1) ?? '0.0'}%',
                  icon: Icons.trending_up,
                  color: platformColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Impressions',
                  value: _formatNumber(stats?.impressions ?? 0),
                  icon: Icons.visibility_outlined,
                  color: platformColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatItem(
                  label: 'Reach',
                  value: _formatNumber(stats?.reach ?? 0),
                  icon: Icons.wifi_tethering,
                  color: platformColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          // 30-day engagement breakdown
          if (stats != null && stats!.last30DaysTotals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '30-Day Engagement',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EngagementBar(
                    stats: stats!,
                    platformColor: platformColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'threads':
        return Icons.alternate_email;
      case 'youtube':
        return Icons.play_circle_filled;
      case 'reddit':
        return Icons.reddit;
      case 'tiktok':
        return Icons.music_note;
      case 'twitter':
      case 'x':
        return Icons.flutter_dash;
      default:
        return Icons.share;
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngagementBar extends StatelessWidget {
  final SocialMediaStats stats;
  final Color platformColor;
  final bool isDark;

  const _EngagementBar({
    required this.stats,
    required this.platformColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final totals = stats.last30DaysTotals;
    final likes = _toInt(totals['likes'] ?? totals['reactions']);
    final comments = _toInt(totals['comments'] ?? totals['replies']);
    final shares = _toInt(totals['shares'] ?? totals['reposts']);
    final total = likes + comments + shares;

    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                if (likes > 0)
                  Expanded(
                    flex: likes,
                    child: Container(color: Colors.red.shade400),
                  ),
                if (comments > 0)
                  Expanded(
                    flex: comments,
                    child: Container(color: Colors.blue.shade400),
                  ),
                if (shares > 0)
                  Expanded(
                    flex: shares,
                    child: Container(color: Colors.green.shade400),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _EngagementLegendItem(
              label: 'Likes',
              value: _formatNumber(likes),
              color: Colors.red.shade400,
            ),
            _EngagementLegendItem(
              label: 'Comments',
              value: _formatNumber(comments),
              color: Colors.blue.shade400,
            ),
            _EngagementLegendItem(
              label: 'Shares',
              value: _formatNumber(shares),
              color: Colors.green.shade400,
            ),
          ],
        ),
      ],
    );
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _EngagementLegendItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EngagementLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
