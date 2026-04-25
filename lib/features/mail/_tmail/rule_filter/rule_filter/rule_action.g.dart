// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleAction _$RuleActionFromJson(Map<String, dynamic> json) => RuleAction(
      appendIn: RuleAppendIn.fromJson(json['appendIn'] as Map<String, dynamic>),
      markAsSeen: json['markAsSeen'] as bool?,
      markAsImportant: json['markAsImportant'] as bool?,
      reject: json['reject'] as bool?,
      withKeywords: (json['withKeywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$RuleActionToJson(RuleAction instance) =>
    <String, dynamic>{
      'appendIn': instance.appendIn.toJson(),
      if (instance.markAsSeen case final value?) 'markAsSeen': value,
      if (instance.markAsImportant case final value?) 'markAsImportant': value,
      if (instance.reject case final value?) 'reject': value,
      if (instance.withKeywords case final value?) 'withKeywords': value,
    };
