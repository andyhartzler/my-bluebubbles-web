import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_analytics.freezed.dart';
part 'job_analytics.g.dart';

/// Individual analytics event for a job (view, apply click, etc.)
@freezed
class JobAnalyticsEvent with _$JobAnalyticsEvent {
  const factory JobAnalyticsEvent({
    required int id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'member_id') required String memberId,
    @JsonKey(name: 'event_type') required String eventType,
    @JsonKey(name: 'event_data') Map<String, dynamic>? eventData,
    @JsonKey(name: 'session_id') String? sessionId,

    // Device info
    @JsonKey(name: 'device_type') String? deviceType,
    @JsonKey(name: 'user_agent') String? userAgent,
    String? browser,
    @JsonKey(name: 'browser_version') String? browserVersion,
    String? os,
    @JsonKey(name: 'os_version') String? osVersion,
    @JsonKey(name: 'is_mobile') @Default(false) bool isMobile,
    @JsonKey(name: 'is_tablet') @Default(false) bool isTablet,

    // Screen info
    @JsonKey(name: 'screen_width') int? screenWidth,
    @JsonKey(name: 'screen_height') int? screenHeight,
    @JsonKey(name: 'viewport_width') int? viewportWidth,
    @JsonKey(name: 'viewport_height') int? viewportHeight,
    @JsonKey(name: 'device_pixel_ratio') double? devicePixelRatio,

    // Location info
    @JsonKey(name: 'ip_address') String? ipAddress,
    String? city,
    String? region,
    String? country,
    @JsonKey(name: 'country_code') String? countryCode,
    double? latitude,
    double? longitude,
    String? timezone,

    // Referrer info
    @JsonKey(name: 'referrer_url') String? referrerUrl,
    @JsonKey(name: 'referrer_domain') String? referrerDomain,

    // UTM tracking
    @JsonKey(name: 'utm_source') String? utmSource,
    @JsonKey(name: 'utm_medium') String? utmMedium,
    @JsonKey(name: 'utm_campaign') String? utmCampaign,
    @JsonKey(name: 'utm_term') String? utmTerm,
    @JsonKey(name: 'utm_content') String? utmContent,

    // Page info
    @JsonKey(name: 'page_url') String? pageUrl,
    @JsonKey(name: 'page_path') String? pagePath,

    // Connection info
    @JsonKey(name: 'connection_type') String? connectionType,
    @JsonKey(name: 'connection_downlink') double? connectionDownlink,

    // Language
    String? language,
    List<String>? languages,
  }) = _JobAnalyticsEvent;

  const JobAnalyticsEvent._();

  factory JobAnalyticsEvent.fromJson(Map<String, dynamic> json) =>
      _$JobAnalyticsEventFromJson(json);

  /// Get a display label for event type
  String get eventTypeLabel {
    switch (eventType) {
      case 'view':
        return 'Page View';
      case 'view_end':
        return 'View Ended';
      case 'apply_click':
        return 'Apply Click';
      case 'apply_external':
        return 'External Apply';
      case 'apply_start':
        return 'Started Application';
      case 'apply_submit':
        return 'Submitted Application';
      case 'share':
        return 'Shared';
      case 'scroll_depth':
        return 'Scroll Depth';
      case 'copy_text':
        return 'Copied Text';
      case 'print':
        return 'Printed';
      case 'focus':
        return 'Window Focus';
      case 'blur':
        return 'Window Blur';
      case 'visibility_change':
        return 'Tab Changed';
      case 'tab_switch':
        return 'Tab Switch';
      case 'idle':
        return 'Went Idle';
      case 'resume':
        return 'Resumed';
      case 'error':
        return 'Error';
      default:
        return eventType;
    }
  }

  /// Get device description
  String get deviceDescription {
    final parts = <String>[];
    if (browser != null) parts.add(browser!);
    if (os != null) parts.add('on $os');
    if (isMobile) {
      parts.add('(Mobile)');
    } else if (isTablet) {
      parts.add('(Tablet)');
    }
    return parts.isEmpty ? 'Unknown device' : parts.join(' ');
  }

  /// Get location description
  String get locationDescription {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (region != null) parts.add(region!);
    if (country != null) parts.add(country!);
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }
}

/// Summarized member interaction with a job
@freezed
class JobMemberInteraction with _$JobMemberInteraction {
  const factory JobMemberInteraction({
    required String id,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'member_id') required String memberId,

    // Action flags
    @JsonKey(name: 'has_viewed') @Default(false) bool hasViewed,
    @JsonKey(name: 'has_clicked_apply') @Default(false) bool hasClickedApply,
    @JsonKey(name: 'has_applied') @Default(false) bool hasApplied,
    @JsonKey(name: 'has_shared') @Default(false) bool hasShared,
    @JsonKey(name: 'has_copied_text') @Default(false) bool hasCopiedText,
    @JsonKey(name: 'has_printed') @Default(false) bool hasPrinted,

    // Timestamps
    @JsonKey(name: 'first_viewed_at') DateTime? firstViewedAt,
    @JsonKey(name: 'last_viewed_at') DateTime? lastViewedAt,
    @JsonKey(name: 'apply_clicked_at') DateTime? applyClickedAt,
    @JsonKey(name: 'applied_at') DateTime? appliedAt,
    @JsonKey(name: 'shared_at') DateTime? sharedAt,
    @JsonKey(name: 'copied_text_at') DateTime? copiedTextAt,
    @JsonKey(name: 'printed_at') DateTime? printedAt,

    // Engagement metrics
    @JsonKey(name: 'view_count') @Default(0) int viewCount,
    @JsonKey(name: 'total_time_seconds') @Default(0) int totalTimeSeconds,
    @JsonKey(name: 'max_scroll_depth_percent') @Default(0) int maxScrollDepthPercent,
    @JsonKey(name: 'session_count') @Default(0) int sessionCount,
    @JsonKey(name: 'avg_session_duration_seconds') @Default(0.0) double avgSessionDurationSeconds,
    @JsonKey(name: 'total_idle_time_seconds') @Default(0) int totalIdleTimeSeconds,
    @JsonKey(name: 'total_active_time_seconds') @Default(0) int totalActiveTimeSeconds,
    @JsonKey(name: 'external_apply_clicks') @Default(0) int externalApplyClicks,

    // Application reference
    @JsonKey(name: 'application_id') String? applicationId,

    // Last device info
    @JsonKey(name: 'last_device_type') String? lastDeviceType,
    @JsonKey(name: 'last_browser') String? lastBrowser,
    @JsonKey(name: 'last_os') String? lastOs,
    @JsonKey(name: 'devices_used') @Default([]) List<String> devicesUsed,
    @JsonKey(name: 'browsers_used') @Default([]) List<String> browsersUsed,

    // Last location info
    @JsonKey(name: 'last_city') String? lastCity,
    @JsonKey(name: 'last_region') String? lastRegion,
    @JsonKey(name: 'last_country') String? lastCountry,
    @JsonKey(name: 'last_ip_address') String? lastIpAddress,

    // Session tracking
    @JsonKey(name: 'last_session_id') String? lastSessionId,

    // First touch attribution
    @JsonKey(name: 'first_referrer_url') String? firstReferrerUrl,
    @JsonKey(name: 'first_referrer_domain') String? firstReferrerDomain,
    @JsonKey(name: 'first_utm_source') String? firstUtmSource,
    @JsonKey(name: 'first_utm_medium') String? firstUtmMedium,
    @JsonKey(name: 'first_utm_campaign') String? firstUtmCampaign,

    // External apply tracking
    @JsonKey(name: 'last_external_apply_url') String? lastExternalApplyUrl,
  }) = _JobMemberInteraction;

  const JobMemberInteraction._();

  factory JobMemberInteraction.fromJson(Map<String, dynamic> json) =>
      _$JobMemberInteractionFromJson(json);

  /// Get engagement score (0-100)
  int get engagementScore {
    int score = 0;

    // View count contributes up to 20 points
    score += (viewCount * 4).clamp(0, 20);

    // Time on page contributes up to 25 points (1 point per 30 seconds)
    score += (totalTimeSeconds ~/ 30).clamp(0, 25);

    // Scroll depth contributes up to 15 points
    score += (maxScrollDepthPercent * 0.15).round().clamp(0, 15);

    // Session count contributes up to 10 points
    score += (sessionCount * 2).clamp(0, 10);

    // Actions contribute fixed points
    if (hasClickedApply) score += 15;
    if (hasApplied) score += 10;
    if (hasShared) score += 3;
    if (hasCopiedText) score += 1;
    if (hasPrinted) score += 1;

    return score.clamp(0, 100);
  }

  /// Get engagement level label
  String get engagementLevel {
    final score = engagementScore;
    if (score >= 70) return 'High';
    if (score >= 40) return 'Medium';
    if (score >= 20) return 'Low';
    return 'Minimal';
  }

  /// Format total time as human readable
  String get formattedTotalTime {
    final seconds = totalTimeSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  /// Format avg session duration as human readable
  String get formattedAvgSession {
    final seconds = avgSessionDurationSeconds.round();
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
  }

  /// Get location description
  String get locationDescription {
    final parts = <String>[];
    if (lastCity != null) parts.add(lastCity!);
    if (lastRegion != null) parts.add(lastRegion!);
    if (lastCountry != null) parts.add(lastCountry!);
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }

  /// Get device description
  String get deviceDescription {
    final parts = <String>[];
    if (lastBrowser != null) parts.add(lastBrowser!);
    if (lastOs != null) parts.add('on $lastOs');
    return parts.isEmpty ? 'Unknown device' : parts.join(' ');
  }

  /// Get attribution source
  String? get attributionSource {
    if (firstUtmSource != null) return firstUtmSource;
    if (firstReferrerDomain != null) return firstReferrerDomain;
    return null;
  }
}

/// Aggregated analytics summary for a job (calculated from events)
class JobAnalyticsSummary {
  final String jobId;
  final int totalViews;
  final int uniqueViewers;
  final int applyClicks;
  final int applications;
  final int shares;
  final int saves;
  final int totalTimeSeconds;
  final int avgTimeSeconds;
  final int maxScrollDepth;
  final Map<String, int> eventCounts;
  final Map<String, int> browserCounts;
  final Map<String, int> deviceCounts;
  final Map<String, int> locationCounts;
  final Map<String, int> referrerCounts;

  JobAnalyticsSummary({
    required this.jobId,
    this.totalViews = 0,
    this.uniqueViewers = 0,
    this.applyClicks = 0,
    this.applications = 0,
    this.shares = 0,
    this.saves = 0,
    this.totalTimeSeconds = 0,
    this.avgTimeSeconds = 0,
    this.maxScrollDepth = 0,
    this.eventCounts = const {},
    this.browserCounts = const {},
    this.deviceCounts = const {},
    this.locationCounts = const {},
    this.referrerCounts = const {},
  });

  /// Format average time as human readable
  String get formattedAvgTime {
    final seconds = avgTimeSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
  }

  /// Get views to apply click rate
  double get clickThroughRate {
    if (totalViews == 0) return 0;
    return applyClicks / totalViews;
  }

  /// Format click through rate as percentage
  String get formattedClickThroughRate {
    return '${(clickThroughRate * 100).toStringAsFixed(1)}%';
  }

  /// Get conversion rate (views to applications)
  double get conversionRate {
    if (totalViews == 0) return 0;
    return applications / totalViews;
  }

  /// Format conversion rate as percentage
  String get formattedConversionRate {
    return '${(conversionRate * 100).toStringAsFixed(1)}%';
  }

  /// Create summary from member interactions
  factory JobAnalyticsSummary.fromInteractions(
    String jobId,
    List<JobMemberInteraction> interactions,
  ) {
    int totalViews = 0;
    int applyClicks = 0;
    int applications = 0;
    int shares = 0;
    int totalTime = 0;
    int maxScroll = 0;

    final browserCounts = <String, int>{};
    final deviceCounts = <String, int>{};
    final locationCounts = <String, int>{};

    for (final interaction in interactions) {
      totalViews += interaction.viewCount;
      if (interaction.hasClickedApply) applyClicks++;
      if (interaction.hasApplied) applications++;
      if (interaction.hasShared) shares++;
      totalTime += interaction.totalTimeSeconds;
      if (interaction.maxScrollDepthPercent > maxScroll) {
        maxScroll = interaction.maxScrollDepthPercent;
      }

      // Count browsers
      if (interaction.lastBrowser != null) {
        browserCounts[interaction.lastBrowser!] =
            (browserCounts[interaction.lastBrowser!] ?? 0) + 1;
      }

      // Count device types
      if (interaction.lastDeviceType != null) {
        deviceCounts[interaction.lastDeviceType!] =
            (deviceCounts[interaction.lastDeviceType!] ?? 0) + 1;
      }

      // Count locations
      if (interaction.lastCountry != null) {
        locationCounts[interaction.lastCountry!] =
            (locationCounts[interaction.lastCountry!] ?? 0) + 1;
      }
    }

    return JobAnalyticsSummary(
      jobId: jobId,
      totalViews: totalViews,
      uniqueViewers: interactions.length,
      applyClicks: applyClicks,
      applications: applications,
      shares: shares,
      saves: 0, // Not tracked in current schema
      totalTimeSeconds: totalTime,
      avgTimeSeconds: interactions.isEmpty ? 0 : totalTime ~/ interactions.length,
      maxScrollDepth: maxScroll,
      browserCounts: browserCounts,
      deviceCounts: deviceCounts,
      locationCounts: locationCounts,
    );
  }
}
