// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'upload_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UploadResponse _$UploadResponseFromJson(Map<String, dynamic> json) =>
    UploadResponse(
      const AccountIdConverter().fromJson(json['accountId'] as String),
      const IdConverter().fromJson(json['blobId'] as String),
      const MediaTypeConverter().fromJson(json['type'] as String),
      (json['size'] as num).toInt(),
    );

Map<String, dynamic> _$UploadResponseToJson(UploadResponse instance) =>
    <String, dynamic>{
      'accountId': const AccountIdConverter().toJson(instance.accountId),
      'blobId': const IdConverter().toJson(instance.blobId),
      'type': const MediaTypeConverter().toJson(instance.type),
      'size': instance.size,
    };
