/// Models for call time list management, mapping to `public.call_time_lists`
/// and `public.call_time_list_items` Supabase tables.

// ---------------------------------------------------------------------------
// CallTimeListItem
// ---------------------------------------------------------------------------

/// A single item within a call time list, representing a donor to be called.
/// Maps to `public.call_time_list_items`.
class CallTimeListItem {
  final int id;
  final int listId;
  final int? donorId;
  final int priority;
  final double? suggestedAsk;
  final String callStatus;
  final String? callNotes;
  final double? pledgedAmount;
  final DateTime? calledAt;
  final String? calledBy;
  final DateTime? createdAt;

  /// Joined donor record from `mec_donors`, if the query includes it.
  final Map<String, dynamic>? mecDonor;

  const CallTimeListItem({
    required this.id,
    required this.listId,
    this.donorId,
    this.priority = 0,
    this.suggestedAsk,
    this.callStatus = 'pending',
    this.callNotes,
    this.pledgedAmount,
    this.calledAt,
    this.calledBy,
    this.createdAt,
    this.mecDonor,
  });

  factory CallTimeListItem.fromJson(Map<String, dynamic> json) {
    // Parse joined mec_donors if present
    final rawDonor = json['mec_donors'];
    final Map<String, dynamic>? donor = rawDonor is Map
        ? Map<String, dynamic>.from(
            rawDonor.map((key, value) => MapEntry(key.toString(), value)),
          )
        : null;

    return CallTimeListItem(
      id: (json['id'] as num).toInt(),
      listId: (json['list_id'] as num).toInt(),
      donorId: (json['donor_id'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      suggestedAsk: (json['suggested_ask'] as num?)?.toDouble(),
      callStatus: json['call_status'] as String? ?? 'pending',
      callNotes: json['call_notes'] as String?,
      pledgedAmount: (json['pledged_amount'] as num?)?.toDouble(),
      calledAt: _parseDate(json['called_at']),
      calledBy: json['called_by'] as String?,
      createdAt: _parseDate(json['created_at']),
      mecDonor: donor,
    );
  }

  /// A human-readable name derived from the joined donor record.
  ///
  /// Tries first name + last name, then company, then committee name,
  /// and finally falls back to "Donor #<donorId>".
  String get displayName {
    if (mecDonor != null) {
      final first = (mecDonor!['first_name'] as String?)?.trim() ?? '';
      final last = (mecDonor!['last_name'] as String?)?.trim() ?? '';
      if (first.isNotEmpty || last.isNotEmpty) {
        return '$first $last'.trim();
      }
      final company = (mecDonor!['company'] as String?)?.trim();
      if (company != null && company.isNotEmpty) return company;

      final committee = (mecDonor!['committee_name'] as String?)?.trim();
      if (committee != null && committee.isNotEmpty) return committee;
    }

    if (donorId != null) return 'Donor #$donorId';
    return 'Unknown Donor';
  }

  /// Whether this item has been acted upon (any status other than pending or
  /// skipped counts as "called").
  bool get isCalled => callStatus != 'pending' && callStatus != 'skipped';

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

// ---------------------------------------------------------------------------
// CallTimeList
// ---------------------------------------------------------------------------

/// A call time list used to organize donor outreach sessions.
/// Maps to `public.call_time_lists`.
class CallTimeList {
  final int id;
  final String name;
  final String? description;
  final String status;
  final Map<String, dynamic>? filters;
  final String? createdBy;
  final int totalItems;
  final int totalCalled;
  final double totalPledged;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Nested items parsed from the joined `call_time_list_items` key.
  final List<CallTimeListItem> items;

  const CallTimeList({
    required this.id,
    required this.name,
    this.description,
    this.status = 'active',
    this.filters,
    this.createdBy,
    this.totalItems = 0,
    this.totalCalled = 0,
    this.totalPledged = 0,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory CallTimeList.fromJson(Map<String, dynamic> json) {
    // Parse joined call_time_list_items if present
    final rawItems = json['call_time_list_items'];
    final List<CallTimeListItem> parsedItems;
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map<String, dynamic>>()
          .map(CallTimeListItem.fromJson)
          .toList();
    } else {
      parsedItems = const [];
    }

    // Parse filters JSONB
    final rawFilters = json['filters'];
    final Map<String, dynamic>? parsedFilters = rawFilters is Map
        ? Map<String, dynamic>.from(
            rawFilters.map((key, value) => MapEntry(key.toString(), value)),
          )
        : null;

    return CallTimeList(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      filters: parsedFilters,
      createdBy: json['created_by'] as String?,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      totalCalled: (json['total_called'] as num?)?.toInt() ?? 0,
      totalPledged: (json['total_pledged'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      items: parsedItems,
    );
  }

  /// Progress towards completing all calls, as a value between 0.0 and 1.0.
  double get progressPercent {
    if (totalItems == 0) return 0;
    return totalCalled / totalItems;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
