// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'campaign_analytics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CampaignAnalytics _$CampaignAnalyticsFromJson(Map<String, dynamic> json) {
  return _CampaignAnalytics.fromJson(json);
}

/// @nodoc
mixin _$CampaignAnalytics {
  @JsonKey(name: 'campaign_id')
  String get campaignId => throw _privateConstructorUsedError;
  int get totalRecipients => throw _privateConstructorUsedError;
  int get pendingCount => throw _privateConstructorUsedError;
  int get queuedCount => throw _privateConstructorUsedError;
  int get processingCount => throw _privateConstructorUsedError;
  int get sentCount => throw _privateConstructorUsedError;
  int get deliveredCount => throw _privateConstructorUsedError;
  int get failedCount => throw _privateConstructorUsedError;
  int get bouncedCount => throw _privateConstructorUsedError;
  int get openedCount => throw _privateConstructorUsedError;
  int get clickedCount => throw _privateConstructorUsedError;
  int get unsubscribedCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'refreshed_at')
  DateTime? get refreshedAt => throw _privateConstructorUsedError;

  /// Serializes this CampaignAnalytics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CampaignAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CampaignAnalyticsCopyWith<CampaignAnalytics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CampaignAnalyticsCopyWith<$Res> {
  factory $CampaignAnalyticsCopyWith(
          CampaignAnalytics value, $Res Function(CampaignAnalytics) then) =
      _$CampaignAnalyticsCopyWithImpl<$Res, CampaignAnalytics>;
  @useResult
  $Res call(
      {@JsonKey(name: 'campaign_id') String campaignId,
      int totalRecipients,
      int pendingCount,
      int queuedCount,
      int processingCount,
      int sentCount,
      int deliveredCount,
      int failedCount,
      int bouncedCount,
      int openedCount,
      int clickedCount,
      int unsubscribedCount,
      @JsonKey(name: 'refreshed_at') DateTime? refreshedAt});
}

/// @nodoc
class _$CampaignAnalyticsCopyWithImpl<$Res, $Val extends CampaignAnalytics>
    implements $CampaignAnalyticsCopyWith<$Res> {
  _$CampaignAnalyticsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CampaignAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? campaignId = null,
    Object? totalRecipients = null,
    Object? pendingCount = null,
    Object? queuedCount = null,
    Object? processingCount = null,
    Object? sentCount = null,
    Object? deliveredCount = null,
    Object? failedCount = null,
    Object? bouncedCount = null,
    Object? openedCount = null,
    Object? clickedCount = null,
    Object? unsubscribedCount = null,
    Object? refreshedAt = freezed,
  }) {
    return _then(_value.copyWith(
      campaignId: null == campaignId
          ? _value.campaignId
          : campaignId // ignore: cast_nullable_to_non_nullable
              as String,
      totalRecipients: null == totalRecipients
          ? _value.totalRecipients
          : totalRecipients // ignore: cast_nullable_to_non_nullable
              as int,
      pendingCount: null == pendingCount
          ? _value.pendingCount
          : pendingCount // ignore: cast_nullable_to_non_nullable
              as int,
      queuedCount: null == queuedCount
          ? _value.queuedCount
          : queuedCount // ignore: cast_nullable_to_non_nullable
              as int,
      processingCount: null == processingCount
          ? _value.processingCount
          : processingCount // ignore: cast_nullable_to_non_nullable
              as int,
      sentCount: null == sentCount
          ? _value.sentCount
          : sentCount // ignore: cast_nullable_to_non_nullable
              as int,
      deliveredCount: null == deliveredCount
          ? _value.deliveredCount
          : deliveredCount // ignore: cast_nullable_to_non_nullable
              as int,
      failedCount: null == failedCount
          ? _value.failedCount
          : failedCount // ignore: cast_nullable_to_non_nullable
              as int,
      bouncedCount: null == bouncedCount
          ? _value.bouncedCount
          : bouncedCount // ignore: cast_nullable_to_non_nullable
              as int,
      openedCount: null == openedCount
          ? _value.openedCount
          : openedCount // ignore: cast_nullable_to_non_nullable
              as int,
      clickedCount: null == clickedCount
          ? _value.clickedCount
          : clickedCount // ignore: cast_nullable_to_non_nullable
              as int,
      unsubscribedCount: null == unsubscribedCount
          ? _value.unsubscribedCount
          : unsubscribedCount // ignore: cast_nullable_to_non_nullable
              as int,
      refreshedAt: freezed == refreshedAt
          ? _value.refreshedAt
          : refreshedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CampaignAnalyticsImplCopyWith<$Res>
    implements $CampaignAnalyticsCopyWith<$Res> {
  factory _$$CampaignAnalyticsImplCopyWith(_$CampaignAnalyticsImpl value,
          $Res Function(_$CampaignAnalyticsImpl) then) =
      __$$CampaignAnalyticsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'campaign_id') String campaignId,
      int totalRecipients,
      int pendingCount,
      int queuedCount,
      int processingCount,
      int sentCount,
      int deliveredCount,
      int failedCount,
      int bouncedCount,
      int openedCount,
      int clickedCount,
      int unsubscribedCount,
      @JsonKey(name: 'refreshed_at') DateTime? refreshedAt});
}

/// @nodoc
class __$$CampaignAnalyticsImplCopyWithImpl<$Res>
    extends _$CampaignAnalyticsCopyWithImpl<$Res, _$CampaignAnalyticsImpl>
    implements _$$CampaignAnalyticsImplCopyWith<$Res> {
  __$$CampaignAnalyticsImplCopyWithImpl(_$CampaignAnalyticsImpl _value,
      $Res Function(_$CampaignAnalyticsImpl) _then)
      : super(_value, _then);

  /// Create a copy of CampaignAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? campaignId = null,
    Object? totalRecipients = null,
    Object? pendingCount = null,
    Object? queuedCount = null,
    Object? processingCount = null,
    Object? sentCount = null,
    Object? deliveredCount = null,
    Object? failedCount = null,
    Object? bouncedCount = null,
    Object? openedCount = null,
    Object? clickedCount = null,
    Object? unsubscribedCount = null,
    Object? refreshedAt = freezed,
  }) {
    return _then(_$CampaignAnalyticsImpl(
      campaignId: null == campaignId
          ? _value.campaignId
          : campaignId // ignore: cast_nullable_to_non_nullable
              as String,
      totalRecipients: null == totalRecipients
          ? _value.totalRecipients
          : totalRecipients // ignore: cast_nullable_to_non_nullable
              as int,
      pendingCount: null == pendingCount
          ? _value.pendingCount
          : pendingCount // ignore: cast_nullable_to_non_nullable
              as int,
      queuedCount: null == queuedCount
          ? _value.queuedCount
          : queuedCount // ignore: cast_nullable_to_non_nullable
              as int,
      processingCount: null == processingCount
          ? _value.processingCount
          : processingCount // ignore: cast_nullable_to_non_nullable
              as int,
      sentCount: null == sentCount
          ? _value.sentCount
          : sentCount // ignore: cast_nullable_to_non_nullable
              as int,
      deliveredCount: null == deliveredCount
          ? _value.deliveredCount
          : deliveredCount // ignore: cast_nullable_to_non_nullable
              as int,
      failedCount: null == failedCount
          ? _value.failedCount
          : failedCount // ignore: cast_nullable_to_non_nullable
              as int,
      bouncedCount: null == bouncedCount
          ? _value.bouncedCount
          : bouncedCount // ignore: cast_nullable_to_non_nullable
              as int,
      openedCount: null == openedCount
          ? _value.openedCount
          : openedCount // ignore: cast_nullable_to_non_nullable
              as int,
      clickedCount: null == clickedCount
          ? _value.clickedCount
          : clickedCount // ignore: cast_nullable_to_non_nullable
              as int,
      unsubscribedCount: null == unsubscribedCount
          ? _value.unsubscribedCount
          : unsubscribedCount // ignore: cast_nullable_to_non_nullable
              as int,
      refreshedAt: freezed == refreshedAt
          ? _value.refreshedAt
          : refreshedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CampaignAnalyticsImpl implements _CampaignAnalytics {
  const _$CampaignAnalyticsImpl(
      {@JsonKey(name: 'campaign_id') required this.campaignId,
      this.totalRecipients = 0,
      this.pendingCount = 0,
      this.queuedCount = 0,
      this.processingCount = 0,
      this.sentCount = 0,
      this.deliveredCount = 0,
      this.failedCount = 0,
      this.bouncedCount = 0,
      this.openedCount = 0,
      this.clickedCount = 0,
      this.unsubscribedCount = 0,
      @JsonKey(name: 'refreshed_at') this.refreshedAt});

  factory _$CampaignAnalyticsImpl.fromJson(Map<String, dynamic> json) =>
      _$$CampaignAnalyticsImplFromJson(json);

  @override
  @JsonKey(name: 'campaign_id')
  final String campaignId;
  @override
  @JsonKey()
  final int totalRecipients;
  @override
  @JsonKey()
  final int pendingCount;
  @override
  @JsonKey()
  final int queuedCount;
  @override
  @JsonKey()
  final int processingCount;
  @override
  @JsonKey()
  final int sentCount;
  @override
  @JsonKey()
  final int deliveredCount;
  @override
  @JsonKey()
  final int failedCount;
  @override
  @JsonKey()
  final int bouncedCount;
  @override
  @JsonKey()
  final int openedCount;
  @override
  @JsonKey()
  final int clickedCount;
  @override
  @JsonKey()
  final int unsubscribedCount;
  @override
  @JsonKey(name: 'refreshed_at')
  final DateTime? refreshedAt;

  @override
  String toString() {
    return 'CampaignAnalytics(campaignId: $campaignId, totalRecipients: $totalRecipients, pendingCount: $pendingCount, queuedCount: $queuedCount, processingCount: $processingCount, sentCount: $sentCount, deliveredCount: $deliveredCount, failedCount: $failedCount, bouncedCount: $bouncedCount, openedCount: $openedCount, clickedCount: $clickedCount, unsubscribedCount: $unsubscribedCount, refreshedAt: $refreshedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CampaignAnalyticsImpl &&
            (identical(other.campaignId, campaignId) ||
                other.campaignId == campaignId) &&
            (identical(other.totalRecipients, totalRecipients) ||
                other.totalRecipients == totalRecipients) &&
            (identical(other.pendingCount, pendingCount) ||
                other.pendingCount == pendingCount) &&
            (identical(other.queuedCount, queuedCount) ||
                other.queuedCount == queuedCount) &&
            (identical(other.processingCount, processingCount) ||
                other.processingCount == processingCount) &&
            (identical(other.sentCount, sentCount) ||
                other.sentCount == sentCount) &&
            (identical(other.deliveredCount, deliveredCount) ||
                other.deliveredCount == deliveredCount) &&
            (identical(other.failedCount, failedCount) ||
                other.failedCount == failedCount) &&
            (identical(other.bouncedCount, bouncedCount) ||
                other.bouncedCount == bouncedCount) &&
            (identical(other.openedCount, openedCount) ||
                other.openedCount == openedCount) &&
            (identical(other.clickedCount, clickedCount) ||
                other.clickedCount == clickedCount) &&
            (identical(other.unsubscribedCount, unsubscribedCount) ||
                other.unsubscribedCount == unsubscribedCount) &&
            (identical(other.refreshedAt, refreshedAt) ||
                other.refreshedAt == refreshedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      campaignId,
      totalRecipients,
      pendingCount,
      queuedCount,
      processingCount,
      sentCount,
      deliveredCount,
      failedCount,
      bouncedCount,
      openedCount,
      clickedCount,
      unsubscribedCount,
      refreshedAt);

  /// Create a copy of CampaignAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CampaignAnalyticsImplCopyWith<_$CampaignAnalyticsImpl> get copyWith =>
      __$$CampaignAnalyticsImplCopyWithImpl<_$CampaignAnalyticsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CampaignAnalyticsImplToJson(
      this,
    );
  }
}

abstract class _CampaignAnalytics implements CampaignAnalytics {
  const factory _CampaignAnalytics(
          {@JsonKey(name: 'campaign_id') required final String campaignId,
          final int totalRecipients,
          final int pendingCount,
          final int queuedCount,
          final int processingCount,
          final int sentCount,
          final int deliveredCount,
          final int failedCount,
          final int bouncedCount,
          final int openedCount,
          final int clickedCount,
          final int unsubscribedCount,
          @JsonKey(name: 'refreshed_at') final DateTime? refreshedAt}) =
      _$CampaignAnalyticsImpl;

  factory _CampaignAnalytics.fromJson(Map<String, dynamic> json) =
      _$CampaignAnalyticsImpl.fromJson;

  @override
  @JsonKey(name: 'campaign_id')
  String get campaignId;
  @override
  int get totalRecipients;
  @override
  int get pendingCount;
  @override
  int get queuedCount;
  @override
  int get processingCount;
  @override
  int get sentCount;
  @override
  int get deliveredCount;
  @override
  int get failedCount;
  @override
  int get bouncedCount;
  @override
  int get openedCount;
  @override
  int get clickedCount;
  @override
  int get unsubscribedCount;
  @override
  @JsonKey(name: 'refreshed_at')
  DateTime? get refreshedAt;

  /// Create a copy of CampaignAnalytics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CampaignAnalyticsImplCopyWith<_$CampaignAnalyticsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
