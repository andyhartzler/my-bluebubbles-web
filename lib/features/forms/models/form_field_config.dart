import 'package:freezed_annotation/freezed_annotation.dart';

part 'form_field_config.freezed.dart';
part 'form_field_config.g.dart';

/// Comprehensive form field configuration supporting all flutter_form_builder field types
@freezed
class FormFieldConfig with _$FormFieldConfig {
  const factory FormFieldConfig({
    required String id,
    required String type,
    required String label,
    String? placeholder,
    String? help,
    @Default(false) bool required,

    // Options for select, radio, checkbox groups, chips, etc.
    List<FormFieldOption>? options,

    // Validation rules configuration
    Map<String, dynamic>? validation,
    List<String>? validatorTypes, // List of validator names to apply

    // Text field specific
    int? rows, // For textarea
    int? maxLines,
    int? minLines,
    int? maxLength,
    String? keyboardType, // text, email, phone, number, url, etc.

    // Numeric fields (slider, range_slider, touch_spin, rating)
    double? minValue,
    double? maxValue,
    double? initialValue,
    double? step, // For touch_spin and sliders
    int? divisions, // For sliders
    double? iconSize, // For rating

    // Date/Time fields
    DateTime? firstDate,
    DateTime? lastDate,
    DateTime? initialDate,
    String? dateFormat, // For formatting date display
    String? timeFormat,

    // Date range picker
    DateTime? initialStartDate,
    DateTime? initialEndDate,

    // Searchable dropdown
    @Default(false) bool isFilterOnline, // For searchable dropdown
    @Default(false) bool showClearButton,

    // Signature pad
    double? signatureHeight,
    double? signatureWidth,
    String? signatureBackgroundColor,
    String? signaturePenColor,

    // Color picker
    String? initialColor,
    String? colorPickerType, // 'material', 'block', 'multiple', etc.

    // Typeahead
    int? suggestionsLimit,
    int? debounceDuration, // milliseconds

    // Switch and checkbox
    String? activeColor,
    String? inactiveColor,

    // Cupertino specific
    @Default(false) bool useCupertinoStyle,

    // Choice/Filter chips
    String? chipShape, // 'rectangle', 'rounded', 'stadium'
    @Default(false) bool allowMultipleSelection, // For filter chips

    // File picker
    List<String>? allowedExtensions, // e.g., ['pdf', 'doc', 'docx']
    @Default(false) bool allowMultipleFiles,
    int? maxFileSizeMB,
    String? fileTypeFilter, // 'any', 'image', 'video', 'audio', 'custom'

    // Image picker
    int? maxImages,
    double? imageQuality, // 0.0 to 1.0
    int? maxImageWidth,
    int? maxImageHeight,
    @Default(false) bool allowCamera,
    @Default(false) bool allowGallery,

    // Conditional logic
    String? conditionalFieldId, // ID of field to watch
    String? conditionalOperator, // 'equals', 'notEquals', 'contains', 'greaterThan', 'lessThan'
    dynamic conditionalValue, // Value to compare against
    @Default(true) bool showWhenConditionMet, // Show field when condition is true or false

    // Form page (for multi-page forms)
    int? pageNumber, // Which page this field belongs to (0-indexed)

    // General settings
    @Default(true) bool enabled,
    dynamic defaultValue,
    String? prefixText,
    String? suffixText,
    String? hintText,
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
