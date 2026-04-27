/// Helper to safely coerce values to bool (handles Supabase returning int for bool)
bool _coerceBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return defaultValue;
}

/// Comprehensive form field configuration supporting all flutter_form_builder field types
class FormFieldConfig {
  final String id;
  final String type;
  final String label;
  final String? placeholder;
  final String? help;
  final bool required;

  // Options for select, radio, checkbox groups, chips, etc.
  final List<FormFieldOption>? options;

  // Validation rules configuration
  final Map<String, dynamic>? validation;
  final List<String>? validatorTypes; // List of validator names to apply

  // Text field specific
  final int? rows; // For textarea
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final String? keyboardType; // text, email, phone, number, url, etc.

  // Numeric fields (slider, range_slider, touch_spin, rating)
  final double? minValue;
  final double? maxValue;
  final double? initialValue;
  final double? step; // For touch_spin and sliders
  final int? divisions; // For sliders
  final double? iconSize; // For rating

  // Date/Time fields
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? initialDate;
  final String? dateFormat; // For formatting date display
  final String? timeFormat;

  // Date range picker
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  // Searchable dropdown
  final bool isFilterOnline; // For searchable dropdown
  final bool showClearButton;

  // Signature pad
  final double? signatureHeight;
  final double? signatureWidth;
  final String? signatureBackgroundColor;
  final String? signaturePenColor;

  // Color picker
  final String? initialColor;
  final String? colorPickerType; // 'material', 'block', 'multiple', etc.

  // Typeahead
  final int? suggestionsLimit;
  final int? debounceDuration; // milliseconds

  // Switch and checkbox
  final String? activeColor;
  final String? inactiveColor;

  // Cupertino specific
  final bool useCupertinoStyle;

  // Choice/Filter chips
  final String? chipShape; // 'rectangle', 'rounded', 'stadium'
  final bool allowMultipleSelection; // For filter chips

  // File picker
  final List<String>? allowedExtensions; // e.g., ['pdf', 'doc', 'docx']
  final bool allowMultipleFiles;
  final int? maxFileSizeMB;
  final String? fileTypeFilter; // 'any', 'image', 'video', 'audio', 'custom'

  // File upload configuration (for file_upload question type)
  final Map<String, dynamic>? fileConfig;

  // Image picker
  final int? maxImages;
  final double? imageQuality; // 0.0 to 1.0
  final int? maxImageWidth;
  final int? maxImageHeight;
  final bool allowCamera;
  final bool allowGallery;

  // Conditional logic - simple condition
  final String? conditionalFieldId; // ID of field to watch
  final String? conditionalOperator; // 'equals', 'notEquals', 'contains', 'greaterThan', 'lessThan'
  final dynamic conditionalValue; // Value to compare against
  final bool showWhenConditionMet; // Show field when condition is true or false

  // Conditional logic - complex AND conditions
  // List of conditions that ALL must be met (AND logic)
  // Each condition is {field: String, value: dynamic, operator: String?}
  final List<Map<String, dynamic>>? conditions;

  // Form page (for multi-page forms)
  final int? pageNumber; // Which page this field belongs to (0-indexed)

  // General settings
  final bool enabled;
  final dynamic defaultValue;
  final String? prefixText;
  final String? suffixText;
  final String? hintText;

  // Smart-form: prefilled-confirm metadata. Only meaningful when
  // `type == 'prefilled_confirm'`. See migration
  // 20260507_01_prefill_endorsement_for_candidate.sql for the contract
  // and form_field_types.dart for the allowed prefillSource values.
  // `prefillSource` names the key the moydforms renderer looks up in
  // the bag returned by `prefill_endorsement_for_candidate(<uuid>)`.
  // `fallbackQuestionType` is the editable widget the renderer mounts
  // when the candidate picks Edit (e.g. 'short_answer', 'number').
  // `prefillFormat` is an optional display hint ('currency'|'text'|'csv'|'date').
  final String? prefillSource;
  final String? prefillFormat;
  final String? fallbackQuestionType;

  const FormFieldConfig({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.help,
    this.required = false,
    this.options,
    this.validation,
    this.validatorTypes,
    this.rows,
    this.maxLines,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.minValue,
    this.maxValue,
    this.initialValue,
    this.step,
    this.divisions,
    this.iconSize,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.dateFormat,
    this.timeFormat,
    this.initialStartDate,
    this.initialEndDate,
    this.isFilterOnline = false,
    this.showClearButton = false,
    this.signatureHeight,
    this.signatureWidth,
    this.signatureBackgroundColor,
    this.signaturePenColor,
    this.initialColor,
    this.colorPickerType,
    this.suggestionsLimit,
    this.debounceDuration,
    this.activeColor,
    this.inactiveColor,
    this.useCupertinoStyle = false,
    this.chipShape,
    this.allowMultipleSelection = false,
    this.allowedExtensions,
    this.allowMultipleFiles = false,
    this.maxFileSizeMB,
    this.fileTypeFilter,
    this.maxImages,
    this.imageQuality,
    this.maxImageWidth,
    this.maxImageHeight,
    this.allowCamera = false,
    this.allowGallery = false,
    this.fileConfig,
    this.conditionalFieldId,
    this.conditionalOperator,
    this.conditionalValue,
    this.showWhenConditionMet = true,
    this.conditions,
    this.pageNumber,
    this.enabled = true,
    this.defaultValue,
    this.prefixText,
    this.suffixText,
    this.hintText,
    this.prefillSource,
    this.prefillFormat,
    this.fallbackQuestionType,
  });

  factory FormFieldConfig.fromJson(Map<String, dynamic> json) {
    // Parse options list
    List<FormFieldOption>? options;
    final optionsData = json['options'];
    if (optionsData is List) {
      options = optionsData
          .whereType<Map<String, dynamic>>()
          .map((e) => FormFieldOption.fromJson(e))
          .toList();
    }

    // Parse validator types list
    List<String>? validatorTypes;
    final validatorData = json['validatorTypes'] ?? json['validator_types'];
    if (validatorData is List) {
      validatorTypes = validatorData.map((e) => e.toString()).toList();
    }

    // Parse allowed extensions list
    List<String>? allowedExtensions;
    final extensionsData = json['allowedExtensions'] ?? json['allowed_extensions'];
    if (extensionsData is List) {
      allowedExtensions = extensionsData.map((e) => e.toString()).toList();
    }

    // Parse file_config for file_upload type
    Map<String, dynamic>? fileConfig;
    final fileConfigData = json['file_config'] ?? json['fileConfig'];
    if (fileConfigData is Map<String, dynamic>) {
      fileConfig = fileConfigData;
      // Extract allowed extensions from file_config.accept if present
      if (allowedExtensions == null && fileConfig['accept'] is List) {
        allowedExtensions = (fileConfig['accept'] as List).map((e) => e.toString()).toList();
      }
      // Extract max file size from file_config if present
    }

    // Parse conditions - handle both simple {field, value} and complex {and: [...]}
    String? conditionalFieldId;
    String? conditionalOperator;
    dynamic conditionalValue;
    List<Map<String, dynamic>>? conditions;

    final conditionData = json['condition'];
    if (conditionData is Map<String, dynamic>) {
      // Check for complex AND condition
      if (conditionData['and'] is List) {
        // Complex AND conditions: {and: [{field, value}, {field, value}]}
        final andConditions = conditionData['and'] as List;
        conditions = andConditions
            .whereType<Map<String, dynamic>>()
            .map((c) => {
                  'field': c['field'],
                  'value': c['value'],
                  'operator': c['operator'] ?? 'equals',
                })
            .toList();
        // For backwards compatibility, also set the first condition as the simple condition
        if (conditions.isNotEmpty) {
          conditionalFieldId = conditions.first['field'] as String?;
          conditionalValue = conditions.first['value'];
          conditionalOperator = conditions.first['operator'] as String? ?? 'equals';
        }
      } else if (conditionData['field'] != null) {
        // Simple condition: {field, value}
        conditionalFieldId = conditionData['field'] as String?;
        conditionalValue = conditionData['value'];
        conditionalOperator = conditionData['operator'] as String? ?? 'equals';
      }
    }

    // Also check for direct conditional* properties (new format)
    conditionalFieldId ??= json['conditionalFieldId'] as String? ?? json['conditional_field_id'] as String?;
    conditionalOperator ??= json['conditionalOperator'] as String? ?? json['conditional_operator'] as String?;
    conditionalValue ??= json['conditionalValue'] ?? json['conditional_value'];

    return FormFieldConfig(
      id: json['id'] as String,
      type: (json['type'] ?? json['question_type']) as String,
      label: (json['label'] ?? json['text']) as String,
      placeholder: json['placeholder'] as String?,
      help: (json['help'] ?? json['helper_text'] ?? json['description']) as String?,
      required: _coerceBool(json['required']),
      options: options,
      validation: json['validation'] as Map<String, dynamic>?,
      validatorTypes: validatorTypes,
      rows: (json['rows'] as num?)?.toInt(),
      maxLines: (json['maxLines'] as num?)?.toInt() ?? (json['max_lines'] as num?)?.toInt(),
      minLines: (json['minLines'] as num?)?.toInt() ?? (json['min_lines'] as num?)?.toInt(),
      maxLength: (json['maxLength'] as num?)?.toInt() ?? (json['max_length'] as num?)?.toInt(),
      keyboardType: json['keyboardType'] as String? ?? json['keyboard_type'] as String?,
      minValue: (json['minValue'] as num?)?.toDouble() ?? (json['min_value'] as num?)?.toDouble(),
      maxValue: (json['maxValue'] as num?)?.toDouble() ?? (json['max_value'] as num?)?.toDouble(),
      initialValue: (json['initialValue'] as num?)?.toDouble() ?? (json['initial_value'] as num?)?.toDouble(),
      step: (json['step'] as num?)?.toDouble(),
      divisions: (json['divisions'] as num?)?.toInt(),
      iconSize: (json['iconSize'] as num?)?.toDouble() ?? (json['icon_size'] as num?)?.toDouble(),
      firstDate: json['firstDate'] != null ? DateTime.tryParse(json['firstDate'] as String) :
                 json['first_date'] != null ? DateTime.tryParse(json['first_date'] as String) : null,
      lastDate: json['lastDate'] != null ? DateTime.tryParse(json['lastDate'] as String) :
                json['last_date'] != null ? DateTime.tryParse(json['last_date'] as String) : null,
      initialDate: json['initialDate'] != null ? DateTime.tryParse(json['initialDate'] as String) :
                   json['initial_date'] != null ? DateTime.tryParse(json['initial_date'] as String) : null,
      dateFormat: json['dateFormat'] as String? ?? json['date_format'] as String?,
      timeFormat: json['timeFormat'] as String? ?? json['time_format'] as String?,
      initialStartDate: json['initialStartDate'] != null ? DateTime.tryParse(json['initialStartDate'] as String) :
                        json['initial_start_date'] != null ? DateTime.tryParse(json['initial_start_date'] as String) : null,
      initialEndDate: json['initialEndDate'] != null ? DateTime.tryParse(json['initialEndDate'] as String) :
                      json['initial_end_date'] != null ? DateTime.tryParse(json['initial_end_date'] as String) : null,
      isFilterOnline: _coerceBool(json['isFilterOnline'] ?? json['is_filter_online']),
      showClearButton: _coerceBool(json['showClearButton'] ?? json['show_clear_button']),
      signatureHeight: (json['signatureHeight'] as num?)?.toDouble() ?? (json['signature_height'] as num?)?.toDouble(),
      signatureWidth: (json['signatureWidth'] as num?)?.toDouble() ?? (json['signature_width'] as num?)?.toDouble(),
      signatureBackgroundColor: json['signatureBackgroundColor'] as String? ?? json['signature_background_color'] as String?,
      signaturePenColor: json['signaturePenColor'] as String? ?? json['signature_pen_color'] as String?,
      initialColor: json['initialColor'] as String? ?? json['initial_color'] as String?,
      colorPickerType: json['colorPickerType'] as String? ?? json['color_picker_type'] as String?,
      suggestionsLimit: (json['suggestionsLimit'] as num?)?.toInt() ?? (json['suggestions_limit'] as num?)?.toInt(),
      debounceDuration: (json['debounceDuration'] as num?)?.toInt() ?? (json['debounce_duration'] as num?)?.toInt(),
      activeColor: json['activeColor'] as String? ?? json['active_color'] as String?,
      inactiveColor: json['inactiveColor'] as String? ?? json['inactive_color'] as String?,
      useCupertinoStyle: _coerceBool(json['useCupertinoStyle'] ?? json['use_cupertino_style']),
      chipShape: json['chipShape'] as String? ?? json['chip_shape'] as String?,
      allowMultipleSelection: _coerceBool(json['allowMultipleSelection'] ?? json['allow_multiple_selection']),
      allowedExtensions: allowedExtensions,
      allowMultipleFiles: _coerceBool(json['allowMultipleFiles'] ?? json['allow_multiple_files']),
      maxFileSizeMB: (json['maxFileSizeMB'] as num?)?.toInt() ?? (json['max_file_size_mb'] as num?)?.toInt(),
      fileTypeFilter: json['fileTypeFilter'] as String? ?? json['file_type_filter'] as String?,
      maxImages: (json['maxImages'] as num?)?.toInt() ?? (json['max_images'] as num?)?.toInt(),
      imageQuality: (json['imageQuality'] as num?)?.toDouble() ?? (json['image_quality'] as num?)?.toDouble(),
      maxImageWidth: (json['maxImageWidth'] as num?)?.toInt() ?? (json['max_image_width'] as num?)?.toInt(),
      maxImageHeight: (json['maxImageHeight'] as num?)?.toInt() ?? (json['max_image_height'] as num?)?.toInt(),
      allowCamera: _coerceBool(json['allowCamera'] ?? json['allow_camera']),
      allowGallery: _coerceBool(json['allowGallery'] ?? json['allow_gallery']),
      conditionalFieldId: conditionalFieldId,
      conditionalOperator: conditionalOperator,
      conditionalValue: conditionalValue,
      conditions: conditions,
      fileConfig: fileConfig,
      showWhenConditionMet: _coerceBool(json['showWhenConditionMet'] ?? json['show_when_condition_met'], defaultValue: true),
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? (json['page_number'] as num?)?.toInt() ?? (json['page'] as num?)?.toInt(),
      enabled: _coerceBool(json['enabled'], defaultValue: true),
      defaultValue: json['defaultValue'] ?? json['default_value'],
      prefixText: json['prefixText'] as String? ?? json['prefix_text'] as String?,
      suffixText: json['suffixText'] as String? ?? json['suffix_text'] as String?,
      hintText: json['hintText'] as String? ?? json['hint_text'] as String?,
      prefillSource: json['prefill_source'] as String? ?? json['prefillSource'] as String?,
      prefillFormat: json['prefill_format'] as String? ?? json['prefillFormat'] as String?,
      fallbackQuestionType: json['fallback_question_type'] as String? ?? json['fallbackQuestionType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label': label,
    if (placeholder != null) 'placeholder': placeholder,
    if (help != null) 'help': help,
    'required': required,
    if (options != null) 'options': options!.map((o) => o.toJson()).toList(),
    if (validation != null) 'validation': validation,
    if (validatorTypes != null) 'validatorTypes': validatorTypes,
    if (rows != null) 'rows': rows,
    if (maxLines != null) 'maxLines': maxLines,
    if (minLines != null) 'minLines': minLines,
    if (maxLength != null) 'maxLength': maxLength,
    if (keyboardType != null) 'keyboardType': keyboardType,
    if (minValue != null) 'minValue': minValue,
    if (maxValue != null) 'maxValue': maxValue,
    if (initialValue != null) 'initialValue': initialValue,
    if (step != null) 'step': step,
    if (divisions != null) 'divisions': divisions,
    if (iconSize != null) 'iconSize': iconSize,
    if (firstDate != null) 'firstDate': firstDate!.toIso8601String(),
    if (lastDate != null) 'lastDate': lastDate!.toIso8601String(),
    if (initialDate != null) 'initialDate': initialDate!.toIso8601String(),
    if (dateFormat != null) 'dateFormat': dateFormat,
    if (timeFormat != null) 'timeFormat': timeFormat,
    if (initialStartDate != null) 'initialStartDate': initialStartDate!.toIso8601String(),
    if (initialEndDate != null) 'initialEndDate': initialEndDate!.toIso8601String(),
    'isFilterOnline': isFilterOnline,
    'showClearButton': showClearButton,
    if (signatureHeight != null) 'signatureHeight': signatureHeight,
    if (signatureWidth != null) 'signatureWidth': signatureWidth,
    if (signatureBackgroundColor != null) 'signatureBackgroundColor': signatureBackgroundColor,
    if (signaturePenColor != null) 'signaturePenColor': signaturePenColor,
    if (initialColor != null) 'initialColor': initialColor,
    if (colorPickerType != null) 'colorPickerType': colorPickerType,
    if (suggestionsLimit != null) 'suggestionsLimit': suggestionsLimit,
    if (debounceDuration != null) 'debounceDuration': debounceDuration,
    if (activeColor != null) 'activeColor': activeColor,
    if (inactiveColor != null) 'inactiveColor': inactiveColor,
    'useCupertinoStyle': useCupertinoStyle,
    if (chipShape != null) 'chipShape': chipShape,
    'allowMultipleSelection': allowMultipleSelection,
    if (allowedExtensions != null) 'allowedExtensions': allowedExtensions,
    'allowMultipleFiles': allowMultipleFiles,
    if (maxFileSizeMB != null) 'maxFileSizeMB': maxFileSizeMB,
    if (fileTypeFilter != null) 'fileTypeFilter': fileTypeFilter,
    if (maxImages != null) 'maxImages': maxImages,
    if (imageQuality != null) 'imageQuality': imageQuality,
    if (maxImageWidth != null) 'maxImageWidth': maxImageWidth,
    if (maxImageHeight != null) 'maxImageHeight': maxImageHeight,
    'allowCamera': allowCamera,
    'allowGallery': allowGallery,
    if (conditionalFieldId != null) 'conditionalFieldId': conditionalFieldId,
    if (conditionalOperator != null) 'conditionalOperator': conditionalOperator,
    if (conditionalValue != null) 'conditionalValue': conditionalValue,
    if (conditions != null) 'conditions': conditions,
    if (fileConfig != null) 'fileConfig': fileConfig,
    'showWhenConditionMet': showWhenConditionMet,
    if (pageNumber != null) 'pageNumber': pageNumber,
    'enabled': enabled,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (prefixText != null) 'prefixText': prefixText,
    if (suffixText != null) 'suffixText': suffixText,
    if (hintText != null) 'hintText': hintText,
    // Smart-form fields — emit snake_case so the moydforms renderer (which
    // reads the questions[] schema) sees the same keys it expects from
    // the migration's seed updates.
    if (prefillSource != null) 'prefill_source': prefillSource,
    if (prefillFormat != null) 'prefill_format': prefillFormat,
    if (fallbackQuestionType != null) 'fallback_question_type': fallbackQuestionType,
  };

  FormFieldConfig copyWith({
    String? id,
    String? type,
    String? label,
    String? placeholder,
    String? help,
    bool? required,
    List<FormFieldOption>? options,
    Map<String, dynamic>? validation,
    List<String>? validatorTypes,
    int? rows,
    int? maxLines,
    int? minLines,
    int? maxLength,
    String? keyboardType,
    double? minValue,
    double? maxValue,
    double? initialValue,
    double? step,
    int? divisions,
    double? iconSize,
    DateTime? firstDate,
    DateTime? lastDate,
    DateTime? initialDate,
    String? dateFormat,
    String? timeFormat,
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    bool? isFilterOnline,
    bool? showClearButton,
    double? signatureHeight,
    double? signatureWidth,
    String? signatureBackgroundColor,
    String? signaturePenColor,
    String? initialColor,
    String? colorPickerType,
    int? suggestionsLimit,
    int? debounceDuration,
    String? activeColor,
    String? inactiveColor,
    bool? useCupertinoStyle,
    String? chipShape,
    bool? allowMultipleSelection,
    List<String>? allowedExtensions,
    bool? allowMultipleFiles,
    int? maxFileSizeMB,
    String? fileTypeFilter,
    int? maxImages,
    double? imageQuality,
    int? maxImageWidth,
    int? maxImageHeight,
    bool? allowCamera,
    bool? allowGallery,
    String? conditionalFieldId,
    String? conditionalOperator,
    dynamic conditionalValue,
    List<Map<String, dynamic>>? conditions,
    Map<String, dynamic>? fileConfig,
    bool? showWhenConditionMet,
    int? pageNumber,
    bool? enabled,
    dynamic defaultValue,
    String? prefixText,
    String? suffixText,
    String? hintText,
    String? prefillSource,
    String? prefillFormat,
    String? fallbackQuestionType,
  }) {
    return FormFieldConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      help: help ?? this.help,
      required: required ?? this.required,
      options: options ?? this.options,
      validation: validation ?? this.validation,
      validatorTypes: validatorTypes ?? this.validatorTypes,
      rows: rows ?? this.rows,
      maxLines: maxLines ?? this.maxLines,
      minLines: minLines ?? this.minLines,
      maxLength: maxLength ?? this.maxLength,
      keyboardType: keyboardType ?? this.keyboardType,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      initialValue: initialValue ?? this.initialValue,
      step: step ?? this.step,
      divisions: divisions ?? this.divisions,
      iconSize: iconSize ?? this.iconSize,
      firstDate: firstDate ?? this.firstDate,
      lastDate: lastDate ?? this.lastDate,
      initialDate: initialDate ?? this.initialDate,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      initialStartDate: initialStartDate ?? this.initialStartDate,
      initialEndDate: initialEndDate ?? this.initialEndDate,
      isFilterOnline: isFilterOnline ?? this.isFilterOnline,
      showClearButton: showClearButton ?? this.showClearButton,
      signatureHeight: signatureHeight ?? this.signatureHeight,
      signatureWidth: signatureWidth ?? this.signatureWidth,
      signatureBackgroundColor: signatureBackgroundColor ?? this.signatureBackgroundColor,
      signaturePenColor: signaturePenColor ?? this.signaturePenColor,
      initialColor: initialColor ?? this.initialColor,
      colorPickerType: colorPickerType ?? this.colorPickerType,
      suggestionsLimit: suggestionsLimit ?? this.suggestionsLimit,
      debounceDuration: debounceDuration ?? this.debounceDuration,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      useCupertinoStyle: useCupertinoStyle ?? this.useCupertinoStyle,
      chipShape: chipShape ?? this.chipShape,
      allowMultipleSelection: allowMultipleSelection ?? this.allowMultipleSelection,
      allowedExtensions: allowedExtensions ?? this.allowedExtensions,
      allowMultipleFiles: allowMultipleFiles ?? this.allowMultipleFiles,
      maxFileSizeMB: maxFileSizeMB ?? this.maxFileSizeMB,
      fileTypeFilter: fileTypeFilter ?? this.fileTypeFilter,
      maxImages: maxImages ?? this.maxImages,
      imageQuality: imageQuality ?? this.imageQuality,
      maxImageWidth: maxImageWidth ?? this.maxImageWidth,
      maxImageHeight: maxImageHeight ?? this.maxImageHeight,
      allowCamera: allowCamera ?? this.allowCamera,
      allowGallery: allowGallery ?? this.allowGallery,
      conditionalFieldId: conditionalFieldId ?? this.conditionalFieldId,
      conditionalOperator: conditionalOperator ?? this.conditionalOperator,
      conditionalValue: conditionalValue ?? this.conditionalValue,
      conditions: conditions ?? this.conditions,
      fileConfig: fileConfig ?? this.fileConfig,
      showWhenConditionMet: showWhenConditionMet ?? this.showWhenConditionMet,
      pageNumber: pageNumber ?? this.pageNumber,
      enabled: enabled ?? this.enabled,
      defaultValue: defaultValue ?? this.defaultValue,
      prefixText: prefixText ?? this.prefixText,
      suffixText: suffixText ?? this.suffixText,
      hintText: hintText ?? this.hintText,
      prefillSource: prefillSource ?? this.prefillSource,
      prefillFormat: prefillFormat ?? this.prefillFormat,
      fallbackQuestionType: fallbackQuestionType ?? this.fallbackQuestionType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormFieldConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class FormFieldOption {
  final String value;
  final String label;

  const FormFieldOption({
    required this.value,
    required this.label,
  });

  factory FormFieldOption.fromJson(Map<String, dynamic> json) {
    return FormFieldOption(
      value: (json['value'] ?? json['id'] ?? '').toString(),
      label: (json['label'] ?? json['text'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'label': label,
  };

  FormFieldOption copyWith({
    String? value,
    String? label,
  }) {
    return FormFieldOption(
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormFieldOption && other.value == value && other.label == label;
  }

  @override
  int get hashCode => Object.hash(value, label);
}
