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

  factory SocialMediaStats.fromJson(Map<String, dynamic> json) {
    // Handle nested platform info if present
    String platform = json['platform'] as String? ?? '';
    if (platform.isEmpty && json['social_media_accounts'] != null) {
      final accountData = json['social_media_accounts'] as Map<String, dynamic>;
      platform = accountData['platform'] as String? ?? '';
    }

    return SocialMediaStats(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      platform: platform,
      metricDate: json['metric_date'] as String,
      metricHour: json['metric_hour'] as int?,
      followersCount: json['followers_count'] as int?,
      followingCount: json['following_count'] as int?,
      subscriberCount: json['subscriber_count'] as int?,
      likesCount: json['likes_count'] as int?,
      commentsCount: json['comments_count'] as int?,
      sharesCount: json['shares_count'] as int?,
      savesCount: json['saves_count'] as int?,
      impressions: json['impressions'] as int?,
      reach: json['reach'] as int?,
      profileViews: json['profile_views'] as int?,
      postsCount: json['posts_count'] as int?,
      storiesCount: json['stories_count'] as int?,
      reelsCount: json['reels_count'] as int?,
      videosCount: json['videos_count'] as int?,
      platformMetrics: json['platform_metrics'] as Map<String, dynamic>? ?? {},
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
    final last30Days = platformMetrics['last_30_days'] as Map<String, dynamic>?;
    if (last30Days != null) {
      final rates = last30Days['rates'] as Map<String, dynamic>?;
      if (rates != null) {
        return (rates['engagement_rate'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }
}
