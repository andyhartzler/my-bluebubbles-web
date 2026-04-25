// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rule_append_in.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RuleAppendIn _$RuleAppendInFromJson(Map<String, dynamic> json) => RuleAppendIn(
      mailboxIds: (json['mailboxIds'] as List<dynamic>)
          .map((e) => const MailboxIdConverter().fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$RuleAppendInToJson(RuleAppendIn instance) =>
    <String, dynamic>{
      'mailboxIds':
          instance.mailboxIds.map(const MailboxIdConverter().toJson).toList(),
    };
