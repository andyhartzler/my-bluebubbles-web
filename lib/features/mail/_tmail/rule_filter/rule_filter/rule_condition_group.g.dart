// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_condition_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleConditionGroup _$RuleConditionGroupFromJson(Map<String, dynamic> json) =>
    RuleConditionGroup(
      conditionCombiner:
          $enumDecode(_$ConditionCombinerEnumMap, json['conditionCombiner']),
      conditions: (json['conditions'] as List<dynamic>)
          .map((e) => RuleCondition.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$RuleConditionGroupToJson(RuleConditionGroup instance) =>
    <String, dynamic>{
      'conditionCombiner':
          _$ConditionCombinerEnumMap[instance.conditionCombiner]!,
      'conditions': instance.conditions,
    };

const _$ConditionCombinerEnumMap = {
  ConditionCombiner.AND: 'AND',
  ConditionCombiner.OR: 'OR',
};
