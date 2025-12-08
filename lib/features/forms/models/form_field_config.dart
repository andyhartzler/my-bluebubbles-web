import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_field_config.freezed.dart';
part 'form_field_config.g.dart';

@freezed
class FormFieldConfig with _$FormFieldConfig {
  const factory FormFieldConfig({
    required String id,
    required String type,
    required String label,
    String? placeholder,
    String? help,
    @Default(false) bool required,
    List<FormFieldOption>? options,
    Map<String, dynamic>? validation,
    int? rows,
  }) = _FormFieldConfig;

  factory FormFieldConfig.fromJson(Map<String, dynamic> json) =>
      _$FormFieldConfigFromJson(json);
}

@freezed
class FormFieldOption with _$FormFieldOption {
  const factory FormFieldOption({
    required String value,
    required String label,
  }) = _FormFieldOption;

  factory FormFieldOption.fromJson(Map<String, dynamic> json) =>
      _$FormFieldOptionFromJson(json);
}
