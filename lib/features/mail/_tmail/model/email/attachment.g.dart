// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
      partId:
          const PartIdNullableConverter().fromJson(json['partId'] as String?),
      blobId: const IdNullableConverter().fromJson(json['blobId'] as String?),
      size: const UnsignedIntNullableConverter()
          .fromJson((json['size'] as num?)?.toInt()),
      name: json['name'] as String?,
      type:
          const MediaTypeNullableConverter().fromJson(json['type'] as String?),
      cid: json['cid'] as String?,
      disposition:
          $enumDecodeNullable(_$ContentDispositionEnumMap, json['disposition']),
      charset: json['charset'] as String?,
    );

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{
      if (const PartIdNullableConverter().toJson(instance.partId)
          case final value?)
        'partId': value,
      if (const IdNullableConverter().toJson(instance.blobId) case final value?)
        'blobId': value,
      if (const UnsignedIntNullableConverter().toJson(instance.size)
          case final value?)
        'size': value,
      if (instance.name case final value?) 'name': value,
      if (const MediaTypeNullableConverter().toJson(instance.type)
          case final value?)
        'type': value,
      if (instance.cid case final value?) 'cid': value,
      if (_$ContentDispositionEnumMap[instance.disposition] case final value?)
        'disposition': value,
      if (instance.charset case final value?) 'charset': value,
    };

const _$ContentDispositionEnumMap = {
  ContentDisposition.inline: 'inline',
  ContentDisposition.attachment: 'attachment',
  ContentDisposition.other: 'other',
};
