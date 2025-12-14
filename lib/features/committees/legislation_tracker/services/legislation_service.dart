import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tracked_bill.dart';
import '../models/bill_action.dart';
import '../models/bill_vote.dart';
import '../models/bill_sponsor.dart';
import '../models/bill_note.dart';
import '../models/bill_document.dart';
import '../models/legislation_category.dart';
import '../models/legislator.dart';
import 'openstates_service.dart' hide Legislator;

/// Service for managing tracked legislation in Supabase
class LegislationService {
  LegislationService._internal();
  static final LegislationService _instance = LegislationService._internal();
  factory LegislationService() => _instance;

  SupabaseClient get _supabase => Supabase.instance.client;

  // ==================== TRACKED BILLS ====================

  /// Get all tracked bills with optional filters
  Future<List<TrackedBill>> getTrackedBills({
    String? session,
    String? position,
    String? priority,
    String? category,
    String? sponsor,
    bool includeArchived = false,
    String? searchQuery,
    bool searchBillText = false,
    int limit = 5000,
  }) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select();

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }
    if (session != null) {
      query = query.eq('session', session);
    }
    if (position != null) {
      query = query.eq('position', position);
    }
    if (priority != null) {
      query = query.eq('priority', priority);
    }
    if (category != null) {
      query = query.contains('categories', [category]);
    }
    if (sponsor != null) {
      query = query.eq('primary_sponsor_name', sponsor);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      if (searchBillText) {
        // Search in title, bill identifier, and bill text
        query = query.or('title.ilike.%$searchQuery%,bill_identifier.ilike.%$searchQuery%,current_bill_text.ilike.%$searchQuery%');
      } else {
        // Search in title and bill identifier only
        query = query.or('title.ilike.%$searchQuery%,bill_identifier.ilike.%$searchQuery%');
      }
    }

    final response = await query
        .order('priority', ascending: true) // critical first
        .order('latest_action_date', ascending: false)
        .limit(limit);

    return (response as List).map((json) => TrackedBill.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get a single tracked bill by ID
  Future<TrackedBill?> getTrackedBill(String id) async {
    final response = await _supabase
        .from('legislation_tracked_bills')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? TrackedBill.fromJson(response) : null;
  }

  /// Get a tracked bill by Open States ID
  Future<TrackedBill?> getTrackedBillByOpenstatesId(String openstatesId) async {
    final response = await _supabase
        .from('legislation_tracked_bills')
        .select()
        .eq('openstates_bill_id', openstatesId)
        .maybeSingle();

    return response != null ? TrackedBill.fromJson(response) : null;
  }

  /// Check if a bill is already tracked
  Future<bool> isBillTracked(String openstatesId) async {
    final result = await getTrackedBillByOpenstatesId(openstatesId);
    return result != null;
  }

  /// Add a new bill to track
  Future<TrackedBill> trackBill({
    required String openstatesBillId,
    required String session,
    required String billIdentifier,
    required String title,
    String? description,
    String? billType,
    String? chamber,
    String? latestActionDate,
    String? latestActionDescription,
    String? primarySponsorName,
    String? primarySponsorParty,
    int sponsorCount = 0,
    String position = 'watching',
    String priority = 'medium',
    List<String> categories = const [],
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final response = await _supabase.from('legislation_tracked_bills').insert({
      'openstates_bill_id': openstatesBillId,
      'jurisdiction': 'mo',
      'session': session,
      'bill_identifier': billIdentifier,
      'title': title,
      'description': description,
      'chamber': chamber,
      'latest_action_date': latestActionDate,
      'latest_action_description': latestActionDescription,
      'primary_sponsor_name': primarySponsorName,
      'primary_sponsor_party': primarySponsorParty,
      'sponsor_count': sponsorCount,
      'position': position,
      'priority': priority,
      'categories': categories,
      'added_by': userId,
    }).select().single();

    return TrackedBill.fromJson(response);
  }

  /// Track a bill from an OpenStatesBillSummary
  Future<TrackedBill> trackBillFromSummary({
    required OpenStatesBillSummary bill,
    String position = 'watching',
    String priority = 'medium',
    List<String> categories = const [],
  }) async {
    return trackBill(
      openstatesBillId: bill.openstatesBillId,
      session: bill.session,
      billIdentifier: bill.billIdentifier,
      title: bill.title,
      description: bill.description,
      billType: bill.billType,
      chamber: bill.chamber,
      latestActionDate: bill.latestActionDate,
      latestActionDescription: bill.latestActionDescription,
      primarySponsorName: bill.primarySponsor,
      sponsorCount: bill.sponsorCount,
      position: position,
      priority: priority,
      categories: categories,
    );
  }

  /// Update bill position
  Future<TrackedBill> updatePosition({
    required String billId,
    required String position,
    String? rationale,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final response = await _supabase.from('legislation_tracked_bills').update({
      'position': position,
      'position_set_by': userId,
      'position_set_at': DateTime.now().toIso8601String(),
      'position_rationale': rationale,
    }).eq('id', billId).select().single();

    return TrackedBill.fromJson(response);
  }

  /// Update bill priority
  Future<TrackedBill> updatePriority({
    required String billId,
    required String priority,
  }) async {
    final response = await _supabase.from('legislation_tracked_bills').update({
      'priority': priority,
    }).eq('id', billId).select().single();

    return TrackedBill.fromJson(response);
  }

  /// Update bill categories
  Future<TrackedBill> updateCategories({
    required String billId,
    required List<String> categories,
  }) async {
    final response = await _supabase.from('legislation_tracked_bills').update({
      'categories': categories,
    }).eq('id', billId).select().single();

    return TrackedBill.fromJson(response);
  }

  /// Update bill tags
  Future<TrackedBill> updateTags({
    required String billId,
    required List<String> tags,
  }) async {
    final response = await _supabase.from('legislation_tracked_bills').update({
      'tags': tags,
    }).eq('id', billId).select().single();

    return TrackedBill.fromJson(response);
  }

  /// Archive a bill
  Future<void> archiveBill({
    required String billId,
    String? reason,
  }) async {
    await _supabase.from('legislation_tracked_bills').update({
      'is_archived': true,
      'archived_at': DateTime.now().toIso8601String(),
      'archived_reason': reason,
    }).eq('id', billId);
  }

  /// Unarchive a bill
  Future<void> unarchiveBill(String billId) async {
    await _supabase.from('legislation_tracked_bills').update({
      'is_archived': false,
      'archived_at': null,
      'archived_reason': null,
    }).eq('id', billId);
  }

  /// Delete a tracked bill
  Future<void> deleteTrackedBill(String billId) async {
    await _supabase.from('legislation_tracked_bills').delete().eq('id', billId);
  }

  // ==================== BILL ACTIONS ====================

  /// Get actions for a bill
  Future<List<BillAction>> getBillActions(String billId) async {
    final response = await _supabase
        .from('legislation_bill_actions')
        .select()
        .eq('bill_id', billId)
        .order('action_date', ascending: false)
        .order('action_order', ascending: false);

    return (response as List).map((json) => BillAction.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Mark actions as read
  Future<void> markActionsAsRead(String billId) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase
        .from('legislation_bill_actions')
        .update({
          'is_read': true,
          'read_by': userId,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('bill_id', billId)
        .eq('is_read', false);
  }

  /// Mark actions as seen (not new)
  Future<void> markActionsAsSeen(String billId) async {
    await _supabase
        .from('legislation_bill_actions')
        .update({'is_new': false})
        .eq('bill_id', billId);
  }

  // ==================== BILL VOTES ====================

  /// Get votes for a bill
  Future<List<BillVote>> getBillVotes(String billId) async {
    final response = await _supabase
        .from('legislation_bill_votes')
        .select()
        .eq('bill_id', billId)
        .order('vote_date', ascending: false);

    return (response as List).map((json) => BillVote.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Mark votes as read
  Future<void> markVotesAsRead(String billId) async {
    final userId = _supabase.auth.currentUser?.id;
    await _supabase
        .from('legislation_bill_votes')
        .update({
          'is_read': true,
          'read_by': userId,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('bill_id', billId)
        .eq('is_read', false);
  }

  /// Mark votes as seen (not new)
  Future<void> markVotesAsSeen(String billId) async {
    await _supabase
        .from('legislation_bill_votes')
        .update({'is_new': false})
        .eq('bill_id', billId);
  }

  // ==================== BILL SPONSORS ====================

  /// Get sponsors for a bill
  Future<List<BillSponsor>> getBillSponsors(String billId) async {
    final response = await _supabase
        .from('legislation_bill_sponsors')
        .select()
        .eq('bill_id', billId)
        .order('is_primary', ascending: false);

    return (response as List).map((json) => BillSponsor.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get sponsors for a bill with linked legislator data
  Future<List<BillSponsor>> getBillSponsorsWithLegislators(String billId) async {
    final response = await _supabase
        .from('legislation_bill_sponsors')
        .select('*, legislator:legislator_id(*)')
        .eq('bill_id', billId)
        .order('is_primary', ascending: false);

    return (response as List).map((json) => BillSponsor.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ==================== LEGISLATORS ====================

  /// Get all current legislators
  Future<List<Legislator>> getAllLegislators() async {
    final response = await _supabase
        .from('legislation_legislators')
        .select()
        .eq('is_current', true)
        .order('chamber')
        .order('district');

    return (response as List).map((json) => Legislator.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get legislators by chamber
  Future<List<Legislator>> getLegislatorsByChamber(String chamber) async {
    final response = await _supabase
        .from('legislation_legislators')
        .select()
        .eq('chamber', chamber) // 'upper' or 'lower'
        .eq('is_current', true)
        .order('district');

    return (response as List).map((json) => Legislator.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get a single legislator by ID
  Future<Legislator?> getLegislator(String id) async {
    final response = await _supabase
        .from('legislation_legislators')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? Legislator.fromJson(response) : null;
  }

  /// Get legislator by district
  Future<Legislator?> getLegislatorByDistrict(String chamber, String district) async {
    final response = await _supabase
        .from('legislation_legislators')
        .select()
        .eq('chamber', chamber)
        .eq('district', district)
        .eq('is_current', true)
        .maybeSingle();

    return response != null ? Legislator.fromJson(response) : null;
  }

  /// Search legislators by name
  Future<List<Legislator>> searchLegislators(String query) async {
    final response = await _supabase
        .from('legislation_legislators')
        .select()
        .eq('is_current', true)
        .or('name.ilike.%$query%,last_name.ilike.%$query%,first_name.ilike.%$query%')
        .order('last_name');

    return (response as List).map((json) => Legislator.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get legislators with filters
  Future<List<Legislator>> getLegislatorsFiltered({
    String? chamber,
    String? party,
    String? searchQuery,
    bool? hasLeadershipRole,
    int limit = 200,
  }) async {
    var query = _supabase
        .from('legislation_legislators')
        .select()
        .eq('is_current', true);

    if (chamber != null) {
      query = query.eq('chamber', chamber);
    }
    if (party != null) {
      query = query.eq('party', party);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('name.ilike.%$searchQuery%,last_name.ilike.%$searchQuery%,first_name.ilike.%$searchQuery%');
    }
    if (hasLeadershipRole == true) {
      query = query.not('leadership_role', 'is', null);
    }

    final response = await query
        .order('chamber')
        .order('district')
        .limit(limit);

    return (response as List).map((json) => Legislator.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get bills sponsored by a legislator
  Future<List<TrackedBill>> getBillsBySponsor(String legislatorId) async {
    // Get bill IDs where this legislator is a sponsor
    final sponsorships = await _supabase
        .from('legislation_bill_sponsors')
        .select('bill_id')
        .eq('legislator_id', legislatorId);

    if ((sponsorships as List).isEmpty) {
      return [];
    }

    final billIds = sponsorships.map((s) => s['bill_id'] as String).toList();

    final response = await _supabase
        .from('legislation_tracked_bills')
        .select()
        .inFilter('id', billIds)
        .order('latest_action_date', ascending: false);

    return (response as List).map((json) => TrackedBill.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Update legislator biography
  Future<Legislator?> updateLegislatorBiography({
    required String legislatorId,
    required String biography,
  }) async {
    final response = await _supabase
        .from('legislation_legislators')
        .update({'biography': biography})
        .eq('id', legislatorId)
        .select()
        .maybeSingle();

    return response != null ? Legislator.fromJson(response) : null;
  }

  /// Upload legislator photo to storage and update record
  Future<Legislator?> uploadLegislatorPhoto({
    required String legislatorId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    // Generate unique storage path
    final extension = fileName.split('.').last.toLowerCase();
    final storagePath = '$legislatorId.$extension';

    // Upload to legislator-photos bucket
    await _supabase.storage.from('legislator-photos').uploadBinary(
      storagePath,
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true),
    );

    // Update legislator record with storage path
    final response = await _supabase
        .from('legislation_legislators')
        .update({'photo_storage_path': storagePath})
        .eq('id', legislatorId)
        .select()
        .maybeSingle();

    return response != null ? Legislator.fromJson(response) : null;
  }

  /// Get legislator statistics
  Future<LegislatorStats> getLegislatorStats() async {
    final legislators = await getAllLegislators();

    int senateCount = 0;
    int houseCount = 0;
    int republicanCount = 0;
    int democratCount = 0;
    int withLeadershipCount = 0;
    int withPhotosCount = 0;

    for (final leg in legislators) {
      if (leg.chamber == 'upper') senateCount++;
      if (leg.chamber == 'lower') houseCount++;
      if (leg.party == 'Republican') republicanCount++;
      if (leg.party == 'Democratic') democratCount++;
      if (leg.leadershipRole != null) withLeadershipCount++;
      if (leg.photoStoragePath != null) withPhotosCount++;
    }

    return LegislatorStats(
      totalLegislators: legislators.length,
      senateCount: senateCount,
      houseCount: houseCount,
      republicanCount: republicanCount,
      democratCount: democratCount,
      withLeadershipCount: withLeadershipCount,
      withPhotosCount: withPhotosCount,
    );
  }

  // ==================== BILL DOCUMENTS ====================

  /// Get documents for a bill
  Future<List<BillDocument>> getBillDocuments(String billId) async {
    final response = await _supabase
        .from('legislation_bill_documents')
        .select()
        .eq('bill_id', billId)
        .order('document_date', ascending: false);

    return (response as List).map((json) => BillDocument.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get versions for a bill
  Future<List<BillDocument>> getBillVersions(String billId) async {
    final response = await _supabase
        .from('legislation_bill_documents')
        .select()
        .eq('bill_id', billId)
        .eq('document_type', 'version')
        .order('document_date', ascending: false);

    return (response as List).map((json) => BillDocument.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ==================== BILL NOTES ====================

  /// Get notes for a bill
  Future<List<BillNote>> getBillNotes(String billId) async {
    final response = await _supabase
        .from('legislation_bill_notes')
        .select('*, members!author_id(id, name, profile_pictures)')
        .eq('bill_id', billId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final authorData = json['members'];
      final Map<String, dynamic> noteJson = Map<String, dynamic>.from(json);
      noteJson.remove('members');
      if (authorData != null && authorData is Map) {
        noteJson['author_name'] = authorData['name'];
        // Handle profile pictures - get first photo URL if available
        final profilePics = authorData['profile_pictures'];
        if (profilePics is List && profilePics.isNotEmpty) {
          final firstPic = profilePics.first;
          if (firstPic is Map) {
            noteJson['author_avatar_url'] = firstPic['public_url'] ?? firstPic['url'];
          }
        }
      }
      return BillNote.fromJson(noteJson);
    }).toList();
  }

  /// Add a note to a bill
  Future<BillNote> addNote({
    required String billId,
    required String content,
    String noteType = 'general',
    bool isPinned = false,
    bool isInternal = true,
    List<String> mentionedMemberIds = const [],
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase.from('legislation_bill_notes').insert({
      'bill_id': billId,
      'author_id': userId,
      'content': content,
      'note_type': noteType,
      'is_pinned': isPinned,
      'is_internal': isInternal,
      'mentioned_member_ids': mentionedMemberIds,
    }).select().single();

    return BillNote.fromJson(response);
  }

  /// Update a note
  Future<BillNote> updateNote({
    required String noteId,
    String? content,
    String? noteType,
    bool? isPinned,
    bool? isInternal,
  }) async {
    final updates = <String, dynamic>{};
    if (content != null) updates['content'] = content;
    if (noteType != null) updates['note_type'] = noteType;
    if (isPinned != null) updates['is_pinned'] = isPinned;
    if (isInternal != null) updates['is_internal'] = isInternal;

    final response = await _supabase
        .from('legislation_bill_notes')
        .update(updates)
        .eq('id', noteId)
        .select()
        .single();

    return BillNote.fromJson(response);
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    await _supabase.from('legislation_bill_notes').delete().eq('id', noteId);
  }

  // ==================== CATEGORIES ====================

  /// Get all categories
  Future<List<LegislationCategory>> getCategories() async {
    final response = await _supabase
        .from('legislation_categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');

    return (response as List).map((json) => LegislationCategory.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ==================== STATISTICS ====================

  /// Get legislation statistics
  Future<LegislationStats> getStatistics({String? session}) async {
    try {
      final response = await _supabase.rpc(
        'get_legislation_statistics',
        params: {'session_filter': session},
      );

      if (response is List && response.isNotEmpty) {
        return LegislationStats.fromJson(response.first as Map<String, dynamic>);
      }
      return LegislationStats.empty();
    } catch (e) {
      // If the RPC doesn't exist, calculate manually
      return _calculateStatisticsManually(session: session);
    }
  }

  /// Calculate statistics manually if RPC not available
  Future<LegislationStats> _calculateStatisticsManually({String? session}) async {
    // Use a very high limit to get all bills (Supabase default is 1000)
    var query = _supabase
        .from('legislation_tracked_bills')
        .select()
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }

    // Set limit to 10000 to ensure we get all bills
    final bills = await query.limit(10000);
    final billList = bills as List;

    int supportCount = 0;
    int opposeCount = 0;
    int watchingCount = 0;
    int criticalCount = 0;
    int highCount = 0;
    int passedLowerCount = 0;
    int passedUpperCount = 0;
    int signedCount = 0;
    int vetoedCount = 0;

    for (final bill in billList) {
      final position = bill['position'] as String?;
      final priority = bill['priority'] as String?;

      if (position == 'support') supportCount++;
      if (position == 'oppose') opposeCount++;
      if (position == 'watching') watchingCount++;

      if (priority == 'critical') criticalCount++;
      if (priority == 'high') highCount++;

      if (bill['passed_lower'] == true) passedLowerCount++;
      if (bill['passed_upper'] == true) passedUpperCount++;
      if (bill['signed_by_governor'] == true) signedCount++;
      if (bill['vetoed'] == true) vetoedCount++;
    }

    return LegislationStats(
      totalTracked: billList.length,
      supportCount: supportCount,
      opposeCount: opposeCount,
      watchingCount: watchingCount,
      criticalCount: criticalCount,
      highCount: highCount,
      passedLowerCount: passedLowerCount,
      passedUpperCount: passedUpperCount,
      signedCount: signedCount,
      vetoedCount: vetoedCount,
    );
  }

  // ==================== SYNC LOG ====================

  /// Get recent sync logs
  Future<List<SyncLog>> getSyncLogs({int limit = 10}) async {
    final response = await _supabase
        .from('legislation_sync_log')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => SyncLog.fromJson(json as Map<String, dynamic>)).toList();
  }
}

// Statistics model
class LegislationStats {
  final int totalTracked;
  final int supportCount;
  final int opposeCount;
  final int watchingCount;
  final int criticalCount;
  final int highCount;
  final int passedLowerCount;
  final int passedUpperCount;
  final int signedCount;
  final int vetoedCount;

  LegislationStats({
    required this.totalTracked,
    required this.supportCount,
    required this.opposeCount,
    required this.watchingCount,
    required this.criticalCount,
    required this.highCount,
    required this.passedLowerCount,
    required this.passedUpperCount,
    required this.signedCount,
    required this.vetoedCount,
  });

  factory LegislationStats.fromJson(Map<String, dynamic> json) {
    return LegislationStats(
      totalTracked: json['total_tracked'] as int? ?? 0,
      supportCount: json['support_count'] as int? ?? 0,
      opposeCount: json['oppose_count'] as int? ?? 0,
      watchingCount: json['watching_count'] as int? ?? 0,
      criticalCount: json['critical_count'] as int? ?? 0,
      highCount: json['high_count'] as int? ?? 0,
      passedLowerCount: json['passed_lower_count'] as int? ?? 0,
      passedUpperCount: json['passed_upper_count'] as int? ?? 0,
      signedCount: json['signed_count'] as int? ?? 0,
      vetoedCount: json['vetoed_count'] as int? ?? 0,
    );
  }

  factory LegislationStats.empty() => LegislationStats(
    totalTracked: 0,
    supportCount: 0,
    opposeCount: 0,
    watchingCount: 0,
    criticalCount: 0,
    highCount: 0,
    passedLowerCount: 0,
    passedUpperCount: 0,
    signedCount: 0,
    vetoedCount: 0,
  );

  Map<String, dynamic> toJson() {
    return {
      'total_tracked': totalTracked,
      'support_count': supportCount,
      'oppose_count': opposeCount,
      'watching_count': watchingCount,
      'critical_count': criticalCount,
      'high_count': highCount,
      'passed_lower_count': passedLowerCount,
      'passed_upper_count': passedUpperCount,
      'signed_count': signedCount,
      'vetoed_count': vetoedCount,
    };
  }

  // Alias getters for UI compatibility
  int get totalBills => totalTracked;
  int get activeBills => totalTracked; // Tracked bills are active
  int get criticalBills => criticalCount;
  int get supportBills => supportCount;
  int get opposeBills => opposeCount;
  int get watchingBills => watchingCount;
  int get newActionsThisWeek => 0; // Not tracked currently
  int get recentVotesCount => 0; // Not tracked currently
}

// Sync log model
class SyncLog {
  final int id;
  final DateTime createdAt;
  final String syncType;
  final String status;
  final int billsChecked;
  final int billsUpdated;
  final int newActionsFound;
  final int newVotesFound;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMs;

  SyncLog({
    required this.id,
    required this.createdAt,
    required this.syncType,
    required this.status,
    required this.billsChecked,
    required this.billsUpdated,
    required this.newActionsFound,
    required this.newVotesFound,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
    this.durationMs,
  });

  factory SyncLog.fromJson(Map<String, dynamic> json) {
    return SyncLog(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      syncType: json['sync_type'] as String? ?? 'manual',
      status: json['status'] as String? ?? 'unknown',
      billsChecked: json['bills_checked'] as int? ?? 0,
      billsUpdated: json['bills_updated'] as int? ?? 0,
      newActionsFound: json['new_actions_found'] as int? ?? 0,
      newVotesFound: json['new_votes_found'] as int? ?? 0,
      errorMessage: json['error_message'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String? ?? json['created_at'] as String),
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      durationMs: json['duration_ms'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'sync_type': syncType,
      'status': status,
      'bills_checked': billsChecked,
      'bills_updated': billsUpdated,
      'new_actions_found': newActionsFound,
      'new_votes_found': newVotesFound,
      'error_message': errorMessage,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'duration_ms': durationMs,
    };
  }
}

/// Legislator statistics
class LegislatorStats {
  final int totalLegislators;
  final int senateCount;
  final int houseCount;
  final int republicanCount;
  final int democratCount;
  final int withLeadershipCount;
  final int withPhotosCount;

  LegislatorStats({
    required this.totalLegislators,
    required this.senateCount,
    required this.houseCount,
    required this.republicanCount,
    required this.democratCount,
    required this.withLeadershipCount,
    required this.withPhotosCount,
  });

  factory LegislatorStats.empty() => LegislatorStats(
    totalLegislators: 0,
    senateCount: 0,
    houseCount: 0,
    republicanCount: 0,
    democratCount: 0,
    withLeadershipCount: 0,
    withPhotosCount: 0,
  );
}
