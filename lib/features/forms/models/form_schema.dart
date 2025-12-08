import 'package:freezed_annotation/freezed_annotation.dart';
import 'form_field_config.dart';

part 'form_schema.freezed.dart';
part 'form_schema.g.dart';

@freezed
class FormSchema with _$FormSchema {
  const factory FormSchema({
    required String id,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'created_by') String? createdBy,
    required String title,
    String? description,
    @JsonKey(name: 'form_type') required String formType,
    required FormSchemaData schema,
    @Default('draft') String status,
  }) = _FormSchema;

  factory FormSchema.fromJson(Map<String, dynamic> json) =>
      _$FormSchemaFromJson(json);
}

@freezed
class FormSchemaData with _$FormSchemaData {
  const factory FormSchemaData({
    required List<FormFieldConfig> fields,
    @Default({}) Map<String, dynamic> styling,
    @Default({}) Map<String, dynamic> confirmation,
  }) = _FormSchemaData;

  factory FormSchemaData.fromJson(Map<String, dynamic> json) =>
      _$FormSchemaDataFromJson(json);
}
