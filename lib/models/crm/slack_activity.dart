import 'package:flutter/foundation.dart';

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

class SlackProfile {
  SlackProfile({
    this.slackUserId,
    this.email,
    this.displayName,
    this.realName,
    this.avatarUrl,
  });

  factory SlackProfile.fromJson(Map<String, dynamic> json) {
    return SlackProfile(
      slackUserId: json['slack_user_id'] as String?,
      email: json['slack_email'] as String?,
      displayName: json['slack_display_name'] as String?,
      realName: json['slack_real_name'] as String?,
      avatarUrl: json['slack_avatar_url'] as String?,
    );
  }

  final String? slackUserId;
  final String? email;
  final String? displayName;
  final String? realName;
  final String? avatarUrl;

  bool get isLinked => slackUserId != null && slackUserId!.isNotEmpty;
}

class SlackChannelInfo {
  const SlackChannelInfo({this.channelName, this.committeeName});

  factory SlackChannelInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SlackChannelInfo();
    return SlackChannelInfo(
      channelName: json['slack_channel_name'] as String?,
      committeeName: json['committee_name'] as String?,
    );
  }

  final String? channelName;
  final String? committeeName;
}

class SlackReaction {
  const SlackReaction({required this.name, required this.count});

  factory SlackReaction.fromJson(Map<String, dynamic> json) {
    return SlackReaction(
      name: json['name'] as String? ?? 'reaction',
      count: _parseInt(json['count']) ?? 0,
    );
  }

  final String name;
  final int count;
}

class SlackMessage {
  SlackMessage({
    required this.id,
    this.messageTs,
    this.text,
    this.postedAt,
    this.channelInfo,
    this.slackUserId,
    this.threadTs,
    this.hasFiles = false,
    List<SlackReaction> reactions = const [],
  }) : reactions = List<SlackReaction>.unmodifiable(reactions);

  factory SlackMessage.fromJson(Map<String, dynamic> json) {
    final channelInfo = json['slack_channel_committee_mapping'];
    final reactions = (json['reactions'] as List<dynamic>? ?? [])
        .map((reaction) => reaction is Map<String, dynamic>
            ? SlackReaction.fromJson(reaction)
            : null)
        .whereType<SlackReaction>()
        .toList(growable: false);

    return SlackMessage(
      id: json['id']?.toString() ?? json['slack_message_ts']?.toString() ?? UniqueKey().toString(),
      messageTs: json['slack_message_ts'] as String?,
      text: json['message_text'] as String?,
      postedAt: _parseDate(json['posted_at']),
      channelInfo: channelInfo is Map<String, dynamic>
          ? SlackChannelInfo.fromJson(channelInfo)
          : const SlackChannelInfo(),
      slackUserId: json['slack_user_id'] as String?,
      threadTs: json['thread_ts'] as String?,
      hasFiles: json['has_files'] == true,
      reactions: reactions,
    );
  }

  final String id;
  final String? messageTs;
  final String? text;
  final DateTime? postedAt;
  final SlackChannelInfo? channelInfo;
  final String? slackUserId;
  final String? threadTs;
  final bool hasFiles;
  final List<SlackReaction> reactions;

  bool get isThreadReply =>
      threadTs != null && messageTs != null && threadTs != messageTs;
}

class SlackActivityStatistics {
  const SlackActivityStatistics({
    required this.totalMessages,
    required this.channelsActiveIn,
    this.latestMessage,
    this.earliestMessage,
  });

  factory SlackActivityStatistics.fromJson(Map<String, dynamic> json) {
    return SlackActivityStatistics(
      totalMessages: _parseInt(json['total_messages']) ?? 0,
      channelsActiveIn: _parseInt(json['channels_active_in']) ?? 0,
      latestMessage: _parseDate(json['latest_message']),
      earliestMessage: _parseDate(json['earliest_message']),
    );
  }

  final int totalMessages;
  final int channelsActiveIn;
  final DateTime? latestMessage;
  final DateTime? earliestMessage;
}

class SlackActivityResult {
  const SlackActivityResult({
    required this.memberId,
    required this.messages,
    required this.totalMessages,
    this.statistics,
  });

  factory SlackActivityResult.fromJson(Map<String, dynamic> json) {
    final messages = (json['messages'] as List<dynamic>? ?? [])
        .map((entry) => entry is Map<String, dynamic>
            ? SlackMessage.fromJson(entry)
            : null)
        .whereType<SlackMessage>()
        .toList(growable: false);

    final statsJson = json['statistics'];
    final stats = statsJson is Map<String, dynamic>
        ? SlackActivityStatistics.fromJson(statsJson)
        : null;

    final totalMessages =
        _parseInt(json['total_messages']) ?? stats?.totalMessages ?? messages.length;

    return SlackActivityResult(
      memberId: json['member_id']?.toString() ?? '',
      messages: messages,
      statistics: stats,
      totalMessages: totalMessages,
    );
  }

  final String memberId;
  final List<SlackMessage> messages;
  final SlackActivityStatistics? statistics;
  final int totalMessages;
}

class SlackUnmatchedUser {
  const SlackUnmatchedUser({
    required this.slackUserId,
    this.email,
    this.displayName,
    this.realName,
    this.notes,
    this.manuallyRejected = false,
    this.createdAt,
  });

  factory SlackUnmatchedUser.fromJson(Map<String, dynamic> json) {
    return SlackUnmatchedUser(
      slackUserId: json['slack_user_id'] as String? ?? '',
      email: json['slack_email'] as String?,
      displayName: json['slack_display_name'] as String?,
      realName: json['slack_real_name'] as String?,
      notes: json['notes'] as String?,
      manuallyRejected: json['manually_rejected'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']),
    );
  }

  final String slackUserId;
  final String? email;
  final String? displayName;
  final String? realName;
  final String? notes;
  final bool manuallyRejected;
  final DateTime? createdAt;

  String? get usernameDisplay =>
      displayName != null && displayName!.isNotEmpty ? '@$displayName' : null;

  String get primaryLabel => realName ?? displayName ?? slackUserId;
}
