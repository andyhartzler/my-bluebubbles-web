import 'dart:convert';

class Chapter {
  final String id;
  final DateTime? createdAt;
  final String chapterName;
  final String standardizedName;
  final String schoolName;
  final String chapterType;
  final DateTime? charterDate;
  final String? status;
  final String? website;
  final Map<String, dynamic>? socialMedia;
  final String? contactEmail;
  final DateTime? lastUpdated;
  final bool isChartered;

  const Chapter({
    required this.id,
    this.createdAt,
    required this.chapterName,
    required this.standardizedName,
    required this.schoolName,
    required this.chapterType,
    this.charterDate,
    this.status,
    this.website,
    this.socialMedia,
    this.contactEmail,
    this.lastUpdated,
    this.isChartered = false,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final socialMediaRaw = json['social_media'];
    Map<String, dynamic>? social;
    if (socialMediaRaw is Map<String, dynamic>) {
      social = socialMediaRaw;
    } else if (socialMediaRaw is String && socialMediaRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(socialMediaRaw);
        if (decoded is Map<String, dynamic>) {
          social = decoded;
        }
      } catch (_) {}
    }

    return Chapter(
      id: (json['id'] ?? json['chapter_name']) as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      chapterName: (json['chapter_name'] ?? '') as String,
      standardizedName: (json['standardized_name'] ?? '') as String,
      schoolName: (json['school_name'] ?? '') as String,
      chapterType: (json['chapter_type'] ?? '') as String,
      charterDate: json['charter_date'] != null
          ? DateTime.tryParse(json['charter_date'] as String)
          : null,
      status: json['status'] as String?,
      website: json['website'] as String?,
      socialMedia: social,
      contactEmail: json['contact_email'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
      isChartered: (json['is_chartered'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'chapter_name': chapterName,
      'standardized_name': standardizedName,
      'school_name': schoolName,
      'chapter_type': chapterType,
      'charter_date': charterDate?.toIso8601String().split('T').first,
      'status': status,
      'website': website,
      'social_media': socialMedia,
      'contact_email': contactEmail,
      'last_updated': lastUpdated?.toIso8601String(),
      'is_chartered': isChartered,
    };
  }

  Chapter copyWith({
    String? id,
    DateTime? createdAt,
    String? chapterName,
    String? standardizedName,
    String? schoolName,
    String? chapterType,
    DateTime? charterDate,
    String? status,
    String? website,
    Map<String, dynamic>? socialMedia,
    String? contactEmail,
    DateTime? lastUpdated,
    bool? isChartered,
  }) {
    return Chapter(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      chapterName: chapterName ?? this.chapterName,
      standardizedName: standardizedName ?? this.standardizedName,
      schoolName: schoolName ?? this.schoolName,
      chapterType: chapterType ?? this.chapterType,
      charterDate: charterDate ?? this.charterDate,
      status: status ?? this.status,
      website: website ?? this.website,
      socialMedia: socialMedia ?? this.socialMedia,
      contactEmail: contactEmail ?? this.contactEmail,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isChartered: isChartered ?? this.isChartered,
    );
  }

  String get displayTitle => chapterName;
  String get displaySubtitle => schoolName;
}
