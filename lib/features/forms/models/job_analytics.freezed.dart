// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

JobAnalyticsEvent _$JobAnalyticsEventFromJson(Map<String, dynamic> json) {
  return _JobAnalyticsEvent.fromJson(json);
}

/// @nodoc
mixin _$JobAnalyticsEvent {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'job_id')
  String get jobId => throw _privateConstructorUsedError;
  @JsonKey(name: 'member_id')
  String get memberId => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_type')
  String get eventType => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_data')
  Map<String, dynamic>? get eventData => throw _privateConstructorUsedError;
  @JsonKey(name: 'session_id')
  String? get sessionId => throw _privateConstructorUsedError; // Device info
  @JsonKey(name: 'device_type')
  String? get deviceType => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_agent')
  String? get userAgent => throw _privateConstructorUsedError;
  String? get browser => throw _privateConstructorUsedError;
  @JsonKey(name: 'browser_version')
  String? get browserVersion => throw _privateConstructorUsedError;
  String? get os => throw _privateConstructorUsedError;
  @JsonKey(name: 'os_version')
  String? get osVersion => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_mobile')
  bool get isMobile => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_tablet')
  bool get isTablet => throw _privateConstructorUsedError; // Screen info
  @JsonKey(name: 'screen_width')
  int? get screenWidth => throw _privateConstructorUsedError;
  @JsonKey(name: 'screen_height')
  int? get screenHeight => throw _privateConstructorUsedError;
  @JsonKey(name: 'viewport_width')
  int? get viewportWidth => throw _privateConstructorUsedError;
  @JsonKey(name: 'viewport_height')
  int? get viewportHeight => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_pixel_ratio')
  double? get devicePixelRatio =>
      throw _privateConstructorUsedError; // Location info
  @JsonKey(name: 'ip_address')
  String? get ipAddress => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get region => throw _privateConstructorUsedError;
  String? get country => throw _privateConstructorUsedError;
  @JsonKey(name: 'country_code')
  String? get countryCode => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;
  String? get timezone => throw _privateConstructorUsedError; // Referrer info
  @JsonKey(name: 'referrer_url')
  String? get referrerUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'referrer_domain')
  String? get referrerDomain =>
      throw _privateConstructorUsedError; // UTM tracking
  @JsonKey(name: 'utm_source')
  String? get utmSource => throw _privateConstructorUsedError;
  @JsonKey(name: 'utm_medium')
  String? get utmMedium => throw _privateConstructorUsedError;
  @JsonKey(name: 'utm_campaign')
  String? get utmCampaign => throw _privateConstructorUsedError;
  @JsonKey(name: 'utm_term')
  String? get utmTerm => throw _privateConstructorUsedError;
  @JsonKey(name: 'utm_content')
  String? get utmContent => throw _privateConstructorUsedError; // Page info
  @JsonKey(name: 'page_url')
  String? get pageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'page_path')
  String? get pagePath => throw _privateConstructorUsedError; // Connection info
  @JsonKey(name: 'connection_type')
  String? get connectionType => throw _privateConstructorUsedError;
  @JsonKey(name: 'connection_downlink')
  double? get connectionDownlink =>
      throw _privateConstructorUsedError; // Language
  String? get language => throw _privateConstructorUsedError;
  List<String>? get languages => throw _privateConstructorUsedError;

  /// Serializes this JobAnalyticsEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobAnalyticsEventCopyWith<JobAnalyticsEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobAnalyticsEventCopyWith<$Res> {
  factory $JobAnalyticsEventCopyWith(
          JobAnalyticsEvent value, $Res Function(JobAnalyticsEvent) then) =
      _$JobAnalyticsEventCopyWithImpl<$Res, JobAnalyticsEvent>;
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'job_id') String jobId,
      @JsonKey(name: 'member_id') String memberId,
      @JsonKey(name: 'event_type') String eventType,
      @JsonKey(name: 'event_data') Map<String, dynamic>? eventData,
      @JsonKey(name: 'session_id') String? sessionId,
      @JsonKey(name: 'device_type') String? deviceType,
      @JsonKey(name: 'user_agent') String? userAgent,
      String? browser,
      @JsonKey(name: 'browser_version') String? browserVersion,
      String? os,
      @JsonKey(name: 'os_version') String? osVersion,
      @JsonKey(name: 'is_mobile') bool isMobile,
      @JsonKey(name: 'is_tablet') bool isTablet,
      @JsonKey(name: 'screen_width') int? screenWidth,
      @JsonKey(name: 'screen_height') int? screenHeight,
      @JsonKey(name: 'viewport_width') int? viewportWidth,
      @JsonKey(name: 'viewport_height') int? viewportHeight,
      @JsonKey(name: 'device_pixel_ratio') double? devicePixelRatio,
      @JsonKey(name: 'ip_address') String? ipAddress,
      String? city,
      String? region,
      String? country,
      @JsonKey(name: 'country_code') String? countryCode,
      double? latitude,
      double? longitude,
      String? timezone,
      @JsonKey(name: 'referrer_url') String? referrerUrl,
      @JsonKey(name: 'referrer_domain') String? referrerDomain,
      @JsonKey(name: 'utm_source') String? utmSource,
      @JsonKey(name: 'utm_medium') String? utmMedium,
      @JsonKey(name: 'utm_campaign') String? utmCampaign,
      @JsonKey(name: 'utm_term') String? utmTerm,
      @JsonKey(name: 'utm_content') String? utmContent,
      @JsonKey(name: 'page_url') String? pageUrl,
      @JsonKey(name: 'page_path') String? pagePath,
      @JsonKey(name: 'connection_type') String? connectionType,
      @JsonKey(name: 'connection_downlink') double? connectionDownlink,
      String? language,
      List<String>? languages});
}

/// @nodoc
class _$JobAnalyticsEventCopyWithImpl<$Res, $Val extends JobAnalyticsEvent>
    implements $JobAnalyticsEventCopyWith<$Res> {
  _$JobAnalyticsEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? jobId = null,
    Object? memberId = null,
    Object? eventType = null,
    Object? eventData = freezed,
    Object? sessionId = freezed,
    Object? deviceType = freezed,
    Object? userAgent = freezed,
    Object? browser = freezed,
    Object? browserVersion = freezed,
    Object? os = freezed,
    Object? osVersion = freezed,
    Object? isMobile = null,
    Object? isTablet = null,
    Object? screenWidth = freezed,
    Object? screenHeight = freezed,
    Object? viewportWidth = freezed,
    Object? viewportHeight = freezed,
    Object? devicePixelRatio = freezed,
    Object? ipAddress = freezed,
    Object? city = freezed,
    Object? region = freezed,
    Object? country = freezed,
    Object? countryCode = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? timezone = freezed,
    Object? referrerUrl = freezed,
    Object? referrerDomain = freezed,
    Object? utmSource = freezed,
    Object? utmMedium = freezed,
    Object? utmCampaign = freezed,
    Object? utmTerm = freezed,
    Object? utmContent = freezed,
    Object? pageUrl = freezed,
    Object? pagePath = freezed,
    Object? connectionType = freezed,
    Object? connectionDownlink = freezed,
    Object? language = freezed,
    Object? languages = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _value.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      eventData: freezed == eventData
          ? _value.eventData
          : eventData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      sessionId: freezed == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceType: freezed == deviceType
          ? _value.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      userAgent: freezed == userAgent
          ? _value.userAgent
          : userAgent // ignore: cast_nullable_to_non_nullable
              as String?,
      browser: freezed == browser
          ? _value.browser
          : browser // ignore: cast_nullable_to_non_nullable
              as String?,
      browserVersion: freezed == browserVersion
          ? _value.browserVersion
          : browserVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      os: freezed == os
          ? _value.os
          : os // ignore: cast_nullable_to_non_nullable
              as String?,
      osVersion: freezed == osVersion
          ? _value.osVersion
          : osVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      isMobile: null == isMobile
          ? _value.isMobile
          : isMobile // ignore: cast_nullable_to_non_nullable
              as bool,
      isTablet: null == isTablet
          ? _value.isTablet
          : isTablet // ignore: cast_nullable_to_non_nullable
              as bool,
      screenWidth: freezed == screenWidth
          ? _value.screenWidth
          : screenWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      screenHeight: freezed == screenHeight
          ? _value.screenHeight
          : screenHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportWidth: freezed == viewportWidth
          ? _value.viewportWidth
          : viewportWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportHeight: freezed == viewportHeight
          ? _value.viewportHeight
          : viewportHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      devicePixelRatio: freezed == devicePixelRatio
          ? _value.devicePixelRatio
          : devicePixelRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      ipAddress: freezed == ipAddress
          ? _value.ipAddress
          : ipAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      country: freezed == country
          ? _value.country
          : country // ignore: cast_nullable_to_non_nullable
              as String?,
      countryCode: freezed == countryCode
          ? _value.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: freezed == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerUrl: freezed == referrerUrl
          ? _value.referrerUrl
          : referrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerDomain: freezed == referrerDomain
          ? _value.referrerDomain
          : referrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      utmSource: freezed == utmSource
          ? _value.utmSource
          : utmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      utmMedium: freezed == utmMedium
          ? _value.utmMedium
          : utmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      utmCampaign: freezed == utmCampaign
          ? _value.utmCampaign
          : utmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      utmTerm: freezed == utmTerm
          ? _value.utmTerm
          : utmTerm // ignore: cast_nullable_to_non_nullable
              as String?,
      utmContent: freezed == utmContent
          ? _value.utmContent
          : utmContent // ignore: cast_nullable_to_non_nullable
              as String?,
      pageUrl: freezed == pageUrl
          ? _value.pageUrl
          : pageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      pagePath: freezed == pagePath
          ? _value.pagePath
          : pagePath // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionType: freezed == connectionType
          ? _value.connectionType
          : connectionType // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionDownlink: freezed == connectionDownlink
          ? _value.connectionDownlink
          : connectionDownlink // ignore: cast_nullable_to_non_nullable
              as double?,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languages: freezed == languages
          ? _value.languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobAnalyticsEventImplCopyWith<$Res>
    implements $JobAnalyticsEventCopyWith<$Res> {
  factory _$$JobAnalyticsEventImplCopyWith(_$JobAnalyticsEventImpl value,
          $Res Function(_$JobAnalyticsEventImpl) then) =
      __$$JobAnalyticsEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'job_id') String jobId,
      @JsonKey(name: 'member_id') String memberId,
      @JsonKey(name: 'event_type') String eventType,
      @JsonKey(name: 'event_data') Map<String, dynamic>? eventData,
      @JsonKey(name: 'session_id') String? sessionId,
      @JsonKey(name: 'device_type') String? deviceType,
      @JsonKey(name: 'user_agent') String? userAgent,
      String? browser,
      @JsonKey(name: 'browser_version') String? browserVersion,
      String? os,
      @JsonKey(name: 'os_version') String? osVersion,
      @JsonKey(name: 'is_mobile') bool isMobile,
      @JsonKey(name: 'is_tablet') bool isTablet,
      @JsonKey(name: 'screen_width') int? screenWidth,
      @JsonKey(name: 'screen_height') int? screenHeight,
      @JsonKey(name: 'viewport_width') int? viewportWidth,
      @JsonKey(name: 'viewport_height') int? viewportHeight,
      @JsonKey(name: 'device_pixel_ratio') double? devicePixelRatio,
      @JsonKey(name: 'ip_address') String? ipAddress,
      String? city,
      String? region,
      String? country,
      @JsonKey(name: 'country_code') String? countryCode,
      double? latitude,
      double? longitude,
      String? timezone,
      @JsonKey(name: 'referrer_url') String? referrerUrl,
      @JsonKey(name: 'referrer_domain') String? referrerDomain,
      @JsonKey(name: 'utm_source') String? utmSource,
      @JsonKey(name: 'utm_medium') String? utmMedium,
      @JsonKey(name: 'utm_campaign') String? utmCampaign,
      @JsonKey(name: 'utm_term') String? utmTerm,
      @JsonKey(name: 'utm_content') String? utmContent,
      @JsonKey(name: 'page_url') String? pageUrl,
      @JsonKey(name: 'page_path') String? pagePath,
      @JsonKey(name: 'connection_type') String? connectionType,
      @JsonKey(name: 'connection_downlink') double? connectionDownlink,
      String? language,
      List<String>? languages});
}

/// @nodoc
class __$$JobAnalyticsEventImplCopyWithImpl<$Res>
    extends _$JobAnalyticsEventCopyWithImpl<$Res, _$JobAnalyticsEventImpl>
    implements _$$JobAnalyticsEventImplCopyWith<$Res> {
  __$$JobAnalyticsEventImplCopyWithImpl(_$JobAnalyticsEventImpl _value,
      $Res Function(_$JobAnalyticsEventImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? jobId = null,
    Object? memberId = null,
    Object? eventType = null,
    Object? eventData = freezed,
    Object? sessionId = freezed,
    Object? deviceType = freezed,
    Object? userAgent = freezed,
    Object? browser = freezed,
    Object? browserVersion = freezed,
    Object? os = freezed,
    Object? osVersion = freezed,
    Object? isMobile = null,
    Object? isTablet = null,
    Object? screenWidth = freezed,
    Object? screenHeight = freezed,
    Object? viewportWidth = freezed,
    Object? viewportHeight = freezed,
    Object? devicePixelRatio = freezed,
    Object? ipAddress = freezed,
    Object? city = freezed,
    Object? region = freezed,
    Object? country = freezed,
    Object? countryCode = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
    Object? timezone = freezed,
    Object? referrerUrl = freezed,
    Object? referrerDomain = freezed,
    Object? utmSource = freezed,
    Object? utmMedium = freezed,
    Object? utmCampaign = freezed,
    Object? utmTerm = freezed,
    Object? utmContent = freezed,
    Object? pageUrl = freezed,
    Object? pagePath = freezed,
    Object? connectionType = freezed,
    Object? connectionDownlink = freezed,
    Object? language = freezed,
    Object? languages = freezed,
  }) {
    return _then(_$JobAnalyticsEventImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _value.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      eventData: freezed == eventData
          ? _value._eventData
          : eventData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      sessionId: freezed == sessionId
          ? _value.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceType: freezed == deviceType
          ? _value.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      userAgent: freezed == userAgent
          ? _value.userAgent
          : userAgent // ignore: cast_nullable_to_non_nullable
              as String?,
      browser: freezed == browser
          ? _value.browser
          : browser // ignore: cast_nullable_to_non_nullable
              as String?,
      browserVersion: freezed == browserVersion
          ? _value.browserVersion
          : browserVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      os: freezed == os
          ? _value.os
          : os // ignore: cast_nullable_to_non_nullable
              as String?,
      osVersion: freezed == osVersion
          ? _value.osVersion
          : osVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      isMobile: null == isMobile
          ? _value.isMobile
          : isMobile // ignore: cast_nullable_to_non_nullable
              as bool,
      isTablet: null == isTablet
          ? _value.isTablet
          : isTablet // ignore: cast_nullable_to_non_nullable
              as bool,
      screenWidth: freezed == screenWidth
          ? _value.screenWidth
          : screenWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      screenHeight: freezed == screenHeight
          ? _value.screenHeight
          : screenHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportWidth: freezed == viewportWidth
          ? _value.viewportWidth
          : viewportWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportHeight: freezed == viewportHeight
          ? _value.viewportHeight
          : viewportHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      devicePixelRatio: freezed == devicePixelRatio
          ? _value.devicePixelRatio
          : devicePixelRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      ipAddress: freezed == ipAddress
          ? _value.ipAddress
          : ipAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _value.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _value.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      country: freezed == country
          ? _value.country
          : country // ignore: cast_nullable_to_non_nullable
              as String?,
      countryCode: freezed == countryCode
          ? _value.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: freezed == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      timezone: freezed == timezone
          ? _value.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerUrl: freezed == referrerUrl
          ? _value.referrerUrl
          : referrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerDomain: freezed == referrerDomain
          ? _value.referrerDomain
          : referrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      utmSource: freezed == utmSource
          ? _value.utmSource
          : utmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      utmMedium: freezed == utmMedium
          ? _value.utmMedium
          : utmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      utmCampaign: freezed == utmCampaign
          ? _value.utmCampaign
          : utmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      utmTerm: freezed == utmTerm
          ? _value.utmTerm
          : utmTerm // ignore: cast_nullable_to_non_nullable
              as String?,
      utmContent: freezed == utmContent
          ? _value.utmContent
          : utmContent // ignore: cast_nullable_to_non_nullable
              as String?,
      pageUrl: freezed == pageUrl
          ? _value.pageUrl
          : pageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      pagePath: freezed == pagePath
          ? _value.pagePath
          : pagePath // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionType: freezed == connectionType
          ? _value.connectionType
          : connectionType // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionDownlink: freezed == connectionDownlink
          ? _value.connectionDownlink
          : connectionDownlink // ignore: cast_nullable_to_non_nullable
              as double?,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languages: freezed == languages
          ? _value._languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobAnalyticsEventImpl extends _JobAnalyticsEvent {
  const _$JobAnalyticsEventImpl(
      {required this.id,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'job_id') required this.jobId,
      @JsonKey(name: 'member_id') required this.memberId,
      @JsonKey(name: 'event_type') required this.eventType,
      @JsonKey(name: 'event_data') final Map<String, dynamic>? eventData,
      @JsonKey(name: 'session_id') this.sessionId,
      @JsonKey(name: 'device_type') this.deviceType,
      @JsonKey(name: 'user_agent') this.userAgent,
      this.browser,
      @JsonKey(name: 'browser_version') this.browserVersion,
      this.os,
      @JsonKey(name: 'os_version') this.osVersion,
      @JsonKey(name: 'is_mobile') this.isMobile = false,
      @JsonKey(name: 'is_tablet') this.isTablet = false,
      @JsonKey(name: 'screen_width') this.screenWidth,
      @JsonKey(name: 'screen_height') this.screenHeight,
      @JsonKey(name: 'viewport_width') this.viewportWidth,
      @JsonKey(name: 'viewport_height') this.viewportHeight,
      @JsonKey(name: 'device_pixel_ratio') this.devicePixelRatio,
      @JsonKey(name: 'ip_address') this.ipAddress,
      this.city,
      this.region,
      this.country,
      @JsonKey(name: 'country_code') this.countryCode,
      this.latitude,
      this.longitude,
      this.timezone,
      @JsonKey(name: 'referrer_url') this.referrerUrl,
      @JsonKey(name: 'referrer_domain') this.referrerDomain,
      @JsonKey(name: 'utm_source') this.utmSource,
      @JsonKey(name: 'utm_medium') this.utmMedium,
      @JsonKey(name: 'utm_campaign') this.utmCampaign,
      @JsonKey(name: 'utm_term') this.utmTerm,
      @JsonKey(name: 'utm_content') this.utmContent,
      @JsonKey(name: 'page_url') this.pageUrl,
      @JsonKey(name: 'page_path') this.pagePath,
      @JsonKey(name: 'connection_type') this.connectionType,
      @JsonKey(name: 'connection_downlink') this.connectionDownlink,
      this.language,
      final List<String>? languages})
      : _eventData = eventData,
        _languages = languages,
        super._();

  factory _$JobAnalyticsEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobAnalyticsEventImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'job_id')
  final String jobId;
  @override
  @JsonKey(name: 'member_id')
  final String memberId;
  @override
  @JsonKey(name: 'event_type')
  final String eventType;
  final Map<String, dynamic>? _eventData;
  @override
  @JsonKey(name: 'event_data')
  Map<String, dynamic>? get eventData {
    final value = _eventData;
    if (value == null) return null;
    if (_eventData is EqualUnmodifiableMapView) return _eventData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'session_id')
  final String? sessionId;
// Device info
  @override
  @JsonKey(name: 'device_type')
  final String? deviceType;
  @override
  @JsonKey(name: 'user_agent')
  final String? userAgent;
  @override
  final String? browser;
  @override
  @JsonKey(name: 'browser_version')
  final String? browserVersion;
  @override
  final String? os;
  @override
  @JsonKey(name: 'os_version')
  final String? osVersion;
  @override
  @JsonKey(name: 'is_mobile')
  final bool isMobile;
  @override
  @JsonKey(name: 'is_tablet')
  final bool isTablet;
// Screen info
  @override
  @JsonKey(name: 'screen_width')
  final int? screenWidth;
  @override
  @JsonKey(name: 'screen_height')
  final int? screenHeight;
  @override
  @JsonKey(name: 'viewport_width')
  final int? viewportWidth;
  @override
  @JsonKey(name: 'viewport_height')
  final int? viewportHeight;
  @override
  @JsonKey(name: 'device_pixel_ratio')
  final double? devicePixelRatio;
// Location info
  @override
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  @override
  final String? city;
  @override
  final String? region;
  @override
  final String? country;
  @override
  @JsonKey(name: 'country_code')
  final String? countryCode;
  @override
  final double? latitude;
  @override
  final double? longitude;
  @override
  final String? timezone;
// Referrer info
  @override
  @JsonKey(name: 'referrer_url')
  final String? referrerUrl;
  @override
  @JsonKey(name: 'referrer_domain')
  final String? referrerDomain;
// UTM tracking
  @override
  @JsonKey(name: 'utm_source')
  final String? utmSource;
  @override
  @JsonKey(name: 'utm_medium')
  final String? utmMedium;
  @override
  @JsonKey(name: 'utm_campaign')
  final String? utmCampaign;
  @override
  @JsonKey(name: 'utm_term')
  final String? utmTerm;
  @override
  @JsonKey(name: 'utm_content')
  final String? utmContent;
// Page info
  @override
  @JsonKey(name: 'page_url')
  final String? pageUrl;
  @override
  @JsonKey(name: 'page_path')
  final String? pagePath;
// Connection info
  @override
  @JsonKey(name: 'connection_type')
  final String? connectionType;
  @override
  @JsonKey(name: 'connection_downlink')
  final double? connectionDownlink;
// Language
  @override
  final String? language;
  final List<String>? _languages;
  @override
  List<String>? get languages {
    final value = _languages;
    if (value == null) return null;
    if (_languages is EqualUnmodifiableListView) return _languages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'JobAnalyticsEvent(id: $id, createdAt: $createdAt, jobId: $jobId, memberId: $memberId, eventType: $eventType, eventData: $eventData, sessionId: $sessionId, deviceType: $deviceType, userAgent: $userAgent, browser: $browser, browserVersion: $browserVersion, os: $os, osVersion: $osVersion, isMobile: $isMobile, isTablet: $isTablet, screenWidth: $screenWidth, screenHeight: $screenHeight, viewportWidth: $viewportWidth, viewportHeight: $viewportHeight, devicePixelRatio: $devicePixelRatio, ipAddress: $ipAddress, city: $city, region: $region, country: $country, countryCode: $countryCode, latitude: $latitude, longitude: $longitude, timezone: $timezone, referrerUrl: $referrerUrl, referrerDomain: $referrerDomain, utmSource: $utmSource, utmMedium: $utmMedium, utmCampaign: $utmCampaign, utmTerm: $utmTerm, utmContent: $utmContent, pageUrl: $pageUrl, pagePath: $pagePath, connectionType: $connectionType, connectionDownlink: $connectionDownlink, language: $language, languages: $languages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobAnalyticsEventImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId) &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            const DeepCollectionEquality()
                .equals(other._eventData, _eventData) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.deviceType, deviceType) ||
                other.deviceType == deviceType) &&
            (identical(other.userAgent, userAgent) ||
                other.userAgent == userAgent) &&
            (identical(other.browser, browser) || other.browser == browser) &&
            (identical(other.browserVersion, browserVersion) ||
                other.browserVersion == browserVersion) &&
            (identical(other.os, os) || other.os == os) &&
            (identical(other.osVersion, osVersion) ||
                other.osVersion == osVersion) &&
            (identical(other.isMobile, isMobile) ||
                other.isMobile == isMobile) &&
            (identical(other.isTablet, isTablet) ||
                other.isTablet == isTablet) &&
            (identical(other.screenWidth, screenWidth) ||
                other.screenWidth == screenWidth) &&
            (identical(other.screenHeight, screenHeight) ||
                other.screenHeight == screenHeight) &&
            (identical(other.viewportWidth, viewportWidth) ||
                other.viewportWidth == viewportWidth) &&
            (identical(other.viewportHeight, viewportHeight) ||
                other.viewportHeight == viewportHeight) &&
            (identical(other.devicePixelRatio, devicePixelRatio) ||
                other.devicePixelRatio == devicePixelRatio) &&
            (identical(other.ipAddress, ipAddress) ||
                other.ipAddress == ipAddress) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.country, country) || other.country == country) &&
            (identical(other.countryCode, countryCode) ||
                other.countryCode == countryCode) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.timezone, timezone) ||
                other.timezone == timezone) &&
            (identical(other.referrerUrl, referrerUrl) ||
                other.referrerUrl == referrerUrl) &&
            (identical(other.referrerDomain, referrerDomain) ||
                other.referrerDomain == referrerDomain) &&
            (identical(other.utmSource, utmSource) ||
                other.utmSource == utmSource) &&
            (identical(other.utmMedium, utmMedium) ||
                other.utmMedium == utmMedium) &&
            (identical(other.utmCampaign, utmCampaign) ||
                other.utmCampaign == utmCampaign) &&
            (identical(other.utmTerm, utmTerm) || other.utmTerm == utmTerm) &&
            (identical(other.utmContent, utmContent) ||
                other.utmContent == utmContent) &&
            (identical(other.pageUrl, pageUrl) || other.pageUrl == pageUrl) &&
            (identical(other.pagePath, pagePath) ||
                other.pagePath == pagePath) &&
            (identical(other.connectionType, connectionType) ||
                other.connectionType == connectionType) &&
            (identical(other.connectionDownlink, connectionDownlink) ||
                other.connectionDownlink == connectionDownlink) &&
            (identical(other.language, language) ||
                other.language == language) &&
            const DeepCollectionEquality()
                .equals(other._languages, _languages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        createdAt,
        jobId,
        memberId,
        eventType,
        const DeepCollectionEquality().hash(_eventData),
        sessionId,
        deviceType,
        userAgent,
        browser,
        browserVersion,
        os,
        osVersion,
        isMobile,
        isTablet,
        screenWidth,
        screenHeight,
        viewportWidth,
        viewportHeight,
        devicePixelRatio,
        ipAddress,
        city,
        region,
        country,
        countryCode,
        latitude,
        longitude,
        timezone,
        referrerUrl,
        referrerDomain,
        utmSource,
        utmMedium,
        utmCampaign,
        utmTerm,
        utmContent,
        pageUrl,
        pagePath,
        connectionType,
        connectionDownlink,
        language,
        const DeepCollectionEquality().hash(_languages)
      ]);

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobAnalyticsEventImplCopyWith<_$JobAnalyticsEventImpl> get copyWith =>
      __$$JobAnalyticsEventImplCopyWithImpl<_$JobAnalyticsEventImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobAnalyticsEventImplToJson(
      this,
    );
  }
}

abstract class _JobAnalyticsEvent extends JobAnalyticsEvent {
  const factory _JobAnalyticsEvent(
      {required final int id,
      @JsonKey(name: 'created_at') required final DateTime createdAt,
      @JsonKey(name: 'job_id') required final String jobId,
      @JsonKey(name: 'member_id') required final String memberId,
      @JsonKey(name: 'event_type') required final String eventType,
      @JsonKey(name: 'event_data') final Map<String, dynamic>? eventData,
      @JsonKey(name: 'session_id') final String? sessionId,
      @JsonKey(name: 'device_type') final String? deviceType,
      @JsonKey(name: 'user_agent') final String? userAgent,
      final String? browser,
      @JsonKey(name: 'browser_version') final String? browserVersion,
      final String? os,
      @JsonKey(name: 'os_version') final String? osVersion,
      @JsonKey(name: 'is_mobile') final bool isMobile,
      @JsonKey(name: 'is_tablet') final bool isTablet,
      @JsonKey(name: 'screen_width') final int? screenWidth,
      @JsonKey(name: 'screen_height') final int? screenHeight,
      @JsonKey(name: 'viewport_width') final int? viewportWidth,
      @JsonKey(name: 'viewport_height') final int? viewportHeight,
      @JsonKey(name: 'device_pixel_ratio') final double? devicePixelRatio,
      @JsonKey(name: 'ip_address') final String? ipAddress,
      final String? city,
      final String? region,
      final String? country,
      @JsonKey(name: 'country_code') final String? countryCode,
      final double? latitude,
      final double? longitude,
      final String? timezone,
      @JsonKey(name: 'referrer_url') final String? referrerUrl,
      @JsonKey(name: 'referrer_domain') final String? referrerDomain,
      @JsonKey(name: 'utm_source') final String? utmSource,
      @JsonKey(name: 'utm_medium') final String? utmMedium,
      @JsonKey(name: 'utm_campaign') final String? utmCampaign,
      @JsonKey(name: 'utm_term') final String? utmTerm,
      @JsonKey(name: 'utm_content') final String? utmContent,
      @JsonKey(name: 'page_url') final String? pageUrl,
      @JsonKey(name: 'page_path') final String? pagePath,
      @JsonKey(name: 'connection_type') final String? connectionType,
      @JsonKey(name: 'connection_downlink') final double? connectionDownlink,
      final String? language,
      final List<String>? languages}) = _$JobAnalyticsEventImpl;
  const _JobAnalyticsEvent._() : super._();

  factory _JobAnalyticsEvent.fromJson(Map<String, dynamic> json) =
      _$JobAnalyticsEventImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'job_id')
  String get jobId;
  @override
  @JsonKey(name: 'member_id')
  String get memberId;
  @override
  @JsonKey(name: 'event_type')
  String get eventType;
  @override
  @JsonKey(name: 'event_data')
  Map<String, dynamic>? get eventData;
  @override
  @JsonKey(name: 'session_id')
  String? get sessionId; // Device info
  @override
  @JsonKey(name: 'device_type')
  String? get deviceType;
  @override
  @JsonKey(name: 'user_agent')
  String? get userAgent;
  @override
  String? get browser;
  @override
  @JsonKey(name: 'browser_version')
  String? get browserVersion;
  @override
  String? get os;
  @override
  @JsonKey(name: 'os_version')
  String? get osVersion;
  @override
  @JsonKey(name: 'is_mobile')
  bool get isMobile;
  @override
  @JsonKey(name: 'is_tablet')
  bool get isTablet; // Screen info
  @override
  @JsonKey(name: 'screen_width')
  int? get screenWidth;
  @override
  @JsonKey(name: 'screen_height')
  int? get screenHeight;
  @override
  @JsonKey(name: 'viewport_width')
  int? get viewportWidth;
  @override
  @JsonKey(name: 'viewport_height')
  int? get viewportHeight;
  @override
  @JsonKey(name: 'device_pixel_ratio')
  double? get devicePixelRatio; // Location info
  @override
  @JsonKey(name: 'ip_address')
  String? get ipAddress;
  @override
  String? get city;
  @override
  String? get region;
  @override
  String? get country;
  @override
  @JsonKey(name: 'country_code')
  String? get countryCode;
  @override
  double? get latitude;
  @override
  double? get longitude;
  @override
  String? get timezone; // Referrer info
  @override
  @JsonKey(name: 'referrer_url')
  String? get referrerUrl;
  @override
  @JsonKey(name: 'referrer_domain')
  String? get referrerDomain; // UTM tracking
  @override
  @JsonKey(name: 'utm_source')
  String? get utmSource;
  @override
  @JsonKey(name: 'utm_medium')
  String? get utmMedium;
  @override
  @JsonKey(name: 'utm_campaign')
  String? get utmCampaign;
  @override
  @JsonKey(name: 'utm_term')
  String? get utmTerm;
  @override
  @JsonKey(name: 'utm_content')
  String? get utmContent; // Page info
  @override
  @JsonKey(name: 'page_url')
  String? get pageUrl;
  @override
  @JsonKey(name: 'page_path')
  String? get pagePath; // Connection info
  @override
  @JsonKey(name: 'connection_type')
  String? get connectionType;
  @override
  @JsonKey(name: 'connection_downlink')
  double? get connectionDownlink; // Language
  @override
  String? get language;
  @override
  List<String>? get languages;

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobAnalyticsEventImplCopyWith<_$JobAnalyticsEventImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

JobMemberInteraction _$JobMemberInteractionFromJson(Map<String, dynamic> json) {
  return _JobMemberInteraction.fromJson(json);
}

/// @nodoc
mixin _$JobMemberInteraction {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'job_id')
  String get jobId => throw _privateConstructorUsedError;
  @JsonKey(name: 'member_id')
  String get memberId =>
      throw _privateConstructorUsedError; // Member info (populated from join)
  String? get memberName => throw _privateConstructorUsedError;
  String? get memberEmail => throw _privateConstructorUsedError;
  String? get memberProfilePhotoUrl => throw _privateConstructorUsedError;
  String? get memberCity => throw _privateConstructorUsedError;
  String? get memberState => throw _privateConstructorUsedError; // Action flags
  @JsonKey(name: 'has_viewed')
  bool get hasViewed => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_clicked_apply')
  bool get hasClickedApply => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_applied')
  bool get hasApplied => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_shared')
  bool get hasShared => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_copied_text')
  bool get hasCopiedText => throw _privateConstructorUsedError;
  @JsonKey(name: 'has_printed')
  bool get hasPrinted => throw _privateConstructorUsedError; // Timestamps
  @JsonKey(name: 'first_viewed_at')
  DateTime? get firstViewedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_viewed_at')
  DateTime? get lastViewedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'apply_clicked_at')
  DateTime? get applyClickedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'applied_at')
  DateTime? get appliedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'shared_at')
  DateTime? get sharedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'copied_text_at')
  DateTime? get copiedTextAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'printed_at')
  DateTime? get printedAt =>
      throw _privateConstructorUsedError; // Engagement metrics
  @JsonKey(name: 'view_count')
  int get viewCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_time_seconds')
  int get totalTimeSeconds => throw _privateConstructorUsedError;
  @JsonKey(name: 'max_scroll_depth_percent')
  int get maxScrollDepthPercent => throw _privateConstructorUsedError;
  @JsonKey(name: 'session_count')
  int get sessionCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'avg_session_duration_seconds')
  double get avgSessionDurationSeconds => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_idle_time_seconds')
  int get totalIdleTimeSeconds => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_active_time_seconds')
  int get totalActiveTimeSeconds => throw _privateConstructorUsedError;
  @JsonKey(name: 'external_apply_clicks')
  int get externalApplyClicks =>
      throw _privateConstructorUsedError; // Application reference
  @JsonKey(name: 'application_id')
  String? get applicationId =>
      throw _privateConstructorUsedError; // Last device info
  @JsonKey(name: 'last_device_type')
  String? get lastDeviceType => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_browser')
  String? get lastBrowser => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_os')
  String? get lastOs => throw _privateConstructorUsedError;
  @JsonKey(name: 'devices_used')
  List<String> get devicesUsed => throw _privateConstructorUsedError;
  @JsonKey(name: 'browsers_used')
  List<String> get browsersUsed =>
      throw _privateConstructorUsedError; // Last location info
  @JsonKey(name: 'last_city')
  String? get lastCity => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_region')
  String? get lastRegion => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_country')
  String? get lastCountry => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_ip_address')
  String? get lastIpAddress =>
      throw _privateConstructorUsedError; // Session tracking
  @JsonKey(name: 'last_session_id')
  String? get lastSessionId =>
      throw _privateConstructorUsedError; // First touch attribution
  @JsonKey(name: 'first_referrer_url')
  String? get firstReferrerUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_referrer_domain')
  String? get firstReferrerDomain => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_utm_source')
  String? get firstUtmSource => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_utm_medium')
  String? get firstUtmMedium => throw _privateConstructorUsedError;
  @JsonKey(name: 'first_utm_campaign')
  String? get firstUtmCampaign =>
      throw _privateConstructorUsedError; // External apply tracking
  @JsonKey(name: 'last_external_apply_url')
  String? get lastExternalApplyUrl => throw _privateConstructorUsedError;

  /// Serializes this JobMemberInteraction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $JobMemberInteractionCopyWith<JobMemberInteraction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $JobMemberInteractionCopyWith<$Res> {
  factory $JobMemberInteractionCopyWith(JobMemberInteraction value,
          $Res Function(JobMemberInteraction) then) =
      _$JobMemberInteractionCopyWithImpl<$Res, JobMemberInteraction>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      @JsonKey(name: 'job_id') String jobId,
      @JsonKey(name: 'member_id') String memberId,
      String? memberName,
      String? memberEmail,
      String? memberProfilePhotoUrl,
      String? memberCity,
      String? memberState,
      @JsonKey(name: 'has_viewed') bool hasViewed,
      @JsonKey(name: 'has_clicked_apply') bool hasClickedApply,
      @JsonKey(name: 'has_applied') bool hasApplied,
      @JsonKey(name: 'has_shared') bool hasShared,
      @JsonKey(name: 'has_copied_text') bool hasCopiedText,
      @JsonKey(name: 'has_printed') bool hasPrinted,
      @JsonKey(name: 'first_viewed_at') DateTime? firstViewedAt,
      @JsonKey(name: 'last_viewed_at') DateTime? lastViewedAt,
      @JsonKey(name: 'apply_clicked_at') DateTime? applyClickedAt,
      @JsonKey(name: 'applied_at') DateTime? appliedAt,
      @JsonKey(name: 'shared_at') DateTime? sharedAt,
      @JsonKey(name: 'copied_text_at') DateTime? copiedTextAt,
      @JsonKey(name: 'printed_at') DateTime? printedAt,
      @JsonKey(name: 'view_count') int viewCount,
      @JsonKey(name: 'total_time_seconds') int totalTimeSeconds,
      @JsonKey(name: 'max_scroll_depth_percent') int maxScrollDepthPercent,
      @JsonKey(name: 'session_count') int sessionCount,
      @JsonKey(name: 'avg_session_duration_seconds')
      double avgSessionDurationSeconds,
      @JsonKey(name: 'total_idle_time_seconds') int totalIdleTimeSeconds,
      @JsonKey(name: 'total_active_time_seconds') int totalActiveTimeSeconds,
      @JsonKey(name: 'external_apply_clicks') int externalApplyClicks,
      @JsonKey(name: 'application_id') String? applicationId,
      @JsonKey(name: 'last_device_type') String? lastDeviceType,
      @JsonKey(name: 'last_browser') String? lastBrowser,
      @JsonKey(name: 'last_os') String? lastOs,
      @JsonKey(name: 'devices_used') List<String> devicesUsed,
      @JsonKey(name: 'browsers_used') List<String> browsersUsed,
      @JsonKey(name: 'last_city') String? lastCity,
      @JsonKey(name: 'last_region') String? lastRegion,
      @JsonKey(name: 'last_country') String? lastCountry,
      @JsonKey(name: 'last_ip_address') String? lastIpAddress,
      @JsonKey(name: 'last_session_id') String? lastSessionId,
      @JsonKey(name: 'first_referrer_url') String? firstReferrerUrl,
      @JsonKey(name: 'first_referrer_domain') String? firstReferrerDomain,
      @JsonKey(name: 'first_utm_source') String? firstUtmSource,
      @JsonKey(name: 'first_utm_medium') String? firstUtmMedium,
      @JsonKey(name: 'first_utm_campaign') String? firstUtmCampaign,
      @JsonKey(name: 'last_external_apply_url') String? lastExternalApplyUrl});
}

/// @nodoc
class _$JobMemberInteractionCopyWithImpl<$Res,
        $Val extends JobMemberInteraction>
    implements $JobMemberInteractionCopyWith<$Res> {
  _$JobMemberInteractionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? jobId = null,
    Object? memberId = null,
    Object? memberName = freezed,
    Object? memberEmail = freezed,
    Object? memberProfilePhotoUrl = freezed,
    Object? memberCity = freezed,
    Object? memberState = freezed,
    Object? hasViewed = null,
    Object? hasClickedApply = null,
    Object? hasApplied = null,
    Object? hasShared = null,
    Object? hasCopiedText = null,
    Object? hasPrinted = null,
    Object? firstViewedAt = freezed,
    Object? lastViewedAt = freezed,
    Object? applyClickedAt = freezed,
    Object? appliedAt = freezed,
    Object? sharedAt = freezed,
    Object? copiedTextAt = freezed,
    Object? printedAt = freezed,
    Object? viewCount = null,
    Object? totalTimeSeconds = null,
    Object? maxScrollDepthPercent = null,
    Object? sessionCount = null,
    Object? avgSessionDurationSeconds = null,
    Object? totalIdleTimeSeconds = null,
    Object? totalActiveTimeSeconds = null,
    Object? externalApplyClicks = null,
    Object? applicationId = freezed,
    Object? lastDeviceType = freezed,
    Object? lastBrowser = freezed,
    Object? lastOs = freezed,
    Object? devicesUsed = null,
    Object? browsersUsed = null,
    Object? lastCity = freezed,
    Object? lastRegion = freezed,
    Object? lastCountry = freezed,
    Object? lastIpAddress = freezed,
    Object? lastSessionId = freezed,
    Object? firstReferrerUrl = freezed,
    Object? firstReferrerDomain = freezed,
    Object? firstUtmSource = freezed,
    Object? firstUtmMedium = freezed,
    Object? firstUtmCampaign = freezed,
    Object? lastExternalApplyUrl = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      jobId: null == jobId
          ? _value.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      memberName: freezed == memberName
          ? _value.memberName
          : memberName // ignore: cast_nullable_to_non_nullable
              as String?,
      memberEmail: freezed == memberEmail
          ? _value.memberEmail
          : memberEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      memberProfilePhotoUrl: freezed == memberProfilePhotoUrl
          ? _value.memberProfilePhotoUrl
          : memberProfilePhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      memberCity: freezed == memberCity
          ? _value.memberCity
          : memberCity // ignore: cast_nullable_to_non_nullable
              as String?,
      memberState: freezed == memberState
          ? _value.memberState
          : memberState // ignore: cast_nullable_to_non_nullable
              as String?,
      hasViewed: null == hasViewed
          ? _value.hasViewed
          : hasViewed // ignore: cast_nullable_to_non_nullable
              as bool,
      hasClickedApply: null == hasClickedApply
          ? _value.hasClickedApply
          : hasClickedApply // ignore: cast_nullable_to_non_nullable
              as bool,
      hasApplied: null == hasApplied
          ? _value.hasApplied
          : hasApplied // ignore: cast_nullable_to_non_nullable
              as bool,
      hasShared: null == hasShared
          ? _value.hasShared
          : hasShared // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCopiedText: null == hasCopiedText
          ? _value.hasCopiedText
          : hasCopiedText // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPrinted: null == hasPrinted
          ? _value.hasPrinted
          : hasPrinted // ignore: cast_nullable_to_non_nullable
              as bool,
      firstViewedAt: freezed == firstViewedAt
          ? _value.firstViewedAt
          : firstViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastViewedAt: freezed == lastViewedAt
          ? _value.lastViewedAt
          : lastViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      applyClickedAt: freezed == applyClickedAt
          ? _value.applyClickedAt
          : applyClickedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      appliedAt: freezed == appliedAt
          ? _value.appliedAt
          : appliedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sharedAt: freezed == sharedAt
          ? _value.sharedAt
          : sharedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      copiedTextAt: freezed == copiedTextAt
          ? _value.copiedTextAt
          : copiedTextAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      printedAt: freezed == printedAt
          ? _value.printedAt
          : printedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      viewCount: null == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTimeSeconds: null == totalTimeSeconds
          ? _value.totalTimeSeconds
          : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxScrollDepthPercent: null == maxScrollDepthPercent
          ? _value.maxScrollDepthPercent
          : maxScrollDepthPercent // ignore: cast_nullable_to_non_nullable
              as int,
      sessionCount: null == sessionCount
          ? _value.sessionCount
          : sessionCount // ignore: cast_nullable_to_non_nullable
              as int,
      avgSessionDurationSeconds: null == avgSessionDurationSeconds
          ? _value.avgSessionDurationSeconds
          : avgSessionDurationSeconds // ignore: cast_nullable_to_non_nullable
              as double,
      totalIdleTimeSeconds: null == totalIdleTimeSeconds
          ? _value.totalIdleTimeSeconds
          : totalIdleTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      totalActiveTimeSeconds: null == totalActiveTimeSeconds
          ? _value.totalActiveTimeSeconds
          : totalActiveTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      externalApplyClicks: null == externalApplyClicks
          ? _value.externalApplyClicks
          : externalApplyClicks // ignore: cast_nullable_to_non_nullable
              as int,
      applicationId: freezed == applicationId
          ? _value.applicationId
          : applicationId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastDeviceType: freezed == lastDeviceType
          ? _value.lastDeviceType
          : lastDeviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      lastBrowser: freezed == lastBrowser
          ? _value.lastBrowser
          : lastBrowser // ignore: cast_nullable_to_non_nullable
              as String?,
      lastOs: freezed == lastOs
          ? _value.lastOs
          : lastOs // ignore: cast_nullable_to_non_nullable
              as String?,
      devicesUsed: null == devicesUsed
          ? _value.devicesUsed
          : devicesUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      browsersUsed: null == browsersUsed
          ? _value.browsersUsed
          : browsersUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastCity: freezed == lastCity
          ? _value.lastCity
          : lastCity // ignore: cast_nullable_to_non_nullable
              as String?,
      lastRegion: freezed == lastRegion
          ? _value.lastRegion
          : lastRegion // ignore: cast_nullable_to_non_nullable
              as String?,
      lastCountry: freezed == lastCountry
          ? _value.lastCountry
          : lastCountry // ignore: cast_nullable_to_non_nullable
              as String?,
      lastIpAddress: freezed == lastIpAddress
          ? _value.lastIpAddress
          : lastIpAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      lastSessionId: freezed == lastSessionId
          ? _value.lastSessionId
          : lastSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerUrl: freezed == firstReferrerUrl
          ? _value.firstReferrerUrl
          : firstReferrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerDomain: freezed == firstReferrerDomain
          ? _value.firstReferrerDomain
          : firstReferrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmSource: freezed == firstUtmSource
          ? _value.firstUtmSource
          : firstUtmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmMedium: freezed == firstUtmMedium
          ? _value.firstUtmMedium
          : firstUtmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmCampaign: freezed == firstUtmCampaign
          ? _value.firstUtmCampaign
          : firstUtmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      lastExternalApplyUrl: freezed == lastExternalApplyUrl
          ? _value.lastExternalApplyUrl
          : lastExternalApplyUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$JobMemberInteractionImplCopyWith<$Res>
    implements $JobMemberInteractionCopyWith<$Res> {
  factory _$$JobMemberInteractionImplCopyWith(_$JobMemberInteractionImpl value,
          $Res Function(_$JobMemberInteractionImpl) then) =
      __$$JobMemberInteractionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt,
      @JsonKey(name: 'job_id') String jobId,
      @JsonKey(name: 'member_id') String memberId,
      String? memberName,
      String? memberEmail,
      String? memberProfilePhotoUrl,
      String? memberCity,
      String? memberState,
      @JsonKey(name: 'has_viewed') bool hasViewed,
      @JsonKey(name: 'has_clicked_apply') bool hasClickedApply,
      @JsonKey(name: 'has_applied') bool hasApplied,
      @JsonKey(name: 'has_shared') bool hasShared,
      @JsonKey(name: 'has_copied_text') bool hasCopiedText,
      @JsonKey(name: 'has_printed') bool hasPrinted,
      @JsonKey(name: 'first_viewed_at') DateTime? firstViewedAt,
      @JsonKey(name: 'last_viewed_at') DateTime? lastViewedAt,
      @JsonKey(name: 'apply_clicked_at') DateTime? applyClickedAt,
      @JsonKey(name: 'applied_at') DateTime? appliedAt,
      @JsonKey(name: 'shared_at') DateTime? sharedAt,
      @JsonKey(name: 'copied_text_at') DateTime? copiedTextAt,
      @JsonKey(name: 'printed_at') DateTime? printedAt,
      @JsonKey(name: 'view_count') int viewCount,
      @JsonKey(name: 'total_time_seconds') int totalTimeSeconds,
      @JsonKey(name: 'max_scroll_depth_percent') int maxScrollDepthPercent,
      @JsonKey(name: 'session_count') int sessionCount,
      @JsonKey(name: 'avg_session_duration_seconds')
      double avgSessionDurationSeconds,
      @JsonKey(name: 'total_idle_time_seconds') int totalIdleTimeSeconds,
      @JsonKey(name: 'total_active_time_seconds') int totalActiveTimeSeconds,
      @JsonKey(name: 'external_apply_clicks') int externalApplyClicks,
      @JsonKey(name: 'application_id') String? applicationId,
      @JsonKey(name: 'last_device_type') String? lastDeviceType,
      @JsonKey(name: 'last_browser') String? lastBrowser,
      @JsonKey(name: 'last_os') String? lastOs,
      @JsonKey(name: 'devices_used') List<String> devicesUsed,
      @JsonKey(name: 'browsers_used') List<String> browsersUsed,
      @JsonKey(name: 'last_city') String? lastCity,
      @JsonKey(name: 'last_region') String? lastRegion,
      @JsonKey(name: 'last_country') String? lastCountry,
      @JsonKey(name: 'last_ip_address') String? lastIpAddress,
      @JsonKey(name: 'last_session_id') String? lastSessionId,
      @JsonKey(name: 'first_referrer_url') String? firstReferrerUrl,
      @JsonKey(name: 'first_referrer_domain') String? firstReferrerDomain,
      @JsonKey(name: 'first_utm_source') String? firstUtmSource,
      @JsonKey(name: 'first_utm_medium') String? firstUtmMedium,
      @JsonKey(name: 'first_utm_campaign') String? firstUtmCampaign,
      @JsonKey(name: 'last_external_apply_url') String? lastExternalApplyUrl});
}

/// @nodoc
class __$$JobMemberInteractionImplCopyWithImpl<$Res>
    extends _$JobMemberInteractionCopyWithImpl<$Res, _$JobMemberInteractionImpl>
    implements _$$JobMemberInteractionImplCopyWith<$Res> {
  __$$JobMemberInteractionImplCopyWithImpl(_$JobMemberInteractionImpl _value,
      $Res Function(_$JobMemberInteractionImpl) _then)
      : super(_value, _then);

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? jobId = null,
    Object? memberId = null,
    Object? memberName = freezed,
    Object? memberEmail = freezed,
    Object? memberProfilePhotoUrl = freezed,
    Object? memberCity = freezed,
    Object? memberState = freezed,
    Object? hasViewed = null,
    Object? hasClickedApply = null,
    Object? hasApplied = null,
    Object? hasShared = null,
    Object? hasCopiedText = null,
    Object? hasPrinted = null,
    Object? firstViewedAt = freezed,
    Object? lastViewedAt = freezed,
    Object? applyClickedAt = freezed,
    Object? appliedAt = freezed,
    Object? sharedAt = freezed,
    Object? copiedTextAt = freezed,
    Object? printedAt = freezed,
    Object? viewCount = null,
    Object? totalTimeSeconds = null,
    Object? maxScrollDepthPercent = null,
    Object? sessionCount = null,
    Object? avgSessionDurationSeconds = null,
    Object? totalIdleTimeSeconds = null,
    Object? totalActiveTimeSeconds = null,
    Object? externalApplyClicks = null,
    Object? applicationId = freezed,
    Object? lastDeviceType = freezed,
    Object? lastBrowser = freezed,
    Object? lastOs = freezed,
    Object? devicesUsed = null,
    Object? browsersUsed = null,
    Object? lastCity = freezed,
    Object? lastRegion = freezed,
    Object? lastCountry = freezed,
    Object? lastIpAddress = freezed,
    Object? lastSessionId = freezed,
    Object? firstReferrerUrl = freezed,
    Object? firstReferrerDomain = freezed,
    Object? firstUtmSource = freezed,
    Object? firstUtmMedium = freezed,
    Object? firstUtmCampaign = freezed,
    Object? lastExternalApplyUrl = freezed,
  }) {
    return _then(_$JobMemberInteractionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      jobId: null == jobId
          ? _value.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _value.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      memberName: freezed == memberName
          ? _value.memberName
          : memberName // ignore: cast_nullable_to_non_nullable
              as String?,
      memberEmail: freezed == memberEmail
          ? _value.memberEmail
          : memberEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      memberProfilePhotoUrl: freezed == memberProfilePhotoUrl
          ? _value.memberProfilePhotoUrl
          : memberProfilePhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      memberCity: freezed == memberCity
          ? _value.memberCity
          : memberCity // ignore: cast_nullable_to_non_nullable
              as String?,
      memberState: freezed == memberState
          ? _value.memberState
          : memberState // ignore: cast_nullable_to_non_nullable
              as String?,
      hasViewed: null == hasViewed
          ? _value.hasViewed
          : hasViewed // ignore: cast_nullable_to_non_nullable
              as bool,
      hasClickedApply: null == hasClickedApply
          ? _value.hasClickedApply
          : hasClickedApply // ignore: cast_nullable_to_non_nullable
              as bool,
      hasApplied: null == hasApplied
          ? _value.hasApplied
          : hasApplied // ignore: cast_nullable_to_non_nullable
              as bool,
      hasShared: null == hasShared
          ? _value.hasShared
          : hasShared // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCopiedText: null == hasCopiedText
          ? _value.hasCopiedText
          : hasCopiedText // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPrinted: null == hasPrinted
          ? _value.hasPrinted
          : hasPrinted // ignore: cast_nullable_to_non_nullable
              as bool,
      firstViewedAt: freezed == firstViewedAt
          ? _value.firstViewedAt
          : firstViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastViewedAt: freezed == lastViewedAt
          ? _value.lastViewedAt
          : lastViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      applyClickedAt: freezed == applyClickedAt
          ? _value.applyClickedAt
          : applyClickedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      appliedAt: freezed == appliedAt
          ? _value.appliedAt
          : appliedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sharedAt: freezed == sharedAt
          ? _value.sharedAt
          : sharedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      copiedTextAt: freezed == copiedTextAt
          ? _value.copiedTextAt
          : copiedTextAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      printedAt: freezed == printedAt
          ? _value.printedAt
          : printedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      viewCount: null == viewCount
          ? _value.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTimeSeconds: null == totalTimeSeconds
          ? _value.totalTimeSeconds
          : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxScrollDepthPercent: null == maxScrollDepthPercent
          ? _value.maxScrollDepthPercent
          : maxScrollDepthPercent // ignore: cast_nullable_to_non_nullable
              as int,
      sessionCount: null == sessionCount
          ? _value.sessionCount
          : sessionCount // ignore: cast_nullable_to_non_nullable
              as int,
      avgSessionDurationSeconds: null == avgSessionDurationSeconds
          ? _value.avgSessionDurationSeconds
          : avgSessionDurationSeconds // ignore: cast_nullable_to_non_nullable
              as double,
      totalIdleTimeSeconds: null == totalIdleTimeSeconds
          ? _value.totalIdleTimeSeconds
          : totalIdleTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      totalActiveTimeSeconds: null == totalActiveTimeSeconds
          ? _value.totalActiveTimeSeconds
          : totalActiveTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      externalApplyClicks: null == externalApplyClicks
          ? _value.externalApplyClicks
          : externalApplyClicks // ignore: cast_nullable_to_non_nullable
              as int,
      applicationId: freezed == applicationId
          ? _value.applicationId
          : applicationId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastDeviceType: freezed == lastDeviceType
          ? _value.lastDeviceType
          : lastDeviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      lastBrowser: freezed == lastBrowser
          ? _value.lastBrowser
          : lastBrowser // ignore: cast_nullable_to_non_nullable
              as String?,
      lastOs: freezed == lastOs
          ? _value.lastOs
          : lastOs // ignore: cast_nullable_to_non_nullable
              as String?,
      devicesUsed: null == devicesUsed
          ? _value._devicesUsed
          : devicesUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      browsersUsed: null == browsersUsed
          ? _value._browsersUsed
          : browsersUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastCity: freezed == lastCity
          ? _value.lastCity
          : lastCity // ignore: cast_nullable_to_non_nullable
              as String?,
      lastRegion: freezed == lastRegion
          ? _value.lastRegion
          : lastRegion // ignore: cast_nullable_to_non_nullable
              as String?,
      lastCountry: freezed == lastCountry
          ? _value.lastCountry
          : lastCountry // ignore: cast_nullable_to_non_nullable
              as String?,
      lastIpAddress: freezed == lastIpAddress
          ? _value.lastIpAddress
          : lastIpAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      lastSessionId: freezed == lastSessionId
          ? _value.lastSessionId
          : lastSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerUrl: freezed == firstReferrerUrl
          ? _value.firstReferrerUrl
          : firstReferrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerDomain: freezed == firstReferrerDomain
          ? _value.firstReferrerDomain
          : firstReferrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmSource: freezed == firstUtmSource
          ? _value.firstUtmSource
          : firstUtmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmMedium: freezed == firstUtmMedium
          ? _value.firstUtmMedium
          : firstUtmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmCampaign: freezed == firstUtmCampaign
          ? _value.firstUtmCampaign
          : firstUtmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      lastExternalApplyUrl: freezed == lastExternalApplyUrl
          ? _value.lastExternalApplyUrl
          : lastExternalApplyUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$JobMemberInteractionImpl extends _JobMemberInteraction {
  const _$JobMemberInteractionImpl(
      {required this.id,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt,
      @JsonKey(name: 'job_id') required this.jobId,
      @JsonKey(name: 'member_id') required this.memberId,
      this.memberName,
      this.memberEmail,
      this.memberProfilePhotoUrl,
      this.memberCity,
      this.memberState,
      @JsonKey(name: 'has_viewed') this.hasViewed = false,
      @JsonKey(name: 'has_clicked_apply') this.hasClickedApply = false,
      @JsonKey(name: 'has_applied') this.hasApplied = false,
      @JsonKey(name: 'has_shared') this.hasShared = false,
      @JsonKey(name: 'has_copied_text') this.hasCopiedText = false,
      @JsonKey(name: 'has_printed') this.hasPrinted = false,
      @JsonKey(name: 'first_viewed_at') this.firstViewedAt,
      @JsonKey(name: 'last_viewed_at') this.lastViewedAt,
      @JsonKey(name: 'apply_clicked_at') this.applyClickedAt,
      @JsonKey(name: 'applied_at') this.appliedAt,
      @JsonKey(name: 'shared_at') this.sharedAt,
      @JsonKey(name: 'copied_text_at') this.copiedTextAt,
      @JsonKey(name: 'printed_at') this.printedAt,
      @JsonKey(name: 'view_count') this.viewCount = 0,
      @JsonKey(name: 'total_time_seconds') this.totalTimeSeconds = 0,
      @JsonKey(name: 'max_scroll_depth_percent') this.maxScrollDepthPercent = 0,
      @JsonKey(name: 'session_count') this.sessionCount = 0,
      @JsonKey(name: 'avg_session_duration_seconds')
      this.avgSessionDurationSeconds = 0.0,
      @JsonKey(name: 'total_idle_time_seconds') this.totalIdleTimeSeconds = 0,
      @JsonKey(name: 'total_active_time_seconds')
      this.totalActiveTimeSeconds = 0,
      @JsonKey(name: 'external_apply_clicks') this.externalApplyClicks = 0,
      @JsonKey(name: 'application_id') this.applicationId,
      @JsonKey(name: 'last_device_type') this.lastDeviceType,
      @JsonKey(name: 'last_browser') this.lastBrowser,
      @JsonKey(name: 'last_os') this.lastOs,
      @JsonKey(name: 'devices_used') final List<String> devicesUsed = const [],
      @JsonKey(name: 'browsers_used')
      final List<String> browsersUsed = const [],
      @JsonKey(name: 'last_city') this.lastCity,
      @JsonKey(name: 'last_region') this.lastRegion,
      @JsonKey(name: 'last_country') this.lastCountry,
      @JsonKey(name: 'last_ip_address') this.lastIpAddress,
      @JsonKey(name: 'last_session_id') this.lastSessionId,
      @JsonKey(name: 'first_referrer_url') this.firstReferrerUrl,
      @JsonKey(name: 'first_referrer_domain') this.firstReferrerDomain,
      @JsonKey(name: 'first_utm_source') this.firstUtmSource,
      @JsonKey(name: 'first_utm_medium') this.firstUtmMedium,
      @JsonKey(name: 'first_utm_campaign') this.firstUtmCampaign,
      @JsonKey(name: 'last_external_apply_url') this.lastExternalApplyUrl})
      : _devicesUsed = devicesUsed,
        _browsersUsed = browsersUsed,
        super._();

  factory _$JobMemberInteractionImpl.fromJson(Map<String, dynamic> json) =>
      _$$JobMemberInteractionImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @override
  @JsonKey(name: 'job_id')
  final String jobId;
  @override
  @JsonKey(name: 'member_id')
  final String memberId;
// Member info (populated from join)
  @override
  final String? memberName;
  @override
  final String? memberEmail;
  @override
  final String? memberProfilePhotoUrl;
  @override
  final String? memberCity;
  @override
  final String? memberState;
// Action flags
  @override
  @JsonKey(name: 'has_viewed')
  final bool hasViewed;
  @override
  @JsonKey(name: 'has_clicked_apply')
  final bool hasClickedApply;
  @override
  @JsonKey(name: 'has_applied')
  final bool hasApplied;
  @override
  @JsonKey(name: 'has_shared')
  final bool hasShared;
  @override
  @JsonKey(name: 'has_copied_text')
  final bool hasCopiedText;
  @override
  @JsonKey(name: 'has_printed')
  final bool hasPrinted;
// Timestamps
  @override
  @JsonKey(name: 'first_viewed_at')
  final DateTime? firstViewedAt;
  @override
  @JsonKey(name: 'last_viewed_at')
  final DateTime? lastViewedAt;
  @override
  @JsonKey(name: 'apply_clicked_at')
  final DateTime? applyClickedAt;
  @override
  @JsonKey(name: 'applied_at')
  final DateTime? appliedAt;
  @override
  @JsonKey(name: 'shared_at')
  final DateTime? sharedAt;
  @override
  @JsonKey(name: 'copied_text_at')
  final DateTime? copiedTextAt;
  @override
  @JsonKey(name: 'printed_at')
  final DateTime? printedAt;
// Engagement metrics
  @override
  @JsonKey(name: 'view_count')
  final int viewCount;
  @override
  @JsonKey(name: 'total_time_seconds')
  final int totalTimeSeconds;
  @override
  @JsonKey(name: 'max_scroll_depth_percent')
  final int maxScrollDepthPercent;
  @override
  @JsonKey(name: 'session_count')
  final int sessionCount;
  @override
  @JsonKey(name: 'avg_session_duration_seconds')
  final double avgSessionDurationSeconds;
  @override
  @JsonKey(name: 'total_idle_time_seconds')
  final int totalIdleTimeSeconds;
  @override
  @JsonKey(name: 'total_active_time_seconds')
  final int totalActiveTimeSeconds;
  @override
  @JsonKey(name: 'external_apply_clicks')
  final int externalApplyClicks;
// Application reference
  @override
  @JsonKey(name: 'application_id')
  final String? applicationId;
// Last device info
  @override
  @JsonKey(name: 'last_device_type')
  final String? lastDeviceType;
  @override
  @JsonKey(name: 'last_browser')
  final String? lastBrowser;
  @override
  @JsonKey(name: 'last_os')
  final String? lastOs;
  final List<String> _devicesUsed;
  @override
  @JsonKey(name: 'devices_used')
  List<String> get devicesUsed {
    if (_devicesUsed is EqualUnmodifiableListView) return _devicesUsed;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_devicesUsed);
  }

  final List<String> _browsersUsed;
  @override
  @JsonKey(name: 'browsers_used')
  List<String> get browsersUsed {
    if (_browsersUsed is EqualUnmodifiableListView) return _browsersUsed;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_browsersUsed);
  }

// Last location info
  @override
  @JsonKey(name: 'last_city')
  final String? lastCity;
  @override
  @JsonKey(name: 'last_region')
  final String? lastRegion;
  @override
  @JsonKey(name: 'last_country')
  final String? lastCountry;
  @override
  @JsonKey(name: 'last_ip_address')
  final String? lastIpAddress;
// Session tracking
  @override
  @JsonKey(name: 'last_session_id')
  final String? lastSessionId;
// First touch attribution
  @override
  @JsonKey(name: 'first_referrer_url')
  final String? firstReferrerUrl;
  @override
  @JsonKey(name: 'first_referrer_domain')
  final String? firstReferrerDomain;
  @override
  @JsonKey(name: 'first_utm_source')
  final String? firstUtmSource;
  @override
  @JsonKey(name: 'first_utm_medium')
  final String? firstUtmMedium;
  @override
  @JsonKey(name: 'first_utm_campaign')
  final String? firstUtmCampaign;
// External apply tracking
  @override
  @JsonKey(name: 'last_external_apply_url')
  final String? lastExternalApplyUrl;

  @override
  String toString() {
    return 'JobMemberInteraction(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, jobId: $jobId, memberId: $memberId, memberName: $memberName, memberEmail: $memberEmail, memberProfilePhotoUrl: $memberProfilePhotoUrl, memberCity: $memberCity, memberState: $memberState, hasViewed: $hasViewed, hasClickedApply: $hasClickedApply, hasApplied: $hasApplied, hasShared: $hasShared, hasCopiedText: $hasCopiedText, hasPrinted: $hasPrinted, firstViewedAt: $firstViewedAt, lastViewedAt: $lastViewedAt, applyClickedAt: $applyClickedAt, appliedAt: $appliedAt, sharedAt: $sharedAt, copiedTextAt: $copiedTextAt, printedAt: $printedAt, viewCount: $viewCount, totalTimeSeconds: $totalTimeSeconds, maxScrollDepthPercent: $maxScrollDepthPercent, sessionCount: $sessionCount, avgSessionDurationSeconds: $avgSessionDurationSeconds, totalIdleTimeSeconds: $totalIdleTimeSeconds, totalActiveTimeSeconds: $totalActiveTimeSeconds, externalApplyClicks: $externalApplyClicks, applicationId: $applicationId, lastDeviceType: $lastDeviceType, lastBrowser: $lastBrowser, lastOs: $lastOs, devicesUsed: $devicesUsed, browsersUsed: $browsersUsed, lastCity: $lastCity, lastRegion: $lastRegion, lastCountry: $lastCountry, lastIpAddress: $lastIpAddress, lastSessionId: $lastSessionId, firstReferrerUrl: $firstReferrerUrl, firstReferrerDomain: $firstReferrerDomain, firstUtmSource: $firstUtmSource, firstUtmMedium: $firstUtmMedium, firstUtmCampaign: $firstUtmCampaign, lastExternalApplyUrl: $lastExternalApplyUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$JobMemberInteractionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId) &&
            (identical(other.memberName, memberName) ||
                other.memberName == memberName) &&
            (identical(other.memberEmail, memberEmail) ||
                other.memberEmail == memberEmail) &&
            (identical(other.memberProfilePhotoUrl, memberProfilePhotoUrl) ||
                other.memberProfilePhotoUrl == memberProfilePhotoUrl) &&
            (identical(other.memberCity, memberCity) ||
                other.memberCity == memberCity) &&
            (identical(other.memberState, memberState) ||
                other.memberState == memberState) &&
            (identical(other.hasViewed, hasViewed) ||
                other.hasViewed == hasViewed) &&
            (identical(other.hasClickedApply, hasClickedApply) ||
                other.hasClickedApply == hasClickedApply) &&
            (identical(other.hasApplied, hasApplied) ||
                other.hasApplied == hasApplied) &&
            (identical(other.hasShared, hasShared) ||
                other.hasShared == hasShared) &&
            (identical(other.hasCopiedText, hasCopiedText) ||
                other.hasCopiedText == hasCopiedText) &&
            (identical(other.hasPrinted, hasPrinted) ||
                other.hasPrinted == hasPrinted) &&
            (identical(other.firstViewedAt, firstViewedAt) ||
                other.firstViewedAt == firstViewedAt) &&
            (identical(other.lastViewedAt, lastViewedAt) ||
                other.lastViewedAt == lastViewedAt) &&
            (identical(other.applyClickedAt, applyClickedAt) ||
                other.applyClickedAt == applyClickedAt) &&
            (identical(other.appliedAt, appliedAt) ||
                other.appliedAt == appliedAt) &&
            (identical(other.sharedAt, sharedAt) ||
                other.sharedAt == sharedAt) &&
            (identical(other.copiedTextAt, copiedTextAt) ||
                other.copiedTextAt == copiedTextAt) &&
            (identical(other.printedAt, printedAt) ||
                other.printedAt == printedAt) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            (identical(other.totalTimeSeconds, totalTimeSeconds) ||
                other.totalTimeSeconds == totalTimeSeconds) &&
            (identical(other.maxScrollDepthPercent, maxScrollDepthPercent) ||
                other.maxScrollDepthPercent == maxScrollDepthPercent) &&
            (identical(other.sessionCount, sessionCount) ||
                other.sessionCount == sessionCount) &&
            (identical(other.avgSessionDurationSeconds, avgSessionDurationSeconds) ||
                other.avgSessionDurationSeconds == avgSessionDurationSeconds) &&
            (identical(other.totalIdleTimeSeconds, totalIdleTimeSeconds) ||
                other.totalIdleTimeSeconds == totalIdleTimeSeconds) &&
            (identical(other.totalActiveTimeSeconds, totalActiveTimeSeconds) ||
                other.totalActiveTimeSeconds == totalActiveTimeSeconds) &&
            (identical(other.externalApplyClicks, externalApplyClicks) ||
                other.externalApplyClicks == externalApplyClicks) &&
            (identical(other.applicationId, applicationId) ||
                other.applicationId == applicationId) &&
            (identical(other.lastDeviceType, lastDeviceType) ||
                other.lastDeviceType == lastDeviceType) &&
            (identical(other.lastBrowser, lastBrowser) ||
                other.lastBrowser == lastBrowser) &&
            (identical(other.lastOs, lastOs) || other.lastOs == lastOs) &&
            const DeepCollectionEquality()
                .equals(other._devicesUsed, _devicesUsed) &&
            const DeepCollectionEquality()
                .equals(other._browsersUsed, _browsersUsed) &&
            (identical(other.lastCity, lastCity) ||
                other.lastCity == lastCity) &&
            (identical(other.lastRegion, lastRegion) ||
                other.lastRegion == lastRegion) &&
            (identical(other.lastCountry, lastCountry) ||
                other.lastCountry == lastCountry) &&
            (identical(other.lastIpAddress, lastIpAddress) ||
                other.lastIpAddress == lastIpAddress) &&
            (identical(other.lastSessionId, lastSessionId) ||
                other.lastSessionId == lastSessionId) &&
            (identical(other.firstReferrerUrl, firstReferrerUrl) ||
                other.firstReferrerUrl == firstReferrerUrl) &&
            (identical(other.firstReferrerDomain, firstReferrerDomain) ||
                other.firstReferrerDomain == firstReferrerDomain) &&
            (identical(other.firstUtmSource, firstUtmSource) || other.firstUtmSource == firstUtmSource) &&
            (identical(other.firstUtmMedium, firstUtmMedium) || other.firstUtmMedium == firstUtmMedium) &&
            (identical(other.firstUtmCampaign, firstUtmCampaign) || other.firstUtmCampaign == firstUtmCampaign) &&
            (identical(other.lastExternalApplyUrl, lastExternalApplyUrl) || other.lastExternalApplyUrl == lastExternalApplyUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        createdAt,
        updatedAt,
        jobId,
        memberId,
        memberName,
        memberEmail,
        memberProfilePhotoUrl,
        memberCity,
        memberState,
        hasViewed,
        hasClickedApply,
        hasApplied,
        hasShared,
        hasCopiedText,
        hasPrinted,
        firstViewedAt,
        lastViewedAt,
        applyClickedAt,
        appliedAt,
        sharedAt,
        copiedTextAt,
        printedAt,
        viewCount,
        totalTimeSeconds,
        maxScrollDepthPercent,
        sessionCount,
        avgSessionDurationSeconds,
        totalIdleTimeSeconds,
        totalActiveTimeSeconds,
        externalApplyClicks,
        applicationId,
        lastDeviceType,
        lastBrowser,
        lastOs,
        const DeepCollectionEquality().hash(_devicesUsed),
        const DeepCollectionEquality().hash(_browsersUsed),
        lastCity,
        lastRegion,
        lastCountry,
        lastIpAddress,
        lastSessionId,
        firstReferrerUrl,
        firstReferrerDomain,
        firstUtmSource,
        firstUtmMedium,
        firstUtmCampaign,
        lastExternalApplyUrl
      ]);

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$JobMemberInteractionImplCopyWith<_$JobMemberInteractionImpl>
      get copyWith =>
          __$$JobMemberInteractionImplCopyWithImpl<_$JobMemberInteractionImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$JobMemberInteractionImplToJson(
      this,
    );
  }
}

abstract class _JobMemberInteraction extends JobMemberInteraction {
  const factory _JobMemberInteraction(
      {required final String id,
      @JsonKey(name: 'created_at') final DateTime? createdAt,
      @JsonKey(name: 'updated_at') final DateTime? updatedAt,
      @JsonKey(name: 'job_id') required final String jobId,
      @JsonKey(name: 'member_id') required final String memberId,
      final String? memberName,
      final String? memberEmail,
      final String? memberProfilePhotoUrl,
      final String? memberCity,
      final String? memberState,
      @JsonKey(name: 'has_viewed') final bool hasViewed,
      @JsonKey(name: 'has_clicked_apply') final bool hasClickedApply,
      @JsonKey(name: 'has_applied') final bool hasApplied,
      @JsonKey(name: 'has_shared') final bool hasShared,
      @JsonKey(name: 'has_copied_text') final bool hasCopiedText,
      @JsonKey(name: 'has_printed') final bool hasPrinted,
      @JsonKey(name: 'first_viewed_at') final DateTime? firstViewedAt,
      @JsonKey(name: 'last_viewed_at') final DateTime? lastViewedAt,
      @JsonKey(name: 'apply_clicked_at') final DateTime? applyClickedAt,
      @JsonKey(name: 'applied_at') final DateTime? appliedAt,
      @JsonKey(name: 'shared_at') final DateTime? sharedAt,
      @JsonKey(name: 'copied_text_at') final DateTime? copiedTextAt,
      @JsonKey(name: 'printed_at') final DateTime? printedAt,
      @JsonKey(name: 'view_count') final int viewCount,
      @JsonKey(name: 'total_time_seconds') final int totalTimeSeconds,
      @JsonKey(name: 'max_scroll_depth_percent')
      final int maxScrollDepthPercent,
      @JsonKey(name: 'session_count') final int sessionCount,
      @JsonKey(name: 'avg_session_duration_seconds')
      final double avgSessionDurationSeconds,
      @JsonKey(name: 'total_idle_time_seconds') final int totalIdleTimeSeconds,
      @JsonKey(name: 'total_active_time_seconds')
      final int totalActiveTimeSeconds,
      @JsonKey(name: 'external_apply_clicks') final int externalApplyClicks,
      @JsonKey(name: 'application_id') final String? applicationId,
      @JsonKey(name: 'last_device_type') final String? lastDeviceType,
      @JsonKey(name: 'last_browser') final String? lastBrowser,
      @JsonKey(name: 'last_os') final String? lastOs,
      @JsonKey(name: 'devices_used') final List<String> devicesUsed,
      @JsonKey(name: 'browsers_used') final List<String> browsersUsed,
      @JsonKey(name: 'last_city') final String? lastCity,
      @JsonKey(name: 'last_region') final String? lastRegion,
      @JsonKey(name: 'last_country') final String? lastCountry,
      @JsonKey(name: 'last_ip_address') final String? lastIpAddress,
      @JsonKey(name: 'last_session_id') final String? lastSessionId,
      @JsonKey(name: 'first_referrer_url') final String? firstReferrerUrl,
      @JsonKey(name: 'first_referrer_domain') final String? firstReferrerDomain,
      @JsonKey(name: 'first_utm_source') final String? firstUtmSource,
      @JsonKey(name: 'first_utm_medium') final String? firstUtmMedium,
      @JsonKey(name: 'first_utm_campaign') final String? firstUtmCampaign,
      @JsonKey(name: 'last_external_apply_url')
      final String? lastExternalApplyUrl}) = _$JobMemberInteractionImpl;
  const _JobMemberInteraction._() : super._();

  factory _JobMemberInteraction.fromJson(Map<String, dynamic> json) =
      _$JobMemberInteractionImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;
  @override
  @JsonKey(name: 'job_id')
  String get jobId;
  @override
  @JsonKey(name: 'member_id')
  String get memberId; // Member info (populated from join)
  @override
  String? get memberName;
  @override
  String? get memberEmail;
  @override
  String? get memberProfilePhotoUrl;
  @override
  String? get memberCity;
  @override
  String? get memberState; // Action flags
  @override
  @JsonKey(name: 'has_viewed')
  bool get hasViewed;
  @override
  @JsonKey(name: 'has_clicked_apply')
  bool get hasClickedApply;
  @override
  @JsonKey(name: 'has_applied')
  bool get hasApplied;
  @override
  @JsonKey(name: 'has_shared')
  bool get hasShared;
  @override
  @JsonKey(name: 'has_copied_text')
  bool get hasCopiedText;
  @override
  @JsonKey(name: 'has_printed')
  bool get hasPrinted; // Timestamps
  @override
  @JsonKey(name: 'first_viewed_at')
  DateTime? get firstViewedAt;
  @override
  @JsonKey(name: 'last_viewed_at')
  DateTime? get lastViewedAt;
  @override
  @JsonKey(name: 'apply_clicked_at')
  DateTime? get applyClickedAt;
  @override
  @JsonKey(name: 'applied_at')
  DateTime? get appliedAt;
  @override
  @JsonKey(name: 'shared_at')
  DateTime? get sharedAt;
  @override
  @JsonKey(name: 'copied_text_at')
  DateTime? get copiedTextAt;
  @override
  @JsonKey(name: 'printed_at')
  DateTime? get printedAt; // Engagement metrics
  @override
  @JsonKey(name: 'view_count')
  int get viewCount;
  @override
  @JsonKey(name: 'total_time_seconds')
  int get totalTimeSeconds;
  @override
  @JsonKey(name: 'max_scroll_depth_percent')
  int get maxScrollDepthPercent;
  @override
  @JsonKey(name: 'session_count')
  int get sessionCount;
  @override
  @JsonKey(name: 'avg_session_duration_seconds')
  double get avgSessionDurationSeconds;
  @override
  @JsonKey(name: 'total_idle_time_seconds')
  int get totalIdleTimeSeconds;
  @override
  @JsonKey(name: 'total_active_time_seconds')
  int get totalActiveTimeSeconds;
  @override
  @JsonKey(name: 'external_apply_clicks')
  int get externalApplyClicks; // Application reference
  @override
  @JsonKey(name: 'application_id')
  String? get applicationId; // Last device info
  @override
  @JsonKey(name: 'last_device_type')
  String? get lastDeviceType;
  @override
  @JsonKey(name: 'last_browser')
  String? get lastBrowser;
  @override
  @JsonKey(name: 'last_os')
  String? get lastOs;
  @override
  @JsonKey(name: 'devices_used')
  List<String> get devicesUsed;
  @override
  @JsonKey(name: 'browsers_used')
  List<String> get browsersUsed; // Last location info
  @override
  @JsonKey(name: 'last_city')
  String? get lastCity;
  @override
  @JsonKey(name: 'last_region')
  String? get lastRegion;
  @override
  @JsonKey(name: 'last_country')
  String? get lastCountry;
  @override
  @JsonKey(name: 'last_ip_address')
  String? get lastIpAddress; // Session tracking
  @override
  @JsonKey(name: 'last_session_id')
  String? get lastSessionId; // First touch attribution
  @override
  @JsonKey(name: 'first_referrer_url')
  String? get firstReferrerUrl;
  @override
  @JsonKey(name: 'first_referrer_domain')
  String? get firstReferrerDomain;
  @override
  @JsonKey(name: 'first_utm_source')
  String? get firstUtmSource;
  @override
  @JsonKey(name: 'first_utm_medium')
  String? get firstUtmMedium;
  @override
  @JsonKey(name: 'first_utm_campaign')
  String? get firstUtmCampaign; // External apply tracking
  @override
  @JsonKey(name: 'last_external_apply_url')
  String? get lastExternalApplyUrl;

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$JobMemberInteractionImplCopyWith<_$JobMemberInteractionImpl>
      get copyWith => throw _privateConstructorUsedError;
}
