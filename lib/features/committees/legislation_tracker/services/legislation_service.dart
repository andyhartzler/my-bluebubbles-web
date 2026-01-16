import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
  /// Uses pagination to bypass Supabase's 1000 row limit
  Future<List<TrackedBill>> getTrackedBills({
    String? session,
    String? position,
    String? priority,
    String? category,
    String? sponsor,
    bool includeArchived = false,
    String? searchQuery,
    bool searchBillText = false,
    int limit = 2000,
  }) async {
    List<TrackedBill> allBills = [];
    int offset = 0;
    const batchSize = 500; // Reduced batch size for better reliability

    while (allBills.length < limit) {
      try {
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
            .range(offset, offset + batchSize - 1);

        final bills = (response as List)
            .map((json) => TrackedBill.fromJson(json as Map<String, dynamic>))
            .toList();

        allBills.addAll(bills);

        // If we got fewer than batchSize, we've reached the end
        if (bills.length < batchSize) {
          break;
        }

        offset += batchSize;
      } catch (e) {
        // If pagination fails, return what we have so far
        print('Error fetching bills at offset $offset: $e');
        break;
      }
    }

    // Apply limit if we fetched more than requested
    if (allBills.length > limit) {
      return allBills.sublist(0, limit);
    }

    return allBills;
  }

  /// Get a single tracked bill by ID
  Future<TrackedBill?> getTrackedBill(String id) async {
    // Get bill data without join (more reliable)
    final response = await _supabase
        .from('legislation_tracked_bills')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;

    // Try to get position setter info separately if set
    final positionSetBy = response['position_set_by'] as String?;
    if (positionSetBy != null && positionSetBy.isNotEmpty) {
      try {
        // Fetch member and slack mapping in parallel for speed
        final results = await Future.wait([
          _supabase
              .from('members')
              .select('id, name, profile_pictures')
              .eq('id', positionSetBy)
              .maybeSingle(),
          _supabase
              .from('slack_user_mapping')
              .select('cached_avatar_path')
              .eq('member_id', positionSetBy)
              .maybeSingle(),
        ]);

        final memberResponse = results[0];
        final slackMapping = results[1];

        if (memberResponse != null) {
          final Map<String, dynamic> setter = Map<String, dynamic>.from(memberResponse);

          // Check if member has profile_pictures
          final profilePics = setter['profile_pictures'];
          bool hasProfilePic = profilePics is List && profilePics.isNotEmpty;

          // If no profile picture, use slack avatar
          if (!hasProfilePic && slackMapping != null && slackMapping['cached_avatar_path'] != null) {
            setter['slack_cached_avatar'] =
                'https://faajpcarasilbfndzkmd.supabase.co/storage/v1/object/public/avatars/${slackMapping['cached_avatar_path']}';
          }

          response['position_setter'] = setter;
        }
      } catch (e) {
        // Ignore - position setter info is optional
        debugPrint('Could not fetch position setter: $e');
      }
    }

    return TrackedBill.fromJson(response);
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
  /// [memberId] is the ID of the member setting the position (from members table)
  Future<TrackedBill> updatePosition({
    required String billId,
    required String position,
    String? memberId,
    String? rationale,
  }) async {
    final response = await _supabase.from('legislation_tracked_bills').update({
      'position': position,
      'position_set_by': memberId,
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
  /// Only fetches essential legislator columns for faster loading
  Future<List<BillSponsor>> getBillSponsorsWithLegislators(String billId) async {
    final response = await _supabase
        .from('legislation_bill_sponsors')
        .select('''
          *,
          legislator:legislator_id(
            id,
            name,
            first_name,
            last_name,
            party,
            chamber,
            district,
            photo_storage_path,
            photo_url,
            leadership_role,
            is_current,
            created_at,
            updated_at
          )
        ''')
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

  /// Get legislators by a list of IDs (for bulk lookup)
  Future<Map<String, Legislator>> getLegislatorsByIds(List<String> ids) async {
    if (ids.isEmpty) return {};

    final response = await _supabase
        .from('legislation_legislators')
        .select()
        .inFilter('id', ids);

    final legislators = (response as List)
        .map((json) => Legislator.fromJson(json as Map<String, dynamic>));

    return {for (var leg in legislators) leg.id: leg};
  }

  /// Enrich leaderboard entries with photo URLs from legislators table
  Future<List<SponsorLeaderboardEntry>> enrichLeaderboardWithPhotos(
    List<SponsorLeaderboardEntry> entries,
  ) async {
    // Collect IDs of entries that need photos
    final idsNeedingPhotos = entries
        .where((e) => e.legislatorId != null && (e.photoUrl == null || e.photoUrl!.isEmpty))
        .map((e) => e.legislatorId!)
        .toSet()
        .toList();

    if (idsNeedingPhotos.isEmpty) return entries;

    // Fetch legislators
    final legislatorsMap = await getLegislatorsByIds(idsNeedingPhotos);

    // Update entries with photo URLs
    return entries.map((entry) {
      if (entry.photoUrl != null && entry.photoUrl!.isNotEmpty) {
        return entry;
      }
      if (entry.legislatorId == null) return entry;

      final legislator = legislatorsMap[entry.legislatorId];
      if (legislator == null) return entry;

      final photoUrl = legislator.getPhotoPublicUrl();
      if (photoUrl == null) return entry;

      return entry.copyWith(photoUrl: photoUrl);
    }).toList();
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
    // Get notes first
    final response = await _supabase
        .from('legislation_bill_notes')
        .select()
        .eq('bill_id', billId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    final notes = (response as List).map((json) => json as Map<String, dynamic>).toList();

    // Get unique author IDs to look up member info
    final authorIds = notes
        .map((n) => n['author_id'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();

    // Look up member info for authors
    Map<String, Map<String, dynamic>> authorInfo = {};
    if (authorIds.isNotEmpty) {
      try {
        // Only select columns that exist on members table
        final membersResponse = await _supabase
            .from('members')
            .select('id, name, profile_pictures')
            .inFilter('id', authorIds);

        for (final member in (membersResponse as List)) {
          final memberId = member['id'] as String;
          authorInfo[memberId] = member as Map<String, dynamic>;
        }
      } catch (e) {
        // Silently fail - author info is optional
        print('Error fetching author info: $e');
      }
    }

    // Build notes with author info
    return notes.map((json) {
      final Map<String, dynamic> noteJson = Map<String, dynamic>.from(json);
      final authorId = json['author_id'] as String?;
      if (authorId != null && authorInfo.containsKey(authorId)) {
        final author = authorInfo[authorId]!;
        noteJson['author_name'] = author['name'];
        // Handle profile pictures - get first photo URL if available
        final profilePics = author['profile_pictures'];
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

  /// Get pre-computed cached statistics from legislation_statistics table
  /// This is MUCH faster than computing stats on the fly (~1ms vs 100-500ms)
  Future<LegislationStats> getCachedStatistics() async {
    try {
      final response = await _supabase
          .from('legislation_statistics')
          .select()
          .single();

      return LegislationStats.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching cached statistics: $e');
      // Fall back to RPC method
      return getStatistics();
    }
  }

  /// Get quick stats subset for dashboards (smaller payload)
  Future<Map<String, dynamic>> getQuickStats() async {
    try {
      final response = await _supabase
          .from('legislation_statistics')
          .select('''
            total_active_bills,
            support_count,
            oppose_count,
            watching_count,
            neutral_count,
            no_position_count,
            critical_count,
            high_count,
            democrat_primary_sponsor_count,
            republican_primary_sponsor_count,
            democrat_legislators_count,
            republican_legislators_count,
            house_legislators_count,
            senate_legislators_count,
            total_legislators_count,
            bills_introduced_this_week,
            actions_this_week
          ''')
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching quick stats: $e');
      return {};
    }
  }

  /// Get leaderboards data for charts
  Future<Map<String, dynamic>> getLeaderboards() async {
    try {
      final response = await _supabase
          .from('legislation_statistics')
          .select('''
            top_10_democrat_primary_sponsors,
            top_10_republican_primary_sponsors,
            top_10_democrat_cosponsors,
            top_10_republican_cosponsors,
            top_10_most_sponsored_bills,
            top_10_most_active_bills,
            avg_bills_per_democrat_legislator,
            avg_bills_per_republican_legislator
          ''')
          .single();

      return response;
    } catch (e) {
      debugPrint('Error fetching leaderboards: $e');
      return {};
    }
  }

  /// Get legislation statistics (legacy method - uses RPC)
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
    // Use Supabase count queries to get accurate counts (avoids 1000 row limit)
    final baseQuery = session != null
        ? _supabase.from('legislation_tracked_bills').select().eq('is_archived', false).eq('session', session)
        : _supabase.from('legislation_tracked_bills').select().eq('is_archived', false);

    // Run all count queries in parallel for efficiency
    final results = await Future.wait([
      // Total count
      _countQuery(session: session),
      // Position counts
      _countQuery(session: session, position: 'support'),
      _countQuery(session: session, position: 'oppose'),
      _countQuery(session: session, position: 'watching'),
      // Priority counts
      _countQuery(session: session, priority: 'critical'),
      _countQuery(session: session, priority: 'high'),
      // Status counts
      _countQueryWithField(session: session, field: 'passed_lower', value: true),
      _countQueryWithField(session: session, field: 'passed_upper', value: true),
      _countQueryWithField(session: session, field: 'signed_by_governor', value: true),
      _countQueryWithField(session: session, field: 'vetoed', value: true),
    ]);

    return LegislationStats(
      totalTracked: results[0],
      supportCount: results[1],
      opposeCount: results[2],
      watchingCount: results[3],
      criticalCount: results[4],
      highCount: results[5],
      passedLowerCount: results[6],
      passedUpperCount: results[7],
      signedCount: results[8],
      vetoedCount: results[9],
    );
  }

  /// Helper to count bills with specific criteria
  Future<int> _countQuery({
    String? session,
    String? position,
    String? priority,
  }) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .eq('is_archived', false);

    if (session != null) {
      query = query.eq('session', session);
    }
    if (position != null) {
      query = query.eq('position', position);
    }
    if (priority != null) {
      query = query.eq('priority', priority);
    }

    // Use pagination to count all rows (Supabase limits to 1000 per request)
    int totalCount = 0;
    int offset = 0;
    const batchSize = 1000;

    while (true) {
      final response = await query.range(offset, offset + batchSize - 1);
      final count = (response as List).length;
      totalCount += count;

      if (count < batchSize) {
        break; // No more rows
      }
      offset += batchSize;
    }

    return totalCount;
  }

  /// Helper to count bills with a specific boolean field value
  Future<int> _countQueryWithField({
    String? session,
    required String field,
    required bool value,
  }) async {
    var query = _supabase
        .from('legislation_tracked_bills')
        .select('id')
        .eq('is_archived', false)
        .eq(field, value);

    if (session != null) {
      query = query.eq('session', session);
    }

    // Use pagination to count all rows
    int totalCount = 0;
    int offset = 0;
    const batchSize = 1000;

    while (true) {
      final response = await query.range(offset, offset + batchSize - 1);
      final count = (response as List).length;
      totalCount += count;

      if (count < batchSize) {
        break;
      }
      offset += batchSize;
    }

    return totalCount;
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
  // === Basic Counts ===
  final int totalTracked;
  final int totalBillsCount;
  final int totalArchivedBillsCount;

  // === Position Counts ===
  final int supportCount;
  final int opposeCount;
  final int watchingCount;
  final int neutralCount;
  final int noPositionCount;

  // === Priority Counts ===
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
  final int noPriorityCount;

  // === Legislative Status ===
  final int passedLowerCount;
  final int passedUpperCount;
  final int passedBothChambersCount;
  final int signedCount;
  final int vetoedCount;

  // === Chamber Origin ===
  final int houseBillsCount;
  final int senateBillsCount;

  // === Party Sponsorship ===
  final int democratPrimarySponsorCount;
  final int republicanPrimarySponsorCount;
  final int democratCosponsorCount;
  final int republicanCosponsorCount;
  final int totalDemocratSponsorships;
  final int totalRepublicanSponsorships;
  final double avgBillsPerDemocratLegislator;
  final double avgBillsPerRepublicanLegislator;

  // === Bipartisan ===
  final int bipartisanBillsCount;
  final int democratOnlyBillsCount;
  final int republicanOnlyBillsCount;

  // === Legislator Counts ===
  final int totalLegislatorsCount;
  final int houseLegislatorsCount;
  final int senateLegislatorsCount;
  final int democratLegislatorsCount;
  final int republicanLegislatorsCount;

  // === Text & PDF Stats ===
  final int billsWithTextCount;
  final int billsWithoutTextCount;
  final int billsWithPdfCount;
  final int billsTextDeferredCount;
  final int totalBillTextWordCount;
  final double avgBillTextWordCount;

  // === AI Analysis ===
  final int billsAiAnalyzedCount;
  final int billsAiPendingCount;
  final int billsAiErrorCount;
  final int billsAwaitingAiAnalysisCount;

  // === AI Recommendations ===
  final int aiRecommendsSupportCount;
  final int aiRecommendsOpposeCount;
  final int aiRecommendsWatchingCount;
  final int aiRecommendsNeutralCount;
  final int aiRecommendsCriticalCount;
  final int aiRecommendsHighCount;
  final int aiRecommendsMediumCount;
  final int aiRecommendsLowCount;

  // === Session Stats ===
  final String? currentSession;
  final int billsCurrentSessionCount;

  // === Activity / Timeline ===
  final int billsIntroducedThisWeek;
  final int billsIntroducedThisMonth;
  final int billsIntroducedThisYear;
  final int actionsThisWeek;
  final int actionsThisMonth;
  final int totalActionsCount;
  final int billsWithRecentAction7dCount;
  final int billsWithRecentAction30dCount;
  final double avgActionsPerBill;

  // === Vote Stats ===
  final int totalVotesCount;
  final int votesPassedCount;
  final int votesFailedCount;
  final double avgVotesPerBill;
  final int votesThisWeek;
  final int votesThisMonth;

  // === Document Stats ===
  final int totalDocumentsCount;
  final int totalVersionsCount;

  // === Sponsor Stats ===
  final int totalSponsorsCount;
  final int totalPrimarySponsorsCount;
  final int totalCosponsorsCount;
  final double avgSponsorsPerBill;
  final int uniqueSponsorsCount;

  // === Category & Tag Stats ===
  final int billsWithCategoriesCount;
  final int billsWithTagsCount;
  final List<dynamic> topCategories;
  final List<dynamic> topSubjects;

  // === Alert Stats ===
  final int totalAlertsCount;
  final int activeAlertsCount;
  final int alertsSentTodayCount;
  final int alertsSentThisWeekCount;

  // === Note Stats ===
  final int totalNotesCount;
  final int billsWithNotesCount;

  // === Sync Stats ===
  final int billsNeedingDetailSyncCount;
  final int billsNeedingTextExtractCount;
  final int billsNeedingSponsorLinkCount;
  final int billsWithSyncErrorsCount;

  // === Leaderboards ===
  final List<SponsorLeaderboardEntry> top10DemocratPrimarySponsors;
  final List<SponsorLeaderboardEntry> top10RepublicanPrimarySponsors;
  final List<SponsorLeaderboardEntry> top10DemocratCosponsors;
  final List<SponsorLeaderboardEntry> top10RepublicanCosponsors;
  final List<BillLeaderboardEntry> top10MostSponsoredBills;
  final List<BillLeaderboardEntry> top10MostActiveBills;

  // === Metadata ===
  final DateTime? lastComputedAt;

  LegislationStats({
    required this.totalTracked,
    this.totalBillsCount = 0,
    this.totalArchivedBillsCount = 0,
    required this.supportCount,
    required this.opposeCount,
    required this.watchingCount,
    this.neutralCount = 0,
    this.noPositionCount = 0,
    required this.criticalCount,
    required this.highCount,
    this.mediumCount = 0,
    this.lowCount = 0,
    this.noPriorityCount = 0,
    required this.passedLowerCount,
    required this.passedUpperCount,
    this.passedBothChambersCount = 0,
    required this.signedCount,
    required this.vetoedCount,
    this.houseBillsCount = 0,
    this.senateBillsCount = 0,
    this.democratPrimarySponsorCount = 0,
    this.republicanPrimarySponsorCount = 0,
    this.democratCosponsorCount = 0,
    this.republicanCosponsorCount = 0,
    this.totalDemocratSponsorships = 0,
    this.totalRepublicanSponsorships = 0,
    this.avgBillsPerDemocratLegislator = 0.0,
    this.avgBillsPerRepublicanLegislator = 0.0,
    this.bipartisanBillsCount = 0,
    this.democratOnlyBillsCount = 0,
    this.republicanOnlyBillsCount = 0,
    this.totalLegislatorsCount = 0,
    this.houseLegislatorsCount = 0,
    this.senateLegislatorsCount = 0,
    this.democratLegislatorsCount = 0,
    this.republicanLegislatorsCount = 0,
    this.billsWithTextCount = 0,
    this.billsWithoutTextCount = 0,
    this.billsWithPdfCount = 0,
    this.billsTextDeferredCount = 0,
    this.totalBillTextWordCount = 0,
    this.avgBillTextWordCount = 0.0,
    this.billsAiAnalyzedCount = 0,
    this.billsAiPendingCount = 0,
    this.billsAiErrorCount = 0,
    this.billsAwaitingAiAnalysisCount = 0,
    this.aiRecommendsSupportCount = 0,
    this.aiRecommendsOpposeCount = 0,
    this.aiRecommendsWatchingCount = 0,
    this.aiRecommendsNeutralCount = 0,
    this.aiRecommendsCriticalCount = 0,
    this.aiRecommendsHighCount = 0,
    this.aiRecommendsMediumCount = 0,
    this.aiRecommendsLowCount = 0,
    this.currentSession,
    this.billsCurrentSessionCount = 0,
    this.billsIntroducedThisWeek = 0,
    this.billsIntroducedThisMonth = 0,
    this.billsIntroducedThisYear = 0,
    this.actionsThisWeek = 0,
    this.actionsThisMonth = 0,
    this.totalActionsCount = 0,
    this.billsWithRecentAction7dCount = 0,
    this.billsWithRecentAction30dCount = 0,
    this.avgActionsPerBill = 0.0,
    this.totalVotesCount = 0,
    this.votesPassedCount = 0,
    this.votesFailedCount = 0,
    this.avgVotesPerBill = 0.0,
    this.votesThisWeek = 0,
    this.votesThisMonth = 0,
    this.totalDocumentsCount = 0,
    this.totalVersionsCount = 0,
    this.totalSponsorsCount = 0,
    this.totalPrimarySponsorsCount = 0,
    this.totalCosponsorsCount = 0,
    this.avgSponsorsPerBill = 0.0,
    this.uniqueSponsorsCount = 0,
    this.billsWithCategoriesCount = 0,
    this.billsWithTagsCount = 0,
    this.topCategories = const [],
    this.topSubjects = const [],
    this.totalAlertsCount = 0,
    this.activeAlertsCount = 0,
    this.alertsSentTodayCount = 0,
    this.alertsSentThisWeekCount = 0,
    this.totalNotesCount = 0,
    this.billsWithNotesCount = 0,
    this.billsNeedingDetailSyncCount = 0,
    this.billsNeedingTextExtractCount = 0,
    this.billsNeedingSponsorLinkCount = 0,
    this.billsWithSyncErrorsCount = 0,
    this.top10DemocratPrimarySponsors = const [],
    this.top10RepublicanPrimarySponsors = const [],
    this.top10DemocratCosponsors = const [],
    this.top10RepublicanCosponsors = const [],
    this.top10MostSponsoredBills = const [],
    this.top10MostActiveBills = const [],
    this.lastComputedAt,
  });

  factory LegislationStats.fromJson(Map<String, dynamic> json) {
    return LegislationStats(
      // Basic Counts
      totalTracked: json['total_tracked'] as int? ?? json['total_active_bills'] as int? ?? 0,
      totalBillsCount: json['total_bills'] as int? ?? 0,
      totalArchivedBillsCount: json['total_archived_bills'] as int? ?? 0,

      // Position Counts
      supportCount: json['support_count'] as int? ?? 0,
      opposeCount: json['oppose_count'] as int? ?? 0,
      watchingCount: json['watching_count'] as int? ?? 0,
      neutralCount: json['neutral_count'] as int? ?? 0,
      noPositionCount: json['no_position_count'] as int? ?? 0,

      // Priority Counts
      criticalCount: json['critical_count'] as int? ?? 0,
      highCount: json['high_count'] as int? ?? 0,
      mediumCount: json['medium_count'] as int? ?? 0,
      lowCount: json['low_count'] as int? ?? 0,
      noPriorityCount: json['no_priority_count'] as int? ?? 0,

      // Legislative Status
      passedLowerCount: json['passed_lower_count'] as int? ?? 0,
      passedUpperCount: json['passed_upper_count'] as int? ?? 0,
      passedBothChambersCount: json['passed_both_chambers_count'] as int? ?? 0,
      signedCount: json['signed_count'] as int? ?? 0,
      vetoedCount: json['vetoed_count'] as int? ?? 0,

      // Chamber Origin
      houseBillsCount: json['house_bills_count'] as int? ?? 0,
      senateBillsCount: json['senate_bills_count'] as int? ?? 0,

      // Party Sponsorship
      democratPrimarySponsorCount: json['democrat_primary_sponsor_count'] as int? ?? 0,
      republicanPrimarySponsorCount: json['republican_primary_sponsor_count'] as int? ?? 0,
      democratCosponsorCount: json['democrat_cosponsor_count'] as int? ?? 0,
      republicanCosponsorCount: json['republican_cosponsor_count'] as int? ?? 0,
      totalDemocratSponsorships: json['total_democrat_sponsorships'] as int? ?? 0,
      totalRepublicanSponsorships: json['total_republican_sponsorships'] as int? ?? 0,
      avgBillsPerDemocratLegislator: (json['avg_bills_per_democrat_legislator'] as num?)?.toDouble() ?? 0.0,
      avgBillsPerRepublicanLegislator: (json['avg_bills_per_republican_legislator'] as num?)?.toDouble() ?? 0.0,

      // Bipartisan
      bipartisanBillsCount: json['bipartisan_bills_count'] as int? ?? 0,
      democratOnlyBillsCount: json['democrat_only_bills_count'] as int? ?? 0,
      republicanOnlyBillsCount: json['republican_only_bills_count'] as int? ?? 0,

      // Legislator Counts
      totalLegislatorsCount: json['total_legislators_count'] as int? ?? 0,
      houseLegislatorsCount: json['house_legislators_count'] as int? ?? 0,
      senateLegislatorsCount: json['senate_legislators_count'] as int? ?? 0,
      democratLegislatorsCount: json['democrat_legislators_count'] as int? ?? 0,
      republicanLegislatorsCount: json['republican_legislators_count'] as int? ?? 0,

      // Text & PDF Stats
      billsWithTextCount: json['bills_with_text_count'] as int? ?? 0,
      billsWithoutTextCount: json['bills_without_text_count'] as int? ?? 0,
      billsWithPdfCount: json['bills_with_pdf_count'] as int? ?? 0,
      billsTextDeferredCount: json['bills_text_deferred_count'] as int? ?? 0,
      totalBillTextWordCount: json['total_bill_text_word_count'] as int? ?? 0,
      avgBillTextWordCount: (json['avg_bill_text_word_count'] as num?)?.toDouble() ?? 0.0,

      // AI Analysis
      billsAiAnalyzedCount: json['bills_ai_analyzed_count'] as int? ?? 0,
      billsAiPendingCount: json['bills_ai_pending_count'] as int? ?? 0,
      billsAiErrorCount: json['bills_ai_error_count'] as int? ?? 0,
      billsAwaitingAiAnalysisCount: json['bills_awaiting_ai_analysis_count'] as int? ?? 0,

      // AI Recommendations
      aiRecommendsSupportCount: json['ai_recommends_support_count'] as int? ?? 0,
      aiRecommendsOpposeCount: json['ai_recommends_oppose_count'] as int? ?? 0,
      aiRecommendsWatchingCount: json['ai_recommends_watching_count'] as int? ?? 0,
      aiRecommendsNeutralCount: json['ai_recommends_neutral_count'] as int? ?? 0,
      aiRecommendsCriticalCount: json['ai_recommends_critical_count'] as int? ?? 0,
      aiRecommendsHighCount: json['ai_recommends_high_count'] as int? ?? 0,
      aiRecommendsMediumCount: json['ai_recommends_medium_count'] as int? ?? 0,
      aiRecommendsLowCount: json['ai_recommends_low_count'] as int? ?? 0,

      // Session Stats
      currentSession: json['current_session'] as String?,
      billsCurrentSessionCount: json['bills_current_session_count'] as int? ?? 0,

      // Activity / Timeline
      billsIntroducedThisWeek: json['bills_introduced_this_week'] as int? ?? 0,
      billsIntroducedThisMonth: json['bills_introduced_this_month'] as int? ?? 0,
      billsIntroducedThisYear: json['bills_introduced_this_year'] as int? ?? 0,
      actionsThisWeek: json['actions_this_week'] as int? ?? 0,
      actionsThisMonth: json['actions_this_month'] as int? ?? 0,
      totalActionsCount: json['total_actions_count'] as int? ?? 0,
      billsWithRecentAction7dCount: json['bills_with_recent_action_7d_count'] as int? ?? 0,
      billsWithRecentAction30dCount: json['bills_with_recent_action_30d_count'] as int? ?? 0,
      avgActionsPerBill: (json['avg_actions_per_bill'] as num?)?.toDouble() ?? 0.0,

      // Vote Stats
      totalVotesCount: json['total_votes_count'] as int? ?? 0,
      votesPassedCount: json['votes_passed_count'] as int? ?? 0,
      votesFailedCount: json['votes_failed_count'] as int? ?? 0,
      avgVotesPerBill: (json['avg_votes_per_bill'] as num?)?.toDouble() ?? 0.0,
      votesThisWeek: json['votes_this_week'] as int? ?? 0,
      votesThisMonth: json['votes_this_month'] as int? ?? 0,

      // Document Stats
      totalDocumentsCount: json['total_documents_count'] as int? ?? 0,
      totalVersionsCount: json['total_versions_count'] as int? ?? 0,

      // Sponsor Stats
      totalSponsorsCount: json['total_sponsors_count'] as int? ?? 0,
      totalPrimarySponsorsCount: json['total_primary_sponsors_count'] as int? ?? 0,
      totalCosponsorsCount: json['total_cosponsors_count'] as int? ?? 0,
      avgSponsorsPerBill: (json['avg_sponsors_per_bill'] as num?)?.toDouble() ?? 0.0,
      uniqueSponsorsCount: json['unique_sponsors_count'] as int? ?? 0,

      // Category & Tag Stats
      billsWithCategoriesCount: json['bills_with_categories_count'] as int? ?? 0,
      billsWithTagsCount: json['bills_with_tags_count'] as int? ?? 0,
      topCategories: json['top_categories'] as List<dynamic>? ?? [],
      topSubjects: json['top_subjects'] as List<dynamic>? ?? [],

      // Alert Stats
      totalAlertsCount: json['total_alerts_count'] as int? ?? 0,
      activeAlertsCount: json['active_alerts_count'] as int? ?? 0,
      alertsSentTodayCount: json['alerts_sent_today_count'] as int? ?? 0,
      alertsSentThisWeekCount: json['alerts_sent_this_week_count'] as int? ?? 0,

      // Note Stats
      totalNotesCount: json['total_notes_count'] as int? ?? 0,
      billsWithNotesCount: json['bills_with_notes_count'] as int? ?? 0,

      // Sync Stats
      billsNeedingDetailSyncCount: json['bills_needing_detail_sync_count'] as int? ?? 0,
      billsNeedingTextExtractCount: json['bills_needing_text_extract_count'] as int? ?? 0,
      billsNeedingSponsorLinkCount: json['bills_needing_sponsor_link_count'] as int? ?? 0,
      billsWithSyncErrorsCount: json['bills_with_sync_errors_count'] as int? ?? 0,

      // Leaderboards
      top10DemocratPrimarySponsors: _parseLeaderboard(json['top_10_democrat_primary_sponsors']),
      top10RepublicanPrimarySponsors: _parseLeaderboard(json['top_10_republican_primary_sponsors']),
      top10DemocratCosponsors: _parseLeaderboard(json['top_10_democrat_cosponsors']),
      top10RepublicanCosponsors: _parseLeaderboard(json['top_10_republican_cosponsors']),
      top10MostSponsoredBills: _parseBillLeaderboard(json['top_10_most_sponsored_bills']),
      top10MostActiveBills: _parseBillLeaderboard(json['top_10_most_active_bills']),

      // Metadata
      lastComputedAt: json['last_computed_at'] != null
          ? DateTime.tryParse(json['last_computed_at'] as String)
          : null,
    );
  }

  static List<SponsorLeaderboardEntry> _parseLeaderboard(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    return data
        .map((item) => SponsorLeaderboardEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static List<BillLeaderboardEntry> _parseBillLeaderboard(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    return data
        .map((item) => BillLeaderboardEntry.fromJson(item as Map<String, dynamic>))
        .toList();
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

  /// Creates a copy with updated leaderboard entries
  LegislationStats copyWith({
    List<SponsorLeaderboardEntry>? top10DemocratPrimarySponsors,
    List<SponsorLeaderboardEntry>? top10RepublicanPrimarySponsors,
    List<SponsorLeaderboardEntry>? top10DemocratCosponsors,
    List<SponsorLeaderboardEntry>? top10RepublicanCosponsors,
    List<BillLeaderboardEntry>? top10MostSponsoredBills,
    List<BillLeaderboardEntry>? top10MostActiveBills,
  }) {
    return LegislationStats(
      totalTracked: totalTracked,
      totalBillsCount: totalBillsCount,
      totalArchivedBillsCount: totalArchivedBillsCount,
      supportCount: supportCount,
      opposeCount: opposeCount,
      watchingCount: watchingCount,
      neutralCount: neutralCount,
      noPositionCount: noPositionCount,
      criticalCount: criticalCount,
      highCount: highCount,
      mediumCount: mediumCount,
      lowCount: lowCount,
      noPriorityCount: noPriorityCount,
      passedLowerCount: passedLowerCount,
      passedUpperCount: passedUpperCount,
      passedBothChambersCount: passedBothChambersCount,
      signedCount: signedCount,
      vetoedCount: vetoedCount,
      houseBillsCount: houseBillsCount,
      senateBillsCount: senateBillsCount,
      democratPrimarySponsorCount: democratPrimarySponsorCount,
      republicanPrimarySponsorCount: republicanPrimarySponsorCount,
      democratCosponsorCount: democratCosponsorCount,
      republicanCosponsorCount: republicanCosponsorCount,
      totalDemocratSponsorships: totalDemocratSponsorships,
      totalRepublicanSponsorships: totalRepublicanSponsorships,
      avgBillsPerDemocratLegislator: avgBillsPerDemocratLegislator,
      avgBillsPerRepublicanLegislator: avgBillsPerRepublicanLegislator,
      bipartisanBillsCount: bipartisanBillsCount,
      democratOnlyBillsCount: democratOnlyBillsCount,
      republicanOnlyBillsCount: republicanOnlyBillsCount,
      totalLegislatorsCount: totalLegislatorsCount,
      houseLegislatorsCount: houseLegislatorsCount,
      senateLegislatorsCount: senateLegislatorsCount,
      democratLegislatorsCount: democratLegislatorsCount,
      republicanLegislatorsCount: republicanLegislatorsCount,
      billsWithTextCount: billsWithTextCount,
      billsWithoutTextCount: billsWithoutTextCount,
      billsWithPdfCount: billsWithPdfCount,
      billsTextDeferredCount: billsTextDeferredCount,
      totalBillTextWordCount: totalBillTextWordCount,
      avgBillTextWordCount: avgBillTextWordCount,
      billsAiAnalyzedCount: billsAiAnalyzedCount,
      billsAiPendingCount: billsAiPendingCount,
      billsAiErrorCount: billsAiErrorCount,
      billsAwaitingAiAnalysisCount: billsAwaitingAiAnalysisCount,
      aiRecommendsSupportCount: aiRecommendsSupportCount,
      aiRecommendsOpposeCount: aiRecommendsOpposeCount,
      aiRecommendsWatchingCount: aiRecommendsWatchingCount,
      aiRecommendsNeutralCount: aiRecommendsNeutralCount,
      aiRecommendsCriticalCount: aiRecommendsCriticalCount,
      aiRecommendsHighCount: aiRecommendsHighCount,
      aiRecommendsMediumCount: aiRecommendsMediumCount,
      aiRecommendsLowCount: aiRecommendsLowCount,
      currentSession: currentSession,
      billsCurrentSessionCount: billsCurrentSessionCount,
      billsIntroducedThisWeek: billsIntroducedThisWeek,
      billsIntroducedThisMonth: billsIntroducedThisMonth,
      billsIntroducedThisYear: billsIntroducedThisYear,
      actionsThisWeek: actionsThisWeek,
      actionsThisMonth: actionsThisMonth,
      totalActionsCount: totalActionsCount,
      billsWithRecentAction7dCount: billsWithRecentAction7dCount,
      billsWithRecentAction30dCount: billsWithRecentAction30dCount,
      avgActionsPerBill: avgActionsPerBill,
      totalVotesCount: totalVotesCount,
      votesPassedCount: votesPassedCount,
      votesFailedCount: votesFailedCount,
      avgVotesPerBill: avgVotesPerBill,
      votesThisWeek: votesThisWeek,
      votesThisMonth: votesThisMonth,
      totalDocumentsCount: totalDocumentsCount,
      totalVersionsCount: totalVersionsCount,
      totalSponsorsCount: totalSponsorsCount,
      totalPrimarySponsorsCount: totalPrimarySponsorsCount,
      totalCosponsorsCount: totalCosponsorsCount,
      avgSponsorsPerBill: avgSponsorsPerBill,
      uniqueSponsorsCount: uniqueSponsorsCount,
      billsWithCategoriesCount: billsWithCategoriesCount,
      billsWithTagsCount: billsWithTagsCount,
      topCategories: topCategories,
      topSubjects: topSubjects,
      totalAlertsCount: totalAlertsCount,
      activeAlertsCount: activeAlertsCount,
      alertsSentTodayCount: alertsSentTodayCount,
      alertsSentThisWeekCount: alertsSentThisWeekCount,
      totalNotesCount: totalNotesCount,
      billsWithNotesCount: billsWithNotesCount,
      billsNeedingDetailSyncCount: billsNeedingDetailSyncCount,
      billsNeedingTextExtractCount: billsNeedingTextExtractCount,
      billsNeedingSponsorLinkCount: billsNeedingSponsorLinkCount,
      billsWithSyncErrorsCount: billsWithSyncErrorsCount,
      top10DemocratPrimarySponsors: top10DemocratPrimarySponsors ?? this.top10DemocratPrimarySponsors,
      top10RepublicanPrimarySponsors: top10RepublicanPrimarySponsors ?? this.top10RepublicanPrimarySponsors,
      top10DemocratCosponsors: top10DemocratCosponsors ?? this.top10DemocratCosponsors,
      top10RepublicanCosponsors: top10RepublicanCosponsors ?? this.top10RepublicanCosponsors,
      top10MostSponsoredBills: top10MostSponsoredBills ?? this.top10MostSponsoredBills,
      top10MostActiveBills: top10MostActiveBills ?? this.top10MostActiveBills,
      lastComputedAt: lastComputedAt,
    );
  }

  // Alias getters for UI compatibility
  int get totalBills => totalBillsCount > 0 ? totalBillsCount : totalTracked;
  int get totalActiveBills => totalTracked;
  int get activeBills => totalTracked;
  int get criticalBills => criticalCount;
  int get supportBills => supportCount;
  int get opposeBills => opposeCount;
  int get watchingBills => watchingCount;
  int get newActionsThisWeek => actionsThisWeek;
  int get recentVotesCount => votesThisWeek;
}

/// Sponsor leaderboard entry for top sponsors
class SponsorLeaderboardEntry {
  final String name;
  final String party;
  final String district;
  final String chamber;
  final int billsCount;
  final String? legislatorId;
  final String? photoUrl;

  SponsorLeaderboardEntry({
    required this.name,
    required this.party,
    required this.district,
    required this.chamber,
    required this.billsCount,
    this.legislatorId,
    this.photoUrl,
  });

  factory SponsorLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    // Try to construct photo URL from legislator_id if photo_storage_path exists
    String? photoUrl = json['photo_url'] as String?;
    if (photoUrl == null && json['photo_storage_path'] != null) {
      final storagePath = json['photo_storage_path'] as String;
      photoUrl = 'https://faajpcarasilbfndzkmd.supabase.co/storage/v1/object/public/legislator-photos/$storagePath';
    }

    return SponsorLeaderboardEntry(
      name: json['name'] as String? ?? '',
      party: json['party'] as String? ?? '',
      district: json['district'] as String? ?? '',
      chamber: json['chamber'] as String? ?? '',
      billsCount: json['bills_count'] as int? ?? 0,
      legislatorId: json['legislator_id'] as String?,
      photoUrl: photoUrl,
    );
  }

  SponsorLeaderboardEntry copyWith({
    String? name,
    String? party,
    String? district,
    String? chamber,
    int? billsCount,
    String? legislatorId,
    String? photoUrl,
  }) {
    return SponsorLeaderboardEntry(
      name: name ?? this.name,
      party: party ?? this.party,
      district: district ?? this.district,
      chamber: chamber ?? this.chamber,
      billsCount: billsCount ?? this.billsCount,
      legislatorId: legislatorId ?? this.legislatorId,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

/// Bill leaderboard entry for most sponsored/active bills
class BillLeaderboardEntry {
  final String id;
  final String billIdentifier;
  final String title;
  final int count;
  final String? position;
  final String? priority;
  final String? latestActionDate;

  BillLeaderboardEntry({
    required this.id,
    required this.billIdentifier,
    required this.title,
    required this.count,
    this.position,
    this.priority,
    this.latestActionDate,
  });

  factory BillLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return BillLeaderboardEntry(
      id: json['id'] as String? ?? '',
      billIdentifier: json['bill_identifier'] as String? ?? '',
      title: json['title'] as String? ?? '',
      count: json['sponsor_count'] as int? ?? json['action_count'] as int? ?? 0,
      position: json['position'] as String?,
      priority: json['priority'] as String?,
      latestActionDate: json['latest_action_date'] as String?,
    );
  }
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
