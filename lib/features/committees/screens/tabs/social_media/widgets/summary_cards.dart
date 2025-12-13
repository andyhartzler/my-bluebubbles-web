import 'package:flutter/material.dart';
import '../theme/communications_committee_theme.dart';

/// Displays summary statistics cards for social media metrics with enhanced design
class SocialMediaSummaryCards extends StatelessWidget {
  final int totalFollowers;
  final int totalEngagement;
  final int totalImpressions;
  final int totalPosts;
  final double? followerGrowth;
  final double? engagementGrowth;

  const SocialMediaSummaryCards({
    super.key,
    required this.totalFollowers,
    required this.totalEngagement,
    required this.totalImpressions,
    required this.totalPosts,
    this.followerGrowth,
    this.engagementGrowth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CommunicationsCommitteeTheme.primary.withOpacity(isDark ? 0.2 : 0.08),
            CommunicationsCommitteeTheme.primaryLight.withOpacity(isDark ? 0.1 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CommunicationsCommitteeTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CommunicationsCommitteeTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics,
                    color: CommunicationsCommitteeTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance Overview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Last 30 days across all platforms',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 48) / 4
                    : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: 'Followers',
                        value: _formatNumber(totalFollowers),
                        icon: Icons.people_alt_rounded,
                        color: CommunicationsCommitteeTheme.chartPalette[0],
                        growth: followerGrowth,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: 'Engagement',
                        value: _formatNumber(totalEngagement),
                        icon: Icons.favorite_rounded,
                        color: CommunicationsCommitteeTheme.chartPalette[1],
                        growth: engagementGrowth,
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: 'Impressions',
                        value: _formatNumber(totalImpressions),
                        icon: Icons.visibility_rounded,
                        color: CommunicationsCommitteeTheme.chartPalette[2],
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        title: 'Posts',
                        value: totalPosts.toString(),
                        icon: Icons.article_rounded,
                        color: CommunicationsCommitteeTheme.chartPalette[3],
                        isDark: isDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? growth;
  final bool isDark;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.growth,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.15 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (growth != null) ...[
                const Spacer(),
                _GrowthIndicator(growth: growth!, color: color),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthIndicator extends StatelessWidget {
  final double growth;
  final Color color;

  const _GrowthIndicator({required this.growth, required this.color});

  @override
  Widget build(BuildContext context) {
    final isPositive = growth >= 0;
    final displayColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: displayColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: displayColor,
          ),
          const SizedBox(width: 4),
          Text(
            '${isPositive ? '+' : ''}${growth.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
        ],
      ),
    );
  }
}
