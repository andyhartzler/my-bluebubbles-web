import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voting_form.dart';
import 'form_confirmation_service.dart';

class VotesService {
  final _supabase = Supabase.instance.client;

  // Voting forms are stored in form_schemas with form_type='vote'
  Stream<List<VotingForm>> watchVotes(String statusFilter) {
    return _supabase
        .from('form_schemas')
        .stream(primaryKey: ['id'])
        .eq('form_type', 'vote')
        .order('created_at', ascending: false)
        .map((data) {
      final votes = data.map((json) => VotingForm.fromJson(json)).toList();
      if (statusFilter == 'all') {
        return votes;
      } else {
        return votes.where((vote) => vote.status == statusFilter).toList();
      }
    });
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
    // Voting-specific fields
    DateTime? votingStartsAt,
    DateTime? votingEndsAt,
    Map<String, dynamic>? eligibleMembers,
    bool resultsPublic = false,
    String status = 'draft',
    // Scheduling (opens_at/closes_at can mirror voting dates or be separate)
    DateTime? opensAt,
    DateTime? closesAt,
    // Access control
    bool requireLogin = false,
    bool oneSubmissionPerUser = true, // Default true for votes (one vote per person)
    // Submission limits
    int? maxSubmissions,
    // Custom URL
    String? slug,
    // Email settings
    String? confirmationEmailTemplate,
    List<String>? notificationEmails,
    // SMS settings
    String? confirmationSmsMessage,
    // Supporting documents
    List<Map<String, dynamic>>? supportingDocuments,
  }) async {
    // Build schema with voting options
    final schema = {
      'fields': options.map((o) => o.toJson()).toList(),
    };

    // Build settings map with SMS confirmation if provided
    final settings = <String, dynamic>{};
    if (confirmationSmsMessage != null && confirmationSmsMessage.isNotEmpty) {
      settings['confirmation_sms'] = confirmationSmsMessage;
    }

    final response = await _supabase
        .from('form_schemas')
        .insert({
          'title': title,
          'description': description,
          'form_type': 'vote',
          'schema': schema,
          'settings': settings,
          'voting_starts_at': votingStartsAt?.toIso8601String(),
          'voting_ends_at': votingEndsAt?.toIso8601String(),
          'eligible_members': eligibleMembers,
          'results_public': resultsPublic,
          'status': status,
          'created_by': _supabase.auth.currentUser?.id,
          // Scheduling - use voting dates if opens_at/closes_at not provided
          if (opensAt != null) 'opens_at': opensAt.toIso8601String()
          else if (votingStartsAt != null) 'opens_at': votingStartsAt.toIso8601String(),
          if (closesAt != null) 'closes_at': closesAt.toIso8601String()
          else if (votingEndsAt != null) 'closes_at': votingEndsAt.toIso8601String(),
          'require_login': requireLogin,
          'one_submission_per_user': oneSubmissionPerUser,
          if (maxSubmissions != null) 'max_submissions': maxSubmissions,
          if (slug != null) 'slug': slug,
          if (confirmationEmailTemplate != null) 'confirmation_email_template': confirmationEmailTemplate,
          if (notificationEmails != null) 'notification_emails': notificationEmails,
          if (supportingDocuments != null) 'supporting_documents': supportingDocuments,
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
    // Voting-specific fields
    DateTime? votingStartsAt,
    bool clearVotingStartsAt = false,
    DateTime? votingEndsAt,
    bool clearVotingEndsAt = false,
    Map<String, dynamic>? eligibleMembers,
    bool clearEligibleMembers = false,
    bool? resultsPublic,
    String? status,
    // Scheduling
    DateTime? opensAt,
    bool clearOpensAt = false,
    DateTime? closesAt,
    bool clearClosesAt = false,
    // Access control
    bool? requireLogin,
    bool? oneSubmissionPerUser,
    // Submission limits
    int? maxSubmissions,
    bool clearMaxSubmissions = false,
    // Custom URL
    String? slug,
    bool clearSlug = false,
    // Email settings
    String? confirmationEmailTemplate,
    bool clearConfirmationEmailTemplate = false,
    List<String>? notificationEmails,
    bool clearNotificationEmails = false,
    // SMS settings
    String? confirmationSmsMessage,
    bool clearConfirmationSmsMessage = false,
    // Supporting documents
    List<Map<String, dynamic>>? supportingDocuments,
    bool clearSupportingDocuments = false,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (options != null) {
      updates['schema'] = {
        'fields': options.map((o) => o.toJson()).toList(),
      };
    }
    if (status != null) updates['status'] = status;

    // Voting-specific fields
    if (votingStartsAt != null) {
      updates['voting_starts_at'] = votingStartsAt.toIso8601String();
    } else if (clearVotingStartsAt) {
      updates['voting_starts_at'] = null;
    }
    if (votingEndsAt != null) {
      updates['voting_ends_at'] = votingEndsAt.toIso8601String();
    } else if (clearVotingEndsAt) {
      updates['voting_ends_at'] = null;
    }
    if (eligibleMembers != null) {
      updates['eligible_members'] = eligibleMembers;
    } else if (clearEligibleMembers) {
      updates['eligible_members'] = null;
    }
    if (resultsPublic != null) updates['results_public'] = resultsPublic;

    // Scheduling
    if (opensAt != null) {
      updates['opens_at'] = opensAt.toIso8601String();
    } else if (clearOpensAt) {
      updates['opens_at'] = null;
    }
    if (closesAt != null) {
      updates['closes_at'] = closesAt.toIso8601String();
    } else if (clearClosesAt) {
      updates['closes_at'] = null;
    }

    // Access control
    if (requireLogin != null) updates['require_login'] = requireLogin;
    if (oneSubmissionPerUser != null) updates['one_submission_per_user'] = oneSubmissionPerUser;

    // Submission limits
    if (maxSubmissions != null) {
      updates['max_submissions'] = maxSubmissions;
    } else if (clearMaxSubmissions) {
      updates['max_submissions'] = null;
    }

    // Custom URL
    if (slug != null) {
      updates['slug'] = slug;
    } else if (clearSlug) {
      updates['slug'] = null;
    }

    // Email settings
    if (confirmationEmailTemplate != null) {
      updates['confirmation_email_template'] = confirmationEmailTemplate;
    } else if (clearConfirmationEmailTemplate) {
      updates['confirmation_email_template'] = null;
    }
    if (notificationEmails != null) {
      updates['notification_emails'] = notificationEmails;
    } else if (clearNotificationEmails) {
      updates['notification_emails'] = null;
    }

    // SMS settings - stored in the settings JSON column
    if (confirmationSmsMessage != null || clearConfirmationSmsMessage) {
      // We need to fetch current settings and merge with new SMS value
      final currentVote = await getVote(id);
      final currentSettings = Map<String, dynamic>.from(currentVote.settings);
      if (confirmationSmsMessage != null && confirmationSmsMessage.isNotEmpty) {
        currentSettings['confirmation_sms'] = confirmationSmsMessage;
      } else if (clearConfirmationSmsMessage) {
        currentSettings.remove('confirmation_sms');
      }
      updates['settings'] = currentSettings;
    }

    // Supporting documents
    if (supportingDocuments != null) {
      updates['supporting_documents'] = supportingDocuments;
    } else if (clearSupportingDocuments) {
      updates['supporting_documents'] = null;
    }

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
    Map<String, dynamic> voteData, {
    String? voterEmail,
    String? voterPhone,
    String? voterName,
    bool sendConfirmations = true,
  }) async {
    // Record the vote in the votes table
    await _supabase.from('votes').insert({
      'voting_form_id': voteId,
      'member_id': memberId,
      'vote_data': voteData,
    });

    // The trigger update_vote_count() will automatically update results_data

    // Send confirmation messages and emails if enabled
    if (sendConfirmations && (voterEmail != null || voterPhone != null)) {
      try {
        final vote = await getVote(voteId);
        await FormConfirmationService().sendVoteConfirmations(
          vote: vote,
          voterEmail: voterEmail,
          voterPhone: voterPhone,
          voterName: voterName,
          voteData: voteData,
        );
      } catch (e) {
        // Log but don't fail the vote if confirmations fail
        print('Warning: Failed to send vote confirmations: $e');
      }
    }
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

  // Get voters with member details for a vote
  Future<List<Map<String, dynamic>>> getVoters(String votingFormId) async {
    final response = await _supabase
        .from('votes')
        .select('''
          id,
          vote_data,
          created_at,
          members:member_id (
            id,
            name,
            email,
            phone,
            phone_e164,
            county,
            profile_pictures
          )
        ''')
        .eq('voting_form_id', votingFormId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
