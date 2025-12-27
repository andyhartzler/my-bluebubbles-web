// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SourceDocumentImpl _$$SourceDocumentImplFromJson(Map<String, dynamic> json) =>
    _$SourceDocumentImpl(
      id: json['id'] as String,
      sourceType: json['source_type'] as String,
      sourceTable: json['source_table'] as String?,
      title: json['title'] as String?,
      similarity: (json['similarity'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$SourceDocumentImplToJson(
        _$SourceDocumentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source_type': instance.sourceType,
      'source_table': instance.sourceTable,
      'title': instance.title,
      'similarity': instance.similarity,
    };
