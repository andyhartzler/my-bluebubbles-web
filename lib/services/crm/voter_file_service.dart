import 'package:flutter/foundation.dart';

import 'package:bluebubbles/models/crm/voter_file_record.dart';

import 'supabase_service.dart';

/// Single shared entry point for looking up voter-file records by
/// `voter_id` (PK on `public.mo_voter_file`).
///
/// Used by CandidateRepository, DonorProfileRepository, MECDonorScreen,
/// and MemberDetailScreen — all of them funnel through `fetchRecord`.
/// The mo_voter_file table is 4.34M rows, so we keep this as a single
/// PK lookup and never embed it in a join.
class VoterFileService {
  static const _columns =
      'voter_id,first_name,middle_name,last_name,suffix,'
      'county,residential_city,residential_zip5,voter_status,'
      'registration_date,birth_year,congressional_district,'
      'legislative_district,senate_district,precinct,ward,'
      'township,voter_history';

  /// Lookup a single voter record by PK. Returns null if not found,
  /// if the voterId is empty, or on any error.
  static Future<VoterFileRecord?> fetchRecord(String? voterId) async {
    if (voterId == null || voterId.isEmpty) return null;
    final supabase = CRMSupabaseService();
    if (!supabase.isInitialized) return null;

    try {
      final response = await supabase.privilegedClient
          .from('mo_voter_file')
          .select(_columns)
          .eq('voter_id', voterId)
          .maybeSingle();

      if (response == null) return null;
      return VoterFileRecord.fromJson(response);
    } catch (e) {
      debugPrint('❌ VoterFileService.fetchRecord($voterId): $e');
      return null;
    }
  }
}
