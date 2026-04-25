// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AIMessage _$AIMessageFromJson(Map<String, dynamic> json) => AIMessage(
      role: $enumDecode(_$AIRoleEnumMap, json['role']),
      content: json['content'] as String,
    );

Map<String, dynamic> _$AIMessageToJson(AIMessage instance) => <String, dynamic>{
      'role': _$AIRoleEnumMap[instance.role]!,
      'content': instance.content,
    };

const _$AIRoleEnumMap = {
  AIRole.user: 'user',
  AIRole.system: 'system',
};
