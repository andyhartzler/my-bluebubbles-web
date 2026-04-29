// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SourceDocument _$SourceDocumentFromJson(Map<String, dynamic> json) =>
    _SourceDocument(
      id: json['id'] as String,
      sourceType: json['source_type'] as String,
      sourceTable: json['source_table'] as String?,
      title: json['title'] as String?,
      similarity: (json['similarity'] as num?)?.toDouble(),
      retrievalMethod: json['retrieval_method'] as String?,
    );

Map<String, dynamic> _$SourceDocumentToJson(_SourceDocument instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source_type': instance.sourceType,
      'source_table': instance.sourceTable,
      'title': instance.title,
      'similarity': instance.similarity,
      'retrieval_method': instance.retrievalMethod,
    };
