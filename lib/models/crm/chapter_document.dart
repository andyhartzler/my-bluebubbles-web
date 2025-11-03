class ChapterDocument {
  final String id;
  final DateTime? createdAt;
  final String chapterName;
  final String documentType;
  final String filePath;
  final String publicUrl;
  final String? originalFilename;
  final int? fileSize;
  final DateTime? uploadedAt;
  final String? uploadedBy;

  const ChapterDocument({
    required this.id,
    this.createdAt,
    required this.chapterName,
    required this.documentType,
    required this.filePath,
    required this.publicUrl,
    this.originalFilename,
    this.fileSize,
    this.uploadedAt,
    this.uploadedBy,
  });

  factory ChapterDocument.fromJson(Map<String, dynamic> json) {
    return ChapterDocument(
      id: json['id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      chapterName: (json['chapter_name'] ?? '') as String,
      documentType: (json['document_type'] ?? '') as String,
      filePath: (json['file_path'] ?? '') as String,
      publicUrl: (json['public_url'] ?? '') as String,
      originalFilename: json['original_filename'] as String?,
      fileSize: json['file_size'] as int?,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'] as String)
          : null,
      uploadedBy: json['uploaded_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'chapter_name': chapterName,
      'document_type': documentType,
      'file_path': filePath,
      'public_url': publicUrl,
      'original_filename': originalFilename,
      'file_size': fileSize,
      'uploaded_at': uploadedAt?.toIso8601String(),
      'uploaded_by': uploadedBy,
    };
  }

  ChapterDocument copyWith({
    String? id,
    DateTime? createdAt,
    String? chapterName,
    String? documentType,
    String? filePath,
    String? publicUrl,
    String? originalFilename,
    int? fileSize,
    DateTime? uploadedAt,
    String? uploadedBy,
  }) {
    return ChapterDocument(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      chapterName: chapterName ?? this.chapterName,
      documentType: documentType ?? this.documentType,
      filePath: filePath ?? this.filePath,
      publicUrl: publicUrl ?? this.publicUrl,
      originalFilename: originalFilename ?? this.originalFilename,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }

  String get displayName => originalFilename ?? documentType;
}
