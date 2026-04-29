// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
  partId: const PartIdNullableConverter().fromJson(json['partId'] as String?),
  blobId: const IdNullableConverter().fromJson(json['blobId'] as String?),
  size: const UnsignedIntNullableConverter().fromJson(
    (json['size'] as num?)?.toInt(),
  ),
  name: json['name'] as String?,
  type: const MediaTypeNullableConverter().fromJson(json['type'] as String?),
  cid: json['cid'] as String?,
  disposition: $enumDecodeNullable(
    _$ContentDispositionEnumMap,
    json['disposition'],
  ),
  charset: json['charset'] as String?,
);

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{
      'partId': ?const PartIdNullableConverter().toJson(instance.partId),
      'blobId': ?const IdNullableConverter().toJson(instance.blobId),
      'size': ?const UnsignedIntNullableConverter().toJson(instance.size),
      'name': ?instance.name,
      'type': ?const MediaTypeNullableConverter().toJson(instance.type),
      'cid': ?instance.cid,
      'disposition': ?_$ContentDispositionEnumMap[instance.disposition],
      'charset': ?instance.charset,
    };

const _$ContentDispositionEnumMap = {
  ContentDisposition.inline: 'inline',
  ContentDisposition.attachment: 'attachment',
  ContentDisposition.other: 'other',
};
