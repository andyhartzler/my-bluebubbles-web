import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class DonorRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  SupabaseClient get _readClient =>
      _supabase.hasServiceRole ? _supabase.privilegedClient : _supabase.client;

  Future<List<Donor>> fetchDonors({
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    if (!_isReady) return [];

    try {
      var query = _readClient.from('donors').select('''
        id,
        name,
        email,
        phone,
        member_id,
        total_donated,
        is_recurring_donor,
        created_at,
        members:member_id (
          id,
          name,
          email,
          phone,
          phone_e164
        )
      ''').order('name', ascending: true);

      if (search != null && search.trim().isNotEmpty) {
        final sanitized = search.trim();
        query = query.or(
          'name.ilike.%$sanitized%,email.ilike.%$sanitized%,phone.ilike.%$sanitized%',
        );
      }

      if (offset > 0 && limit > 0) {
        query = query.range(offset, offset + limit - 1);
      } else if (limit > 0) {
        query = query.limit(limit);
      }

      final data = await query;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Donor.fromJson)
            .toList();
      }

      return [];
    } catch (e) {
      print('❌ Error fetching donors: $e');
      rethrow;
    }
  }

  Future<Donor?> fetchDonorDetails(String donorId) async {
    if (!_isReady) return null;

    try {
      final data = await _readClient
          .from('donors')
          .select('''
        id,
        name,
        email,
        phone,
        member_id,
        total_donated,
        is_recurring_donor,
        created_at,
        members:member_id (*),
        donations:donations (
          id,
          amount,
          donated_at,
          donation_date,
          created_at,
          method,
          payment_method,
          status,
          notes,
          is_recurring,
          recurring,
          event_id,
          events:event_id (
            id,
            name,
            starts_at,
            end_time,
            city,
            state,
            location
          )
        )
      ''')
          .eq('id', donorId)
          .maybeSingle();

      if (data == null) return null;
      return Donor.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching donor detail: $e');
      rethrow;
    }
  }
}
