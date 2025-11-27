import 'package:bluebubbles/models/crm/message_filter.dart';

enum CampaignStatus {
  draft,
  scheduled,
  sending,
  sent,
  failed,
  archived,
}

CampaignStatus _statusFromString(String? value) {
  switch (value) {
    case 'scheduled':
      return CampaignStatus.scheduled;
    case 'sending':
      return CampaignStatus.sending;
    case 'sent':
      return CampaignStatus.sent;
    case 'failed':
      return CampaignStatus.failed;
    case 'archived':
      return CampaignStatus.archived;
    case 'draft':
    default:
      return CampaignStatus.draft;
  }
}

String _statusToString(CampaignStatus status) {
  switch (status) {
    case CampaignStatus.scheduled:
      return 'scheduled';
    case CampaignStatus.sending:
      return 'sending';
    case CampaignStatus.sent:
      return 'sent';
    case CampaignStatus.failed:
      return 'failed';
    case CampaignStatus.archived:
      return 'archived';
    case CampaignStatus.draft:
    default:
      return 'draft';
  }
}

class Campaign {
  final String? id;
  final String name;
  final String subject;
  final String? previewText;
  final String? htmlContent;
  final Map<String, dynamic>? designJson;
  final MessageFilter? segment;
  final CampaignStatus status;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int expectedRecipients;
  final int sentCount;
  final int openedCount;
  final int clickedCount;

  const Campaign({
    required this.name,
    required this.subject,
    this.id,
    this.previewText,
    this.htmlContent,
    this.designJson,
    this.segment,
    this.status = CampaignStatus.draft,
    this.scheduledAt,
    this.createdAt,
    this.updatedAt,
    this.expectedRecipients = 0,
    this.sentCount = 0,
    this.openedCount = 0,
    this.clickedCount = 0,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled campaign',
      subject: json['subject'] as String? ?? '',
      previewText: json['preview_text'] as String?,
      htmlContent: json['html_content'] as String?,
      designJson: (json['design_json'] as Map?)?.cast<String, dynamic>(),
      segment: _segmentFromJson(json['segment'] as Map<String, dynamic>?),
      status: _statusFromString(json['status'] as String?),
      scheduledAt: _parseDate(json['scheduled_at'] as String?),
      createdAt: _parseDate(json['created_at'] as String?),
      updatedAt: _parseDate(json['updated_at'] as String?),
      expectedRecipients: json['expected_recipients'] as int? ?? 0,
      sentCount: json['sent_count'] as int? ?? 0,
      openedCount: json['opened_count'] as int? ?? 0,
      clickedCount: json['clicked_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'preview_text': previewText,
      'html_content': htmlContent,
      'design_json': designJson,
      'segment': segment != null ? _segmentToJson(segment!) : null,
      'status': _statusToString(status),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'expected_recipients': expectedRecipients,
      'sent_count': sentCount,
      'opened_count': openedCount,
      'clicked_count': clickedCount,
    }..removeWhere((_, value) => value == null);
  }

  Campaign copyWith({
    String? id,
    String? name,
    String? subject,
    String? previewText,
    String? htmlContent,
    Map<String, dynamic>? designJson,
    MessageFilter? segment,
    CampaignStatus? status,
    DateTime? scheduledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? expectedRecipients,
    int? sentCount,
    int? openedCount,
    int? clickedCount,
  }) {
    return Campaign(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      previewText: previewText ?? this.previewText,
      htmlContent: htmlContent ?? this.htmlContent,
      designJson: designJson ?? this.designJson,
      segment: segment ?? this.segment,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expectedRecipients: expectedRecipients ?? this.expectedRecipients,
      sentCount: sentCount ?? this.sentCount,
      openedCount: openedCount ?? this.openedCount,
      clickedCount: clickedCount ?? this.clickedCount,
    );
  }

  String get statusLabel {
    switch (status) {
      case CampaignStatus.scheduled:
        return 'Scheduled';
      case CampaignStatus.sending:
        return 'Sending';
      case CampaignStatus.sent:
        return 'Sent';
      case CampaignStatus.failed:
        return 'Failed';
      case CampaignStatus.archived:
        return 'Archived';
      case CampaignStatus.draft:
      default:
        return 'Draft';
    }
  }
}

class CampaignRecipient {
  final String name;
  final String? email;
  final String? phoneE164;
  final String? county;

  const CampaignRecipient({
    required this.name,
    this.email,
    this.phoneE164,
    this.county,
  });

  factory CampaignRecipient.fromJson(Map<String, dynamic> json) {
    return CampaignRecipient(
      name: json['name'] as String? ?? 'Unknown',
      email: json['email'] as String?,
      phoneE164: json['phone_e164'] as String?,
      county: json['county'] as String?,
    );
  }
}

class CampaignAnalytics {
  final int delivered;
  final int opened;
  final int clicked;
  final int bounced;
  final int spam;
  final int unsubscribed;
  final int queued;
  final int scheduled;
  final int replies;

  const CampaignAnalytics({
    this.delivered = 0,
    this.opened = 0,
    this.clicked = 0,
    this.bounced = 0,
    this.spam = 0,
    this.unsubscribed = 0,
    this.queued = 0,
    this.scheduled = 0,
    this.replies = 0,
  });

  int get totalRecipients => delivered + queued + scheduled;

  double get openRate => totalRecipients == 0 ? 0 : opened / totalRecipients;

  double get clickRate => delivered == 0 ? 0 : clicked / delivered;

  double get replyRate => delivered == 0 ? 0 : replies / delivered;

  factory CampaignAnalytics.fromJson(Map<String, dynamic> json) {
    return CampaignAnalytics(
      delivered: json['delivered'] as int? ?? 0,
      opened: json['opened'] as int? ?? 0,
      clicked: json['clicked'] as int? ?? 0,
      bounced: json['bounced'] as int? ?? 0,
      spam: json['spam'] as int? ?? 0,
      unsubscribed: json['unsubscribed'] as int? ?? 0,
      queued: json['queued'] as int? ?? 0,
      scheduled: json['scheduled'] as int? ?? 0,
      replies: json['replies'] as int? ?? 0,
    );
  }
}

MessageFilter? _segmentFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  return MessageFilter(
    county: json['county'] as String?,
    congressionalDistrict: json['congressional_district'] as String?,
    committees:
        (json['committees'] as List<dynamic>?)?.whereType<String>().toList(),
    highSchool: json['high_school'] as String?,
    college: json['college'] as String?,
    chapterName: json['chapter_name'] as String?,
    chapterStatus: json['chapter_status'] as String?,
    minAge: json['min_age'] as int?,
    maxAge: json['max_age'] as int?,
    excludeOptedOut: json['exclude_opted_out'] as bool? ?? true,
    excludeRecentlyContacted:
        json['exclude_recently_contacted'] as bool? ?? false,
    recentContactThreshold: json['recent_contact_threshold'] is int
        ? Duration(days: json['recent_contact_threshold'] as int)
        : const Duration(days: 7),
  );
}

Map<String, dynamic> _segmentToJson(MessageFilter filter) {
  return {
    'county': filter.county,
    'congressional_district': filter.congressionalDistrict,
    'committees': filter.committees,
    'high_school': filter.highSchool,
    'college': filter.college,
    'chapter_name': filter.chapterName,
    'chapter_status': filter.chapterStatus,
    'min_age': filter.minAge,
    'max_age': filter.maxAge,
    'exclude_opted_out': filter.excludeOptedOut,
    'exclude_recently_contacted': filter.excludeRecentlyContacted,
    'recent_contact_threshold': filter.recentContactThreshold?.inDays,
  }..removeWhere((_, value) => value == null);
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}
