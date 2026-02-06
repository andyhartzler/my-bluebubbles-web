class PageView {
  final String id;
  final String? eventId;
  final String pagePath;
  final String? pageTitle;
  final String? visitorId;
  final String? sessionId;
  final String? trackingId;
  final String? referrer;
  final String? utmSource, utmMedium, utmCampaign, utmTerm, utmContent;
  final String? userAgent, browser, browserVersion, os, osVersion;
  final String? deviceType;
  final int? screenWidth, screenHeight, viewportWidth, viewportHeight;
  final int? colorDepth, hardwareConcurrency, maxTouchPoints;
  final double? pixelRatio, deviceMemory;
  final bool? touchSupport;
  final String? ipAddress, city, region, country, timezone;
  final double? latitude, longitude;
  final String? language, platform, connectionType, webglRenderer;
  final double? connectionDownlink;
  final bool? cookieEnabled, doNotTrack, pdfViewerEnabled;
  final int? durationSeconds, scrollDepthPct, maxScrollY;
  final DateTime createdAt;

  PageView({
    required this.id,
    this.eventId,
    required this.pagePath,
    this.pageTitle,
    this.visitorId,
    this.sessionId,
    this.trackingId,
    this.referrer,
    this.utmSource, this.utmMedium, this.utmCampaign, this.utmTerm, this.utmContent,
    this.userAgent, this.browser, this.browserVersion, this.os, this.osVersion,
    this.deviceType,
    this.screenWidth, this.screenHeight, this.viewportWidth, this.viewportHeight,
    this.colorDepth, this.hardwareConcurrency, this.maxTouchPoints,
    this.pixelRatio, this.deviceMemory,
    this.touchSupport,
    this.ipAddress, this.city, this.region, this.country, this.timezone,
    this.latitude, this.longitude,
    this.language, this.platform, this.connectionType, this.webglRenderer,
    this.connectionDownlink,
    this.cookieEnabled, this.doNotTrack, this.pdfViewerEnabled,
    this.durationSeconds, this.scrollDepthPct, this.maxScrollY,
    required this.createdAt,
  });

  factory PageView.fromJson(Map<String, dynamic> json) {
    return PageView(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      pagePath: json['page_path'] as String? ?? '/',
      pageTitle: json['page_title'] as String?,
      visitorId: json['visitor_id'] as String?,
      sessionId: json['session_id'] as String?,
      trackingId: json['tracking_id'] as String?,
      referrer: json['referrer'] as String?,
      utmSource: json['utm_source'] as String?,
      utmMedium: json['utm_medium'] as String?,
      utmCampaign: json['utm_campaign'] as String?,
      utmTerm: json['utm_term'] as String?,
      utmContent: json['utm_content'] as String?,
      userAgent: json['user_agent'] as String?,
      browser: json['browser'] as String?,
      browserVersion: json['browser_version'] as String?,
      os: json['os'] as String?,
      osVersion: json['os_version'] as String?,
      deviceType: json['device_type'] as String?,
      screenWidth: json['screen_width'] as int?,
      screenHeight: json['screen_height'] as int?,
      viewportWidth: json['viewport_width'] as int?,
      viewportHeight: json['viewport_height'] as int?,
      colorDepth: json['color_depth'] as int?,
      hardwareConcurrency: json['hardware_concurrency'] as int?,
      maxTouchPoints: json['max_touch_points'] as int?,
      pixelRatio: (json['pixel_ratio'] as num?)?.toDouble(),
      deviceMemory: (json['device_memory'] as num?)?.toDouble(),
      touchSupport: json['touch_support'] as bool?,
      ipAddress: json['ip_address'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      timezone: json['timezone'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      language: json['language'] as String?,
      platform: json['platform'] as String?,
      connectionType: json['connection_type'] as String?,
      webglRenderer: json['webgl_renderer'] as String?,
      connectionDownlink: (json['connection_downlink'] as num?)?.toDouble(),
      cookieEnabled: json['cookie_enabled'] as bool?,
      doNotTrack: json['do_not_track'] as bool?,
      pdfViewerEnabled: json['pdf_viewer_enabled'] as bool?,
      durationSeconds: json['duration_seconds'] as int?,
      scrollDepthPct: json['scroll_depth_pct'] as int?,
      maxScrollY: json['max_scroll_y'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class FormEvent {
  final String id;
  final String? eventId, pageViewId, visitorId, sessionId, trackingId;
  final String eventType;
  final String? fieldName;
  final bool? fieldHasValue;
  final Map<String, dynamic>? formData;
  final String? errorMessage;
  final DateTime createdAt;

  FormEvent({
    required this.id,
    this.eventId, this.pageViewId, this.visitorId, this.sessionId, this.trackingId,
    required this.eventType,
    this.fieldName,
    this.fieldHasValue,
    this.formData,
    this.errorMessage,
    required this.createdAt,
  });

  factory FormEvent.fromJson(Map<String, dynamic> json) {
    return FormEvent(
      id: json['id'] as String,
      eventId: json['event_id'] as String?,
      pageViewId: json['page_view_id'] as String?,
      visitorId: json['visitor_id'] as String?,
      sessionId: json['session_id'] as String?,
      trackingId: json['tracking_id'] as String?,
      eventType: json['event_type'] as String,
      fieldName: json['field_name'] as String?,
      fieldHasValue: json['field_has_value'] as bool?,
      formData: json['form_data'] != null
          ? Map<String, dynamic>.from(json['form_data'] as Map)
          : null,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TrackingLink {
  final String id;
  final String token;
  final String? eventId, phoneE164, attendeeName;
  final DateTime sentAt;
  final DateTime? clickedAt, formStartedAt, formCompletedAt;
  final int clickCount;

  TrackingLink({
    required this.id,
    required this.token,
    this.eventId, this.phoneE164, this.attendeeName,
    required this.sentAt,
    this.clickedAt, this.formStartedAt, this.formCompletedAt,
    this.clickCount = 0,
  });

  factory TrackingLink.fromJson(Map<String, dynamic> json) {
    return TrackingLink(
      id: json['id'] as String,
      token: json['token'] as String,
      eventId: json['event_id'] as String?,
      phoneE164: json['phone_e164'] as String?,
      attendeeName: json['attendee_name'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
      clickedAt: json['clicked_at'] != null ? DateTime.parse(json['clicked_at'] as String) : null,
      formStartedAt: json['form_started_at'] != null ? DateTime.parse(json['form_started_at'] as String) : null,
      formCompletedAt: json['form_completed_at'] != null ? DateTime.parse(json['form_completed_at'] as String) : null,
      clickCount: json['click_count'] as int? ?? 0,
    );
  }
}

class EventAnalyticsSummary {
  final int totalViews, uniqueVisitors, totalSessions;
  final double avgDuration, avgScrollDepth;
  final int desktopViews, mobileViews, tabletViews;
  final DateTime? firstView, lastView;

  EventAnalyticsSummary({
    this.totalViews = 0,
    this.uniqueVisitors = 0,
    this.totalSessions = 0,
    this.avgDuration = 0,
    this.avgScrollDepth = 0,
    this.desktopViews = 0,
    this.mobileViews = 0,
    this.tabletViews = 0,
    this.firstView,
    this.lastView,
  });

  factory EventAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return EventAnalyticsSummary(
      totalViews: (json['total_views'] as num?)?.toInt() ?? 0,
      uniqueVisitors: (json['unique_visitors'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      avgDuration: (json['avg_duration'] as num?)?.toDouble() ?? 0,
      avgScrollDepth: (json['avg_scroll_depth'] as num?)?.toDouble() ?? 0,
      desktopViews: (json['desktop_views'] as num?)?.toInt() ?? 0,
      mobileViews: (json['mobile_views'] as num?)?.toInt() ?? 0,
      tabletViews: (json['tablet_views'] as num?)?.toInt() ?? 0,
      firstView: json['first_view'] != null ? DateTime.parse(json['first_view'] as String) : null,
      lastView: json['last_view'] != null ? DateTime.parse(json['last_view'] as String) : null,
    );
  }
}
