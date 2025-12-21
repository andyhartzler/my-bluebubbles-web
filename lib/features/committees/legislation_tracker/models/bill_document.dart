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

/// Represents a bill version or document (fiscal note, committee report, etc.)
/// CAPTURES ALL Open States API v3 BillDocumentOrVersion fields
class BillDocument {
  final String id;
  final DateTime createdAt;
  final String billId;

  // Open States Identifiers
  final String? openstatesDocumentId; // UUID from API

  // Document Type
  final String documentType; // 'version' or 'document'
  // versions = bill text versions (introduced, engrossed, enrolled)
  // documents = fiscal notes, committee reports, analysis

  // Document Details
  final String note; // "Introduced Version", "Fiscal Note"
  final DateTime? documentDate;
  final String? classification; // 'introduced', 'engrossed', 'fiscal-note'

  // Document Links
  final List<DocumentLink> links;
  final String? primaryLink; // First/preferred URL
  final String? primaryMediaType; // 'application/pdf', 'text/html'

  // MOYD Tracking
  final bool isNew;
  final DateTime? firstSeenAt;
  final bool isReviewed;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  BillDocument({
    required this.id,
    required this.createdAt,
    required this.billId,
    this.openstatesDocumentId,
    required this.documentType,
    required this.note,
    this.documentDate,
    this.classification,
    this.links = const [],
    this.primaryLink,
    this.primaryMediaType,
    this.isNew = false,
    this.firstSeenAt,
    this.isReviewed = false,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
  });

  factory BillDocument.fromJson(Map<String, dynamic> json) {
    return BillDocument(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      billId: json['bill_id'] as String,
      openstatesDocumentId: json['openstates_document_id'] as String?,
      documentType: json['document_type'] as String,
      note: json['note'] as String,
      documentDate: _parseDate(json['document_date']),
      classification: json['classification'] as String?,
      links: _parseLinks(json['links']),
      primaryLink: json['primary_link'] as String?,
      primaryMediaType: json['primary_media_type'] as String?,
      isNew: _coerceBool(json['is_new']),
      firstSeenAt: _parseDate(json['first_seen_at']),
      isReviewed: _coerceBool(json['is_reviewed']),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: _parseDate(json['reviewed_at']),
      reviewNotes: json['review_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'bill_id': billId,
      'openstates_document_id': openstatesDocumentId,
      'document_type': documentType,
      'note': note,
      'document_date': documentDate?.toIso8601String(),
      'classification': classification,
      'links': links.map((l) => l.toJson()).toList(),
      'primary_link': primaryLink,
      'primary_media_type': primaryMediaType,
      'is_new': isNew,
      'first_seen_at': firstSeenAt?.toIso8601String(),
      'is_reviewed': isReviewed,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_notes': reviewNotes,
    };
  }

  BillDocument copyWith({
    String? id,
    DateTime? createdAt,
    String? billId,
    String? openstatesDocumentId,
    String? documentType,
    String? note,
    DateTime? documentDate,
    String? classification,
    List<DocumentLink>? links,
    String? primaryLink,
    String? primaryMediaType,
    bool? isNew,
    DateTime? firstSeenAt,
    bool? isReviewed,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNotes,
  }) {
    return BillDocument(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      billId: billId ?? this.billId,
      openstatesDocumentId: openstatesDocumentId ?? this.openstatesDocumentId,
      documentType: documentType ?? this.documentType,
      note: note ?? this.note,
      documentDate: documentDate ?? this.documentDate,
      classification: classification ?? this.classification,
      links: links ?? this.links,
      primaryLink: primaryLink ?? this.primaryLink,
      primaryMediaType: primaryMediaType ?? this.primaryMediaType,
      isNew: isNew ?? this.isNew,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      isReviewed: isReviewed ?? this.isReviewed,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }

  /// Whether this is a bill text version
  bool get isVersion => documentType == 'version';

  /// Whether this is a supporting document
  bool get isDocument => documentType == 'document';

  /// Whether this is a fiscal note
  bool get isFiscalNote {
    final noteLower = note.toLowerCase();
    final classLower = classification?.toLowerCase() ?? '';
    return noteLower.contains('fiscal') || classLower.contains('fiscal');
  }

  /// Whether this is a committee report
  bool get isCommitteeReport {
    final noteLower = note.toLowerCase();
    final classLower = classification?.toLowerCase() ?? '';
    return noteLower.contains('committee') || classLower.contains('committee');
  }

  /// Whether this is an amendment
  bool get isAmendment {
    final noteLower = note.toLowerCase();
    final classLower = classification?.toLowerCase() ?? '';
    return noteLower.contains('amendment') || classLower.contains('amendment');
  }

  /// Get the best available link URL
  String? get bestLink {
    if (primaryLink != null) return primaryLink;
    if (links.isNotEmpty) return links.first.url;
    return null;
  }

  /// Whether this is a PDF document
  bool get isPdf {
    final mediaType = primaryMediaType ?? links.firstOrNull?.mediaType;
    return mediaType?.contains('pdf') ?? false;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<DocumentLink> _parseLinks(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => DocumentLink.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}

/// Link to a document file
class DocumentLink {
  final String url;
  final String? mediaType; // 'application/pdf', 'text/html'

  DocumentLink({
    required this.url,
    this.mediaType,
  });

  factory DocumentLink.fromJson(Map<String, dynamic> json) {
    return DocumentLink(
      url: json['url'] as String,
      mediaType: json['media_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'media_type': mediaType,
    };
  }
}

/// Document type enum for filtering
enum BillDocumentType {
  version('version', 'Bill Text'),
  document('document', 'Document');

  const BillDocumentType(this.value, this.label);

  final String value;
  final String label;

  static BillDocumentType fromString(String value) {
    return BillDocumentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BillDocumentType.document,
    );
  }
}
