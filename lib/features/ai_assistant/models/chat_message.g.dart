// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMessageImpl _$$ChatMessageImplFromJson(Map<String, dynamic> json) =>
    _$ChatMessageImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      sessionId: json['session_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      sourceDocuments: (json['source_documents'] as List<dynamic>?)
              ?.map((e) => SourceDocument.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      tokensUsed: json['tokens_used'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$ChatMessageImplToJson(_$ChatMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'session_id': instance.sessionId,
      'role': instance.role,
      'content': instance.content,
      'source_documents':
          instance.sourceDocuments.map((e) => e.toJson()).toList(),
      'tokens_used': instance.tokensUsed,
    };
