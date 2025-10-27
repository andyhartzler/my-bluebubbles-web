import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart' show CountOption;

import 'package:bluebubbles/models/crm/member.dart';

import 'supabase_service.dart';

/// Repository for member CRUD operations
/// All Supabase queries for members go through here
class MemberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  bool get _isReady => _supabase.isInitialized;

  /// Get all members (with optional filters)
  Future<List<Member>> getAllMembers({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    int? minAge,
    int? maxAge,
    bool? optedOut,
  }) async {
    if (!_isReady) return [];

    try {
      var query = _supabase.client.from('members').select();

      if (county != null && county.isNotEmpty) {
        query = query.eq('county', county);
      }

      if (congressionalDistrict != null && congressionalDistrict.isNotEmpty) {
        query = query.eq('congressional_district', congressionalDistrict);
      }

      if (committees != null && committees.isNotEmpty) {
        query = query.overlaps('committee', committees);
      }

      if (optedOut != null) {
        query = query.eq('opt_out', optedOut);
      }

      final response = await query;
      final data = response as List<dynamic>;

      List<Member> members = data
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();

      if (minAge != null || maxAge != null) {
        members = members.where((member) {
          final age = member.age;
          if (age == null) return false;
          if (minAge != null && age < minAge) return false;
          if (maxAge != null && age > maxAge) return false;
          return true;
        }).toList();
      }

      return members;
    } catch (e) {
      print('❌ Error fetching members: $e');
      rethrow;
    }
  }

  /// Get member by ID
  Future<Member?> getMemberById(String id) async {
    if (!_isReady) return null;

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('id', id)
          .single();

      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by ID: $e');
      return null;
    }
  }

  /// Get member by phone number (E.164 format)
  /// This is the KEY lookup for linking to BlueBubbles Handles
  Future<Member?> getMemberByPhone(String phoneE164) async {
    if (!_isReady) return null;

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('phone_e164', phoneE164)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by phone: $e');
      return null;
    }
  }

  /// Get all unique counties (for filter UI)
  Future<List<String>> getUniqueCounties() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('county')
          .not('county', 'is', null);

      final counties = (response as List<dynamic>)
          .map((item) => item['county'] as String)
          .toSet()
          .toList();

      counties.sort();
      return counties;
    } catch (e) {
      print('❌ Error fetching counties: $e');
      return [];
    }
  }

  /// Get all unique congressional districts (for filter UI)
  Future<List<String>> getUniqueCongressionalDistricts() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('congressional_district')
          .not('congressional_district', 'is', null);

      final districts = (response as List<dynamic>)
          .map((item) => item['congressional_district'] as String)
          .toSet()
          .toList();

      districts.sort();
      return districts;
    } catch (e) {
      print('❌ Error fetching congressional districts: $e');
      return [];
    }
  }

  /// Get all unique committees (for filter UI)
  Future<List<String>> getUniqueCommittees() async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select('committee')
          .not('committee', 'is', null);

      final allCommittees = <String>{};
      for (final item in response as List<dynamic>) {
        final committees = item['committee'] as List<dynamic>?;
        if (committees != null) {
          allCommittees.addAll(committees.map((c) => c.toString()));
        }
      }

      final sorted = allCommittees.toList()..sort();
      return sorted;
    } catch (e) {
      print('❌ Error fetching committees: $e');
      return [];
    }
  }

  /// Update member's last contacted timestamp
  Future<void> updateLastContacted(String memberId) async {
    if (!_isReady) return;

    try {
      await _supabase.client
          .from('members')
          .update({'last_contacted': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating last contacted: $e');
    }
  }

  /// Update member's intro sent timestamp
  Future<void> markIntroSent(String memberId) async {
    if (!_isReady) return;

    try {
      await _supabase.client
          .from('members')
          .update({'intro_sent_at': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error marking intro sent: $e');
    }
  }

  /// Update member's opt-out status
  Future<void> updateOptOutStatus(
    String memberId,
    bool optOut, {
    String? reason,
  }) async {
    if (!_isReady) return;

    try {
      final data = {
        'opt_out': optOut,
        optOut ? 'opt_out_date' : 'opt_in_date': DateTime.now().toIso8601String(),
      };

      if (reason != null) {
        data['opt_out_reason'] = reason;
      }

      await _supabase.client
          .from('members')
          .update(data)
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating opt-out status: $e');
    }
  }

  /// Update member notes
  Future<void> updateNotes(String memberId, String notes) async {
    if (!_isReady) return;

    try {
      await _supabase.client
          .from('members')
          .update({'notes': notes})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating notes: $e');
    }
  }

  /// Search members by name or phone
  Future<List<Member>> searchMembers(String query) async {
    if (!_isReady) return [];

    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%,phone_e164.ilike.%$query%');

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error searching members: $e');
      return [];
    }
  }

  /// Get member statistics
  Future<Map<String, dynamic>> getMemberStats() async {
    if (!_isReady) {
      return {'total': 0, 'optedOut': 0, 'contactable': 0, 'withPhone': 0};
    }

    try {
      final PostgrestResponse totalResponse = await _supabase.client
          .from('members')
          .select('id', head: true, count: CountOption.exact);
      final total = totalResponse.count ?? 0;

      final PostgrestResponse optedOutResponse = await _supabase.client
          .from('members')
          .select('id', head: true, count: CountOption.exact)
          .eq('opt_out', true);
      final optedOut = optedOutResponse.count ?? 0;

      final PostgrestResponse withPhoneResponse = await _supabase.client
          .from('members')
          .select('id', head: true, count: CountOption.exact)
          .not('phone_e164', 'is', null);
      final withPhone = withPhoneResponse.count ?? 0;

      return {
        'total': total,
        'optedOut': optedOut,
        'contactable': total - optedOut,
        'withPhone': withPhone,
      };
    } catch (e) {
      print('❌ Error fetching member stats: $e');
      return {
        'total': 0,
        'optedOut': 0,
        'contactable': 0,
        'withPhone': 0,
      };
    }
  }
}
