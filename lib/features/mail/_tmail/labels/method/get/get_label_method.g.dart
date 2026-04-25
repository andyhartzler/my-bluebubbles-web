// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_label_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetLabelMethod _$GetLabelMethodFromJson(Map<String, dynamic> json) =>
    GetLabelMethod(
      const AccountIdConverter().fromJson(json['accountId'] as String),
    )
      ..ids = (json['ids'] as List<dynamic>?)
          ?.map((e) => const IdConverter().fromJson(e as String))
          .toSet()
      ..referenceIds = json['#ids'] == null
          ? null
          : ResultReference.fromJson(json['#ids'] as Map<String, dynamic>)
      ..properties = const PropertiesConverter()
          .fromJson(json['properties'] as List<String>?)
      ..referenceProperties = json['#properties'] == null
          ? null
          : ResultReference.fromJson(
              json['#properties'] as Map<String, dynamic>);

Map<String, dynamic> _$GetLabelMethodToJson(GetLabelMethod instance) =>
    <String, dynamic>{
      'accountId': const AccountIdConverter().toJson(instance.accountId),
      if (instance.ids?.map(const IdConverter().toJson).toList()
          case final value?)
        'ids': value,
      if (instance.referenceIds?.toJson() case final value?) '#ids': value,
      if (const PropertiesConverter().toJson(instance.properties)
          case final value?)
        'properties': value,
      if (instance.referenceProperties?.toJson() case final value?)
        '#properties': value,
    };
