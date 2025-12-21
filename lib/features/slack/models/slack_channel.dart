/// Helper to safely coerce values to bool (handles Supabase returning int for bool)
bool _coerceBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

/// Model representing a Slack channel with its committee mapping
class SlackChannel {
  const SlackChannel({
    required this.id,
    required this.slackChannelId,
    required this.slackChannelName,
    required this.committeeName,
    this.isActive = true,
    this.archiveMessages = true,
    this.createdAt,
  });

  factory SlackChannel.fromJson(Map<String, dynamic> json) {
    return SlackChannel(
      id: json['id']?.toString() ?? '',
      slackChannelId: json['slack_channel_id']?.toString() ?? '',
      slackChannelName: json['slack_channel_name']?.toString() ?? '',
      committeeName: json['committee_name']?.toString() ?? '',
      isActive: _coerceBool(json['is_active'], defaultValue: true),
      archiveMessages: _coerceBool(json['archive_messages'], defaultValue: true),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  final String id;
  final String slackChannelId;
  final String slackChannelName;
  final String committeeName;
  final bool isActive;
  final bool archiveMessages;
  final DateTime? createdAt;

  /// Display name with # prefix
  String get displayName => '#$slackChannelName';

  Map<String, dynamic> toJson() => {
        'id': id,
        'slack_channel_id': slackChannelId,
        'slack_channel_name': slackChannelName,
        'committee_name': committeeName,
        'is_active': isActive,
        'archive_messages': archiveMessages,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// Model representing archive status for a channel
class SlackArchiveStatus {
  const SlackArchiveStatus({
    required this.slackChannelId,
    this.lastArchivedTs,
    this.lastArchiveDate,
    this.totalMessagesArchived = 0,
    this.archiveInProgress = false,
  });

  factory SlackArchiveStatus.fromJson(Map<String, dynamic> json) {
    return SlackArchiveStatus(
      slackChannelId: json['slack_channel_id']?.toString() ?? '',
      lastArchivedTs: json['last_archived_ts']?.toString(),
      lastArchiveDate: json['last_archive_date'] != null
          ? DateTime.tryParse(json['last_archive_date'].toString())
          : null,
      totalMessagesArchived:
          (json['total_messages_archived'] as num?)?.toInt() ?? 0,
      archiveInProgress: _coerceBool(json['archive_in_progress']),
    );
  }

  final String slackChannelId;
  final String? lastArchivedTs;
  final DateTime? lastArchiveDate;
  final int totalMessagesArchived;
  final bool archiveInProgress;
}
