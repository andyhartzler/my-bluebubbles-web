import 'package:uuid/uuid.dart';

class EmailTemplate {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> designJson;
  final String htmlContent;
  final DateTime? updatedAt;
  final String? accentColor;

  const EmailTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.designJson,
    required this.htmlContent,
    this.updatedAt,
    this.accentColor,
  });

  factory EmailTemplate.newTemplate({
    required String name,
    required String description,
    required Map<String, dynamic> designJson,
    required String htmlContent,
    String? accentColor,
  }) {
    return EmailTemplate(
      id: const Uuid().v4(),
      name: name,
      description: description,
      designJson: designJson,
      htmlContent: htmlContent,
      accentColor: accentColor,
      updatedAt: DateTime.now(),
    );
  }

  factory EmailTemplate.fromMap(Map<String, dynamic> map) {
    return EmailTemplate(
      id: map['id']?.toString() ?? const Uuid().v4(),
      name: map['name']?.toString() ?? 'Untitled Template',
      description: map['description']?.toString() ?? '',
      designJson: Map<String, dynamic>.from(map['design_json'] ?? {}),
      htmlContent: map['html_content']?.toString() ?? '',
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      accentColor: map['accent_color']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'design_json': designJson,
      'html_content': htmlContent,
      'updated_at': updatedAt?.toIso8601String(),
      if (accentColor != null) 'accent_color': accentColor,
    };
  }
}
