// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autocomplete_tmail_contact_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AutoCompleteTMailContactResponse _$AutoCompleteTMailContactResponseFromJson(
  Map<String, dynamic> json,
) => AutoCompleteTMailContactResponse(
  const AccountIdConverter().fromJson(json['accountId'] as String),
  (json['list'] as List<dynamic>)
      .map((e) => TMailContact.fromJson(e as Map<String, dynamic>))
      .toList(),
  const UnsignedIntNullableConverter().fromJson(
    (json['limit'] as num?)?.toInt(),
  ),
);

Map<String, dynamic> _$AutoCompleteTMailContactResponseToJson(
  AutoCompleteTMailContactResponse instance,
) => <String, dynamic>{
  'accountId': const AccountIdConverter().toJson(instance.accountId),
  'list': instance.list,
  'limit': const UnsignedIntNullableConverter().toJson(instance.limit),
};
