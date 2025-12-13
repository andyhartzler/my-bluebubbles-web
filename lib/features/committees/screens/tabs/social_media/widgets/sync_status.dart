import 'package:flutter/material.dart';
import '../models/social_media_account.dart';
import '../theme/communications_committee_theme.dart';

/// Displays the last sync status for each platform
class SyncStatus extends StatelessWidget {
  final List<SocialMediaAccount> accounts;
  final Set<String> selectedAccountIds;

  const SyncStatus({
    super.key,
    required this.accounts,
    required this.selectedAccountIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredAccounts = accounts.where((a) => selectedAccountIds.contains(a.id)).toList();

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
            'Last Sync Status',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...filteredAccounts.map((account) {
            final platformColor =
                CommunicationsCommitteeTheme.getPlatformColor(account.platform);
            final hasSync = account.lastSyncedAt != null;
            final isRecent = hasSync &&
                account.lastSyncedAt!.isAfter(
                  DateTime.now().subtract(const Duration(hours: 24)),
                );

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: platformColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPlatformIcon(account.platform),
                  color: platformColor,
                  size: 20,
                ),
              ),
              title: Text(
                account.accountName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                hasSync
                    ? 'Last synced: ${_formatDateTime(account.lastSyncedAt!)}'
                    : 'Never synced',
                style: TextStyle(
                  color: hasSync ? Colors.grey[600] : Colors.orange[700],
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                hasSync
                    ? (isRecent ? Icons.check_circle : Icons.schedule)
                    : Icons.warning,
                color: hasSync
                    ? (isRecent ? Colors.green : Colors.orange)
                    : Colors.orange,
                size: 20,
              ),
            );
          }),
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
