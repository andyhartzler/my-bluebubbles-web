// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tmail_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TMailRule _$TMailRuleFromJson(Map<String, dynamic> json) => TMailRule(
      id: const RuleIdNullableConverter().fromJson(json['id'] as String?),
      name: json['name'] as String,
      condition: json['condition'] == null
          ? null
          : RuleCondition.fromJson(json['condition'] as Map<String, dynamic>),
      conditionGroup: json['conditionGroup'] == null
          ? null
          : RuleConditionGroup.fromJson(
              json['conditionGroup'] as Map<String, dynamic>),
      action: RuleAction.fromJson(json['action'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TMailRuleToJson(TMailRule instance) => <String, dynamic>{
      'id': const RuleIdNullableConverter().toJson(instance.id),
      'name': instance.name,
      if (instance.condition?.toJson() case final value?) 'condition': value,
      if (instance.conditionGroup?.toJson() case final value?)
        'conditionGroup': value,
      'action': instance.action.toJson(),
    };
