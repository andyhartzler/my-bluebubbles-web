// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'campaign_recipient.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

CampaignRecipient _$CampaignRecipientFromJson(Map<String, dynamic> json) {
  return _CampaignRecipient.fromJson(json);
}

/// @nodoc
mixin _$CampaignRecipient {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'campaign_id')
  String get campaignId => throw _privateConstructorUsedError;
  @JsonKey(name: 'recipient_id')
  String? get recipientId => throw _privateConstructorUsedError;
  String? get name => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  CampaignChannel get channel => throw _privateConstructorUsedError;
  CampaignRecipientStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'error_message')
  String? get errorMessage => throw _privateConstructorUsedError;
  @JsonKey(name: 'queued_at')
  DateTime? get queuedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'sent_at')
  DateTime? get sentAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivered_at')
  DateTime? get deliveredAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'opened_at')
  DateTime? get openedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'clicked_at')
  DateTime? get clickedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'unsubscribed_at')
  DateTime? get unsubscribedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this CampaignRecipient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CampaignRecipient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CampaignRecipientCopyWith<CampaignRecipient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CampaignRecipientCopyWith<$Res> {
  factory $CampaignRecipientCopyWith(
          CampaignRecipient value, $Res Function(CampaignRecipient) then) =
      _$CampaignRecipientCopyWithImpl<$Res, CampaignRecipient>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'campaign_id') String campaignId,
      @JsonKey(name: 'recipient_id') String? recipientId,
      String? name,
      String address,
      CampaignChannel channel,
      CampaignRecipientStatus status,
      @JsonKey(name: 'error_message') String? errorMessage,
      @JsonKey(name: 'queued_at') DateTime? queuedAt,
      @JsonKey(name: 'sent_at') DateTime? sentAt,
      @JsonKey(name: 'delivered_at') DateTime? deliveredAt,
      @JsonKey(name: 'opened_at') DateTime? openedAt,
      @JsonKey(name: 'clicked_at') DateTime? clickedAt,
      @JsonKey(name: 'unsubscribed_at') DateTime? unsubscribedAt,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class _$CampaignRecipientCopyWithImpl<$Res, $Val extends CampaignRecipient>
    implements $CampaignRecipientCopyWith<$Res> {
  _$CampaignRecipientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CampaignRecipient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? campaignId = null,
    Object? recipientId = freezed,
    Object? name = freezed,
    Object? address = null,
    Object? channel = null,
    Object? status = null,
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
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      campaignId: null == campaignId
          ? _value.campaignId
          : campaignId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: freezed == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      channel: null == channel
          ? _value.channel
          : channel // ignore: cast_nullable_to_non_nullable
              as CampaignChannel,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as CampaignRecipientStatus,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      queuedAt: freezed == queuedAt
          ? _value.queuedAt
          : queuedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sentAt: freezed == sentAt
          ? _value.sentAt
          : sentAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveredAt: freezed == deliveredAt
          ? _value.deliveredAt
          : deliveredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      openedAt: freezed == openedAt
          ? _value.openedAt
          : openedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      clickedAt: freezed == clickedAt
          ? _value.clickedAt
          : clickedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unsubscribedAt: freezed == unsubscribedAt
          ? _value.unsubscribedAt
          : unsubscribedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CampaignRecipientImplCopyWith<$Res>
    implements $CampaignRecipientCopyWith<$Res> {
  factory _$$CampaignRecipientImplCopyWith(_$CampaignRecipientImpl value,
          $Res Function(_$CampaignRecipientImpl) then) =
      __$$CampaignRecipientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'campaign_id') String campaignId,
      @JsonKey(name: 'recipient_id') String? recipientId,
      String? name,
      String address,
      CampaignChannel channel,
      CampaignRecipientStatus status,
      @JsonKey(name: 'error_message') String? errorMessage,
      @JsonKey(name: 'queued_at') DateTime? queuedAt,
      @JsonKey(name: 'sent_at') DateTime? sentAt,
      @JsonKey(name: 'delivered_at') DateTime? deliveredAt,
      @JsonKey(name: 'opened_at') DateTime? openedAt,
      @JsonKey(name: 'clicked_at') DateTime? clickedAt,
      @JsonKey(name: 'unsubscribed_at') DateTime? unsubscribedAt,
      @JsonKey(name: 'created_at') DateTime? createdAt,
      @JsonKey(name: 'updated_at') DateTime? updatedAt});
}

/// @nodoc
class __$$CampaignRecipientImplCopyWithImpl<$Res>
    extends _$CampaignRecipientCopyWithImpl<$Res, _$CampaignRecipientImpl>
    implements _$$CampaignRecipientImplCopyWith<$Res> {
  __$$CampaignRecipientImplCopyWithImpl(_$CampaignRecipientImpl _value,
      $Res Function(_$CampaignRecipientImpl) _then)
      : super(_value, _then);

  /// Create a copy of CampaignRecipient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? campaignId = null,
    Object? recipientId = freezed,
    Object? name = freezed,
    Object? address = null,
    Object? channel = null,
    Object? status = null,
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
    return _then(_$CampaignRecipientImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      campaignId: null == campaignId
          ? _value.campaignId
          : campaignId // ignore: cast_nullable_to_non_nullable
              as String,
      recipientId: freezed == recipientId
          ? _value.recipientId
          : recipientId // ignore: cast_nullable_to_non_nullable
              as String?,
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      channel: null == channel
          ? _value.channel
          : channel // ignore: cast_nullable_to_non_nullable
              as CampaignChannel,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as CampaignRecipientStatus,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      queuedAt: freezed == queuedAt
          ? _value.queuedAt
          : queuedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      sentAt: freezed == sentAt
          ? _value.sentAt
          : sentAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveredAt: freezed == deliveredAt
          ? _value.deliveredAt
          : deliveredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      openedAt: freezed == openedAt
          ? _value.openedAt
          : openedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      clickedAt: freezed == clickedAt
          ? _value.clickedAt
          : clickedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      unsubscribedAt: freezed == unsubscribedAt
          ? _value.unsubscribedAt
          : unsubscribedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CampaignRecipientImpl implements _CampaignRecipient {
  const _$CampaignRecipientImpl(
      {required this.id,
      @JsonKey(name: 'campaign_id') required this.campaignId,
      @JsonKey(name: 'recipient_id') this.recipientId,
      this.name,
      required this.address,
      this.channel = CampaignChannel.sms,
      this.status = CampaignRecipientStatus.pending,
      @JsonKey(name: 'error_message') this.errorMessage,
      @JsonKey(name: 'queued_at') this.queuedAt,
      @JsonKey(name: 'sent_at') this.sentAt,
      @JsonKey(name: 'delivered_at') this.deliveredAt,
      @JsonKey(name: 'opened_at') this.openedAt,
      @JsonKey(name: 'clicked_at') this.clickedAt,
      @JsonKey(name: 'unsubscribed_at') this.unsubscribedAt,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'updated_at') this.updatedAt});

  factory _$CampaignRecipientImpl.fromJson(Map<String, dynamic> json) =>
      _$$CampaignRecipientImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'campaign_id')
  final String campaignId;
  @override
  @JsonKey(name: 'recipient_id')
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
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @override
  @JsonKey(name: 'queued_at')
  final DateTime? queuedAt;
  @override
  @JsonKey(name: 'sent_at')
  final DateTime? sentAt;
  @override
  @JsonKey(name: 'delivered_at')
  final DateTime? deliveredAt;
  @override
  @JsonKey(name: 'opened_at')
  final DateTime? openedAt;
  @override
  @JsonKey(name: 'clicked_at')
  final DateTime? clickedAt;
  @override
  @JsonKey(name: 'unsubscribed_at')
  final DateTime? unsubscribedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'CampaignRecipient(id: $id, campaignId: $campaignId, recipientId: $recipientId, name: $name, address: $address, channel: $channel, status: $status, errorMessage: $errorMessage, queuedAt: $queuedAt, sentAt: $sentAt, deliveredAt: $deliveredAt, openedAt: $openedAt, clickedAt: $clickedAt, unsubscribedAt: $unsubscribedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CampaignRecipientImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.campaignId, campaignId) ||
                other.campaignId == campaignId) &&
            (identical(other.recipientId, recipientId) ||
                other.recipientId == recipientId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.channel, channel) || other.channel == channel) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.queuedAt, queuedAt) ||
                other.queuedAt == queuedAt) &&
            (identical(other.sentAt, sentAt) || other.sentAt == sentAt) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.openedAt, openedAt) ||
                other.openedAt == openedAt) &&
            (identical(other.clickedAt, clickedAt) ||
                other.clickedAt == clickedAt) &&
            (identical(other.unsubscribedAt, unsubscribedAt) ||
                other.unsubscribedAt == unsubscribedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
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
      updatedAt);

  /// Create a copy of CampaignRecipient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CampaignRecipientImplCopyWith<_$CampaignRecipientImpl> get copyWith =>
      __$$CampaignRecipientImplCopyWithImpl<_$CampaignRecipientImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CampaignRecipientImplToJson(
      this,
    );
  }
}

abstract class _CampaignRecipient implements CampaignRecipient {
  const factory _CampaignRecipient(
          {required final String id,
          @JsonKey(name: 'campaign_id') required final String campaignId,
          @JsonKey(name: 'recipient_id') final String? recipientId,
          final String? name,
          required final String address,
          final CampaignChannel channel,
          final CampaignRecipientStatus status,
          @JsonKey(name: 'error_message') final String? errorMessage,
          @JsonKey(name: 'queued_at') final DateTime? queuedAt,
          @JsonKey(name: 'sent_at') final DateTime? sentAt,
          @JsonKey(name: 'delivered_at') final DateTime? deliveredAt,
          @JsonKey(name: 'opened_at') final DateTime? openedAt,
          @JsonKey(name: 'clicked_at') final DateTime? clickedAt,
          @JsonKey(name: 'unsubscribed_at') final DateTime? unsubscribedAt,
          @JsonKey(name: 'created_at') final DateTime? createdAt,
          @JsonKey(name: 'updated_at') final DateTime? updatedAt}) =
      _$CampaignRecipientImpl;

  factory _CampaignRecipient.fromJson(Map<String, dynamic> json) =
      _$CampaignRecipientImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'campaign_id')
  String get campaignId;
  @override
  @JsonKey(name: 'recipient_id')
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
  @JsonKey(name: 'error_message')
  String? get errorMessage;
  @override
  @JsonKey(name: 'queued_at')
  DateTime? get queuedAt;
  @override
  @JsonKey(name: 'sent_at')
  DateTime? get sentAt;
  @override
  @JsonKey(name: 'delivered_at')
  DateTime? get deliveredAt;
  @override
  @JsonKey(name: 'opened_at')
  DateTime? get openedAt;
  @override
  @JsonKey(name: 'clicked_at')
  DateTime? get clickedAt;
  @override
  @JsonKey(name: 'unsubscribed_at')
  DateTime? get unsubscribedAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime? get updatedAt;

  /// Create a copy of CampaignRecipient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CampaignRecipientImplCopyWith<_$CampaignRecipientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
