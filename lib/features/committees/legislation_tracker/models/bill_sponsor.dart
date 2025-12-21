import 'legislator.dart';

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

/// Represents a sponsor of a bill
/// CAPTURES ALL Open States API v3 BillSponsorship fields
class BillSponsor {
  final String id;
  final DateTime createdAt;
  final String billId;

  // Open States Identifiers
  final String? openstatesSponsorshipId; // UUID from API sponsorship record

  // Basic Sponsor Info
  final String name; // "JONES", "Smith"
  final String entityType; // 'person' or 'organization'
  final bool isPrimary; // API: primary field
  final String? sponsorshipClassification; // 'primary', 'cosponsor', etc.

  // Person Details (if entityType = 'person')
  final String? openstatesPersonId; // ocd-person/...
  final String? party; // 'Democratic', 'Republican'

  // Current Role
  final String? roleTitle; // 'Senator', 'Representative'
  final String? roleOrgClassification; // 'upper', 'lower'
  final String? district; // '3', '45-A'
  final String? divisionId; // ocd-division/country:us/state:mo/sldu:3

  // Legacy chamber field
  final String? chamber; // 'lower', 'upper'

  // Organization Details (if entityType = 'organization')
  final String? organizationId; // ocd-organization/...
  final String? organizationName;
  final String? organizationClassification; // 'committee', etc.

  // MOYD Integration
  final String? linkedMemberId; // Link to MOYD members table

  // Legislator link (populated when fetched with join)
  final String? legislatorId;
  final Legislator? legislator;

  BillSponsor({
    required this.id,
    required this.createdAt,
    required this.billId,
    this.openstatesSponsorshipId,
    required this.name,
    this.entityType = 'person',
    this.isPrimary = false,
    this.sponsorshipClassification,
    this.openstatesPersonId,
    this.party,
    this.roleTitle,
    this.roleOrgClassification,
    this.district,
    this.divisionId,
    this.chamber,
    this.organizationId,
    this.organizationName,
    this.organizationClassification,
    this.linkedMemberId,
    this.legislatorId,
    this.legislator,
  });

  factory BillSponsor.fromJson(Map<String, dynamic> json) {
    // Parse legislator if included in the join
    Legislator? legislator;
    final legislatorData = json['legislator'];
    if (legislatorData != null && legislatorData is Map<String, dynamic>) {
      legislator = Legislator.fromJson(legislatorData);
    }

    return BillSponsor(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      billId: json['bill_id'] as String,
      openstatesSponsorshipId: json['openstates_sponsorship_id'] as String?,
      name: json['name'] as String,
      entityType: json['entity_type'] as String? ?? 'person',
      isPrimary: _coerceBool(json['is_primary']),
      sponsorshipClassification: json['sponsorship_classification'] as String?,
      openstatesPersonId: json['openstates_person_id'] as String?,
      party: json['party'] as String?,
      roleTitle: json['role_title'] as String?,
      roleOrgClassification: json['role_org_classification'] as String?,
      district: json['district'] as String?,
      divisionId: json['division_id'] as String?,
      chamber: json['chamber'] as String?,
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      organizationClassification: json['organization_classification'] as String?,
      linkedMemberId: json['linked_member_id'] as String?,
      legislatorId: json['legislator_id'] as String?,
      legislator: legislator,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'bill_id': billId,
      'openstates_sponsorship_id': openstatesSponsorshipId,
      'name': name,
      'entity_type': entityType,
      'is_primary': isPrimary,
      'sponsorship_classification': sponsorshipClassification,
      'openstates_person_id': openstatesPersonId,
      'party': party,
      'role_title': roleTitle,
      'role_org_classification': roleOrgClassification,
      'district': district,
      'division_id': divisionId,
      'chamber': chamber,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_classification': organizationClassification,
      'linked_member_id': linkedMemberId,
      'legislator_id': legislatorId,
      if (legislator != null) 'legislator': legislator!.toJson(),
    };
  }

  BillSponsor copyWith({
    String? id,
    DateTime? createdAt,
    String? billId,
    String? openstatesSponsorshipId,
    String? name,
    String? entityType,
    bool? isPrimary,
    String? sponsorshipClassification,
    String? openstatesPersonId,
    String? party,
    String? roleTitle,
    String? roleOrgClassification,
    String? district,
    String? divisionId,
    String? chamber,
    String? organizationId,
    String? organizationName,
    String? organizationClassification,
    String? linkedMemberId,
    String? legislatorId,
    Legislator? legislator,
  }) {
    return BillSponsor(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      billId: billId ?? this.billId,
      openstatesSponsorshipId: openstatesSponsorshipId ?? this.openstatesSponsorshipId,
      name: name ?? this.name,
      entityType: entityType ?? this.entityType,
      isPrimary: isPrimary ?? this.isPrimary,
      sponsorshipClassification: sponsorshipClassification ?? this.sponsorshipClassification,
      openstatesPersonId: openstatesPersonId ?? this.openstatesPersonId,
      party: party ?? this.party,
      roleTitle: roleTitle ?? this.roleTitle,
      roleOrgClassification: roleOrgClassification ?? this.roleOrgClassification,
      district: district ?? this.district,
      divisionId: divisionId ?? this.divisionId,
      chamber: chamber ?? this.chamber,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationClassification: organizationClassification ?? this.organizationClassification,
      linkedMemberId: linkedMemberId ?? this.linkedMemberId,
      legislatorId: legislatorId ?? this.legislatorId,
      legislator: legislator ?? this.legislator,
    );
  }

  /// Get a readable chamber name
  String get chamberDisplay {
    switch (chamber?.toLowerCase() ?? roleOrgClassification?.toLowerCase()) {
      case 'lower':
        return 'House';
      case 'upper':
        return 'Senate';
      default:
        return '';
    }
  }

  /// Get a display string for the sponsor
  String get displayName {
    final parts = <String>[name];
    if (party != null) {
      parts.add('($party)');
    }
    if (district != null) {
      parts.add('District $district');
    }
    return parts.join(' - ');
  }

  /// Whether this is a person sponsor (vs organization)
  bool get isPerson => entityType == 'person';

  /// Whether this is an organization sponsor
  bool get isOrganization => entityType == 'organization';
}
