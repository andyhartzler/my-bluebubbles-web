import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';

class JobsService {
  final _supabase = Supabase.instance.client;

  Stream<List<Job>> watchJobs(String statusFilter) {
    var query = _supabase.from('jobs').stream(primaryKey: ['id']);

    if (statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    return query
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Job.fromJson(json)).toList());
  }

  Stream<int> watchPendingCount() {
    return _supabase
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .map((data) => data.length);
  }

  Future<Job> getJob(String id) async {
    final response = await _supabase
        .from('jobs')
        .select()
        .eq('id', id)
        .single();

    return Job.fromJson(response);
  }

  Future<void> approveJob(String id) async {
    await _supabase.from('jobs').update({
      'status': 'approved',
      'approved_at': DateTime.now().toIso8601String(),
      'approved_by': _supabase.auth.currentUser?.id,
    }).eq('id', id);

    // TODO: Send approval email to submitter
  }

  Future<void> rejectJob(String id, String reason) async {
    await _supabase.from('jobs').update({
      'status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', id);

    // TODO: Send rejection email to submitter
  }

  Future<void> updateJob(String id, Map<String, dynamic> updates) async {
    await _supabase
        .from('jobs')
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteJob(String id) async {
    await _supabase
        .from('jobs')
        .delete()
        .eq('id', id);
  }

  Future<void> toggleFeatured(String id, bool featured) async {
    await _supabase
        .from('jobs')
        .update({'featured': featured})
        .eq('id', id);
  }
}
