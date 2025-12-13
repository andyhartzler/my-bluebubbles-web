/// Represents social media statistics for a given account and date
class SocialMediaStats {
  final String id;
  final String accountId;
  final String platform;
  final String metricDate;
  final int? metricHour;
  final int? followersCount;
  final int? followingCount;
  final int? subscriberCount;
  final int? likesCount;
  final int? commentsCount;
  final int? sharesCount;
  final int? savesCount;
  final int? impressions;
  final int? reach;
  final int? profileViews;
  final int? postsCount;
  final int? storiesCount;
  final int? reelsCount;
  final int? videosCount;
  final Map<String, dynamic> platformMetrics;

  const SocialMediaStats({
    required this.id,
    required this.accountId,
    required this.platform,
    required this.metricDate,
    this.metricHour,
    this.followersCount,
    this.followingCount,
    this.subscriberCount,
    this.likesCount,
    this.commentsCount,
    this.sharesCount,
    this.savesCount,
    this.impressions,
    this.reach,
    this.profileViews,
    this.postsCount,
    this.storiesCount,
    this.reelsCount,
    this.videosCount,
    this.platformMetrics = const {},
  });

  /// Safely parse a value that should be a Map
  static Map<String, dynamic> _safeParseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  /// Safely parse an int value
  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory SocialMediaStats.fromJson(Map<String, dynamic> json) {
    // Handle nested platform info if present
    String platform = json['platform'] as String? ?? '';
    if (platform.isEmpty && json['social_media_accounts'] != null) {
      final accountData = _safeParseMap(json['social_media_accounts']);
      platform = accountData['platform'] as String? ?? '';
    }

    return SocialMediaStats(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      platform: platform,
      metricDate: json['metric_date'] as String,
      metricHour: _safeParseInt(json['metric_hour']),
      followersCount: _safeParseInt(json['followers_count']),
      followingCount: _safeParseInt(json['following_count']),
      subscriberCount: _safeParseInt(json['subscriber_count']),
      likesCount: _safeParseInt(json['likes_count']),
      commentsCount: _safeParseInt(json['comments_count']),
      sharesCount: _safeParseInt(json['shares_count']),
      savesCount: _safeParseInt(json['saves_count']),
      impressions: _safeParseInt(json['impressions']),
      reach: _safeParseInt(json['reach']),
      profileViews: _safeParseInt(json['profile_views']),
      postsCount: _safeParseInt(json['posts_count']),
      storiesCount: _safeParseInt(json['stories_count']),
      reelsCount: _safeParseInt(json['reels_count']),
      videosCount: _safeParseInt(json['videos_count']),
      platformMetrics: _safeParseMap(json['platform_metrics']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'platform': platform,
      'metric_date': metricDate,
      'metric_hour': metricHour,
      'followers_count': followersCount,
      'following_count': followingCount,
      'subscriber_count': subscriberCount,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'saves_count': savesCount,
      'impressions': impressions,
      'reach': reach,
      'profile_views': profileViews,
      'posts_count': postsCount,
      'stories_count': storiesCount,
      'reels_count': reelsCount,
      'videos_count': videosCount,
      'platform_metrics': platformMetrics,
    };
  }

  /// Calculate total engagement (likes + comments + shares)
  int get totalEngagement => (likesCount ?? 0) + (commentsCount ?? 0) + (sharesCount ?? 0);

  /// Get engagement rate from platform metrics if available
  double get engagementRate {
    final last30Days = _safeParseMap(platformMetrics['last_30_days']);
    if (last30Days.isNotEmpty) {
      final rates = _safeParseMap(last30Days['rates']);
      if (rates.isNotEmpty) {
        final rate = rates['engagement_rate'];
        if (rate is num) return rate.toDouble();
        if (rate is String) return double.tryParse(rate) ?? 0.0;
      }
    }
    return 0.0;
  }

  /// Get 30-day totals from platform metrics
  Map<String, dynamic> get last30DaysTotals {
    final last30Days = _safeParseMap(platformMetrics['last_30_days']);
    return _safeParseMap(last30Days['totals']);
  }

  /// Get 30-day averages from platform metrics
  Map<String, dynamic> get last30DaysAverages {
    final last30Days = _safeParseMap(platformMetrics['last_30_days']);
    return _safeParseMap(last30Days['averages']);
  }

  /// Get content breakdown from platform metrics
  Map<String, dynamic> get contentBreakdown {
    final last30Days = _safeParseMap(platformMetrics['last_30_days']);
    return _safeParseMap(last30Days['content_breakdown']);
  }
}
