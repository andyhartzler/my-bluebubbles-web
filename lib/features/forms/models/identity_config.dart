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

/// Identity configuration for forms with automatic person tracking
/// Every form automatically includes these identity fields at the start:
/// Phone -> Name -> Email -> Zip Code
///
/// These fields enable person lookup and analytics tracking through
/// the subscriber system.

/// Reserved field keys that should not be used for custom fields
class ReservedFieldKeys {
  static const List<String> phoneKeys = ['phone', 'phone_number', 'mobile', 'cell'];
  static const List<String> nameKeys = ['name', 'full_name', 'first_name'];
  static const List<String> emailKeys = ['email', 'email_address'];
  static const List<String> zipKeys = ['zip_code', 'zipcode', 'postal_code', 'zip'];

  /// All reserved keys combined
  static List<String> get all => [
    ...phoneKeys,
    ...nameKeys,
    ...emailKeys,
    ...zipKeys,
  ];

  /// Check if a key is reserved
  static bool isReserved(String key) {
    final lowerKey = key.toLowerCase();
    return all.any((reserved) => reserved.toLowerCase() == lowerKey);
  }

  /// Get the category of a reserved key
  static String? getCategory(String key) {
    final lowerKey = key.toLowerCase();
    if (phoneKeys.any((k) => k.toLowerCase() == lowerKey)) return 'phone';
    if (nameKeys.any((k) => k.toLowerCase() == lowerKey)) return 'name';
    if (emailKeys.any((k) => k.toLowerCase() == lowerKey)) return 'email';
    if (zipKeys.any((k) => k.toLowerCase() == lowerKey)) return 'zip';
    return null;
  }
}

/// Configuration for a single identity field
class IdentityFieldConfig {
  final String key;
  final String label;
  final bool required;
  final String? helpText;

  const IdentityFieldConfig({
    required this.key,
    required this.label,
    this.required = true,
    this.helpText,
  });

  factory IdentityFieldConfig.fromJson(Map<String, dynamic> json) {
    return IdentityFieldConfig(
      key: json['key'] as String,
      label: json['label'] as String,
      required: _coerceBool(json['required'], defaultValue: true),
      helpText: json['help_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'required': required,
    if (helpText != null) 'help_text': helpText,
  };

  IdentityFieldConfig copyWith({
    String? key,
    String? label,
    bool? required,
    String? helpText,
  }) {
    return IdentityFieldConfig(
      key: key ?? this.key,
      label: label ?? this.label,
      required: required ?? this.required,
      helpText: helpText ?? this.helpText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IdentityFieldConfig &&
        other.key == key &&
        other.label == label &&
        other.required == required &&
        other.helpText == helpText;
  }

  @override
  int get hashCode => Object.hash(key, label, required, helpText);
}

/// Main identity configuration for a form
/// Controls how identity fields (phone, name, email, zip) are collected
/// and linked to subscribers
class IdentityConfig {
  final bool enabled;
  final IdentityFieldConfig phoneField;
  final IdentityFieldConfig nameField;
  final IdentityFieldConfig emailField;
  final IdentityFieldConfig zipField;

  const IdentityConfig({
    required this.enabled,
    required this.phoneField,
    required this.nameField,
    required this.emailField,
    required this.zipField,
  });

  /// Standard identity configuration used by default for all forms
  factory IdentityConfig.standard() => const IdentityConfig(
    enabled: true,
    phoneField: IdentityFieldConfig(
      key: 'phone',
      label: 'Phone Number',
      required: true,
      helpText: "We'll use this to look up your information",
    ),
    nameField: IdentityFieldConfig(
      key: 'name',
      label: 'Full Name',
      required: true,
    ),
    emailField: IdentityFieldConfig(
      key: 'email',
      label: 'Email Address',
      required: true,
    ),
    zipField: IdentityFieldConfig(
      key: 'zip_code',
      label: 'Zip Code',
      required: true,
    ),
  );

  /// Disabled identity configuration (no automatic identity fields)
  factory IdentityConfig.disabled() => IdentityConfig(
    enabled: false,
    phoneField: IdentityConfig.standard().phoneField,
    nameField: IdentityConfig.standard().nameField,
    emailField: IdentityConfig.standard().emailField,
    zipField: IdentityConfig.standard().zipField,
  );

  factory IdentityConfig.fromJson(Map<String, dynamic> json) {
    return IdentityConfig(
      enabled: _coerceBool(json['enabled'], defaultValue: true),
      phoneField: json['phone_field'] != null
          ? IdentityFieldConfig.fromJson(json['phone_field'] as Map<String, dynamic>)
          : IdentityConfig.standard().phoneField,
      nameField: json['name_field'] != null
          ? IdentityFieldConfig.fromJson(json['name_field'] as Map<String, dynamic>)
          : IdentityConfig.standard().nameField,
      emailField: json['email_field'] != null
          ? IdentityFieldConfig.fromJson(json['email_field'] as Map<String, dynamic>)
          : IdentityConfig.standard().emailField,
      zipField: json['zip_field'] != null
          ? IdentityFieldConfig.fromJson(json['zip_field'] as Map<String, dynamic>)
          : IdentityConfig.standard().zipField,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'phone_field': phoneField.toJson(),
    'name_field': nameField.toJson(),
    'email_field': emailField.toJson(),
    'zip_field': zipField.toJson(),
  };

  /// Get all identity field keys
  List<String> get allKeys => [
    phoneField.key,
    nameField.key,
    emailField.key,
    zipField.key,
  ];

  /// Get all identity fields as a list
  List<IdentityFieldConfig> get allFields => [
    phoneField,
    nameField,
    emailField,
    zipField,
  ];

  IdentityConfig copyWith({
    bool? enabled,
    IdentityFieldConfig? phoneField,
    IdentityFieldConfig? nameField,
    IdentityFieldConfig? emailField,
    IdentityFieldConfig? zipField,
  }) {
    return IdentityConfig(
      enabled: enabled ?? this.enabled,
      phoneField: phoneField ?? this.phoneField,
      nameField: nameField ?? this.nameField,
      emailField: emailField ?? this.emailField,
      zipField: zipField ?? this.zipField,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IdentityConfig &&
        other.enabled == enabled &&
        other.phoneField == phoneField &&
        other.nameField == nameField &&
        other.emailField == emailField &&
        other.zipField == zipField;
  }

  @override
  int get hashCode => Object.hash(enabled, phoneField, nameField, emailField, zipField);
}
