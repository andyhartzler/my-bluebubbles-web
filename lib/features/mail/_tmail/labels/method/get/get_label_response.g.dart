// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_label_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetLabelResponse _$GetLabelResponseFromJson(Map<String, dynamic> json) =>
    GetLabelResponse(
      const AccountIdConverter().fromJson(json['accountId'] as String),
      const StateConverter().fromJson(json['state'] as String),
      (json['list'] as List<dynamic>)
          .map((e) => Label.fromJson(e as Map<String, dynamic>))
          .toList(),
      (json['notFound'] as List<dynamic>?)
          ?.map((e) => const IdConverter().fromJson(e as String))
          .toList(),
    );
