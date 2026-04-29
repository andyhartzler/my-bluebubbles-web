// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_JobAnalyticsEvent _$JobAnalyticsEventFromJson(Map<String, dynamic> json) =>
    _JobAnalyticsEvent(
      id: (json['id'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      jobId: json['job_id'] as String,
      memberId: json['member_id'] as String,
      eventType: json['event_type'] as String,
      eventData: json['event_data'] as Map<String, dynamic>?,
      sessionId: json['session_id'] as String?,
      deviceType: json['device_type'] as String?,
      userAgent: json['user_agent'] as String?,
      browser: json['browser'] as String?,
      browserVersion: json['browser_version'] as String?,
      os: json['os'] as String?,
      osVersion: json['os_version'] as String?,
      isMobile: json['is_mobile'] as bool? ?? false,
      isTablet: json['is_tablet'] as bool? ?? false,
      screenWidth: (json['screen_width'] as num?)?.toInt(),
      screenHeight: (json['screen_height'] as num?)?.toInt(),
      viewportWidth: (json['viewport_width'] as num?)?.toInt(),
      viewportHeight: (json['viewport_height'] as num?)?.toInt(),
      devicePixelRatio: (json['device_pixel_ratio'] as num?)?.toDouble(),
      ipAddress: json['ip_address'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timezone: json['timezone'] as String?,
      referrerUrl: json['referrer_url'] as String?,
      referrerDomain: json['referrer_domain'] as String?,
      utmSource: json['utm_source'] as String?,
      utmMedium: json['utm_medium'] as String?,
      utmCampaign: json['utm_campaign'] as String?,
      utmTerm: json['utm_term'] as String?,
      utmContent: json['utm_content'] as String?,
      pageUrl: json['page_url'] as String?,
      pagePath: json['page_path'] as String?,
      connectionType: json['connection_type'] as String?,
      connectionDownlink: (json['connection_downlink'] as num?)?.toDouble(),
      language: json['language'] as String?,
      languages: (json['languages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$JobAnalyticsEventToJson(_JobAnalyticsEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'job_id': instance.jobId,
      'member_id': instance.memberId,
      'event_type': instance.eventType,
      'event_data': instance.eventData,
      'session_id': instance.sessionId,
      'device_type': instance.deviceType,
      'user_agent': instance.userAgent,
      'browser': instance.browser,
      'browser_version': instance.browserVersion,
      'os': instance.os,
      'os_version': instance.osVersion,
      'is_mobile': instance.isMobile,
      'is_tablet': instance.isTablet,
      'screen_width': instance.screenWidth,
      'screen_height': instance.screenHeight,
      'viewport_width': instance.viewportWidth,
      'viewport_height': instance.viewportHeight,
      'device_pixel_ratio': instance.devicePixelRatio,
      'ip_address': instance.ipAddress,
      'city': instance.city,
      'region': instance.region,
      'country': instance.country,
      'country_code': instance.countryCode,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'timezone': instance.timezone,
      'referrer_url': instance.referrerUrl,
      'referrer_domain': instance.referrerDomain,
      'utm_source': instance.utmSource,
      'utm_medium': instance.utmMedium,
      'utm_campaign': instance.utmCampaign,
      'utm_term': instance.utmTerm,
      'utm_content': instance.utmContent,
      'page_url': instance.pageUrl,
      'page_path': instance.pagePath,
      'connection_type': instance.connectionType,
      'connection_downlink': instance.connectionDownlink,
      'language': instance.language,
      'languages': instance.languages,
    };

_JobMemberInteraction _$JobMemberInteractionFromJson(
        Map<String, dynamic> json) =>
    _JobMemberInteraction(
      id: json['id'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      jobId: json['job_id'] as String,
      memberId: json['member_id'] as String,
      memberName: json['memberName'] as String?,
      memberEmail: json['memberEmail'] as String?,
      memberProfilePhotoUrl: json['memberProfilePhotoUrl'] as String?,
      memberCity: json['memberCity'] as String?,
      memberState: json['memberState'] as String?,
      hasViewed: json['has_viewed'] as bool? ?? false,
      hasClickedApply: json['has_clicked_apply'] as bool? ?? false,
      hasApplied: json['has_applied'] as bool? ?? false,
      hasShared: json['has_shared'] as bool? ?? false,
      hasCopiedText: json['has_copied_text'] as bool? ?? false,
      hasPrinted: json['has_printed'] as bool? ?? false,
      firstViewedAt: json['first_viewed_at'] == null
          ? null
          : DateTime.parse(json['first_viewed_at'] as String),
      lastViewedAt: json['last_viewed_at'] == null
          ? null
          : DateTime.parse(json['last_viewed_at'] as String),
      applyClickedAt: json['apply_clicked_at'] == null
          ? null
          : DateTime.parse(json['apply_clicked_at'] as String),
      appliedAt: json['applied_at'] == null
          ? null
          : DateTime.parse(json['applied_at'] as String),
      sharedAt: json['shared_at'] == null
          ? null
          : DateTime.parse(json['shared_at'] as String),
      copiedTextAt: json['copied_text_at'] == null
          ? null
          : DateTime.parse(json['copied_text_at'] as String),
      printedAt: json['printed_at'] == null
          ? null
          : DateTime.parse(json['printed_at'] as String),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      totalTimeSeconds: (json['total_time_seconds'] as num?)?.toInt() ?? 0,
      maxScrollDepthPercent:
          (json['max_scroll_depth_percent'] as num?)?.toInt() ?? 0,
      sessionCount: (json['session_count'] as num?)?.toInt() ?? 0,
      avgSessionDurationSeconds:
          (json['avg_session_duration_seconds'] as num?)?.toDouble() ?? 0.0,
      totalIdleTimeSeconds:
          (json['total_idle_time_seconds'] as num?)?.toInt() ?? 0,
      totalActiveTimeSeconds:
          (json['total_active_time_seconds'] as num?)?.toInt() ?? 0,
      externalApplyClicks:
          (json['external_apply_clicks'] as num?)?.toInt() ?? 0,
      applicationId: json['application_id'] as String?,
      lastDeviceType: json['last_device_type'] as String?,
      lastBrowser: json['last_browser'] as String?,
      lastOs: json['last_os'] as String?,
      devicesUsed: (json['devices_used'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      browsersUsed: (json['browsers_used'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      lastCity: json['last_city'] as String?,
      lastRegion: json['last_region'] as String?,
      lastCountry: json['last_country'] as String?,
      lastIpAddress: json['last_ip_address'] as String?,
      lastSessionId: json['last_session_id'] as String?,
      firstReferrerUrl: json['first_referrer_url'] as String?,
      firstReferrerDomain: json['first_referrer_domain'] as String?,
      firstUtmSource: json['first_utm_source'] as String?,
      firstUtmMedium: json['first_utm_medium'] as String?,
      firstUtmCampaign: json['first_utm_campaign'] as String?,
      lastExternalApplyUrl: json['last_external_apply_url'] as String?,
    );

Map<String, dynamic> _$JobMemberInteractionToJson(
        _JobMemberInteraction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'job_id': instance.jobId,
      'member_id': instance.memberId,
      'memberName': instance.memberName,
      'memberEmail': instance.memberEmail,
      'memberProfilePhotoUrl': instance.memberProfilePhotoUrl,
      'memberCity': instance.memberCity,
      'memberState': instance.memberState,
      'has_viewed': instance.hasViewed,
      'has_clicked_apply': instance.hasClickedApply,
      'has_applied': instance.hasApplied,
      'has_shared': instance.hasShared,
      'has_copied_text': instance.hasCopiedText,
      'has_printed': instance.hasPrinted,
      'first_viewed_at': instance.firstViewedAt?.toIso8601String(),
      'last_viewed_at': instance.lastViewedAt?.toIso8601String(),
      'apply_clicked_at': instance.applyClickedAt?.toIso8601String(),
      'applied_at': instance.appliedAt?.toIso8601String(),
      'shared_at': instance.sharedAt?.toIso8601String(),
      'copied_text_at': instance.copiedTextAt?.toIso8601String(),
      'printed_at': instance.printedAt?.toIso8601String(),
      'view_count': instance.viewCount,
      'total_time_seconds': instance.totalTimeSeconds,
      'max_scroll_depth_percent': instance.maxScrollDepthPercent,
      'session_count': instance.sessionCount,
      'avg_session_duration_seconds': instance.avgSessionDurationSeconds,
      'total_idle_time_seconds': instance.totalIdleTimeSeconds,
      'total_active_time_seconds': instance.totalActiveTimeSeconds,
      'external_apply_clicks': instance.externalApplyClicks,
      'application_id': instance.applicationId,
      'last_device_type': instance.lastDeviceType,
      'last_browser': instance.lastBrowser,
      'last_os': instance.lastOs,
      'devices_used': instance.devicesUsed,
      'browsers_used': instance.browsersUsed,
      'last_city': instance.lastCity,
      'last_region': instance.lastRegion,
      'last_country': instance.lastCountry,
      'last_ip_address': instance.lastIpAddress,
      'last_session_id': instance.lastSessionId,
      'first_referrer_url': instance.firstReferrerUrl,
      'first_referrer_domain': instance.firstReferrerDomain,
      'first_utm_source': instance.firstUtmSource,
      'first_utm_medium': instance.firstUtmMedium,
      'first_utm_campaign': instance.firstUtmCampaign,
      'last_external_apply_url': instance.lastExternalApplyUrl,
    };
