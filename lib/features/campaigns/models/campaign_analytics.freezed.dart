// coverage:ignore-file
// GENERATED CODE - MANUALLY WRITTEN UNTIL BUILD RUNNER IS AVAILABLE.
// ignore_for_file: type=lint

part of 'campaign_analytics.dart';

T _$identity<T>(T value) => value;

CampaignAnalytics _$CampaignAnalyticsFromJson(Map<String, dynamic> json) {
  return _CampaignAnalytics.fromJson(json);
}

/// @nodoc
mixin _$CampaignAnalytics {
  String get campaignId => throw UnimplementedError();
  int get totalRecipients => throw UnimplementedError();
  int get pendingCount => throw UnimplementedError();
  int get queuedCount => throw UnimplementedError();
  int get processingCount => throw UnimplementedError();
  int get sentCount => throw UnimplementedError();
  int get deliveredCount => throw UnimplementedError();
  int get failedCount => throw UnimplementedError();
  int get bouncedCount => throw UnimplementedError();
  int get openedCount => throw UnimplementedError();
  int get clickedCount => throw UnimplementedError();
  int get unsubscribedCount => throw UnimplementedError();
  DateTime? get refreshedAt => throw UnimplementedError();

  Map<String, dynamic> toJson() => throw UnimplementedError();
  @JsonKey(ignore: true)
  $CampaignAnalyticsCopyWith<CampaignAnalytics> get copyWith =>
      throw UnimplementedError();
}

/// @nodoc
abstract class $CampaignAnalyticsCopyWith<$Res> {
  factory $CampaignAnalyticsCopyWith(
          CampaignAnalytics value, $Res Function(CampaignAnalytics) then) =
      _$CampaignAnalyticsCopyWithImpl<$Res, CampaignAnalytics>;
  $Res call({
    String campaignId,
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
    DateTime? refreshedAt,
  });
}

/// @nodoc
class _$CampaignAnalyticsCopyWithImpl<$Res, $Val extends CampaignAnalytics>
    implements $CampaignAnalyticsCopyWith<$Res> {
  _$CampaignAnalyticsCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @override
  $Res call({
    Object? campaignId = freezed,
    Object? totalRecipients = freezed,
    Object? pendingCount = freezed,
    Object? queuedCount = freezed,
    Object? processingCount = freezed,
    Object? sentCount = freezed,
    Object? deliveredCount = freezed,
    Object? failedCount = freezed,
    Object? bouncedCount = freezed,
    Object? openedCount = freezed,
    Object? clickedCount = freezed,
    Object? unsubscribedCount = freezed,
    Object? refreshedAt = freezed,
  }) {
    return _then(_value.copyWith(
      campaignId:
          campaignId == freezed ? _value.campaignId : campaignId as String,
      totalRecipients: totalRecipients == freezed
          ? _value.totalRecipients
          : totalRecipients as int,
      pendingCount:
          pendingCount == freezed ? _value.pendingCount : pendingCount as int,
      queuedCount:
          queuedCount == freezed ? _value.queuedCount : queuedCount as int,
      processingCount: processingCount == freezed
          ? _value.processingCount
          : processingCount as int,
      sentCount: sentCount == freezed ? _value.sentCount : sentCount as int,
      deliveredCount: deliveredCount == freezed
          ? _value.deliveredCount
          : deliveredCount as int,
      failedCount:
          failedCount == freezed ? _value.failedCount : failedCount as int,
      bouncedCount: bouncedCount == freezed
          ? _value.bouncedCount
          : bouncedCount as int,
      openedCount:
          openedCount == freezed ? _value.openedCount : openedCount as int,
      clickedCount: clickedCount == freezed
          ? _value.clickedCount
          : clickedCount as int,
      unsubscribedCount: unsubscribedCount == freezed
          ? _value.unsubscribedCount
          : unsubscribedCount as int,
      refreshedAt:
          refreshedAt == freezed ? _value.refreshedAt : refreshedAt as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_CampaignAnalyticsCopyWith<$Res>
    implements $CampaignAnalyticsCopyWith<$Res> {
  factory _$$_CampaignAnalyticsCopyWith(
          _$_CampaignAnalytics value, $Res Function(_$_CampaignAnalytics) then) =
      __$$_CampaignAnalyticsCopyWithImpl<$Res>;
  @override
  $Res call({
    String campaignId,
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
    DateTime? refreshedAt,
  });
}

/// @nodoc
class __$$_CampaignAnalyticsCopyWithImpl<$Res>
    extends _$CampaignAnalyticsCopyWithImpl<$Res, _$_CampaignAnalytics>
    implements _$$_CampaignAnalyticsCopyWith<$Res> {
  __$$_CampaignAnalyticsCopyWithImpl(
      _$_CampaignAnalytics _value, $Res Function(_$_CampaignAnalytics) _then)
      : super(_value, _then);
}

/// @nodoc
@JsonSerializable()
class _$_CampaignAnalytics implements _CampaignAnalytics {
  const _$_CampaignAnalytics({
    required this.campaignId,
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
    this.refreshedAt,
  });

  factory _$_CampaignAnalytics.fromJson(Map<String, dynamic> json) =>
      _$CampaignAnalyticsFromJson(json);

  @override
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
  final DateTime? refreshedAt;

  @override
  String toString() {
    return 'CampaignAnalytics(campaignId: $campaignId, totalRecipients: $totalRecipients)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _$_CampaignAnalytics &&
            other.campaignId == campaignId &&
            other.totalRecipients == totalRecipients &&
            other.pendingCount == pendingCount &&
            other.queuedCount == queuedCount &&
            other.processingCount == processingCount &&
            other.sentCount == sentCount &&
            other.deliveredCount == deliveredCount &&
            other.failedCount == failedCount &&
            other.bouncedCount == bouncedCount &&
            other.openedCount == openedCount &&
            other.clickedCount == clickedCount &&
            other.unsubscribedCount == unsubscribedCount &&
            other.refreshedAt == refreshedAt);
  }

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
        refreshedAt,
      );

  @JsonKey(ignore: true)
  @override
  _$$_CampaignAnalyticsCopyWith<_$_CampaignAnalytics> get copyWith =>
      __$$_CampaignAnalyticsCopyWithImpl<_$_CampaignAnalytics>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CampaignAnalyticsToJson(this);
  }
}

/// @nodoc
abstract class _CampaignAnalytics implements CampaignAnalytics {
  const factory _CampaignAnalytics({
    required String campaignId,
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
    DateTime? refreshedAt,
  }) = _$_CampaignAnalytics;

  factory _CampaignAnalytics.fromJson(Map<String, dynamic> json) =
      _$_CampaignAnalytics.fromJson;

  @override
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
  DateTime? get refreshedAt;
  @override
  @JsonKey(ignore: true)
  _$$_CampaignAnalyticsCopyWith<_$_CampaignAnalytics> get copyWith =>
      throw UnimplementedError();
}
