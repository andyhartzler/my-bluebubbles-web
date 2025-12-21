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

/// Represents a legislative action on a bill
/// CAPTURES ALL Open States API v3 BillAction fields
class BillAction {
  final String id;
  final DateTime createdAt;
  final String billId;

  // Open States Identifiers
  final String? openstatesActionId; // UUID from API

  // Action Details
  final DateTime actionDate;
  final String actionDescription;
  final List<String> actionClassification; // ['passage', 'reading-1', etc.]
  final int actionOrder; // Order in the action sequence

  // Organization that took the action
  final String? organizationId; // ocd-organization/...
  final String? organizationName; // "Missouri House of Representatives"
  final String? organizationClassification; // 'lower', 'upper', 'legislature', 'executive'
  final String? chamber; // Legacy field: 'lower', 'upper', 'executive'

  // Related Entities (committees, people mentioned)
  final List<Map<String, dynamic>>? relatedEntities;

  // MOYD Tracking
  final bool isNew; // New since last check
  final DateTime? firstSeenAt;
  final bool isRead; // Has someone reviewed this action
  final String? readBy;
  final DateTime? readAt;

  BillAction({
    required this.id,
    required this.createdAt,
    required this.billId,
    this.openstatesActionId,
    required this.actionDate,
    required this.actionDescription,
    this.actionClassification = const [],
    this.actionOrder = 0,
    this.organizationId,
    this.organizationName,
    this.organizationClassification,
    this.chamber,
    this.relatedEntities,
    this.isNew = false,
    this.firstSeenAt,
    this.isRead = false,
    this.readBy,
    this.readAt,
  });

  factory BillAction.fromJson(Map<String, dynamic> json) {
    return BillAction(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      billId: json['bill_id'] as String,
      openstatesActionId: json['openstates_action_id'] as String?,
      actionDate: DateTime.parse(json['action_date'] as String),
      actionDescription: json['action_description'] as String,
      actionClassification: _parseStringList(json['action_classification']),
      actionOrder: json['action_order'] as int? ?? 0,
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      organizationClassification: json['organization_classification'] as String?,
      chamber: json['chamber'] as String?,
      relatedEntities: _parseMapList(json['related_entities']),
      isNew: _coerceBool(json['is_new']),
      firstSeenAt: _parseDate(json['first_seen_at']),
      isRead: _coerceBool(json['is_read']),
      readBy: json['read_by'] as String?,
      readAt: _parseDate(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'bill_id': billId,
      'openstates_action_id': openstatesActionId,
      'action_date': actionDate.toIso8601String(),
      'action_description': actionDescription,
      'action_classification': actionClassification,
      'action_order': actionOrder,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_classification': organizationClassification,
      'chamber': chamber,
      'related_entities': relatedEntities,
      'is_new': isNew,
      'first_seen_at': firstSeenAt?.toIso8601String(),
      'is_read': isRead,
      'read_by': readBy,
      'read_at': readAt?.toIso8601String(),
    };
  }

  BillAction copyWith({
    String? id,
    DateTime? createdAt,
    String? billId,
    String? openstatesActionId,
    DateTime? actionDate,
    String? actionDescription,
    List<String>? actionClassification,
    int? actionOrder,
    String? organizationId,
    String? organizationName,
    String? organizationClassification,
    String? chamber,
    List<Map<String, dynamic>>? relatedEntities,
    bool? isNew,
    DateTime? firstSeenAt,
    bool? isRead,
    String? readBy,
    DateTime? readAt,
  }) {
    return BillAction(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      billId: billId ?? this.billId,
      openstatesActionId: openstatesActionId ?? this.openstatesActionId,
      actionDate: actionDate ?? this.actionDate,
      actionDescription: actionDescription ?? this.actionDescription,
      actionClassification: actionClassification ?? this.actionClassification,
      actionOrder: actionOrder ?? this.actionOrder,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationClassification: organizationClassification ?? this.organizationClassification,
      chamber: chamber ?? this.chamber,
      relatedEntities: relatedEntities ?? this.relatedEntities,
      isNew: isNew ?? this.isNew,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Get a readable chamber name
  String get chamberDisplay {
    switch (chamber?.toLowerCase()) {
      case 'lower':
        return 'House';
      case 'upper':
        return 'Senate';
      case 'executive':
        return 'Governor';
      default:
        return organizationName ?? 'Unknown';
    }
  }

  /// Check if this is a significant action
  bool get isSignificant {
    final classifications = actionClassification.map((c) => c.toLowerCase()).toSet();
    return classifications.contains('passage') ||
        classifications.contains('veto') ||
        classifications.contains('executive-signature') ||
        classifications.contains('became-law');
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  static List<Map<String, dynamic>>? _parseMapList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return null;
  }
}
