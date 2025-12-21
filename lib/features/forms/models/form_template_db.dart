import 'dart:convert';

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

/// Model for form templates stored in the database
/// These templates can include variable placeholders like {{chapter_name}}
class FormTemplateDb {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String name;
  final String? description;
  final String? category;
  final String? icon;
  final Map<String, dynamic> schema;
  final Map<String, dynamic> settings;
  final bool isPublic;
  final bool isSystem;
  final int useCount;

  const FormTemplateDb({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    required this.name,
    this.description,
    this.category,
    this.icon,
    required this.schema,
    this.settings = const {},
    this.isPublic = false,
    this.isSystem = false,
    this.useCount = 0,
  });

  factory FormTemplateDb.fromJson(Map<String, dynamic> json) {
    return FormTemplateDb(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      icon: json['icon'] as String?,
      schema: _parseJsonField(json['schema']),
      settings: _parseJsonField(json['settings']),
      isPublic: _coerceBool(json['is_public']),
      isSystem: _coerceBool(json['is_system']),
      useCount: json['use_count'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> _parseJsonField(dynamic field) {
    if (field == null) return {};
    if (field is Map<String, dynamic>) return field;
    if (field is String) {
      try {
        return jsonDecode(field) as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'name': name,
      'description': description,
      'category': category,
      'icon': icon,
      'schema': schema,
      'settings': settings,
      'is_public': isPublic,
      'is_system': isSystem,
      'use_count': useCount,
    };
  }

  /// Get the list of questions from the schema
  List<Map<String, dynamic>> get questions {
    final questionsData = schema['questions'];
    if (questionsData is List) {
      return questionsData.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Extract variable placeholders from the template (e.g., {{chapter_name}})
  Set<String> get variables {
    final vars = <String>{};
    final jsonString = jsonEncode(schema);
    final regex = RegExp(r'\{\{(\w+)\}\}');
    for (final match in regex.allMatches(jsonString)) {
      vars.add(match.group(1)!);
    }
    return vars;
  }

  /// Check if this template has variables that need to be filled in
  bool get hasVariables => variables.isNotEmpty;

  /// Apply variable substitutions to the schema
  Map<String, dynamic> applyVariables(Map<String, String> values) {
    var jsonString = jsonEncode(schema);
    for (final entry in values.entries) {
      jsonString = jsonString.replaceAll('{{${entry.key}}}', entry.value);
    }
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Create a copy with updated fields
  FormTemplateDb copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? name,
    String? description,
    String? category,
    String? icon,
    Map<String, dynamic>? schema,
    Map<String, dynamic>? settings,
    bool? isPublic,
    bool? isSystem,
    int? useCount,
  }) {
    return FormTemplateDb(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      schema: schema ?? this.schema,
      settings: settings ?? this.settings,
      isPublic: isPublic ?? this.isPublic,
      isSystem: isSystem ?? this.isSystem,
      useCount: useCount ?? this.useCount,
    );
  }
}

/// Pre-defined categories for form templates
class TemplateCategories {
  static const String membership = 'Membership';
  static const String events = 'Events';
  static const String feedback = 'Feedback';
  static const String surveys = 'Surveys';
  static const String registration = 'Registration';
  static const String volunteer = 'Volunteer';
  static const String donation = 'Donation';
  static const String contact = 'Contact';
  static const String other = 'Other';

  static const List<String> all = [
    membership,
    events,
    feedback,
    surveys,
    registration,
    volunteer,
    donation,
    contact,
    other,
  ];
}
