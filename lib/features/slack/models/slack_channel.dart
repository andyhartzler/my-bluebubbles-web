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
      isActive: json['is_active'] as bool? ?? true,
      archiveMessages: json['archive_messages'] as bool? ?? true,
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
      archiveInProgress: json['archive_in_progress'] as bool? ?? false,
    );
  }

  final String slackChannelId;
  final String? lastArchivedTs;
  final DateTime? lastArchiveDate;
  final int totalMessagesArchived;
  final bool archiveInProgress;
}
