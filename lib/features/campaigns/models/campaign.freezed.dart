// coverage:ignore-file
// GENERATED CODE - MANUALLY WRITTEN UNTIL BUILD RUNNER IS AVAILABLE.
// ignore_for_file: type=lint

part of 'campaign.dart';

T _$identity<T>(T value) => value;

Campaign _$CampaignFromJson(Map<String, dynamic> json) {
  return _Campaign.fromJson(json);
}

/// @nodoc
mixin _$Campaign {
  String get id => throw UnimplementedError();
  String get name => throw UnimplementedError();
  String? get description => throw UnimplementedError();
  String? get subject => throw UnimplementedError();
  String? get segmentId => throw UnimplementedError();
  String? get templateId => throw UnimplementedError();
  String? get creatorId => throw UnimplementedError();
  CampaignStatus get status => throw UnimplementedError();
  DateTime? get scheduledFor => throw UnimplementedError();
  DateTime? get createdAt => throw UnimplementedError();
  DateTime? get updatedAt => throw UnimplementedError();
  CampaignAnalytics? get analytics => throw UnimplementedError();

  Map<String, dynamic> toJson() => throw UnimplementedError();
  @JsonKey(ignore: true)
  $CampaignCopyWith<Campaign> get copyWith => throw UnimplementedError();
}

/// @nodoc
abstract class $CampaignCopyWith<$Res> {
  factory $CampaignCopyWith(Campaign value, $Res Function(Campaign) then) =
      _$CampaignCopyWithImpl<$Res, Campaign>;
  $Res call({
    String id,
    String name,
    String? description,
    String? subject,
    String? segmentId,
    String? templateId,
    String? creatorId,
    CampaignStatus status,
    DateTime? scheduledFor,
    DateTime? createdAt,
    DateTime? updatedAt,
    CampaignAnalytics? analytics,
  });

  $CampaignAnalyticsCopyWith<$Res>? get analytics;
}

/// @nodoc
class _$CampaignCopyWithImpl<$Res, $Val extends Campaign>
    implements $CampaignCopyWith<$Res> {
  _$CampaignCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @override
  $Res call({
    Object? id = freezed,
    Object? name = freezed,
    Object? description = freezed,
    Object? subject = freezed,
    Object? segmentId = freezed,
    Object? templateId = freezed,
    Object? creatorId = freezed,
    Object? status = freezed,
    Object? scheduledFor = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? analytics = freezed,
  }) {
    return _then(_value.copyWith(
      id: id == freezed ? _value.id : id as String,
      name: name == freezed ? _value.name : name as String,
      description: description == freezed
          ? _value.description
          : description as String?,
      subject: subject == freezed ? _value.subject : subject as String?,
      segmentId: segmentId == freezed ? _value.segmentId : segmentId as String?,
      templateId: templateId == freezed ? _value.templateId : templateId as String?,
      creatorId: creatorId == freezed ? _value.creatorId : creatorId as String?,
      status: status == freezed ? _value.status : status as CampaignStatus,
      scheduledFor:
          scheduledFor == freezed ? _value.scheduledFor : scheduledFor as DateTime?,
      createdAt: createdAt == freezed ? _value.createdAt : createdAt as DateTime?,
      updatedAt: updatedAt == freezed ? _value.updatedAt : updatedAt as DateTime?,
      analytics: analytics == freezed ? _value.analytics : analytics as CampaignAnalytics?,
    ) as $Val);
  }

  @override
  $CampaignAnalyticsCopyWith<$Res>? get analytics {
    if (_value.analytics == null) {
      return null;
    }

    return $CampaignAnalyticsCopyWith<$Res>(_value.analytics!, (value) {
      return _then(_value.copyWith(analytics: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_CampaignCopyWith<$Res> implements $CampaignCopyWith<$Res> {
  factory _$$_CampaignCopyWith(_$_Campaign value, $Res Function(_$_Campaign) then) =
      __$$_CampaignCopyWithImpl<$Res>;
  @override
  $Res call({
    String id,
    String name,
    String? description,
    String? subject,
    String? segmentId,
    String? templateId,
    String? creatorId,
    CampaignStatus status,
    DateTime? scheduledFor,
    DateTime? createdAt,
    DateTime? updatedAt,
    CampaignAnalytics? analytics,
  });

  @override
  $CampaignAnalyticsCopyWith<$Res>? get analytics;
}

/// @nodoc
class __$$_CampaignCopyWithImpl<$Res>
    extends _$CampaignCopyWithImpl<$Res, _$_Campaign>
    implements _$$_CampaignCopyWith<$Res> {
  __$$_CampaignCopyWithImpl(_$_Campaign _value, $Res Function(_$_Campaign) _then)
      : super(_value, _then);
}

/// @nodoc
@JsonSerializable()
class _$_Campaign implements _Campaign {
  const _$_Campaign({
    required this.id,
    required this.name,
    this.description,
    this.subject,
    this.segmentId,
    this.templateId,
    this.creatorId,
    this.status = CampaignStatus.draft,
    this.scheduledFor,
    this.createdAt,
    this.updatedAt,
    this.analytics,
  });

  factory _$_Campaign.fromJson(Map<String, dynamic> json) => _$CampaignFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String? subject;
  @override
  final String? segmentId;
  @override
  final String? templateId;
  @override
  final String? creatorId;
  @override
  @JsonKey()
  final CampaignStatus status;
  @override
  final DateTime? scheduledFor;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final CampaignAnalytics? analytics;

  @override
  String toString() {
    return 'Campaign(id: $id, name: $name, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _$_Campaign &&
            other.id == id &&
            other.name == name &&
            other.description == description &&
            other.subject == subject &&
            other.segmentId == segmentId &&
            other.templateId == templateId &&
            other.creatorId == creatorId &&
            other.status == status &&
            other.scheduledFor == scheduledFor &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.analytics == analytics);
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        description,
        subject,
        segmentId,
        templateId,
        creatorId,
        status,
        scheduledFor,
        createdAt,
        updatedAt,
        analytics,
      );

  @JsonKey(ignore: true)
  @override
  _$$_CampaignCopyWith<_$_Campaign> get copyWith =>
      __$$_CampaignCopyWithImpl<_$_Campaign>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CampaignToJson(this);
  }
}

/// @nodoc
abstract class _Campaign implements Campaign {
  const factory _Campaign({
    required String id,
    required String name,
    String? description,
    String? subject,
    String? segmentId,
    String? templateId,
    String? creatorId,
    CampaignStatus status,
    DateTime? scheduledFor,
    DateTime? createdAt,
    DateTime? updatedAt,
    CampaignAnalytics? analytics,
  }) = _$_Campaign;

  factory _Campaign.fromJson(Map<String, dynamic> json) = _$_Campaign.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String? get subject;
  @override
  String? get segmentId;
  @override
  String? get templateId;
  @override
  String? get creatorId;
  @override
  CampaignStatus get status;
  @override
  DateTime? get scheduledFor;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  CampaignAnalytics? get analytics;
  @override
  @JsonKey(ignore: true)
  _$$_CampaignCopyWith<_$_Campaign> get copyWith => throw UnimplementedError();
}
