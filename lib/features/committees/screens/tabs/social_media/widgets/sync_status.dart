import 'package:flutter/material.dart';
import '../models/social_media_account.dart';
import '../models/social_media_stats.dart';
import '../theme/communications_committee_theme.dart';

/// Displays the last sync status for each platform
class SyncStatus extends StatelessWidget {
  final List<SocialMediaAccount> accounts;
  final Set<String> selectedAccountIds;
  final Map<String, SocialMediaStats>? latestStats;

  const SyncStatus({
    super.key,
    required this.accounts,
    required this.selectedAccountIds,
    this.latestStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filteredAccounts = accounts.where((a) => selectedAccountIds.contains(a.id)).toList();

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
                    Icons.sync_rounded,
                    color: CommunicationsCommitteeTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Last Sync Status',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: filteredAccounts.map((account) {
                final platformColor =
                    CommunicationsCommitteeTheme.getPlatformColor(account.platform);

                // Get sync date from stats if available, fall back to account lastSyncedAt
                DateTime? lastSyncDate;
                final stats = latestStats?[account.id];
                if (stats != null) {
                  // Try to get collection_date from platform_metrics first
                  final collectionDateStr = stats.platformMetrics['collection_date'];
                  if (collectionDateStr is String) {
                    lastSyncDate = DateTime.tryParse(collectionDateStr);
                  }
                  // Fall back to metric_date
                  lastSyncDate ??= DateTime.tryParse(stats.metricDate);
                }
                // Final fallback to account's lastSyncedAt
                lastSyncDate ??= account.lastSyncedAt;

                final hasSync = lastSyncDate != null;
                final isRecent = hasSync &&
                    lastSyncDate.isAfter(
                      DateTime.now().subtract(const Duration(hours: 24)),
                    );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: platformColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getPlatformIcon(account.platform),
                          color: platformColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.accountName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasSync
                                  ? 'Last synced: ${_formatDateTime(lastSyncDate!)}'
                                  : 'Never synced',
                              style: TextStyle(
                                color: hasSync ? Colors.grey[600] : Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasSync
                              ? (isRecent ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1))
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasSync
                                  ? (isRecent ? Icons.check_circle : Icons.schedule)
                                  : Icons.warning_rounded,
                              color: hasSync
                                  ? (isRecent ? Colors.green : Colors.orange)
                                  : Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasSync ? (isRecent ? 'Synced' : 'Stale') : 'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasSync
                                    ? (isRecent ? Colors.green : Colors.orange)
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
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

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
