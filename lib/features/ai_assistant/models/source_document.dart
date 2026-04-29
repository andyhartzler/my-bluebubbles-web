import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_document.freezed.dart';
part 'source_document.g.dart';

@freezed
abstract class SourceDocument with _$SourceDocument {
  const factory SourceDocument({
    required String id,
    @JsonKey(name: 'source_type') required String sourceType,
    @JsonKey(name: 'source_table') String? sourceTable,
    String? title,
    double? similarity,
    @JsonKey(name: 'retrieval_method') String? retrievalMethod,
  }) = _SourceDocument;

  factory SourceDocument.fromJson(Map<String, dynamic> json) =>
      _$SourceDocumentFromJson(json);
}
