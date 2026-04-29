// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobAnalyticsEvent {
  int get id;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @JsonKey(name: 'job_id')
  String get jobId;
  @JsonKey(name: 'member_id')
  String get memberId;
  @JsonKey(name: 'event_type')
  String get eventType;
  @JsonKey(name: 'event_data')
  Map<String, dynamic>? get eventData;
  @JsonKey(name: 'session_id')
  String? get sessionId; // Device info
  @JsonKey(name: 'device_type')
  String? get deviceType;
  @JsonKey(name: 'user_agent')
  String? get userAgent;
  String? get browser;
  @JsonKey(name: 'browser_version')
  String? get browserVersion;
  String? get os;
  @JsonKey(name: 'os_version')
  String? get osVersion;
  @JsonKey(name: 'is_mobile')
  bool get isMobile;
  @JsonKey(name: 'is_tablet')
  bool get isTablet; // Screen info
  @JsonKey(name: 'screen_width')
  int? get screenWidth;
  @JsonKey(name: 'screen_height')
  int? get screenHeight;
  @JsonKey(name: 'viewport_width')
  int? get viewportWidth;
  @JsonKey(name: 'viewport_height')
  int? get viewportHeight;
  @JsonKey(name: 'device_pixel_ratio')
  double? get devicePixelRatio; // Location info
  @JsonKey(name: 'ip_address')
  String? get ipAddress;
  String? get city;
  String? get region;
  String? get country;
  @JsonKey(name: 'country_code')
  String? get countryCode;
  double? get latitude;
  double? get longitude;
  String? get timezone; // Referrer info
  @JsonKey(name: 'referrer_url')
  String? get referrerUrl;
  @JsonKey(name: 'referrer_domain')
  String? get referrerDomain; // UTM tracking
  @JsonKey(name: 'utm_source')
  String? get utmSource;
  @JsonKey(name: 'utm_medium')
  String? get utmMedium;
  @JsonKey(name: 'utm_campaign')
  String? get utmCampaign;
  @JsonKey(name: 'utm_term')
  String? get utmTerm;
  @JsonKey(name: 'utm_content')
  String? get utmContent; // Page info
  @JsonKey(name: 'page_url')
  String? get pageUrl;
  @JsonKey(name: 'page_path')
  String? get pagePath; // Connection info
  @JsonKey(name: 'connection_type')
  String? get connectionType;
  @JsonKey(name: 'connection_downlink')
  double? get connectionDownlink; // Language
  String? get language;
  List<String>? get languages;

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JobAnalyticsEventCopyWith<JobAnalyticsEvent> get copyWith =>
      _$JobAnalyticsEventCopyWithImpl<JobAnalyticsEvent>(
          this as JobAnalyticsEvent, _$identity);

  /// Serializes this JobAnalyticsEvent to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JobAnalyticsEvent &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.jobId, jobId) || other.jobId == jobId) &&
            (identical(other.memberId, memberId) ||
                other.memberId == memberId) &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            const DeepCollectionEquality().equals(other.eventData, eventData) &&
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
            const DeepCollectionEquality().equals(other.languages, languages));
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
        const DeepCollectionEquality().hash(eventData),
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
        const DeepCollectionEquality().hash(languages)
      ]);

  @override
  String toString() {
    return 'JobAnalyticsEvent(id: $id, createdAt: $createdAt, jobId: $jobId, memberId: $memberId, eventType: $eventType, eventData: $eventData, sessionId: $sessionId, deviceType: $deviceType, userAgent: $userAgent, browser: $browser, browserVersion: $browserVersion, os: $os, osVersion: $osVersion, isMobile: $isMobile, isTablet: $isTablet, screenWidth: $screenWidth, screenHeight: $screenHeight, viewportWidth: $viewportWidth, viewportHeight: $viewportHeight, devicePixelRatio: $devicePixelRatio, ipAddress: $ipAddress, city: $city, region: $region, country: $country, countryCode: $countryCode, latitude: $latitude, longitude: $longitude, timezone: $timezone, referrerUrl: $referrerUrl, referrerDomain: $referrerDomain, utmSource: $utmSource, utmMedium: $utmMedium, utmCampaign: $utmCampaign, utmTerm: $utmTerm, utmContent: $utmContent, pageUrl: $pageUrl, pagePath: $pagePath, connectionType: $connectionType, connectionDownlink: $connectionDownlink, language: $language, languages: $languages)';
  }
}

/// @nodoc
abstract mixin class $JobAnalyticsEventCopyWith<$Res> {
  factory $JobAnalyticsEventCopyWith(
          JobAnalyticsEvent value, $Res Function(JobAnalyticsEvent) _then) =
      _$JobAnalyticsEventCopyWithImpl;
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
class _$JobAnalyticsEventCopyWithImpl<$Res>
    implements $JobAnalyticsEventCopyWith<$Res> {
  _$JobAnalyticsEventCopyWithImpl(this._self, this._then);

  final JobAnalyticsEvent _self;
  final $Res Function(JobAnalyticsEvent) _then;

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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _self.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      eventType: null == eventType
          ? _self.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      eventData: freezed == eventData
          ? _self.eventData
          : eventData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      sessionId: freezed == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceType: freezed == deviceType
          ? _self.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      userAgent: freezed == userAgent
          ? _self.userAgent
          : userAgent // ignore: cast_nullable_to_non_nullable
              as String?,
      browser: freezed == browser
          ? _self.browser
          : browser // ignore: cast_nullable_to_non_nullable
              as String?,
      browserVersion: freezed == browserVersion
          ? _self.browserVersion
          : browserVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      os: freezed == os
          ? _self.os
          : os // ignore: cast_nullable_to_non_nullable
              as String?,
      osVersion: freezed == osVersion
          ? _self.osVersion
          : osVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      isMobile: null == isMobile
          ? _self.isMobile
          : isMobile // ignore: cast_nullable_to_non_nullable
              as bool,
      isTablet: null == isTablet
          ? _self.isTablet
          : isTablet // ignore: cast_nullable_to_non_nullable
              as bool,
      screenWidth: freezed == screenWidth
          ? _self.screenWidth
          : screenWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      screenHeight: freezed == screenHeight
          ? _self.screenHeight
          : screenHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportWidth: freezed == viewportWidth
          ? _self.viewportWidth
          : viewportWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportHeight: freezed == viewportHeight
          ? _self.viewportHeight
          : viewportHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      devicePixelRatio: freezed == devicePixelRatio
          ? _self.devicePixelRatio
          : devicePixelRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      ipAddress: freezed == ipAddress
          ? _self.ipAddress
          : ipAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _self.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _self.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      country: freezed == country
          ? _self.country
          : country // ignore: cast_nullable_to_non_nullable
              as String?,
      countryCode: freezed == countryCode
          ? _self.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: freezed == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerUrl: freezed == referrerUrl
          ? _self.referrerUrl
          : referrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerDomain: freezed == referrerDomain
          ? _self.referrerDomain
          : referrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      utmSource: freezed == utmSource
          ? _self.utmSource
          : utmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      utmMedium: freezed == utmMedium
          ? _self.utmMedium
          : utmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      utmCampaign: freezed == utmCampaign
          ? _self.utmCampaign
          : utmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      utmTerm: freezed == utmTerm
          ? _self.utmTerm
          : utmTerm // ignore: cast_nullable_to_non_nullable
              as String?,
      utmContent: freezed == utmContent
          ? _self.utmContent
          : utmContent // ignore: cast_nullable_to_non_nullable
              as String?,
      pageUrl: freezed == pageUrl
          ? _self.pageUrl
          : pageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      pagePath: freezed == pagePath
          ? _self.pagePath
          : pagePath // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionType: freezed == connectionType
          ? _self.connectionType
          : connectionType // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionDownlink: freezed == connectionDownlink
          ? _self.connectionDownlink
          : connectionDownlink // ignore: cast_nullable_to_non_nullable
              as double?,
      language: freezed == language
          ? _self.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languages: freezed == languages
          ? _self.languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [JobAnalyticsEvent].
extension JobAnalyticsEventPatterns on JobAnalyticsEvent {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_JobAnalyticsEvent value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobAnalyticsEvent() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_JobAnalyticsEvent value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobAnalyticsEvent():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_JobAnalyticsEvent value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobAnalyticsEvent() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            int id,
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
            List<String>? languages)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobAnalyticsEvent() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.jobId,
            _that.memberId,
            _that.eventType,
            _that.eventData,
            _that.sessionId,
            _that.deviceType,
            _that.userAgent,
            _that.browser,
            _that.browserVersion,
            _that.os,
            _that.osVersion,
            _that.isMobile,
            _that.isTablet,
            _that.screenWidth,
            _that.screenHeight,
            _that.viewportWidth,
            _that.viewportHeight,
            _that.devicePixelRatio,
            _that.ipAddress,
            _that.city,
            _that.region,
            _that.country,
            _that.countryCode,
            _that.latitude,
            _that.longitude,
            _that.timezone,
            _that.referrerUrl,
            _that.referrerDomain,
            _that.utmSource,
            _that.utmMedium,
            _that.utmCampaign,
            _that.utmTerm,
            _that.utmContent,
            _that.pageUrl,
            _that.pagePath,
            _that.connectionType,
            _that.connectionDownlink,
            _that.language,
            _that.languages);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            int id,
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
            List<String>? languages)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobAnalyticsEvent():
        return $default(
            _that.id,
            _that.createdAt,
            _that.jobId,
            _that.memberId,
            _that.eventType,
            _that.eventData,
            _that.sessionId,
            _that.deviceType,
            _that.userAgent,
            _that.browser,
            _that.browserVersion,
            _that.os,
            _that.osVersion,
            _that.isMobile,
            _that.isTablet,
            _that.screenWidth,
            _that.screenHeight,
            _that.viewportWidth,
            _that.viewportHeight,
            _that.devicePixelRatio,
            _that.ipAddress,
            _that.city,
            _that.region,
            _that.country,
            _that.countryCode,
            _that.latitude,
            _that.longitude,
            _that.timezone,
            _that.referrerUrl,
            _that.referrerDomain,
            _that.utmSource,
            _that.utmMedium,
            _that.utmCampaign,
            _that.utmTerm,
            _that.utmContent,
            _that.pageUrl,
            _that.pagePath,
            _that.connectionType,
            _that.connectionDownlink,
            _that.language,
            _that.languages);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            int id,
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
            List<String>? languages)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobAnalyticsEvent() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.jobId,
            _that.memberId,
            _that.eventType,
            _that.eventData,
            _that.sessionId,
            _that.deviceType,
            _that.userAgent,
            _that.browser,
            _that.browserVersion,
            _that.os,
            _that.osVersion,
            _that.isMobile,
            _that.isTablet,
            _that.screenWidth,
            _that.screenHeight,
            _that.viewportWidth,
            _that.viewportHeight,
            _that.devicePixelRatio,
            _that.ipAddress,
            _that.city,
            _that.region,
            _that.country,
            _that.countryCode,
            _that.latitude,
            _that.longitude,
            _that.timezone,
            _that.referrerUrl,
            _that.referrerDomain,
            _that.utmSource,
            _that.utmMedium,
            _that.utmCampaign,
            _that.utmTerm,
            _that.utmContent,
            _that.pageUrl,
            _that.pagePath,
            _that.connectionType,
            _that.connectionDownlink,
            _that.language,
            _that.languages);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _JobAnalyticsEvent extends JobAnalyticsEvent {
  const _JobAnalyticsEvent(
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
  factory _JobAnalyticsEvent.fromJson(Map<String, dynamic> json) =>
      _$JobAnalyticsEventFromJson(json);

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

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JobAnalyticsEventCopyWith<_JobAnalyticsEvent> get copyWith =>
      __$JobAnalyticsEventCopyWithImpl<_JobAnalyticsEvent>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JobAnalyticsEventToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JobAnalyticsEvent &&
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

  @override
  String toString() {
    return 'JobAnalyticsEvent(id: $id, createdAt: $createdAt, jobId: $jobId, memberId: $memberId, eventType: $eventType, eventData: $eventData, sessionId: $sessionId, deviceType: $deviceType, userAgent: $userAgent, browser: $browser, browserVersion: $browserVersion, os: $os, osVersion: $osVersion, isMobile: $isMobile, isTablet: $isTablet, screenWidth: $screenWidth, screenHeight: $screenHeight, viewportWidth: $viewportWidth, viewportHeight: $viewportHeight, devicePixelRatio: $devicePixelRatio, ipAddress: $ipAddress, city: $city, region: $region, country: $country, countryCode: $countryCode, latitude: $latitude, longitude: $longitude, timezone: $timezone, referrerUrl: $referrerUrl, referrerDomain: $referrerDomain, utmSource: $utmSource, utmMedium: $utmMedium, utmCampaign: $utmCampaign, utmTerm: $utmTerm, utmContent: $utmContent, pageUrl: $pageUrl, pagePath: $pagePath, connectionType: $connectionType, connectionDownlink: $connectionDownlink, language: $language, languages: $languages)';
  }
}

/// @nodoc
abstract mixin class _$JobAnalyticsEventCopyWith<$Res>
    implements $JobAnalyticsEventCopyWith<$Res> {
  factory _$JobAnalyticsEventCopyWith(
          _JobAnalyticsEvent value, $Res Function(_JobAnalyticsEvent) _then) =
      __$JobAnalyticsEventCopyWithImpl;
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
class __$JobAnalyticsEventCopyWithImpl<$Res>
    implements _$JobAnalyticsEventCopyWith<$Res> {
  __$JobAnalyticsEventCopyWithImpl(this._self, this._then);

  final _JobAnalyticsEvent _self;
  final $Res Function(_JobAnalyticsEvent) _then;

  /// Create a copy of JobAnalyticsEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_JobAnalyticsEvent(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      jobId: null == jobId
          ? _self.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      eventType: null == eventType
          ? _self.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      eventData: freezed == eventData
          ? _self._eventData
          : eventData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      sessionId: freezed == sessionId
          ? _self.sessionId
          : sessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      deviceType: freezed == deviceType
          ? _self.deviceType
          : deviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      userAgent: freezed == userAgent
          ? _self.userAgent
          : userAgent // ignore: cast_nullable_to_non_nullable
              as String?,
      browser: freezed == browser
          ? _self.browser
          : browser // ignore: cast_nullable_to_non_nullable
              as String?,
      browserVersion: freezed == browserVersion
          ? _self.browserVersion
          : browserVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      os: freezed == os
          ? _self.os
          : os // ignore: cast_nullable_to_non_nullable
              as String?,
      osVersion: freezed == osVersion
          ? _self.osVersion
          : osVersion // ignore: cast_nullable_to_non_nullable
              as String?,
      isMobile: null == isMobile
          ? _self.isMobile
          : isMobile // ignore: cast_nullable_to_non_nullable
              as bool,
      isTablet: null == isTablet
          ? _self.isTablet
          : isTablet // ignore: cast_nullable_to_non_nullable
              as bool,
      screenWidth: freezed == screenWidth
          ? _self.screenWidth
          : screenWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      screenHeight: freezed == screenHeight
          ? _self.screenHeight
          : screenHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportWidth: freezed == viewportWidth
          ? _self.viewportWidth
          : viewportWidth // ignore: cast_nullable_to_non_nullable
              as int?,
      viewportHeight: freezed == viewportHeight
          ? _self.viewportHeight
          : viewportHeight // ignore: cast_nullable_to_non_nullable
              as int?,
      devicePixelRatio: freezed == devicePixelRatio
          ? _self.devicePixelRatio
          : devicePixelRatio // ignore: cast_nullable_to_non_nullable
              as double?,
      ipAddress: freezed == ipAddress
          ? _self.ipAddress
          : ipAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      city: freezed == city
          ? _self.city
          : city // ignore: cast_nullable_to_non_nullable
              as String?,
      region: freezed == region
          ? _self.region
          : region // ignore: cast_nullable_to_non_nullable
              as String?,
      country: freezed == country
          ? _self.country
          : country // ignore: cast_nullable_to_non_nullable
              as String?,
      countryCode: freezed == countryCode
          ? _self.countryCode
          : countryCode // ignore: cast_nullable_to_non_nullable
              as String?,
      latitude: freezed == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double?,
      longitude: freezed == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double?,
      timezone: freezed == timezone
          ? _self.timezone
          : timezone // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerUrl: freezed == referrerUrl
          ? _self.referrerUrl
          : referrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      referrerDomain: freezed == referrerDomain
          ? _self.referrerDomain
          : referrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      utmSource: freezed == utmSource
          ? _self.utmSource
          : utmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      utmMedium: freezed == utmMedium
          ? _self.utmMedium
          : utmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      utmCampaign: freezed == utmCampaign
          ? _self.utmCampaign
          : utmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      utmTerm: freezed == utmTerm
          ? _self.utmTerm
          : utmTerm // ignore: cast_nullable_to_non_nullable
              as String?,
      utmContent: freezed == utmContent
          ? _self.utmContent
          : utmContent // ignore: cast_nullable_to_non_nullable
              as String?,
      pageUrl: freezed == pageUrl
          ? _self.pageUrl
          : pageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      pagePath: freezed == pagePath
          ? _self.pagePath
          : pagePath // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionType: freezed == connectionType
          ? _self.connectionType
          : connectionType // ignore: cast_nullable_to_non_nullable
              as String?,
      connectionDownlink: freezed == connectionDownlink
          ? _self.connectionDownlink
          : connectionDownlink // ignore: cast_nullable_to_non_nullable
              as double?,
      language: freezed == language
          ? _self.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languages: freezed == languages
          ? _self._languages
          : languages // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
mixin _$JobMemberInteraction {
  String get id;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;
  @JsonKey(name: 'job_id')
  String get jobId;
  @JsonKey(name: 'member_id')
  String get memberId; // Member info (populated from join)
  String? get memberName;
  String? get memberEmail;
  String? get memberProfilePhotoUrl;
  String? get memberCity;
  String? get memberState; // Action flags
  @JsonKey(name: 'has_viewed')
  bool get hasViewed;
  @JsonKey(name: 'has_clicked_apply')
  bool get hasClickedApply;
  @JsonKey(name: 'has_applied')
  bool get hasApplied;
  @JsonKey(name: 'has_shared')
  bool get hasShared;
  @JsonKey(name: 'has_copied_text')
  bool get hasCopiedText;
  @JsonKey(name: 'has_printed')
  bool get hasPrinted; // Timestamps
  @JsonKey(name: 'first_viewed_at')
  DateTime? get firstViewedAt;
  @JsonKey(name: 'last_viewed_at')
  DateTime? get lastViewedAt;
  @JsonKey(name: 'apply_clicked_at')
  DateTime? get applyClickedAt;
  @JsonKey(name: 'applied_at')
  DateTime? get appliedAt;
  @JsonKey(name: 'shared_at')
  DateTime? get sharedAt;
  @JsonKey(name: 'copied_text_at')
  DateTime? get copiedTextAt;
  @JsonKey(name: 'printed_at')
  DateTime? get printedAt; // Engagement metrics
  @JsonKey(name: 'view_count')
  int get viewCount;
  @JsonKey(name: 'total_time_seconds')
  int get totalTimeSeconds;
  @JsonKey(name: 'max_scroll_depth_percent')
  int get maxScrollDepthPercent;
  @JsonKey(name: 'session_count')
  int get sessionCount;
  @JsonKey(name: 'avg_session_duration_seconds')
  double get avgSessionDurationSeconds;
  @JsonKey(name: 'total_idle_time_seconds')
  int get totalIdleTimeSeconds;
  @JsonKey(name: 'total_active_time_seconds')
  int get totalActiveTimeSeconds;
  @JsonKey(name: 'external_apply_clicks')
  int get externalApplyClicks; // Application reference
  @JsonKey(name: 'application_id')
  String? get applicationId; // Last device info
  @JsonKey(name: 'last_device_type')
  String? get lastDeviceType;
  @JsonKey(name: 'last_browser')
  String? get lastBrowser;
  @JsonKey(name: 'last_os')
  String? get lastOs;
  @JsonKey(name: 'devices_used')
  List<String> get devicesUsed;
  @JsonKey(name: 'browsers_used')
  List<String> get browsersUsed; // Last location info
  @JsonKey(name: 'last_city')
  String? get lastCity;
  @JsonKey(name: 'last_region')
  String? get lastRegion;
  @JsonKey(name: 'last_country')
  String? get lastCountry;
  @JsonKey(name: 'last_ip_address')
  String? get lastIpAddress; // Session tracking
  @JsonKey(name: 'last_session_id')
  String? get lastSessionId; // First touch attribution
  @JsonKey(name: 'first_referrer_url')
  String? get firstReferrerUrl;
  @JsonKey(name: 'first_referrer_domain')
  String? get firstReferrerDomain;
  @JsonKey(name: 'first_utm_source')
  String? get firstUtmSource;
  @JsonKey(name: 'first_utm_medium')
  String? get firstUtmMedium;
  @JsonKey(name: 'first_utm_campaign')
  String? get firstUtmCampaign; // External apply tracking
  @JsonKey(name: 'last_external_apply_url')
  String? get lastExternalApplyUrl;

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $JobMemberInteractionCopyWith<JobMemberInteraction> get copyWith =>
      _$JobMemberInteractionCopyWithImpl<JobMemberInteraction>(
          this as JobMemberInteraction, _$identity);

  /// Serializes this JobMemberInteraction to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is JobMemberInteraction &&
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
                .equals(other.devicesUsed, devicesUsed) &&
            const DeepCollectionEquality()
                .equals(other.browsersUsed, browsersUsed) &&
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
        const DeepCollectionEquality().hash(devicesUsed),
        const DeepCollectionEquality().hash(browsersUsed),
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

  @override
  String toString() {
    return 'JobMemberInteraction(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, jobId: $jobId, memberId: $memberId, memberName: $memberName, memberEmail: $memberEmail, memberProfilePhotoUrl: $memberProfilePhotoUrl, memberCity: $memberCity, memberState: $memberState, hasViewed: $hasViewed, hasClickedApply: $hasClickedApply, hasApplied: $hasApplied, hasShared: $hasShared, hasCopiedText: $hasCopiedText, hasPrinted: $hasPrinted, firstViewedAt: $firstViewedAt, lastViewedAt: $lastViewedAt, applyClickedAt: $applyClickedAt, appliedAt: $appliedAt, sharedAt: $sharedAt, copiedTextAt: $copiedTextAt, printedAt: $printedAt, viewCount: $viewCount, totalTimeSeconds: $totalTimeSeconds, maxScrollDepthPercent: $maxScrollDepthPercent, sessionCount: $sessionCount, avgSessionDurationSeconds: $avgSessionDurationSeconds, totalIdleTimeSeconds: $totalIdleTimeSeconds, totalActiveTimeSeconds: $totalActiveTimeSeconds, externalApplyClicks: $externalApplyClicks, applicationId: $applicationId, lastDeviceType: $lastDeviceType, lastBrowser: $lastBrowser, lastOs: $lastOs, devicesUsed: $devicesUsed, browsersUsed: $browsersUsed, lastCity: $lastCity, lastRegion: $lastRegion, lastCountry: $lastCountry, lastIpAddress: $lastIpAddress, lastSessionId: $lastSessionId, firstReferrerUrl: $firstReferrerUrl, firstReferrerDomain: $firstReferrerDomain, firstUtmSource: $firstUtmSource, firstUtmMedium: $firstUtmMedium, firstUtmCampaign: $firstUtmCampaign, lastExternalApplyUrl: $lastExternalApplyUrl)';
  }
}

/// @nodoc
abstract mixin class $JobMemberInteractionCopyWith<$Res> {
  factory $JobMemberInteractionCopyWith(JobMemberInteraction value,
          $Res Function(JobMemberInteraction) _then) =
      _$JobMemberInteractionCopyWithImpl;
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
class _$JobMemberInteractionCopyWithImpl<$Res>
    implements $JobMemberInteractionCopyWith<$Res> {
  _$JobMemberInteractionCopyWithImpl(this._self, this._then);

  final JobMemberInteraction _self;
  final $Res Function(JobMemberInteraction) _then;

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
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      jobId: null == jobId
          ? _self.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      memberName: freezed == memberName
          ? _self.memberName
          : memberName // ignore: cast_nullable_to_non_nullable
              as String?,
      memberEmail: freezed == memberEmail
          ? _self.memberEmail
          : memberEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      memberProfilePhotoUrl: freezed == memberProfilePhotoUrl
          ? _self.memberProfilePhotoUrl
          : memberProfilePhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      memberCity: freezed == memberCity
          ? _self.memberCity
          : memberCity // ignore: cast_nullable_to_non_nullable
              as String?,
      memberState: freezed == memberState
          ? _self.memberState
          : memberState // ignore: cast_nullable_to_non_nullable
              as String?,
      hasViewed: null == hasViewed
          ? _self.hasViewed
          : hasViewed // ignore: cast_nullable_to_non_nullable
              as bool,
      hasClickedApply: null == hasClickedApply
          ? _self.hasClickedApply
          : hasClickedApply // ignore: cast_nullable_to_non_nullable
              as bool,
      hasApplied: null == hasApplied
          ? _self.hasApplied
          : hasApplied // ignore: cast_nullable_to_non_nullable
              as bool,
      hasShared: null == hasShared
          ? _self.hasShared
          : hasShared // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCopiedText: null == hasCopiedText
          ? _self.hasCopiedText
          : hasCopiedText // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPrinted: null == hasPrinted
          ? _self.hasPrinted
          : hasPrinted // ignore: cast_nullable_to_non_nullable
              as bool,
      firstViewedAt: freezed == firstViewedAt
          ? _self.firstViewedAt
          : firstViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastViewedAt: freezed == lastViewedAt
          ? _self.lastViewedAt
          : lastViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      applyClickedAt: freezed == applyClickedAt
          ? _self.applyClickedAt
          : applyClickedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      appliedAt: freezed == appliedAt
          ? _self.appliedAt
          : appliedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sharedAt: freezed == sharedAt
          ? _self.sharedAt
          : sharedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      copiedTextAt: freezed == copiedTextAt
          ? _self.copiedTextAt
          : copiedTextAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      printedAt: freezed == printedAt
          ? _self.printedAt
          : printedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      viewCount: null == viewCount
          ? _self.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTimeSeconds: null == totalTimeSeconds
          ? _self.totalTimeSeconds
          : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxScrollDepthPercent: null == maxScrollDepthPercent
          ? _self.maxScrollDepthPercent
          : maxScrollDepthPercent // ignore: cast_nullable_to_non_nullable
              as int,
      sessionCount: null == sessionCount
          ? _self.sessionCount
          : sessionCount // ignore: cast_nullable_to_non_nullable
              as int,
      avgSessionDurationSeconds: null == avgSessionDurationSeconds
          ? _self.avgSessionDurationSeconds
          : avgSessionDurationSeconds // ignore: cast_nullable_to_non_nullable
              as double,
      totalIdleTimeSeconds: null == totalIdleTimeSeconds
          ? _self.totalIdleTimeSeconds
          : totalIdleTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      totalActiveTimeSeconds: null == totalActiveTimeSeconds
          ? _self.totalActiveTimeSeconds
          : totalActiveTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      externalApplyClicks: null == externalApplyClicks
          ? _self.externalApplyClicks
          : externalApplyClicks // ignore: cast_nullable_to_non_nullable
              as int,
      applicationId: freezed == applicationId
          ? _self.applicationId
          : applicationId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastDeviceType: freezed == lastDeviceType
          ? _self.lastDeviceType
          : lastDeviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      lastBrowser: freezed == lastBrowser
          ? _self.lastBrowser
          : lastBrowser // ignore: cast_nullable_to_non_nullable
              as String?,
      lastOs: freezed == lastOs
          ? _self.lastOs
          : lastOs // ignore: cast_nullable_to_non_nullable
              as String?,
      devicesUsed: null == devicesUsed
          ? _self.devicesUsed
          : devicesUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      browsersUsed: null == browsersUsed
          ? _self.browsersUsed
          : browsersUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastCity: freezed == lastCity
          ? _self.lastCity
          : lastCity // ignore: cast_nullable_to_non_nullable
              as String?,
      lastRegion: freezed == lastRegion
          ? _self.lastRegion
          : lastRegion // ignore: cast_nullable_to_non_nullable
              as String?,
      lastCountry: freezed == lastCountry
          ? _self.lastCountry
          : lastCountry // ignore: cast_nullable_to_non_nullable
              as String?,
      lastIpAddress: freezed == lastIpAddress
          ? _self.lastIpAddress
          : lastIpAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      lastSessionId: freezed == lastSessionId
          ? _self.lastSessionId
          : lastSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerUrl: freezed == firstReferrerUrl
          ? _self.firstReferrerUrl
          : firstReferrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerDomain: freezed == firstReferrerDomain
          ? _self.firstReferrerDomain
          : firstReferrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmSource: freezed == firstUtmSource
          ? _self.firstUtmSource
          : firstUtmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmMedium: freezed == firstUtmMedium
          ? _self.firstUtmMedium
          : firstUtmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmCampaign: freezed == firstUtmCampaign
          ? _self.firstUtmCampaign
          : firstUtmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      lastExternalApplyUrl: freezed == lastExternalApplyUrl
          ? _self.lastExternalApplyUrl
          : lastExternalApplyUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [JobMemberInteraction].
extension JobMemberInteractionPatterns on JobMemberInteraction {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_JobMemberInteraction value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobMemberInteraction() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_JobMemberInteraction value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobMemberInteraction():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_JobMemberInteraction value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobMemberInteraction() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
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
            @JsonKey(name: 'max_scroll_depth_percent')
            int maxScrollDepthPercent,
            @JsonKey(name: 'session_count') int sessionCount,
            @JsonKey(name: 'avg_session_duration_seconds')
            double avgSessionDurationSeconds,
            @JsonKey(name: 'total_idle_time_seconds') int totalIdleTimeSeconds,
            @JsonKey(name: 'total_active_time_seconds')
            int totalActiveTimeSeconds,
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
            @JsonKey(name: 'last_external_apply_url')
            String? lastExternalApplyUrl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _JobMemberInteraction() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.jobId,
            _that.memberId,
            _that.memberName,
            _that.memberEmail,
            _that.memberProfilePhotoUrl,
            _that.memberCity,
            _that.memberState,
            _that.hasViewed,
            _that.hasClickedApply,
            _that.hasApplied,
            _that.hasShared,
            _that.hasCopiedText,
            _that.hasPrinted,
            _that.firstViewedAt,
            _that.lastViewedAt,
            _that.applyClickedAt,
            _that.appliedAt,
            _that.sharedAt,
            _that.copiedTextAt,
            _that.printedAt,
            _that.viewCount,
            _that.totalTimeSeconds,
            _that.maxScrollDepthPercent,
            _that.sessionCount,
            _that.avgSessionDurationSeconds,
            _that.totalIdleTimeSeconds,
            _that.totalActiveTimeSeconds,
            _that.externalApplyClicks,
            _that.applicationId,
            _that.lastDeviceType,
            _that.lastBrowser,
            _that.lastOs,
            _that.devicesUsed,
            _that.browsersUsed,
            _that.lastCity,
            _that.lastRegion,
            _that.lastCountry,
            _that.lastIpAddress,
            _that.lastSessionId,
            _that.firstReferrerUrl,
            _that.firstReferrerDomain,
            _that.firstUtmSource,
            _that.firstUtmMedium,
            _that.firstUtmCampaign,
            _that.lastExternalApplyUrl);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
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
            @JsonKey(name: 'max_scroll_depth_percent')
            int maxScrollDepthPercent,
            @JsonKey(name: 'session_count') int sessionCount,
            @JsonKey(name: 'avg_session_duration_seconds')
            double avgSessionDurationSeconds,
            @JsonKey(name: 'total_idle_time_seconds') int totalIdleTimeSeconds,
            @JsonKey(name: 'total_active_time_seconds')
            int totalActiveTimeSeconds,
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
            @JsonKey(name: 'last_external_apply_url')
            String? lastExternalApplyUrl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobMemberInteraction():
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.jobId,
            _that.memberId,
            _that.memberName,
            _that.memberEmail,
            _that.memberProfilePhotoUrl,
            _that.memberCity,
            _that.memberState,
            _that.hasViewed,
            _that.hasClickedApply,
            _that.hasApplied,
            _that.hasShared,
            _that.hasCopiedText,
            _that.hasPrinted,
            _that.firstViewedAt,
            _that.lastViewedAt,
            _that.applyClickedAt,
            _that.appliedAt,
            _that.sharedAt,
            _that.copiedTextAt,
            _that.printedAt,
            _that.viewCount,
            _that.totalTimeSeconds,
            _that.maxScrollDepthPercent,
            _that.sessionCount,
            _that.avgSessionDurationSeconds,
            _that.totalIdleTimeSeconds,
            _that.totalActiveTimeSeconds,
            _that.externalApplyClicks,
            _that.applicationId,
            _that.lastDeviceType,
            _that.lastBrowser,
            _that.lastOs,
            _that.devicesUsed,
            _that.browsersUsed,
            _that.lastCity,
            _that.lastRegion,
            _that.lastCountry,
            _that.lastIpAddress,
            _that.lastSessionId,
            _that.firstReferrerUrl,
            _that.firstReferrerDomain,
            _that.firstUtmSource,
            _that.firstUtmMedium,
            _that.firstUtmCampaign,
            _that.lastExternalApplyUrl);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
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
            @JsonKey(name: 'max_scroll_depth_percent')
            int maxScrollDepthPercent,
            @JsonKey(name: 'session_count') int sessionCount,
            @JsonKey(name: 'avg_session_duration_seconds')
            double avgSessionDurationSeconds,
            @JsonKey(name: 'total_idle_time_seconds') int totalIdleTimeSeconds,
            @JsonKey(name: 'total_active_time_seconds')
            int totalActiveTimeSeconds,
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
            @JsonKey(name: 'last_external_apply_url')
            String? lastExternalApplyUrl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _JobMemberInteraction() when $default != null:
        return $default(
            _that.id,
            _that.createdAt,
            _that.updatedAt,
            _that.jobId,
            _that.memberId,
            _that.memberName,
            _that.memberEmail,
            _that.memberProfilePhotoUrl,
            _that.memberCity,
            _that.memberState,
            _that.hasViewed,
            _that.hasClickedApply,
            _that.hasApplied,
            _that.hasShared,
            _that.hasCopiedText,
            _that.hasPrinted,
            _that.firstViewedAt,
            _that.lastViewedAt,
            _that.applyClickedAt,
            _that.appliedAt,
            _that.sharedAt,
            _that.copiedTextAt,
            _that.printedAt,
            _that.viewCount,
            _that.totalTimeSeconds,
            _that.maxScrollDepthPercent,
            _that.sessionCount,
            _that.avgSessionDurationSeconds,
            _that.totalIdleTimeSeconds,
            _that.totalActiveTimeSeconds,
            _that.externalApplyClicks,
            _that.applicationId,
            _that.lastDeviceType,
            _that.lastBrowser,
            _that.lastOs,
            _that.devicesUsed,
            _that.browsersUsed,
            _that.lastCity,
            _that.lastRegion,
            _that.lastCountry,
            _that.lastIpAddress,
            _that.lastSessionId,
            _that.firstReferrerUrl,
            _that.firstReferrerDomain,
            _that.firstUtmSource,
            _that.firstUtmMedium,
            _that.firstUtmCampaign,
            _that.lastExternalApplyUrl);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _JobMemberInteraction extends JobMemberInteraction {
  const _JobMemberInteraction(
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
  factory _JobMemberInteraction.fromJson(Map<String, dynamic> json) =>
      _$JobMemberInteractionFromJson(json);

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

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$JobMemberInteractionCopyWith<_JobMemberInteraction> get copyWith =>
      __$JobMemberInteractionCopyWithImpl<_JobMemberInteraction>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$JobMemberInteractionToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _JobMemberInteraction &&
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

  @override
  String toString() {
    return 'JobMemberInteraction(id: $id, createdAt: $createdAt, updatedAt: $updatedAt, jobId: $jobId, memberId: $memberId, memberName: $memberName, memberEmail: $memberEmail, memberProfilePhotoUrl: $memberProfilePhotoUrl, memberCity: $memberCity, memberState: $memberState, hasViewed: $hasViewed, hasClickedApply: $hasClickedApply, hasApplied: $hasApplied, hasShared: $hasShared, hasCopiedText: $hasCopiedText, hasPrinted: $hasPrinted, firstViewedAt: $firstViewedAt, lastViewedAt: $lastViewedAt, applyClickedAt: $applyClickedAt, appliedAt: $appliedAt, sharedAt: $sharedAt, copiedTextAt: $copiedTextAt, printedAt: $printedAt, viewCount: $viewCount, totalTimeSeconds: $totalTimeSeconds, maxScrollDepthPercent: $maxScrollDepthPercent, sessionCount: $sessionCount, avgSessionDurationSeconds: $avgSessionDurationSeconds, totalIdleTimeSeconds: $totalIdleTimeSeconds, totalActiveTimeSeconds: $totalActiveTimeSeconds, externalApplyClicks: $externalApplyClicks, applicationId: $applicationId, lastDeviceType: $lastDeviceType, lastBrowser: $lastBrowser, lastOs: $lastOs, devicesUsed: $devicesUsed, browsersUsed: $browsersUsed, lastCity: $lastCity, lastRegion: $lastRegion, lastCountry: $lastCountry, lastIpAddress: $lastIpAddress, lastSessionId: $lastSessionId, firstReferrerUrl: $firstReferrerUrl, firstReferrerDomain: $firstReferrerDomain, firstUtmSource: $firstUtmSource, firstUtmMedium: $firstUtmMedium, firstUtmCampaign: $firstUtmCampaign, lastExternalApplyUrl: $lastExternalApplyUrl)';
  }
}

/// @nodoc
abstract mixin class _$JobMemberInteractionCopyWith<$Res>
    implements $JobMemberInteractionCopyWith<$Res> {
  factory _$JobMemberInteractionCopyWith(_JobMemberInteraction value,
          $Res Function(_JobMemberInteraction) _then) =
      __$JobMemberInteractionCopyWithImpl;
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
class __$JobMemberInteractionCopyWithImpl<$Res>
    implements _$JobMemberInteractionCopyWith<$Res> {
  __$JobMemberInteractionCopyWithImpl(this._self, this._then);

  final _JobMemberInteraction _self;
  final $Res Function(_JobMemberInteraction) _then;

  /// Create a copy of JobMemberInteraction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    return _then(_JobMemberInteraction(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      jobId: null == jobId
          ? _self.jobId
          : jobId // ignore: cast_nullable_to_non_nullable
              as String,
      memberId: null == memberId
          ? _self.memberId
          : memberId // ignore: cast_nullable_to_non_nullable
              as String,
      memberName: freezed == memberName
          ? _self.memberName
          : memberName // ignore: cast_nullable_to_non_nullable
              as String?,
      memberEmail: freezed == memberEmail
          ? _self.memberEmail
          : memberEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      memberProfilePhotoUrl: freezed == memberProfilePhotoUrl
          ? _self.memberProfilePhotoUrl
          : memberProfilePhotoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      memberCity: freezed == memberCity
          ? _self.memberCity
          : memberCity // ignore: cast_nullable_to_non_nullable
              as String?,
      memberState: freezed == memberState
          ? _self.memberState
          : memberState // ignore: cast_nullable_to_non_nullable
              as String?,
      hasViewed: null == hasViewed
          ? _self.hasViewed
          : hasViewed // ignore: cast_nullable_to_non_nullable
              as bool,
      hasClickedApply: null == hasClickedApply
          ? _self.hasClickedApply
          : hasClickedApply // ignore: cast_nullable_to_non_nullable
              as bool,
      hasApplied: null == hasApplied
          ? _self.hasApplied
          : hasApplied // ignore: cast_nullable_to_non_nullable
              as bool,
      hasShared: null == hasShared
          ? _self.hasShared
          : hasShared // ignore: cast_nullable_to_non_nullable
              as bool,
      hasCopiedText: null == hasCopiedText
          ? _self.hasCopiedText
          : hasCopiedText // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPrinted: null == hasPrinted
          ? _self.hasPrinted
          : hasPrinted // ignore: cast_nullable_to_non_nullable
              as bool,
      firstViewedAt: freezed == firstViewedAt
          ? _self.firstViewedAt
          : firstViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastViewedAt: freezed == lastViewedAt
          ? _self.lastViewedAt
          : lastViewedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      applyClickedAt: freezed == applyClickedAt
          ? _self.applyClickedAt
          : applyClickedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      appliedAt: freezed == appliedAt
          ? _self.appliedAt
          : appliedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sharedAt: freezed == sharedAt
          ? _self.sharedAt
          : sharedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      copiedTextAt: freezed == copiedTextAt
          ? _self.copiedTextAt
          : copiedTextAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      printedAt: freezed == printedAt
          ? _self.printedAt
          : printedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      viewCount: null == viewCount
          ? _self.viewCount
          : viewCount // ignore: cast_nullable_to_non_nullable
              as int,
      totalTimeSeconds: null == totalTimeSeconds
          ? _self.totalTimeSeconds
          : totalTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxScrollDepthPercent: null == maxScrollDepthPercent
          ? _self.maxScrollDepthPercent
          : maxScrollDepthPercent // ignore: cast_nullable_to_non_nullable
              as int,
      sessionCount: null == sessionCount
          ? _self.sessionCount
          : sessionCount // ignore: cast_nullable_to_non_nullable
              as int,
      avgSessionDurationSeconds: null == avgSessionDurationSeconds
          ? _self.avgSessionDurationSeconds
          : avgSessionDurationSeconds // ignore: cast_nullable_to_non_nullable
              as double,
      totalIdleTimeSeconds: null == totalIdleTimeSeconds
          ? _self.totalIdleTimeSeconds
          : totalIdleTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      totalActiveTimeSeconds: null == totalActiveTimeSeconds
          ? _self.totalActiveTimeSeconds
          : totalActiveTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      externalApplyClicks: null == externalApplyClicks
          ? _self.externalApplyClicks
          : externalApplyClicks // ignore: cast_nullable_to_non_nullable
              as int,
      applicationId: freezed == applicationId
          ? _self.applicationId
          : applicationId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastDeviceType: freezed == lastDeviceType
          ? _self.lastDeviceType
          : lastDeviceType // ignore: cast_nullable_to_non_nullable
              as String?,
      lastBrowser: freezed == lastBrowser
          ? _self.lastBrowser
          : lastBrowser // ignore: cast_nullable_to_non_nullable
              as String?,
      lastOs: freezed == lastOs
          ? _self.lastOs
          : lastOs // ignore: cast_nullable_to_non_nullable
              as String?,
      devicesUsed: null == devicesUsed
          ? _self._devicesUsed
          : devicesUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      browsersUsed: null == browsersUsed
          ? _self._browsersUsed
          : browsersUsed // ignore: cast_nullable_to_non_nullable
              as List<String>,
      lastCity: freezed == lastCity
          ? _self.lastCity
          : lastCity // ignore: cast_nullable_to_non_nullable
              as String?,
      lastRegion: freezed == lastRegion
          ? _self.lastRegion
          : lastRegion // ignore: cast_nullable_to_non_nullable
              as String?,
      lastCountry: freezed == lastCountry
          ? _self.lastCountry
          : lastCountry // ignore: cast_nullable_to_non_nullable
              as String?,
      lastIpAddress: freezed == lastIpAddress
          ? _self.lastIpAddress
          : lastIpAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      lastSessionId: freezed == lastSessionId
          ? _self.lastSessionId
          : lastSessionId // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerUrl: freezed == firstReferrerUrl
          ? _self.firstReferrerUrl
          : firstReferrerUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      firstReferrerDomain: freezed == firstReferrerDomain
          ? _self.firstReferrerDomain
          : firstReferrerDomain // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmSource: freezed == firstUtmSource
          ? _self.firstUtmSource
          : firstUtmSource // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmMedium: freezed == firstUtmMedium
          ? _self.firstUtmMedium
          : firstUtmMedium // ignore: cast_nullable_to_non_nullable
              as String?,
      firstUtmCampaign: freezed == firstUtmCampaign
          ? _self.firstUtmCampaign
          : firstUtmCampaign // ignore: cast_nullable_to_non_nullable
              as String?,
      lastExternalApplyUrl: freezed == lastExternalApplyUrl
          ? _self.lastExternalApplyUrl
          : lastExternalApplyUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
