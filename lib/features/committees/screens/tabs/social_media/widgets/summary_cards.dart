import 'package:flutter/material.dart';
import '../theme/communications_committee_theme.dart';

/// Displays summary statistics cards for social media metrics
class SocialMediaSummaryCards extends StatelessWidget {
  final int totalFollowers;
  final int totalEngagement;
  final int totalImpressions;
  final int totalPosts;

  const SocialMediaSummaryCards({
    super.key,
    required this.totalFollowers,
    required this.totalEngagement,
    required this.totalImpressions,
    required this.totalPosts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
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
                child: _SummaryCard(
                  title: 'Total Followers',
                  value: _formatNumber(totalFollowers),
                  icon: Icons.people,
                  color: CommunicationsCommitteeTheme.chartPalette[0],
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  title: 'Total Engagement',
                  value: _formatNumber(totalEngagement),
                  subtitle: 'Last 30 days',
                  icon: Icons.favorite,
                  color: CommunicationsCommitteeTheme.chartPalette[1],
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  title: 'Impressions',
                  value: _formatNumber(totalImpressions),
                  subtitle: 'Last 30 days',
                  icon: Icons.visibility,
                  color: CommunicationsCommitteeTheme.chartPalette[2],
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  title: 'Total Posts',
                  value: totalPosts.toString(),
                  icon: Icons.article,
                  color: CommunicationsCommitteeTheme.chartPalette[3],
                ),
              ),
            ],
          );
        },
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }
}
