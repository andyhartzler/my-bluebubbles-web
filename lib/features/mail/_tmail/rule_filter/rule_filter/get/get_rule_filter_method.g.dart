// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_rule_filter_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetRuleFilterMethod _$GetRuleFilterMethodFromJson(Map<String, dynamic> json) =>
    GetRuleFilterMethod(
        const AccountIdConverter().fromJson(json['accountId'] as String),
      )
      ..ids = (json['ids'] as List<dynamic>?)
          ?.map((e) => const IdConverter().fromJson(e as String))
          .toSet()
      ..referenceIds = json['#ids'] == null
          ? null
          : ResultReference.fromJson(json['#ids'] as Map<String, dynamic>)
      ..properties = const PropertiesConverter().fromJson(
        json['properties'] as List<String>?,
      )
      ..referenceProperties = json['#properties'] == null
          ? null
          : ResultReference.fromJson(
              json['#properties'] as Map<String, dynamic>,
            );

Map<String, dynamic> _$GetRuleFilterMethodToJson(
  GetRuleFilterMethod instance,
) => <String, dynamic>{
  'accountId': const AccountIdConverter().toJson(instance.accountId),
  'ids': ?instance.ids?.map(const IdConverter().toJson).toList(),
  '#ids': ?instance.referenceIds?.toJson(),
  'properties': ?const PropertiesConverter().toJson(instance.properties),
  '#properties': ?instance.referenceProperties?.toJson(),
};
