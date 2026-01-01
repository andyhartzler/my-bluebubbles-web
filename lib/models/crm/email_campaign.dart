import 'package:bluebubbles/models/crm/subscriber.dart';

/// Represents an email campaign with aggregate statistics
class EmailCampaign {
  final String id;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String source;
  final String? sourceCampaignId;
  final String name;
  final String subject;
  final String? previewText;
  final String? fromName;
  final String? fromEmail;
  final String? replyTo;
  final String? audienceName;
  final String? segmentName;
  final String? htmlContent;
  final String? textContent;
  final DateTime? sentAt;
  final String? sendWeekday;
  final int totalRecipients;
  final int totalSent;
  final int totalDelivered;
  final int totalSoftBounces;
  final int totalHardBounces;
  final int totalBounces;
  final int totalOpens;
  final int uniqueOpens;
  final double? openRate;
  final int totalClicks;
  final int uniqueClicks;
  final double? clickRate;
  final double? clickToOpenRate;
  final int totalUnsubscribes;
  final int totalComplaints;
  final int totalFailed;
  final int timesForwarded;
  final int forwardedOpens;
  final int timesLikedFacebook;
  final int totalWebview;
  final String? folderId;
  final List<String>? tags;

  const EmailCampaign({
    required this.id,
    required this.name,
    required this.subject,
    required this.source,
    this.createdAt,
    this.updatedAt,
    this.sourceCampaignId,
    this.previewText,
    this.fromName,
    this.fromEmail,
    this.replyTo,
    this.audienceName,
    this.segmentName,
    this.htmlContent,
    this.textContent,
    this.sentAt,
    this.sendWeekday,
    this.totalRecipients = 0,
    this.totalSent = 0,
    this.totalDelivered = 0,
    this.totalSoftBounces = 0,
    this.totalHardBounces = 0,
    this.totalBounces = 0,
    this.totalOpens = 0,
    this.uniqueOpens = 0,
    this.openRate,
    this.totalClicks = 0,
    this.uniqueClicks = 0,
    this.clickRate,
    this.clickToOpenRate,
    this.totalUnsubscribes = 0,
    this.totalComplaints = 0,
    this.totalFailed = 0,
    this.timesForwarded = 0,
    this.forwardedOpens = 0,
    this.timesLikedFacebook = 0,
    this.totalWebview = 0,
    this.folderId,
    this.tags,
  });

  factory EmailCampaign.fromJson(Map<String, dynamic> json) {
    return EmailCampaign(
      id: json['id'] as String,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      source: json['source'] as String? ?? 'unknown',
      sourceCampaignId: json['source_campaign_id'] as String?,
      name: json['name'] as String? ?? 'Untitled Campaign',
      subject: json['subject'] as String? ?? '',
      previewText: json['preview_text'] as String?,
      fromName: json['from_name'] as String?,
      fromEmail: json['from_email'] as String?,
      replyTo: json['reply_to'] as String?,
      audienceName: json['audience_name'] as String?,
      segmentName: json['segment_name'] as String?,
      htmlContent: json['html_content'] as String?,
      textContent: json['text_content'] as String?,
      sentAt: _parseDate(json['sent_at']),
      sendWeekday: json['send_weekday'] as String?,
      totalRecipients: json['total_recipients'] as int? ?? 0,
      totalSent: json['total_sent'] as int? ?? 0,
      totalDelivered: json['total_delivered'] as int? ?? 0,
      totalSoftBounces: json['total_soft_bounces'] as int? ?? 0,
      totalHardBounces: json['total_hard_bounces'] as int? ?? 0,
      totalBounces: json['total_bounces'] as int? ?? 0,
      totalOpens: json['total_opens'] as int? ?? 0,
      uniqueOpens: json['unique_opens'] as int? ?? 0,
      openRate: _parseDouble(json['open_rate']),
      totalClicks: json['total_clicks'] as int? ?? 0,
      uniqueClicks: json['unique_clicks'] as int? ?? 0,
      clickRate: _parseDouble(json['click_rate']),
      clickToOpenRate: _parseDouble(json['click_to_open_rate']),
      totalUnsubscribes: json['total_unsubscribes'] as int? ?? 0,
      totalComplaints: json['total_complaints'] as int? ?? 0,
      totalFailed: json['total_failed'] as int? ?? 0,
      timesForwarded: json['times_forwarded'] as int? ?? 0,
      forwardedOpens: json['forwarded_opens'] as int? ?? 0,
      timesLikedFacebook: json['times_liked_facebook'] as int? ?? 0,
      totalWebview: json['total_webview'] as int? ?? 0,
      folderId: json['folder_id'] as String?,
      tags: _parseStringList(json['tags']),
    );
  }

  /// Computed open rate if not stored
  double get calculatedOpenRate =>
      totalDelivered > 0 ? (uniqueOpens / totalDelivered) * 100 : 0;

  /// Computed click rate if not stored
  double get calculatedClickRate =>
      totalDelivered > 0 ? (uniqueClicks / totalDelivered) * 100 : 0;

  /// Computed click-to-open rate
  double get calculatedClickToOpenRate =>
      uniqueOpens > 0 ? (uniqueClicks / uniqueOpens) * 100 : 0;

  /// Display-friendly open rate
  double get displayOpenRate => openRate ?? calculatedOpenRate;

  /// Display-friendly click rate
  double get displayClickRate => clickRate ?? calculatedClickRate;

  /// Whether this campaign has been sent
  bool get isSent => sentAt != null;

  /// Whether this campaign has HTML content
  bool get hasHtmlContent => htmlContent != null && htmlContent!.isNotEmpty;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.tryParse(value as String);
    } catch (_) {
      return null;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }
}

/// Represents a recipient's engagement with a specific campaign
class EmailCampaignRecipient {
  final String id;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String campaignId;
  final String? subscriberId;
  final String source;
  final String? sourceStatId;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final int? mauticLeadId;
  final String? mauticTrackingHash;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final bool bounced;
  final DateTime? bouncedAt;
  final String? bounceType;
  final String? bounceReason;
  final bool failed;
  final DateTime? failedAt;
  final bool opened;
  final DateTime? firstOpenedAt;
  final DateTime? lastOpenedAt;
  final int openCount;
  final Map<String, dynamic>? openDetails;
  final bool clicked;
  final DateTime? firstClickedAt;
  final DateTime? lastClickedAt;
  final int clickCount;
  final bool unsubscribed;
  final DateTime? unsubscribedAt;
  final String? unsubscribeReason;
  final String? unsubscribeDescription;
  final bool complained;
  final DateTime? complainedAt;
  final bool viewedInBrowser;
  final DateTime? viewedInBrowserAt;
  final int? memberRating;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceType;
  final String? geoCountry;
  final String? geoRegion;
  final String? geoCity;

  // Optional joined data
  final Subscriber? subscriber;
  final EmailCampaign? campaign;

  const EmailCampaignRecipient({
    required this.id,
    required this.campaignId,
    required this.email,
    required this.source,
    this.createdAt,
    this.updatedAt,
    this.subscriberId,
    this.sourceStatId,
    this.firstName,
    this.lastName,
    this.fullName,
    this.mauticLeadId,
    this.mauticTrackingHash,
    this.sentAt,
    this.deliveredAt,
    this.bounced = false,
    this.bouncedAt,
    this.bounceType,
    this.bounceReason,
    this.failed = false,
    this.failedAt,
    this.opened = false,
    this.firstOpenedAt,
    this.lastOpenedAt,
    this.openCount = 0,
    this.openDetails,
    this.clicked = false,
    this.firstClickedAt,
    this.lastClickedAt,
    this.clickCount = 0,
    this.unsubscribed = false,
    this.unsubscribedAt,
    this.unsubscribeReason,
    this.unsubscribeDescription,
    this.complained = false,
    this.complainedAt,
    this.viewedInBrowser = false,
    this.viewedInBrowserAt,
    this.memberRating,
    this.ipAddress,
    this.userAgent,
    this.deviceType,
    this.geoCountry,
    this.geoRegion,
    this.geoCity,
    this.subscriber,
    this.campaign,
  });

  factory EmailCampaignRecipient.fromJson(Map<String, dynamic> json) {
    return EmailCampaignRecipient(
      id: json['id'] as String,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      campaignId: json['campaign_id'] as String,
      subscriberId: json['subscriber_id'] as String?,
      source: json['source'] as String? ?? 'unknown',
      sourceStatId: json['source_stat_id'] as String?,
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      fullName: json['full_name'] as String?,
      mauticLeadId: json['mautic_lead_id'] as int?,
      mauticTrackingHash: json['mautic_tracking_hash'] as String?,
      sentAt: _parseDate(json['sent_at']),
      deliveredAt: _parseDate(json['delivered_at']),
      bounced: _coerceBool(json['bounced']) ?? false,
      bouncedAt: _parseDate(json['bounced_at']),
      bounceType: json['bounce_type'] as String?,
      bounceReason: json['bounce_reason'] as String?,
      failed: _coerceBool(json['failed']) ?? false,
      failedAt: _parseDate(json['failed_at']),
      opened: _coerceBool(json['opened']) ?? false,
      firstOpenedAt: _parseDate(json['first_opened_at']),
      lastOpenedAt: _parseDate(json['last_opened_at']),
      openCount: json['open_count'] as int? ?? 0,
      openDetails: json['open_details'] as Map<String, dynamic>?,
      clicked: _coerceBool(json['clicked']) ?? false,
      firstClickedAt: _parseDate(json['first_clicked_at']),
      lastClickedAt: _parseDate(json['last_clicked_at']),
      clickCount: json['click_count'] as int? ?? 0,
      unsubscribed: _coerceBool(json['unsubscribed']) ?? false,
      unsubscribedAt: _parseDate(json['unsubscribed_at']),
      unsubscribeReason: json['unsubscribe_reason'] as String?,
      unsubscribeDescription: json['unsubscribe_description'] as String?,
      complained: _coerceBool(json['complained']) ?? false,
      complainedAt: _parseDate(json['complained_at']),
      viewedInBrowser: _coerceBool(json['viewed_in_browser']) ?? false,
      viewedInBrowserAt: _parseDate(json['viewed_in_browser_at']),
      memberRating: json['member_rating'] as int?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      deviceType: json['device_type'] as String?,
      geoCountry: json['geo_country'] as String?,
      geoRegion: json['geo_region'] as String?,
      geoCity: json['geo_city'] as String?,
      subscriber: json['subscriber'] != null
          ? Subscriber.fromJson(json['subscriber'] as Map<String, dynamic>)
          : null,
      campaign: json['campaign'] != null
          ? EmailCampaign.fromJson(json['campaign'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Display name (full name, first+last, or email)
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return email;
  }

  /// Get geo location string
  String? get geoLocation {
    final parts = <String>[];
    if (geoCity != null) parts.add(geoCity!);
    if (geoRegion != null) parts.add(geoRegion!);
    if (geoCountry != null) parts.add(geoCountry!);
    return parts.isEmpty ? null : parts.join(', ');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.tryParse(value as String);
    } catch (_) {
      return null;
    }
  }

  static bool? _coerceBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') return true;
      if (lower == 'false' || lower == '0' || lower == 'no') return false;
    }
    return null;
  }
}

/// Represents a tracked link in an email campaign
class EmailCampaignLink {
  final String id;
  final DateTime? createdAt;
  final String campaignId;
  final String url;
  final String? urlTitle;
  final String source;
  final String? sourceLinkId;
  final int totalClicks;
  final int uniqueClicks;

  const EmailCampaignLink({
    required this.id,
    required this.campaignId,
    required this.url,
    required this.source,
    this.createdAt,
    this.urlTitle,
    this.sourceLinkId,
    this.totalClicks = 0,
    this.uniqueClicks = 0,
  });

  factory EmailCampaignLink.fromJson(Map<String, dynamic> json) {
    return EmailCampaignLink(
      id: json['id'] as String,
      createdAt: _parseDate(json['created_at']),
      campaignId: json['campaign_id'] as String,
      url: json['url'] as String? ?? '',
      urlTitle: json['url_title'] as String?,
      source: json['source'] as String? ?? 'unknown',
      sourceLinkId: json['source_link_id'] as String?,
      totalClicks: json['total_clicks'] as int? ?? 0,
      uniqueClicks: json['unique_clicks'] as int? ?? 0,
    );
  }

  /// Display-friendly title (url_title or truncated URL)
  String get displayTitle {
    if (urlTitle != null && urlTitle!.isNotEmpty) return urlTitle!;
    if (url.length > 60) return '${url.substring(0, 57)}...';
    return url;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.tryParse(value as String);
    } catch (_) {
      return null;
    }
  }
}

/// Represents a single click event on a campaign link
class EmailCampaignLinkClick {
  final int id;
  final DateTime? createdAt;
  final String campaignId;
  final String? linkId;
  final String? recipientId;
  final String? subscriberId;
  final String email;
  final String url;
  final DateTime clickedAt;
  final String? ipAddress;
  final String? userAgent;
  final String? referer;
  final String? deviceType;
  final String? browser;
  final String? os;
  final String? geoCountry;
  final String? geoRegion;
  final String? geoCity;

  // Optional joined data
  final Subscriber? subscriber;

  const EmailCampaignLinkClick({
    required this.id,
    required this.campaignId,
    required this.email,
    required this.url,
    required this.clickedAt,
    this.createdAt,
    this.linkId,
    this.recipientId,
    this.subscriberId,
    this.ipAddress,
    this.userAgent,
    this.referer,
    this.deviceType,
    this.browser,
    this.os,
    this.geoCountry,
    this.geoRegion,
    this.geoCity,
    this.subscriber,
  });

  factory EmailCampaignLinkClick.fromJson(Map<String, dynamic> json) {
    return EmailCampaignLinkClick(
      id: json['id'] as int,
      createdAt: _parseDate(json['created_at']),
      campaignId: json['campaign_id'] as String,
      linkId: json['link_id'] as String?,
      recipientId: json['recipient_id'] as String?,
      subscriberId: json['subscriber_id'] as String?,
      email: json['email'] as String? ?? '',
      url: json['url'] as String? ?? '',
      clickedAt: _parseDate(json['clicked_at']) ?? DateTime.now(),
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      referer: json['referer'] as String?,
      deviceType: json['device_type'] as String?,
      browser: json['browser'] as String?,
      os: json['os'] as String?,
      geoCountry: json['geo_country'] as String?,
      geoRegion: json['geo_region'] as String?,
      geoCity: json['geo_city'] as String?,
      subscriber: json['subscriber'] != null
          ? Subscriber.fromJson(json['subscriber'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Get geo location string
  String? get geoLocation {
    final parts = <String>[];
    if (geoCity != null) parts.add(geoCity!);
    if (geoRegion != null) parts.add(geoRegion!);
    if (geoCountry != null) parts.add(geoCountry!);
    return parts.isEmpty ? null : parts.join(', ');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.tryParse(value as String);
    } catch (_) {
      return null;
    }
  }
}

/// Aggregate statistics for email campaigns
class EmailCampaignStats {
  final int totalCampaigns;
  final int sentCampaigns;
  final int totalRecipients;
  final int totalOpens;
  final int totalClicks;
  final int totalBounces;
  final int totalUnsubscribes;
  final double averageOpenRate;
  final double averageClickRate;
  final Map<String, int> bySource;

  const EmailCampaignStats({
    this.totalCampaigns = 0,
    this.sentCampaigns = 0,
    this.totalRecipients = 0,
    this.totalOpens = 0,
    this.totalClicks = 0,
    this.totalBounces = 0,
    this.totalUnsubscribes = 0,
    this.averageOpenRate = 0,
    this.averageClickRate = 0,
    this.bySource = const {},
  });
}

/// Result wrapper for paginated campaign fetches
class EmailCampaignFetchResult {
  final List<EmailCampaign> campaigns;
  final int? totalCount;
  final EmailCampaignStats? stats;

  const EmailCampaignFetchResult({
    required this.campaigns,
    this.totalCount,
    this.stats,
  });
}

/// Filter options for campaign recipients
enum RecipientFilter {
  all,
  opened,
  clicked,
  bounced,
  unsubscribed,
  complained,
  delivered,
  failed,
}
