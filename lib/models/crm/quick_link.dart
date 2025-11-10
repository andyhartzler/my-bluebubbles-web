import 'package:flutter/foundation.dart';

@immutable
class QuickLink {
  const QuickLink({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.externalUrl,
    this.iconUrl,
    this.storageBucket,
    this.storagePath,
    this.fileName,
    this.contentType,
    this.fileSize,
    this.createdAt,
    this.updatedAt,
    this.signedUrl,
    this.signedUrlExpiresAt,
    this.sortOrder,
    this.isActive = true,
    this.notes,
  });

  factory QuickLink.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];
    final updatedAtRaw = json['updated_at'];

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value.toUtc();
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toUtc();
      }
      return null;
    }

    return QuickLink(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString(),
      externalUrl: json['external_url']?.toString(),
      iconUrl: json['icon_url']?.toString(),
      storageBucket: json['storage_bucket']?.toString(),
      storagePath: json['storage_path']?.toString(),
      fileName: json['file_name']?.toString(),
      contentType: json['content_type']?.toString(),
      fileSize: _parseInt(json['file_size']),
      createdAt: parseDate(createdAtRaw),
      updatedAt: parseDate(updatedAtRaw),
      signedUrl: json['signed_url']?.toString(),
      signedUrlExpiresAt: parseDate(json['signed_url_expires_at']),
      sortOrder: _parseInt(json['sort_order']),
      isActive: _parseBool(json['is_active']),
      notes: json['notes']?.toString(),
    );
  }

  final String id;
  final String title;
  final String category;
  final String? description;
  final String? externalUrl;
  final String? iconUrl;
  final String? storageBucket;
  final String? storagePath;
  final String? fileName;
  final String? contentType;
  final int? fileSize;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? signedUrl;
  final DateTime? signedUrlExpiresAt;
  final int? sortOrder;
  final bool isActive;
  final String? notes;

  bool get hasStorageReference => (storagePath ?? '').isNotEmpty;

  bool get hasExternalUrl => (externalUrl ?? '').trim().isNotEmpty;

  String get displayCategory =>
      category.trim().isEmpty ? 'Uncategorized' : category.trim();

  String get normalizedCategory => category.trim().toLowerCase();

  String? get resolvedUrl {
    if (hasExternalUrl) {
      return externalUrl!.trim();
    }
    if ((signedUrl ?? '').isNotEmpty) {
      return signedUrl;
    }
    return null;
  }

  QuickLink copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    String? externalUrl,
    String? iconUrl,
    String? storageBucket,
    String? storagePath,
    String? fileName,
    String? contentType,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? signedUrl,
    DateTime? signedUrlExpiresAt,
    bool clearStorage = false,
    int? sortOrder,
    bool? isActive,
    String? notes,
  }) {
    return QuickLink(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      externalUrl: externalUrl ?? this.externalUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      storageBucket: clearStorage ? null : storageBucket ?? this.storageBucket,
      storagePath: clearStorage ? null : storagePath ?? this.storagePath,
      fileName: clearStorage ? null : fileName ?? this.fileName,
      contentType: clearStorage ? null : contentType ?? this.contentType,
      fileSize: clearStorage ? null : fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      signedUrl: signedUrl ?? this.signedUrl,
      signedUrlExpiresAt: signedUrlExpiresAt ?? this.signedUrlExpiresAt,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      if (description != null) 'description': description,
      if (externalUrl != null) 'external_url': externalUrl,
      if (iconUrl != null) 'icon_url': iconUrl,
      if (storageBucket != null) 'storage_bucket': storageBucket,
      if (storagePath != null) 'storage_path': storagePath,
      if (fileName != null) 'file_name': fileName,
      if (contentType != null) 'content_type': contentType,
      if (fileSize != null) 'file_size': fileSize,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (signedUrl != null) 'signed_url': signedUrl,
      if (signedUrlExpiresAt != null)
        'signed_url_expires_at': signedUrlExpiresAt!.toIso8601String(),
      if (sortOrder != null) 'sort_order': sortOrder,
      'is_active': isActive,
      if (notes != null) 'notes': notes,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return true;
      return normalized == 'true' || normalized == '1' || normalized == 't';
    }
    return true;
  }
}
