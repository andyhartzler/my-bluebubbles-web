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

  // Image picker
  final int? maxImages;
  final double? imageQuality; // 0.0 to 1.0
  final int? maxImageWidth;
  final int? maxImageHeight;
  final bool allowCamera;
  final bool allowGallery;

  // Conditional logic
  final String? conditionalFieldId; // ID of field to watch
  final String? conditionalOperator; // 'equals', 'notEquals', 'contains', 'greaterThan', 'lessThan'
  final dynamic conditionalValue; // Value to compare against
  final bool showWhenConditionMet; // Show field when condition is true or false

  // Form page (for multi-page forms)
  final int? pageNumber; // Which page this field belongs to (0-indexed)

  // General settings
  final bool enabled;
  final dynamic defaultValue;
  final String? prefixText;
  final String? suffixText;
  final String? hintText;

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
    this.conditionalFieldId,
    this.conditionalOperator,
    this.conditionalValue,
    this.showWhenConditionMet = true,
    this.pageNumber,
    this.enabled = true,
    this.defaultValue,
    this.prefixText,
    this.suffixText,
    this.hintText,
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

    return FormFieldConfig(
      id: json['id'] as String,
      type: (json['type'] ?? json['question_type']) as String,
      label: (json['label'] ?? json['text']) as String,
      placeholder: json['placeholder'] as String?,
      help: (json['help'] ?? json['helper_text'] ?? json['description']) as String?,
      required: json['required'] as bool? ?? false,
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
      isFilterOnline: json['isFilterOnline'] as bool? ?? json['is_filter_online'] as bool? ?? false,
      showClearButton: json['showClearButton'] as bool? ?? json['show_clear_button'] as bool? ?? false,
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
      useCupertinoStyle: json['useCupertinoStyle'] as bool? ?? json['use_cupertino_style'] as bool? ?? false,
      chipShape: json['chipShape'] as String? ?? json['chip_shape'] as String?,
      allowMultipleSelection: json['allowMultipleSelection'] as bool? ?? json['allow_multiple_selection'] as bool? ?? false,
      allowedExtensions: allowedExtensions,
      allowMultipleFiles: json['allowMultipleFiles'] as bool? ?? json['allow_multiple_files'] as bool? ?? false,
      maxFileSizeMB: (json['maxFileSizeMB'] as num?)?.toInt() ?? (json['max_file_size_mb'] as num?)?.toInt(),
      fileTypeFilter: json['fileTypeFilter'] as String? ?? json['file_type_filter'] as String?,
      maxImages: (json['maxImages'] as num?)?.toInt() ?? (json['max_images'] as num?)?.toInt(),
      imageQuality: (json['imageQuality'] as num?)?.toDouble() ?? (json['image_quality'] as num?)?.toDouble(),
      maxImageWidth: (json['maxImageWidth'] as num?)?.toInt() ?? (json['max_image_width'] as num?)?.toInt(),
      maxImageHeight: (json['maxImageHeight'] as num?)?.toInt() ?? (json['max_image_height'] as num?)?.toInt(),
      allowCamera: json['allowCamera'] as bool? ?? json['allow_camera'] as bool? ?? false,
      allowGallery: json['allowGallery'] as bool? ?? json['allow_gallery'] as bool? ?? false,
      conditionalFieldId: json['conditionalFieldId'] as String? ?? json['conditional_field_id'] as String? ?? json['condition']?['field'] as String?,
      conditionalOperator: json['conditionalOperator'] as String? ?? json['conditional_operator'] as String?,
      conditionalValue: json['conditionalValue'] ?? json['conditional_value'] ?? json['condition']?['value'],
      showWhenConditionMet: json['showWhenConditionMet'] as bool? ?? json['show_when_condition_met'] as bool? ?? true,
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? (json['page_number'] as num?)?.toInt() ?? (json['page'] as num?)?.toInt(),
      enabled: json['enabled'] as bool? ?? true,
      defaultValue: json['defaultValue'] ?? json['default_value'],
      prefixText: json['prefixText'] as String? ?? json['prefix_text'] as String?,
      suffixText: json['suffixText'] as String? ?? json['suffix_text'] as String?,
      hintText: json['hintText'] as String? ?? json['hint_text'] as String?,
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
    'showWhenConditionMet': showWhenConditionMet,
    if (pageNumber != null) 'pageNumber': pageNumber,
    'enabled': enabled,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (prefixText != null) 'prefixText': prefixText,
    if (suffixText != null) 'suffixText': suffixText,
    if (hintText != null) 'hintText': hintText,
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
    bool? showWhenConditionMet,
    int? pageNumber,
    bool? enabled,
    dynamic defaultValue,
    String? prefixText,
    String? suffixText,
    String? hintText,
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
      showWhenConditionMet: showWhenConditionMet ?? this.showWhenConditionMet,
      pageNumber: pageNumber ?? this.pageNumber,
      enabled: enabled ?? this.enabled,
      defaultValue: defaultValue ?? this.defaultValue,
      prefixText: prefixText ?? this.prefixText,
      suffixText: suffixText ?? this.suffixText,
      hintText: hintText ?? this.hintText,
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
