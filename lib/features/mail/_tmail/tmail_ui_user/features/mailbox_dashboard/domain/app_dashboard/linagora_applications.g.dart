// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'linagora_applications.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinagoraApplications _$LinagoraApplicationsFromJson(
        Map<String, dynamic> json) =>
    LinagoraApplications(
      (json['apps'] as List<dynamic>)
          .map((e) => LinagoraApp.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LinagoraApplicationsToJson(
        LinagoraApplications instance) =>
    <String, dynamic>{
      'apps': instance.apps,
    };
