// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleCondition _$RuleConditionFromJson(Map<String, dynamic> json) =>
    RuleCondition(
      field: $enumDecode(_$FieldEnumMap, json['field']),
      comparator: $enumDecode(_$ComparatorEnumMap, json['comparator']),
      value: json['value'] as String,
    );

Map<String, dynamic> _$RuleConditionToJson(RuleCondition instance) =>
    <String, dynamic>{
      'field': _$FieldEnumMap[instance.field]!,
      'comparator': _$ComparatorEnumMap[instance.comparator]!,
      'value': instance.value,
    };

const _$FieldEnumMap = {
  Field.from: 'from',
  Field.to: 'to',
  Field.cc: 'cc',
  Field.recipient: 'recipient',
  Field.subject: 'subject',
};

const _$ComparatorEnumMap = {
  Comparator.contains: 'contains',
  Comparator.notContains: 'not-contains',
  Comparator.exactlyEquals: 'exactly-equals',
  Comparator.notExactlyEquals: 'not-exactly-equals',
};
