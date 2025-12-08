import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voting_form.dart';

class VotesService {
  final _supabase = Supabase.instance.client;

  // Voting forms are stored in form_schemas with form_type='vote'
  Stream<List<VotingForm>> watchVotes(String statusFilter) {
    var query = _supabase.from('form_schemas').eq('form_type', 'vote');

    if (statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    return query
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => VotingForm.fromJson(json)).toList());
  }

  Future<VotingForm> getVote(String id) async {
    final response = await _supabase
        .from('form_schemas')
        .select()
        .eq('id', id)
        .eq('form_type', 'vote')
        .single();

    return VotingForm.fromJson(response);
  }

  Future<String> createVote({
    required String title,
    String? description,
    required List<VotingOption> options,
    DateTime? votingStartsAt,
    DateTime? votingEndsAt,
    Map<String, dynamic>? eligibleMembers,
    bool resultsPublic = false,
    String status = 'draft',
  }) async {
    // Build schema with voting options
    final schema = {
      'fields': options.map((o) => o.toJson()).toList(),
    };

    final response = await _supabase
        .from('form_schemas')
        .insert({
          'title': title,
          'description': description,
          'form_type': 'vote',
          'schema': schema,
          'settings': {},
          'voting_starts_at': votingStartsAt?.toIso8601String(),
          'voting_ends_at': votingEndsAt?.toIso8601String(),
          'eligible_members': eligibleMembers,
          'results_public': resultsPublic,
          'status': status,
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  Future<void> updateVote(
    String id, {
    String? title,
    String? description,
    List<VotingOption>? options,
    DateTime? votingStartsAt,
    DateTime? votingEndsAt,
    String? status,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (options != null) {
      updates['schema'] = {
        'fields': options.map((o) => o.toJson()).toList(),
      };
    }
    if (votingStartsAt != null) {
      updates['voting_starts_at'] = votingStartsAt.toIso8601String();
    }
    if (votingEndsAt != null) {
      updates['voting_ends_at'] = votingEndsAt.toIso8601String();
    }
    if (status != null) updates['status'] = status;

    await _supabase
        .from('form_schemas')
        .update(updates)
        .eq('id', id)
        .eq('form_type', 'vote');
  }

  Future<void> deleteVote(String id) async {
    await _supabase
        .from('form_schemas')
        .delete()
        .eq('id', id)
        .eq('form_type', 'vote');
  }

  Future<void> publishVote(String id) async {
    await _supabase
        .from('form_schemas')
        .update({'status': 'active'})
        .eq('id', id)
        .eq('form_type', 'vote');
  }

  Future<void> unpublishVote(String id) async {
    await _supabase
        .from('form_schemas')
        .update({'status': 'draft'})
        .eq('id', id)
        .eq('form_type', 'vote');
  }

  Future<Map<String, dynamic>?> getVoteResults(String id) async {
    final vote = await getVote(id);
    return vote.resultsData;
  }

  Future<void> castVote(
    String voteId,
    String memberId,
    Map<String, dynamic> voteData,
  ) async {
    // Record the vote in the votes table
    await _supabase.from('votes').insert({
      'voting_form_id': voteId,
      'member_id': memberId,
      'vote_data': voteData,
    });

    // The trigger update_vote_count() will automatically update results_data
  }

  // Check if a member can vote
  Future<bool> canMemberVote(String memberId, String votingFormId) async {
    try {
      final response = await _supabase.rpc('can_member_vote', params: {
        'p_member_id': memberId,
        'p_voting_form_id': votingFormId,
      });
      return response as bool;
    } catch (e) {
      return false;
    }
  }

  // Check if member has already voted
  Future<bool> hasVoted(String memberId, String votingFormId) async {
    final response = await _supabase
        .from('votes')
        .select('id')
        .eq('voting_form_id', votingFormId)
        .eq('member_id', memberId)
        .maybeSingle();

    return response != null;
  }
}
