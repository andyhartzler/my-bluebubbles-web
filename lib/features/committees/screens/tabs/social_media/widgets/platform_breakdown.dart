import 'package:flutter/material.dart';
import '../models/social_media_account.dart';
import '../models/social_media_stats.dart';
import '../theme/communications_committee_theme.dart';

/// Displays a breakdown of stats by platform
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

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...accounts
              .where((a) => selectedAccountIds.contains(a.id))
              .map((account) {
            final stats = latestStats[account.id];
            final platformColor =
                CommunicationsCommitteeTheme.getPlatformColor(account.platform);

            return _PlatformCard(
              account: account,
              stats: stats,
              color: platformColor,
            );
          }),
        ],
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final SocialMediaAccount account;
  final SocialMediaStats? stats;
  final Color color;

  const _PlatformCard({
    required this.account,
    this.stats,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;

          if (isWide) {
            return Row(
              children: [
                _buildPlatformIcon(),
                const SizedBox(width: 12),
                _buildAccountInfo(),
                const Spacer(),
                _buildStatColumn('Followers', _formatNumber(stats?.followersCount ?? 0)),
                const SizedBox(width: 24),
                _buildStatColumn('Engagement', '${stats?.engagementRate.toStringAsFixed(2) ?? '0.00'}%'),
                const SizedBox(width: 24),
                _buildStatColumn('Impressions', _formatNumber(stats?.impressions ?? 0)),
              ],
            );
          }

          // Mobile layout - stacked
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildPlatformIcon(),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAccountInfo()),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Followers', _formatNumber(stats?.followersCount ?? 0)),
                  _buildStatColumn('Engagement', '${stats?.engagementRate.toStringAsFixed(2) ?? '0.00'}%'),
                  _buildStatColumn('Impressions', _formatNumber(stats?.impressions ?? 0)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlatformIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          _getPlatformIcon(account.platform),
          color: color,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAccountInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account.accountName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          account.platform.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
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
