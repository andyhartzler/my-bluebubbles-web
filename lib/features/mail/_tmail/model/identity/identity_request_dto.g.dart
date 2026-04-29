// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentityRequestDto _$IdentityRequestDtoFromJson(Map<String, dynamic> json) =>
    IdentityRequestDto(
      name: json['name'] as String?,
      bcc: (json['bcc'] as List<dynamic>?)
          ?.map((e) => EmailAddress.fromJson(e as Map<String, dynamic>))
          .toSet(),
      replyTo: (json['replyTo'] as List<dynamic>?)
          ?.map((e) => EmailAddress.fromJson(e as Map<String, dynamic>))
          .toSet(),
      textSignature: const SignatureNullableConverter().fromJson(
        json['textSignature'] as String?,
      ),
      htmlSignature: const SignatureNullableConverter().fromJson(
        json['htmlSignature'] as String?,
      ),
      sortOrder: const UnsignedIntNullableConverter().fromJson(
        (json['sortOrder'] as num?)?.toInt(),
      ),
    );

Map<String, dynamic> _$IdentityRequestDtoToJson(
  IdentityRequestDto instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'bcc': ?instance.bcc?.map((e) => e.toJson()).toList(),
  'replyTo': ?instance.replyTo?.map((e) => e.toJson()).toList(),
  'textSignature': ?const SignatureNullableConverter().toJson(
    instance.textSignature,
  ),
  'htmlSignature': ?const SignatureNullableConverter().toJson(
    instance.htmlSignature,
  ),
  'sortOrder': ?const UnsignedIntNullableConverter().toJson(instance.sortOrder),
};
