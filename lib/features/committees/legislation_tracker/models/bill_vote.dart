/// Represents a vote on a bill
/// CAPTURES ALL Open States API v3 VoteEvent fields
class BillVote {
  final String id;
  final DateTime createdAt;
  final String billId;

  // Open States Identifiers
  final String openstatesVoteId; // ocd-vote/...
  final String? voteIdentifier; // "HV #3312", "SV #1234" - official vote number

  // Vote Details
  final DateTime voteDate; // start_date from API
  final String motionText; // "Shall the bill be passed?"
  final List<String> motionClassification; // ['passage', 'amendment']
  final String result; // 'pass' or 'fail'

  // Organization that held the vote
  final String? organizationId; // ocd-organization/...
  final String? organizationName; // "Missouri House of Representatives"
  final String? organizationClassification; // 'lower', 'upper', 'legislature'
  final String? chamber; // Legacy: 'lower', 'upper'

  // Vote Counts
  final int yesCount;
  final int noCount;
  final int abstainCount;
  final int notVotingCount;
  final int absentCount;
  final int excusedCount;
  final int otherCount;
  final List<Map<String, dynamic>>? countsDetail; // Full counts array

  // Individual Votes
  final List<VoteDetail>? votesDetail;

  // Sources & Extras
  final List<Map<String, dynamic>>? sources;
  final Map<String, dynamic>? extras;

  // MOYD Tracking
  final bool isNew;
  final DateTime? firstSeenAt;
  final bool isRead;
  final String? readBy;
  final DateTime? readAt;

  BillVote({
    required this.id,
    required this.createdAt,
    required this.billId,
    required this.openstatesVoteId,
    this.voteIdentifier,
    required this.voteDate,
    required this.motionText,
    this.motionClassification = const [],
    required this.result,
    this.organizationId,
    this.organizationName,
    this.organizationClassification,
    this.chamber,
    this.yesCount = 0,
    this.noCount = 0,
    this.abstainCount = 0,
    this.notVotingCount = 0,
    this.absentCount = 0,
    this.excusedCount = 0,
    this.otherCount = 0,
    this.countsDetail,
    this.votesDetail,
    this.sources,
    this.extras,
    this.isNew = false,
    this.firstSeenAt,
    this.isRead = false,
    this.readBy,
    this.readAt,
  });

  factory BillVote.fromJson(Map<String, dynamic> json) {
    return BillVote(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      billId: json['bill_id'] as String,
      openstatesVoteId: json['openstates_vote_id'] as String,
      voteIdentifier: json['vote_identifier'] as String?,
      voteDate: DateTime.parse(json['vote_date'] as String),
      motionText: json['motion_text'] as String,
      motionClassification: _parseStringList(json['motion_classification']),
      result: json['result'] as String,
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      organizationClassification: json['organization_classification'] as String?,
      chamber: json['chamber'] as String?,
      yesCount: json['yes_count'] as int? ?? 0,
      noCount: json['no_count'] as int? ?? 0,
      abstainCount: json['abstain_count'] as int? ?? 0,
      notVotingCount: json['not_voting_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      excusedCount: json['excused_count'] as int? ?? 0,
      otherCount: json['other_count'] as int? ?? 0,
      countsDetail: _parseMapList(json['counts_detail']),
      votesDetail: _parseVoteDetails(json['votes_detail']),
      sources: _parseMapList(json['sources']),
      extras: json['extras'] as Map<String, dynamic>?,
      isNew: json['is_new'] as bool? ?? false,
      firstSeenAt: _parseDate(json['first_seen_at']),
      isRead: json['is_read'] as bool? ?? false,
      readBy: json['read_by'] as String?,
      readAt: _parseDate(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'bill_id': billId,
      'openstates_vote_id': openstatesVoteId,
      'vote_identifier': voteIdentifier,
      'vote_date': voteDate.toIso8601String(),
      'motion_text': motionText,
      'motion_classification': motionClassification,
      'result': result,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_classification': organizationClassification,
      'chamber': chamber,
      'yes_count': yesCount,
      'no_count': noCount,
      'abstain_count': abstainCount,
      'not_voting_count': notVotingCount,
      'absent_count': absentCount,
      'excused_count': excusedCount,
      'other_count': otherCount,
      'counts_detail': countsDetail,
      'votes_detail': votesDetail?.map((v) => v.toJson()).toList(),
      'sources': sources,
      'extras': extras,
      'is_new': isNew,
      'first_seen_at': firstSeenAt?.toIso8601String(),
      'is_read': isRead,
      'read_by': readBy,
      'read_at': readAt?.toIso8601String(),
    };
  }

  BillVote copyWith({
    String? id,
    DateTime? createdAt,
    String? billId,
    String? openstatesVoteId,
    String? voteIdentifier,
    DateTime? voteDate,
    String? motionText,
    List<String>? motionClassification,
    String? result,
    String? organizationId,
    String? organizationName,
    String? organizationClassification,
    String? chamber,
    int? yesCount,
    int? noCount,
    int? abstainCount,
    int? notVotingCount,
    int? absentCount,
    int? excusedCount,
    int? otherCount,
    List<Map<String, dynamic>>? countsDetail,
    List<VoteDetail>? votesDetail,
    List<Map<String, dynamic>>? sources,
    Map<String, dynamic>? extras,
    bool? isNew,
    DateTime? firstSeenAt,
    bool? isRead,
    String? readBy,
    DateTime? readAt,
  }) {
    return BillVote(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      billId: billId ?? this.billId,
      openstatesVoteId: openstatesVoteId ?? this.openstatesVoteId,
      voteIdentifier: voteIdentifier ?? this.voteIdentifier,
      voteDate: voteDate ?? this.voteDate,
      motionText: motionText ?? this.motionText,
      motionClassification: motionClassification ?? this.motionClassification,
      result: result ?? this.result,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      organizationClassification: organizationClassification ?? this.organizationClassification,
      chamber: chamber ?? this.chamber,
      yesCount: yesCount ?? this.yesCount,
      noCount: noCount ?? this.noCount,
      abstainCount: abstainCount ?? this.abstainCount,
      notVotingCount: notVotingCount ?? this.notVotingCount,
      absentCount: absentCount ?? this.absentCount,
      excusedCount: excusedCount ?? this.excusedCount,
      otherCount: otherCount ?? this.otherCount,
      countsDetail: countsDetail ?? this.countsDetail,
      votesDetail: votesDetail ?? this.votesDetail,
      sources: sources ?? this.sources,
      extras: extras ?? this.extras,
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
      default:
        return organizationName ?? 'Unknown';
    }
  }

  /// Whether the vote passed
  bool get passed => result.toLowerCase() == 'pass';

  /// Total votes cast
  int get totalVotes => yesCount + noCount + abstainCount + notVotingCount + absentCount + excusedCount + otherCount;

  /// Votes by party (if vote details available)
  Map<String, Map<String, int>> get votesByParty {
    final result = <String, Map<String, int>>{};
    if (votesDetail == null) return result;

    for (final vote in votesDetail!) {
      final party = vote.party ?? 'Unknown';
      final option = vote.option.toLowerCase();

      result.putIfAbsent(party, () => {});
      result[party]![option] = (result[party]![option] ?? 0) + 1;
    }

    return result;
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

  static List<VoteDetail>? _parseVoteDetails(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => VoteDetail.fromJson(e as Map<String, dynamic>)).toList();
    }
    return null;
  }
}

/// Individual vote record with full voter info
class VoteDetail {
  final String? id;
  final String voterName;
  final String option; // 'yes', 'no', 'abstain', etc.
  final String? party;
  final String? voterId; // ocd-person/...
  final String? voterNameFull;
  final Map<String, dynamic>? currentRole; // Full role info

  VoteDetail({
    this.id,
    required this.voterName,
    required this.option,
    this.party,
    this.voterId,
    this.voterNameFull,
    this.currentRole,
  });

  factory VoteDetail.fromJson(Map<String, dynamic> json) {
    return VoteDetail(
      id: json['id'] as String?,
      voterName: json['voter_name'] as String? ?? json['name'] as String? ?? 'Unknown',
      option: json['option'] as String? ?? json['vote'] as String? ?? 'unknown',
      party: json['party'] as String?,
      voterId: json['voter_id'] as String?,
      voterNameFull: json['voter_name_full'] as String?,
      currentRole: json['current_role'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'voter_name': voterName,
      'option': option,
      'party': party,
      'voter_id': voterId,
      'voter_name_full': voterNameFull,
      'current_role': currentRole,
    };
  }
}
