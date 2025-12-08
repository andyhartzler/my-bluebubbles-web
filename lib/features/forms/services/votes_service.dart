import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voting_form.dart';

class VotesService {
  final _supabase = Supabase.instance.client;

  Stream<List<VotingForm>> watchVotes(String statusFilter) {
    var query = _supabase
        .from('voting_forms')
        .stream(primaryKey: ['id']);

    if (statusFilter != 'all') {
      query = query.eq('status', statusFilter) as RealtimePostgresStreamBuilder;
    }

    return query
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => VotingForm.fromJson(json)).toList());
  }

  Future<VotingForm> getVote(String id) async {
    final response = await _supabase
        .from('voting_forms')
        .select()
        .eq('id', id)
        .single();

    return VotingForm.fromJson(response);
  }

  Future<String> createVote({
    required String title,
    String? description,
    required String votingType,
    required List<VotingOption> options,
    DateTime? startDate,
    DateTime? endDate,
    bool allowMultiple = false,
    int? maxChoices,
    bool requireMember = true,
    String status = 'draft',
  }) async {
    final response = await _supabase
        .from('voting_forms')
        .insert({
          'title': title,
          'description': description,
          'voting_type': votingType,
          'options': options.map((o) => o.toJson()).toList(),
          'start_date': startDate?.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'allow_multiple': allowMultiple,
          'max_choices': maxChoices,
          'require_member': requireMember,
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
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (options != null) {
      updates['options'] = options.map((o) => o.toJson()).toList();
    }
    if (startDate != null) updates['start_date'] = startDate.toIso8601String();
    if (endDate != null) updates['end_date'] = endDate.toIso8601String();
    if (status != null) updates['status'] = status;

    await _supabase
        .from('voting_forms')
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteVote(String id) async {
    await _supabase
        .from('voting_forms')
        .delete()
        .eq('id', id);
  }

  Future<void> publishVote(String id) async {
    await _supabase
        .from('voting_forms')
        .update({'status': 'active'})
        .eq('id', id);
  }

  Future<void> unpublishVote(String id) async {
    await _supabase
        .from('voting_forms')
        .update({'status': 'draft'})
        .eq('id', id);
  }

  Future<Map<String, int>> getVoteResults(String id) async {
    final vote = await getVote(id);
    final results = <String, int>{};

    for (final option in vote.options) {
      results[option.id] = option.votes;
    }

    return results;
  }

  Future<void> castVote(String voteId, List<String> optionIds) async {
    // Record the vote in the database
    await _supabase.from('vote_submissions').insert({
      'voting_form_id': voteId,
      'member_id': _supabase.auth.currentUser?.id,
      'option_ids': optionIds,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update vote counts
    for (final optionId in optionIds) {
      await _supabase.rpc('increment_vote_count', params: {
        'vote_id': voteId,
        'option_id': optionId,
      });
    }
  }
}
