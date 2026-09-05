// ═══════════════════════════════════════════════════════════════
//  CANDIDATE MEMBER LINKS. Maps to public.candidate_member_links.
//  Which members form the volunteer base for a November nominee.
//  Pure data. No I/O; CandidateMemberLinkRepository owns Supabase.
// ═══════════════════════════════════════════════════════════════

/// One (candidate, member) link, as stored.
///
/// NOT the same relationship as `candidates.member_id`, which says "this
/// candidate IS this member" and is singular by construction. This says "this
/// member will work for this nominee" and is many-to-many. Nothing here should
/// ever be written to or read from that column (spec 5.1).
///
/// Area-wide links are materialized rather than resolved at read time: linking
/// a county wrote one row per member in it, all sharing [batchId] and stamped
/// with the region that produced them. So [sourceRegionMode] and
/// [sourceRegionId] describe the gesture that created the row, not a live
/// filter. A member who has since moved out of the county keeps their link
/// until someone removes it (spec 5.2).
class CandidateMemberLink {
  const CandidateMemberLink({
    required this.candidateId,
    required this.memberId,
    this.sourceRegionMode,
    this.sourceRegionId,
    this.batchId,
    this.note,
    this.createdByUserId,
    this.createdByMemberId,
    this.createdAt,
  });

  final String candidateId;
  final String memberId;

  /// 'county', 'congressional', 'senate' or 'house', which is `MapMode.name`.
  /// Null means the member was linked on their own, not as part of a region.
  /// Kept as the stored string so this model stays free of the map layer;
  /// `candidateLinkSourceMode` in the repository turns it back into a MapMode.
  final String? sourceRegionMode;

  /// County name, or bare-digit district number, matching the map's region
  /// keys. Null whenever [sourceRegionMode] is null.
  final String? sourceRegionId;

  /// Shared by every row one link gesture inserted, so that gesture can be
  /// named and undone as a unit. A one-member link is a batch of one.
  final String? batchId;

  final String? note;

  /// auth.users.id of the exec who made the link. NOT a members.id (spec 4.1).
  final String? createdByUserId;

  /// members.id of the exec who made the link. NOT an auth.users.id.
  final String? createdByMemberId;

  final DateTime? createdAt;

  bool get isFromRegion => sourceRegionMode != null && sourceRegionId != null;

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  factory CandidateMemberLink.fromJson(Map<String, dynamic> json) {
    return CandidateMemberLink(
      candidateId: json['candidate_id'] as String,
      memberId: json['member_id'] as String,
      sourceRegionMode: json['source_region_mode'] as String?,
      sourceRegionId: json['source_region_id'] as String?,
      batchId: json['batch_id'] as String?,
      note: json['note'] as String?,
      createdByUserId: json['created_by_user_id'] as String?,
      createdByMemberId: json['created_by_member_id'] as String?,
      createdAt: _date(json['created_at']),
    );
  }
}

/// One link gesture, folded up from the rows it inserted, so the CONNECT
/// section can say "Boone County, 42 members" and offer a single unlink or a
/// refresh without asking the database a second question.
///
/// Derived, never stored. [memberCount] is how many rows from that batch
/// SURVIVE, so it drops as individual members are unlinked. That is the point:
/// the count reflects the roster the exec actually has, not the size of the
/// original county.
class CandidateMemberLinkBatch {
  const CandidateMemberLinkBatch({
    required this.batchId,
    required this.candidateId,
    required this.memberCount,
    this.sourceRegionMode,
    this.sourceRegionId,
    this.createdByMemberId,
    this.createdAt,
  });

  final String batchId;
  final String candidateId;
  final int memberCount;
  final String? sourceRegionMode;
  final String? sourceRegionId;
  final String? createdByMemberId;
  final DateTime? createdAt;

  /// Group a candidate's links into the gestures that made them, newest first.
  /// Every link written through the repository carries a batch_id; a row
  /// without one was inserted outside the app and belongs to no gesture, so it
  /// is skipped rather than invented into a batch of its own.
  static List<CandidateMemberLinkBatch> groupFrom(
      List<CandidateMemberLink> links) {
    final counts = <String, int>{};
    final first = <String, CandidateMemberLink>{};

    for (final link in links) {
      final batchId = link.batchId;
      if (batchId == null) continue;
      counts[batchId] = (counts[batchId] ?? 0) + 1;
      // Every row in a batch carries the same provenance, so the first one
      // seen describes the whole batch.
      first.putIfAbsent(batchId, () => link);
    }

    final batches = <CandidateMemberLinkBatch>[
      for (final entry in counts.entries)
        CandidateMemberLinkBatch(
          batchId: entry.key,
          candidateId: first[entry.key]!.candidateId,
          memberCount: entry.value,
          sourceRegionMode: first[entry.key]!.sourceRegionMode,
          sourceRegionId: first[entry.key]!.sourceRegionId,
          createdByMemberId: first[entry.key]!.createdByMemberId,
          createdAt: first[entry.key]!.createdAt,
        ),
    ];

    batches.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return batches;
  }
}
