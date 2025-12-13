import 'package:flutter/material.dart';

/// Represents a bill being tracked by the Policy & Advocacy committee
/// CAPTURES ALL Open States API v3 Bill fields
class TrackedBill {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Open States Core Identifiers
  final String openstatesBillId; // ocd-bill/...
  final String jurisdiction; // 'mo'
  final String session; // "2026"
  final String billIdentifier; // "HB 123", "SB 456"

  // Bill Metadata (from API)
  final String title;
  final String? description;
  final List<String> classification; // ['bill'], ['resolution']
  final List<String> subjects; // ['EDUCATION', 'BUDGET']

  // From organization (introducing chamber)
  final String? fromOrganizationId;
  final String? fromOrganizationName;
  final String? fromOrganizationClassification; // 'lower', 'upper'
  final String? chamber; // Legacy: 'lower', 'upper'

  // Abstracts
  final List<Map<String, dynamic>>? abstracts;
  final String? primaryAbstract; // First abstract for quick display

  // Other titles and identifiers
  final List<Map<String, dynamic>>? otherTitles;
  final List<Map<String, dynamic>>? otherIdentifiers;

  // Related bills (companions, amendments)
  final List<Map<String, dynamic>>? relatedBills;

  // Timeline Dates
  final DateTime? firstActionDate;
  final DateTime? latestActionDate;
  final String? latestActionDescription;
  final DateTime? latestPassageDate;

  // Open States timestamps
  final DateTime? openstatesCreatedAt;
  final DateTime? openstatesUpdatedAt;

  // Passage Tracking (derived from actions)
  final bool passedLower;
  final DateTime? passedLowerDate;
  final bool passedUpper;
  final DateTime? passedUpperDate;
  final bool signedByGovernor;
  final DateTime? signedDate;
  final bool vetoed;
  final DateTime? vetoDate;

  // External Links
  final String? openstatesUrl;
  final List<Map<String, dynamic>>? sources;

  // Cached Counts
  final int sponsorCount;
  final int actionCount;
  final int voteCount;
  final int versionCount;
  final int documentCount;

  // Primary sponsor (cached for display)
  final String? primarySponsorName;
  final String? primarySponsorParty;
  final String? primarySponsorDistrict;

  // Latest vote (cached for display)
  final String? latestVoteResult;
  final DateTime? latestVoteDate;

  // MOYD Committee Position & Tracking
  final String position; // 'support', 'oppose', 'watching', 'neutral'
  final String? positionSetBy;
  final DateTime? positionSetAt;
  final String? positionRationale;

  final String priority; // 'critical', 'high', 'medium', 'low'
  final List<String> categories; // ['climate', 'healthcare']
  final List<String> tags; // Custom tags

  final String? addedBy;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedReason;

  // Sync & Cache
  final DateTime? lastSyncedAt;
  final String? syncError;
  final Map<String, dynamic>? extras;

  TrackedBill({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.openstatesBillId,
    this.jurisdiction = 'mo',
    required this.session,
    required this.billIdentifier,
    required this.title,
    this.description,
    this.classification = const [],
    this.subjects = const [],
    this.fromOrganizationId,
    this.fromOrganizationName,
    this.fromOrganizationClassification,
    this.chamber,
    this.abstracts,
    this.primaryAbstract,
    this.otherTitles,
    this.otherIdentifiers,
    this.relatedBills,
    this.firstActionDate,
    this.latestActionDate,
    this.latestActionDescription,
    this.latestPassageDate,
    this.openstatesCreatedAt,
    this.openstatesUpdatedAt,
    this.passedLower = false,
    this.passedLowerDate,
    this.passedUpper = false,
    this.passedUpperDate,
    this.signedByGovernor = false,
    this.signedDate,
    this.vetoed = false,
    this.vetoDate,
    this.openstatesUrl,
    this.sources,
    this.sponsorCount = 0,
    this.actionCount = 0,
    this.voteCount = 0,
    this.versionCount = 0,
    this.documentCount = 0,
    this.primarySponsorName,
    this.primarySponsorParty,
    this.primarySponsorDistrict,
    this.latestVoteResult,
    this.latestVoteDate,
    this.position = 'watching',
    this.positionSetBy,
    this.positionSetAt,
    this.positionRationale,
    this.priority = 'medium',
    this.categories = const [],
    this.tags = const [],
    this.addedBy,
    this.isArchived = false,
    this.archivedAt,
    this.archivedReason,
    this.lastSyncedAt,
    this.syncError,
    this.extras,
  });

  factory TrackedBill.fromJson(Map<String, dynamic> json) {
    return TrackedBill(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      openstatesBillId: json['openstates_bill_id'] as String,
      jurisdiction: json['jurisdiction'] as String? ?? 'mo',
      session: json['session'] as String,
      billIdentifier: json['bill_identifier'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      classification: _parseStringList(json['classification']),
      subjects: _parseStringList(json['subjects']),
      fromOrganizationId: json['from_organization_id'] as String?,
      fromOrganizationName: json['from_organization_name'] as String?,
      fromOrganizationClassification: json['from_organization_classification'] as String?,
      chamber: json['chamber'] as String?,
      abstracts: _parseMapList(json['abstracts']),
      primaryAbstract: json['primary_abstract'] as String?,
      otherTitles: _parseMapList(json['other_titles']),
      otherIdentifiers: _parseMapList(json['other_identifiers']),
      relatedBills: _parseMapList(json['related_bills']),
      firstActionDate: _parseDate(json['first_action_date']),
      latestActionDate: _parseDate(json['latest_action_date']),
      latestActionDescription: json['latest_action_description'] as String?,
      latestPassageDate: _parseDate(json['latest_passage_date']),
      openstatesCreatedAt: _parseDate(json['openstates_created_at']),
      openstatesUpdatedAt: _parseDate(json['openstates_updated_at']),
      passedLower: json['passed_lower'] as bool? ?? false,
      passedLowerDate: _parseDate(json['passed_lower_date']),
      passedUpper: json['passed_upper'] as bool? ?? false,
      passedUpperDate: _parseDate(json['passed_upper_date']),
      signedByGovernor: json['signed_by_governor'] as bool? ?? false,
      signedDate: _parseDate(json['signed_date']),
      vetoed: json['vetoed'] as bool? ?? false,
      vetoDate: _parseDate(json['veto_date']),
      openstatesUrl: json['openstates_url'] as String?,
      sources: _parseMapList(json['sources']),
      sponsorCount: json['sponsor_count'] as int? ?? 0,
      actionCount: json['action_count'] as int? ?? 0,
      voteCount: json['vote_count'] as int? ?? 0,
      versionCount: json['version_count'] as int? ?? 0,
      documentCount: json['document_count'] as int? ?? 0,
      primarySponsorName: json['primary_sponsor_name'] as String?,
      primarySponsorParty: json['primary_sponsor_party'] as String?,
      primarySponsorDistrict: json['primary_sponsor_district'] as String?,
      latestVoteResult: json['latest_vote_result'] as String?,
      latestVoteDate: _parseDate(json['latest_vote_date']),
      position: json['position'] as String? ?? 'watching',
      positionSetBy: json['position_set_by'] as String?,
      positionSetAt: _parseDate(json['position_set_at']),
      positionRationale: json['position_rationale'] as String?,
      priority: json['priority'] as String? ?? 'medium',
      categories: _parseStringList(json['categories']),
      tags: _parseStringList(json['tags']),
      addedBy: json['added_by'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      archivedAt: _parseDate(json['archived_at']),
      archivedReason: json['archived_reason'] as String?,
      lastSyncedAt: _parseDate(json['last_synced_at']),
      syncError: json['sync_error'] as String?,
      extras: json['extras'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'openstates_bill_id': openstatesBillId,
      'jurisdiction': jurisdiction,
      'session': session,
      'bill_identifier': billIdentifier,
      'title': title,
      'description': description,
      'classification': classification,
      'subjects': subjects,
      'from_organization_id': fromOrganizationId,
      'from_organization_name': fromOrganizationName,
      'from_organization_classification': fromOrganizationClassification,
      'chamber': chamber,
      'abstracts': abstracts,
      'primary_abstract': primaryAbstract,
      'other_titles': otherTitles,
      'other_identifiers': otherIdentifiers,
      'related_bills': relatedBills,
      'first_action_date': firstActionDate?.toIso8601String(),
      'latest_action_date': latestActionDate?.toIso8601String(),
      'latest_action_description': latestActionDescription,
      'latest_passage_date': latestPassageDate?.toIso8601String(),
      'openstates_created_at': openstatesCreatedAt?.toIso8601String(),
      'openstates_updated_at': openstatesUpdatedAt?.toIso8601String(),
      'passed_lower': passedLower,
      'passed_lower_date': passedLowerDate?.toIso8601String(),
      'passed_upper': passedUpper,
      'passed_upper_date': passedUpperDate?.toIso8601String(),
      'signed_by_governor': signedByGovernor,
      'signed_date': signedDate?.toIso8601String(),
      'vetoed': vetoed,
      'veto_date': vetoDate?.toIso8601String(),
      'openstates_url': openstatesUrl,
      'sources': sources,
      'sponsor_count': sponsorCount,
      'action_count': actionCount,
      'vote_count': voteCount,
      'version_count': versionCount,
      'document_count': documentCount,
      'primary_sponsor_name': primarySponsorName,
      'primary_sponsor_party': primarySponsorParty,
      'primary_sponsor_district': primarySponsorDistrict,
      'latest_vote_result': latestVoteResult,
      'latest_vote_date': latestVoteDate?.toIso8601String(),
      'position': position,
      'position_set_by': positionSetBy,
      'position_set_at': positionSetAt?.toIso8601String(),
      'position_rationale': positionRationale,
      'priority': priority,
      'categories': categories,
      'tags': tags,
      'added_by': addedBy,
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
      'archived_reason': archivedReason,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_error': syncError,
      'extras': extras,
    };
  }

  TrackedBill copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? openstatesBillId,
    String? jurisdiction,
    String? session,
    String? billIdentifier,
    String? title,
    String? description,
    List<String>? classification,
    List<String>? subjects,
    String? fromOrganizationId,
    String? fromOrganizationName,
    String? fromOrganizationClassification,
    String? chamber,
    List<Map<String, dynamic>>? abstracts,
    String? primaryAbstract,
    List<Map<String, dynamic>>? otherTitles,
    List<Map<String, dynamic>>? otherIdentifiers,
    List<Map<String, dynamic>>? relatedBills,
    DateTime? firstActionDate,
    DateTime? latestActionDate,
    String? latestActionDescription,
    DateTime? latestPassageDate,
    DateTime? openstatesCreatedAt,
    DateTime? openstatesUpdatedAt,
    bool? passedLower,
    DateTime? passedLowerDate,
    bool? passedUpper,
    DateTime? passedUpperDate,
    bool? signedByGovernor,
    DateTime? signedDate,
    bool? vetoed,
    DateTime? vetoDate,
    String? openstatesUrl,
    List<Map<String, dynamic>>? sources,
    int? sponsorCount,
    int? actionCount,
    int? voteCount,
    int? versionCount,
    int? documentCount,
    String? primarySponsorName,
    String? primarySponsorParty,
    String? primarySponsorDistrict,
    String? latestVoteResult,
    DateTime? latestVoteDate,
    String? position,
    String? positionSetBy,
    DateTime? positionSetAt,
    String? positionRationale,
    String? priority,
    List<String>? categories,
    List<String>? tags,
    String? addedBy,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedReason,
    DateTime? lastSyncedAt,
    String? syncError,
    Map<String, dynamic>? extras,
  }) {
    return TrackedBill(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openstatesBillId: openstatesBillId ?? this.openstatesBillId,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      session: session ?? this.session,
      billIdentifier: billIdentifier ?? this.billIdentifier,
      title: title ?? this.title,
      description: description ?? this.description,
      classification: classification ?? this.classification,
      subjects: subjects ?? this.subjects,
      fromOrganizationId: fromOrganizationId ?? this.fromOrganizationId,
      fromOrganizationName: fromOrganizationName ?? this.fromOrganizationName,
      fromOrganizationClassification: fromOrganizationClassification ?? this.fromOrganizationClassification,
      chamber: chamber ?? this.chamber,
      abstracts: abstracts ?? this.abstracts,
      primaryAbstract: primaryAbstract ?? this.primaryAbstract,
      otherTitles: otherTitles ?? this.otherTitles,
      otherIdentifiers: otherIdentifiers ?? this.otherIdentifiers,
      relatedBills: relatedBills ?? this.relatedBills,
      firstActionDate: firstActionDate ?? this.firstActionDate,
      latestActionDate: latestActionDate ?? this.latestActionDate,
      latestActionDescription: latestActionDescription ?? this.latestActionDescription,
      latestPassageDate: latestPassageDate ?? this.latestPassageDate,
      openstatesCreatedAt: openstatesCreatedAt ?? this.openstatesCreatedAt,
      openstatesUpdatedAt: openstatesUpdatedAt ?? this.openstatesUpdatedAt,
      passedLower: passedLower ?? this.passedLower,
      passedLowerDate: passedLowerDate ?? this.passedLowerDate,
      passedUpper: passedUpper ?? this.passedUpper,
      passedUpperDate: passedUpperDate ?? this.passedUpperDate,
      signedByGovernor: signedByGovernor ?? this.signedByGovernor,
      signedDate: signedDate ?? this.signedDate,
      vetoed: vetoed ?? this.vetoed,
      vetoDate: vetoDate ?? this.vetoDate,
      openstatesUrl: openstatesUrl ?? this.openstatesUrl,
      sources: sources ?? this.sources,
      sponsorCount: sponsorCount ?? this.sponsorCount,
      actionCount: actionCount ?? this.actionCount,
      voteCount: voteCount ?? this.voteCount,
      versionCount: versionCount ?? this.versionCount,
      documentCount: documentCount ?? this.documentCount,
      primarySponsorName: primarySponsorName ?? this.primarySponsorName,
      primarySponsorParty: primarySponsorParty ?? this.primarySponsorParty,
      primarySponsorDistrict: primarySponsorDistrict ?? this.primarySponsorDistrict,
      latestVoteResult: latestVoteResult ?? this.latestVoteResult,
      latestVoteDate: latestVoteDate ?? this.latestVoteDate,
      position: position ?? this.position,
      positionSetBy: positionSetBy ?? this.positionSetBy,
      positionSetAt: positionSetAt ?? this.positionSetAt,
      positionRationale: positionRationale ?? this.positionRationale,
      priority: priority ?? this.priority,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      addedBy: addedBy ?? this.addedBy,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedReason: archivedReason ?? this.archivedReason,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncError: syncError ?? this.syncError,
      extras: extras ?? this.extras,
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

/// Position options for bills
enum BillPosition {
  support('support', 'Support', '👍', Color(0xFF22C55E)),
  oppose('oppose', 'Oppose', '👎', Color(0xFFEF4444)),
  watching('watching', 'Watching', '👀', Color(0xFF3B82F6)),
  neutral('neutral', 'Neutral', '➖', Color(0xFF6B7280));

  const BillPosition(this.value, this.label, this.emoji, this.color);

  final String value;
  final String label;
  final String emoji;
  final Color color;

  static BillPosition fromString(String value) {
    return BillPosition.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BillPosition.watching,
    );
  }
}

/// Priority levels for bills
enum BillPriority {
  critical('critical', 'Critical', '🔴', Color(0xFFDC2626), 1),
  high('high', 'High', '🟠', Color(0xFFF97316), 2),
  medium('medium', 'Medium', '🟡', Color(0xFFEAB308), 3),
  low('low', 'Low', '🟢', Color(0xFF22C55E), 4);

  const BillPriority(this.value, this.label, this.emoji, this.color, this.sortOrder);

  final String value;
  final String label;
  final String emoji;
  final Color color;
  final int sortOrder;

  static BillPriority fromString(String value) {
    return BillPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BillPriority.medium,
    );
  }
}
