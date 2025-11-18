import 'package:collection/collection.dart';

class EmailTemplate {
  final String id;
  final String templateKey;
  final String templateName;
  final String templateType;
  final String audience;
  final String subject;
  final String body;
  final List<String> variables;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EmailTemplate({
    required this.id,
    required this.templateKey,
    required this.templateName,
    required this.templateType,
    required this.audience,
    required this.subject,
    required this.body,
    required this.variables,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    List<String> parseVariables(dynamic value) {
      if (value is List) {
        return value
            .whereNotNull()
            .map((variable) => variable.toString())
            .where((variable) => variable.isNotEmpty)
            .toList();
      }
      if (value is String && value.isNotEmpty) {
        return [value];
      }
      return const [];
    }

    return EmailTemplate(
      id: json['id']?.toString() ?? '',
      templateKey: json['template_key']?.toString() ?? '',
      templateName: json['template_name']?.toString() ?? 'Untitled Template',
      templateType: json['template_type']?.toString() ?? 'general',
      audience: json['audience']?.toString() ?? 'general',
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      variables: parseVariables(json['variables']),
      active: json['active'] == null ? true : json['active'] == true,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  String get audienceLabel => _titleize(audience.replaceAll('_', ' '));

  String get templateTypeLabel => _titleize(templateType.replaceAll('_', ' '));

  bool matchesQuery(String query) {
    final normalized = query.toLowerCase();
    return templateName.toLowerCase().contains(normalized) ||
        templateType.toLowerCase().contains(normalized) ||
        audience.toLowerCase().contains(normalized) ||
        subject.toLowerCase().contains(normalized) ||
        templateKey.toLowerCase().contains(normalized);
  }

  String _titleize(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
