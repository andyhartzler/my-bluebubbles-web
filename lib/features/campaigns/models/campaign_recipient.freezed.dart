// coverage:ignore-file
// GENERATED CODE - MANUALLY WRITTEN UNTIL BUILD RUNNER IS AVAILABLE.
// ignore_for_file: type=lint

part of 'campaign_recipient.dart';

T _$identity<T>(T value) => value;

CampaignRecipient _$CampaignRecipientFromJson(Map<String, dynamic> json) {
  return _CampaignRecipient.fromJson(json);
}

/// @nodoc
mixin _$CampaignRecipient {
  String get id => throw UnimplementedError();
  String get campaignId => throw UnimplementedError();
  String? get recipientId => throw UnimplementedError();
  String? get name => throw UnimplementedError();
  String get address => throw UnimplementedError();
  CampaignChannel get channel => throw UnimplementedError();
  CampaignRecipientStatus get status => throw UnimplementedError();
  String? get errorMessage => throw UnimplementedError();
  DateTime? get queuedAt => throw UnimplementedError();
  DateTime? get sentAt => throw UnimplementedError();
  DateTime? get deliveredAt => throw UnimplementedError();
  DateTime? get openedAt => throw UnimplementedError();
  DateTime? get clickedAt => throw UnimplementedError();
  DateTime? get unsubscribedAt => throw UnimplementedError();
  DateTime? get createdAt => throw UnimplementedError();
  DateTime? get updatedAt => throw UnimplementedError();

  Map<String, dynamic> toJson() => throw UnimplementedError();
  @JsonKey(ignore: true)
  $CampaignRecipientCopyWith<CampaignRecipient> get copyWith =>
      throw UnimplementedError();
}

/// @nodoc
abstract class $CampaignRecipientCopyWith<$Res> {
  factory $CampaignRecipientCopyWith(
          CampaignRecipient value, $Res Function(CampaignRecipient) then) =
      _$CampaignRecipientCopyWithImpl<$Res, CampaignRecipient>;
  $Res call({
    String id,
    String campaignId,
    String? recipientId,
    String? name,
    String address,
    CampaignChannel channel,
    CampaignRecipientStatus status,
    String? errorMessage,
    DateTime? queuedAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    DateTime? unsubscribedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class _$CampaignRecipientCopyWithImpl<$Res, $Val extends CampaignRecipient>
    implements $CampaignRecipientCopyWith<$Res> {
  _$CampaignRecipientCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @override
  $Res call({
    Object? id = freezed,
    Object? campaignId = freezed,
    Object? recipientId = freezed,
    Object? name = freezed,
    Object? address = freezed,
    Object? channel = freezed,
    Object? status = freezed,
    Object? errorMessage = freezed,
    Object? queuedAt = freezed,
    Object? sentAt = freezed,
    Object? deliveredAt = freezed,
    Object? openedAt = freezed,
    Object? clickedAt = freezed,
    Object? unsubscribedAt = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: id == freezed ? _value.id : id as String,
      campaignId: campaignId == freezed ? _value.campaignId : campaignId as String,
      recipientId: recipientId == freezed ? _value.recipientId : recipientId as String?,
      name: name == freezed ? _value.name : name as String?,
      address: address == freezed ? _value.address : address as String,
      channel: channel == freezed ? _value.channel : channel as CampaignChannel,
      status: status == freezed ? _value.status : status as CampaignRecipientStatus,
      errorMessage: errorMessage == freezed ? _value.errorMessage : errorMessage as String?,
      queuedAt: queuedAt == freezed ? _value.queuedAt : queuedAt as DateTime?,
      sentAt: sentAt == freezed ? _value.sentAt : sentAt as DateTime?,
      deliveredAt: deliveredAt == freezed ? _value.deliveredAt : deliveredAt as DateTime?,
      openedAt: openedAt == freezed ? _value.openedAt : openedAt as DateTime?,
      clickedAt: clickedAt == freezed ? _value.clickedAt : clickedAt as DateTime?,
      unsubscribedAt:
          unsubscribedAt == freezed ? _value.unsubscribedAt : unsubscribedAt as DateTime?,
      createdAt: createdAt == freezed ? _value.createdAt : createdAt as DateTime?,
      updatedAt: updatedAt == freezed ? _value.updatedAt : updatedAt as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_CampaignRecipientCopyWith<$Res>
    implements $CampaignRecipientCopyWith<$Res> {
  factory _$$_CampaignRecipientCopyWith(
          _$_CampaignRecipient value, $Res Function(_$_CampaignRecipient) then) =
      __$$_CampaignRecipientCopyWithImpl<$Res>;
  @override
  $Res call({
    String id,
    String campaignId,
    String? recipientId,
    String? name,
    String address,
    CampaignChannel channel,
    CampaignRecipientStatus status,
    String? errorMessage,
    DateTime? queuedAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    DateTime? unsubscribedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
}

/// @nodoc
class __$$_CampaignRecipientCopyWithImpl<$Res>
    extends _$CampaignRecipientCopyWithImpl<$Res, _$_CampaignRecipient>
    implements _$$_CampaignRecipientCopyWith<$Res> {
  __$$_CampaignRecipientCopyWithImpl(
      _$_CampaignRecipient _value, $Res Function(_$_CampaignRecipient) _then)
      : super(_value, _then);
}

/// @nodoc
@JsonSerializable()
class _$_CampaignRecipient implements _CampaignRecipient {
  const _$_CampaignRecipient({
    required this.id,
    required this.campaignId,
    this.recipientId,
    this.name,
    required this.address,
    this.channel = CampaignChannel.sms,
    this.status = CampaignRecipientStatus.pending,
    this.errorMessage,
    this.queuedAt,
    this.sentAt,
    this.deliveredAt,
    this.openedAt,
    this.clickedAt,
    this.unsubscribedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory _$_CampaignRecipient.fromJson(Map<String, dynamic> json) =>
      _$CampaignRecipientFromJson(json);

  @override
  final String id;
  @override
  final String campaignId;
  @override
  final String? recipientId;
  @override
  final String? name;
  @override
  final String address;
  @override
  @JsonKey()
  final CampaignChannel channel;
  @override
  @JsonKey()
  final CampaignRecipientStatus status;
  @override
  final String? errorMessage;
  @override
  final DateTime? queuedAt;
  @override
  final DateTime? sentAt;
  @override
  final DateTime? deliveredAt;
  @override
  final DateTime? openedAt;
  @override
  final DateTime? clickedAt;
  @override
  final DateTime? unsubscribedAt;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'CampaignRecipient(id: $id, address: $address, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is _$_CampaignRecipient &&
            other.id == id &&
            other.campaignId == campaignId &&
            other.recipientId == recipientId &&
            other.name == name &&
            other.address == address &&
            other.channel == channel &&
            other.status == status &&
            other.errorMessage == errorMessage &&
            other.queuedAt == queuedAt &&
            other.sentAt == sentAt &&
            other.deliveredAt == deliveredAt &&
            other.openedAt == openedAt &&
            other.clickedAt == clickedAt &&
            other.unsubscribedAt == unsubscribedAt &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt);
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        campaignId,
        recipientId,
        name,
        address,
        channel,
        status,
        errorMessage,
        queuedAt,
        sentAt,
        deliveredAt,
        openedAt,
        clickedAt,
        unsubscribedAt,
        createdAt,
        updatedAt,
      );

  @JsonKey(ignore: true)
  @override
  _$$_CampaignRecipientCopyWith<_$_CampaignRecipient> get copyWith =>
      __$$_CampaignRecipientCopyWithImpl<_$_CampaignRecipient>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CampaignRecipientToJson(this);
  }
}

/// @nodoc
abstract class _CampaignRecipient implements CampaignRecipient {
  const factory _CampaignRecipient({
    required String id,
    required String campaignId,
    String? recipientId,
    String? name,
    required String address,
    CampaignChannel channel,
    CampaignRecipientStatus status,
    String? errorMessage,
    DateTime? queuedAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    DateTime? unsubscribedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _$_CampaignRecipient;

  factory _CampaignRecipient.fromJson(Map<String, dynamic> json) =
      _$_CampaignRecipient.fromJson;

  @override
  String get id;
  @override
  String get campaignId;
  @override
  String? get recipientId;
  @override
  String? get name;
  @override
  String get address;
  @override
  CampaignChannel get channel;
  @override
  CampaignRecipientStatus get status;
  @override
  String? get errorMessage;
  @override
  DateTime? get queuedAt;
  @override
  DateTime? get sentAt;
  @override
  DateTime? get deliveredAt;
  @override
  DateTime? get openedAt;
  @override
  DateTime? get clickedAt;
  @override
  DateTime? get unsubscribedAt;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$_CampaignRecipientCopyWith<_$_CampaignRecipient> get copyWith =>
      throw UnimplementedError();
}
