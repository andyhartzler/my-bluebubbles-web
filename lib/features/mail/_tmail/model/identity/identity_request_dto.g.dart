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
      textSignature: const SignatureNullableConverter()
          .fromJson(json['textSignature'] as String?),
      htmlSignature: const SignatureNullableConverter()
          .fromJson(json['htmlSignature'] as String?),
      sortOrder: const UnsignedIntNullableConverter()
          .fromJson((json['sortOrder'] as num?)?.toInt()),
    );

Map<String, dynamic> _$IdentityRequestDtoToJson(IdentityRequestDto instance) =>
    <String, dynamic>{
      if (instance.name case final value?) 'name': value,
      if (instance.bcc?.map((e) => e.toJson()).toList() case final value?)
        'bcc': value,
      if (instance.replyTo?.map((e) => e.toJson()).toList() case final value?)
        'replyTo': value,
      if (const SignatureNullableConverter().toJson(instance.textSignature)
          case final value?)
        'textSignature': value,
      if (const SignatureNullableConverter().toJson(instance.htmlSignature)
          case final value?)
        'htmlSignature': value,
      if (const UnsignedIntNullableConverter().toJson(instance.sortOrder)
          case final value?)
        'sortOrder': value,
    };
