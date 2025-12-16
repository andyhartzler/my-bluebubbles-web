import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_analytics.freezed.dart';
part 'job_analytics.g.dart';

/// Individual analytics event for a job (page view, apply click, etc.)
@freezed
class JobAnalyticsEvent with _$JobAnalyticsEvent {
  const factory JobAnalyticsEvent({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'event_type') required String eventType,
    @JsonKey(name: 'member_id') String? memberId,
    @JsonKey(name: 'member_name') String? memberName,
    @JsonKey(name: 'member_email') String? memberEmail,
    @JsonKey(name: 'occurred_at') required DateTime occurredAt,
    @JsonKey(name: 'page_url') String? pageUrl,
    String? referrer,
    @JsonKey(name: 'device_type') String? deviceType,
    String? browser,
    @JsonKey(name: 'time_on_page') int? timeOnPage,
    @JsonKey(name: 'scroll_depth') int? scrollDepth,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _JobAnalyticsEvent;

  const JobAnalyticsEvent._();

  factory JobAnalyticsEvent.fromJson(Map<String, dynamic> json) =>
      _$JobAnalyticsEventFromJson(json);

  /// Get a display label for event type
  String get eventTypeLabel {
    switch (eventType) {
      case 'page_view':
        return 'Page View';
      case 'apply_click':
        return 'Apply Click';
      case 'share':
        return 'Share';
      case 'save':
        return 'Saved';
      case 'external_apply':
        return 'External Apply';
      default:
        return eventType;
    }
  }

  /// Get icon for event type
  static String eventTypeIcon(String type) {
    switch (type) {
      case 'page_view':
        return 'visibility';
      case 'apply_click':
        return 'touch_app';
      case 'share':
        return 'share';
      case 'save':
        return 'bookmark';
      case 'external_apply':
        return 'open_in_new';
      default:
        return 'event';
    }
  }
}

/// Summarized member interaction with a job
@freezed
class JobMemberInteraction with _$JobMemberInteraction {
  const factory JobMemberInteraction({
    required String id,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'member_id') required String memberId,
    @JsonKey(name: 'member_name') String? memberName,
    @JsonKey(name: 'member_email') String? memberEmail,
    @JsonKey(name: 'first_view_at') DateTime? firstViewAt,
    @JsonKey(name: 'last_view_at') DateTime? lastViewAt,
    @JsonKey(name: 'view_count') @Default(0) int viewCount,
    @JsonKey(name: 'total_time_on_page') @Default(0) int totalTimeOnPage,
    @JsonKey(name: 'max_scroll_depth') @Default(0) int maxScrollDepth,
    @JsonKey(name: 'clicked_apply') @Default(false) bool clickedApply,
    @JsonKey(name: 'applied_at') DateTime? appliedAt,
    @JsonKey(name: 'saved_job') @Default(false) bool savedJob,
    @JsonKey(name: 'shared_job') @Default(false) bool sharedJob,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _JobMemberInteraction;

  const JobMemberInteraction._();

  factory JobMemberInteraction.fromJson(Map<String, dynamic> json) =>
      _$JobMemberInteractionFromJson(json);

  /// Get engagement score (0-100)
  int get engagementScore {
    int score = 0;

    // View count contributes up to 30 points
    score += (viewCount * 5).clamp(0, 30);

    // Time on page contributes up to 20 points (1 point per 10 seconds)
    score += (totalTimeOnPage ~/ 10).clamp(0, 20);

    // Scroll depth contributes up to 20 points
    score += (maxScrollDepth * 0.2).round().clamp(0, 20);

    // Actions contribute fixed points
    if (clickedApply) score += 15;
    if (appliedAt != null) score += 10;
    if (savedJob) score += 3;
    if (sharedJob) score += 2;

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

  /// Format time on page as human readable
  String get formattedTimeOnPage {
    final seconds = totalTimeOnPage;
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
}

/// Aggregated analytics summary for a job
@freezed
class JobAnalyticsSummary with _$JobAnalyticsSummary {
  const factory JobAnalyticsSummary({
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'total_views') @Default(0) int totalViews,
    @JsonKey(name: 'unique_viewers') @Default(0) int uniqueViewers,
    @JsonKey(name: 'apply_clicks') @Default(0) int applyClicks,
    @JsonKey(name: 'applications') @Default(0) int applications,
    @JsonKey(name: 'shares') @Default(0) int shares,
    @JsonKey(name: 'saves') @Default(0) int saves,
    @JsonKey(name: 'avg_time_on_page') @Default(0) int avgTimeOnPage,
    @JsonKey(name: 'avg_scroll_depth') @Default(0) int avgScrollDepth,
    @JsonKey(name: 'conversion_rate') @Default(0.0) double conversionRate,
  }) = _JobAnalyticsSummary;

  const JobAnalyticsSummary._();

  factory JobAnalyticsSummary.fromJson(Map<String, dynamic> json) =>
      _$JobAnalyticsSummaryFromJson(json);

  /// Format average time on page as human readable
  String get formattedAvgTime {
    final seconds = avgTimeOnPage;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
  }

  /// Format conversion rate as percentage
  String get formattedConversionRate {
    return '${(conversionRate * 100).toStringAsFixed(1)}%';
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
}

/// Per-member activity summary for analytics dashboard
@freezed
class MemberJobActivity with _$MemberJobActivity {
  const factory MemberJobActivity({
    @JsonKey(name: 'member_id') required String memberId,
    @JsonKey(name: 'member_name') String? memberName,
    @JsonKey(name: 'member_email') String? memberEmail,
    @JsonKey(name: 'job_id') required String jobId,
    @JsonKey(name: 'job_title') String? jobTitle,
    @JsonKey(name: 'job_organization') String? jobOrganization,
    @JsonKey(name: 'first_view_at') DateTime? firstViewAt,
    @JsonKey(name: 'last_view_at') DateTime? lastViewAt,
    @JsonKey(name: 'view_count') @Default(0) int viewCount,
    @JsonKey(name: 'total_time_on_page') @Default(0) int totalTimeOnPage,
    @JsonKey(name: 'max_scroll_depth') @Default(0) int maxScrollDepth,
    @JsonKey(name: 'clicked_apply') @Default(false) bool clickedApply,
    @JsonKey(name: 'applied_at') DateTime? appliedAt,
    @JsonKey(name: 'saved_job') @Default(false) bool savedJob,
    @JsonKey(name: 'shared_job') @Default(false) bool sharedJob,
    @JsonKey(name: 'engagement_score') @Default(0) int engagementScore,
  }) = _MemberJobActivity;

  const MemberJobActivity._();

  factory MemberJobActivity.fromJson(Map<String, dynamic> json) =>
      _$MemberJobActivityFromJson(json);

  /// Get engagement level label
  String get engagementLevel {
    if (engagementScore >= 70) return 'High';
    if (engagementScore >= 40) return 'Medium';
    if (engagementScore >= 20) return 'Low';
    return 'Minimal';
  }

  /// Format time on page as human readable
  String get formattedTimeOnPage {
    final seconds = totalTimeOnPage;
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
}
