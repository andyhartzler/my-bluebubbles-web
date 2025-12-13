/// Represents an alert/notification for legislation activity
class LegislationAlert {
  final String id;
  final DateTime createdAt;
  final String? billId;
  final String alertType; // 'new_action', 'vote', 'position_change', 'sync_error'
  final String title;
  final String? description;
  final String severity; // 'info', 'warning', 'critical'
  final bool isRead;
  final String? readBy;
  final DateTime? readAt;
  final bool isDismissed;
  final String? dismissedBy;
  final DateTime? dismissedAt;
  final Map<String, dynamic>? metadata;

  LegislationAlert({
    required this.id,
    required this.createdAt,
    this.billId,
    required this.alertType,
    required this.title,
    this.description,
    this.severity = 'info',
    this.isRead = false,
    this.readBy,
    this.readAt,
    this.isDismissed = false,
    this.dismissedBy,
    this.dismissedAt,
    this.metadata,
  });

  factory LegislationAlert.fromJson(Map<String, dynamic> json) {
    return LegislationAlert(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      billId: json['bill_id'] as String?,
      alertType: json['alert_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      severity: json['severity'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
      readBy: json['read_by'] as String?,
      readAt: _parseDate(json['read_at']),
      isDismissed: json['is_dismissed'] as bool? ?? false,
      dismissedBy: json['dismissed_by'] as String?,
      dismissedAt: _parseDate(json['dismissed_at']),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'bill_id': billId,
      'alert_type': alertType,
      'title': title,
      'description': description,
      'severity': severity,
      'is_read': isRead,
      'read_by': readBy,
      'read_at': readAt?.toIso8601String(),
      'is_dismissed': isDismissed,
      'dismissed_by': dismissedBy,
      'dismissed_at': dismissedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  LegislationAlert copyWith({
    String? id,
    DateTime? createdAt,
    String? billId,
    String? alertType,
    String? title,
    String? description,
    String? severity,
    bool? isRead,
    String? readBy,
    DateTime? readAt,
    bool? isDismissed,
    String? dismissedBy,
    DateTime? dismissedAt,
    Map<String, dynamic>? metadata,
  }) {
    return LegislationAlert(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      billId: billId ?? this.billId,
      alertType: alertType ?? this.alertType,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      readAt: readAt ?? this.readAt,
      isDismissed: isDismissed ?? this.isDismissed,
      dismissedBy: dismissedBy ?? this.dismissedBy,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Alert type enum
enum AlertType {
  newAction('new_action', 'New Action'),
  vote('vote', 'Vote'),
  positionChange('position_change', 'Position Change'),
  syncError('sync_error', 'Sync Error'),
  billPassed('bill_passed', 'Bill Passed'),
  billSigned('bill_signed', 'Bill Signed'),
  billVetoed('bill_vetoed', 'Bill Vetoed');

  const AlertType(this.value, this.label);

  final String value;
  final String label;

  static AlertType fromString(String value) {
    return AlertType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AlertType.newAction,
    );
  }
}

/// Alert severity enum
enum AlertSeverity {
  info('info', 'Info'),
  warning('warning', 'Warning'),
  critical('critical', 'Critical');

  const AlertSeverity(this.value, this.label);

  final String value;
  final String label;

  static AlertSeverity fromString(String value) {
    return AlertSeverity.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AlertSeverity.info,
    );
  }
}
