// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_filter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleFilter _$RuleFilterFromJson(Map<String, dynamic> json) => RuleFilter(
  id: const RuleFilterIdConverter().fromJson(json['id'] as String),
  rules: (json['rules'] as List<dynamic>)
      .map((e) => TMailRule.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RuleFilterToJson(RuleFilter instance) =>
    <String, dynamic>{
      'id': const RuleFilterIdConverter().toJson(instance.id),
      'rules': instance.rules,
    };
