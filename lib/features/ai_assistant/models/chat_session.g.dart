// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) => _ChatSession(
  id: json['id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  userId: json['user_id'] as String,
  title: json['title'] as String?,
  isArchived: json['is_archived'] as bool? ?? false,
);

Map<String, dynamic> _$ChatSessionToJson(_ChatSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'user_id': instance.userId,
      'title': instance.title,
      'is_archived': instance.isArchived,
    };
