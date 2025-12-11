import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/voting_form.dart';
import '../models/vote_analytics.dart';
import 'form_confirmation_service.dart';
import 'form_analytics_service.dart';
import '../../../services/crm/supabase_service.dart';

class VotesService {
  final _supabase = Supabase.instance.client;
  final _crmService = CRMSupabaseService();

  /// Get privileged client for bypassing RLS when reading votes
  SupabaseClient get _readClient =>
      _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

  // Voting forms are stored in form_schemas with form_type='vote'
  Stream<List<VotingForm>> watchVotes(String statusFilter, {String? committee}) {
    return _supabase
        .from('form_schemas')
        .stream(primaryKey: ['id'])
        .eq('form_type', 'vote')
        .order('created_at', ascending: false)
        .map((data) {
      var votes = data.map((json) => VotingForm.fromJson(json)).toList();

      // Filter by committee if provided
      if (committee != null) {
        votes = votes.where((vote) => vote.committee == committee).toList();
      }

      // Filter by status
      if (statusFilter != 'all') {
        votes = votes.where((vote) => vote.status == statusFilter).toList();
      }

      return votes;
    });
  }

  /// Watch votes for a specific committee
  Stream<List<VotingForm>> watchVotesForCommittee(String committee, String statusFilter) {
    return watchVotes(statusFilter, committee: committee);
  }

  Future<VotingForm> getVote(String id) async {
    final response = await _readClient
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
    // Legacy: simple options list (converted to single multiple_choice question)
    List<VotingOption>? options,
    // New: full questions list with different types
    List<Map<String, dynamic>>? questions,
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
    bool executiveOnly = false, // Restrict voting to executive committee members
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
    // Committee association
    String? committee,
  }) async {
    // Build schema with voting questions or legacy options
    final Map<String, dynamic> schema;
    if (questions != null && questions.isNotEmpty) {
      // New format: multiple questions with different types
      schema = {
        'questions': questions,
      };
    } else if (options != null && options.isNotEmpty) {
      // Legacy format: single question with options stored in 'fields'
      schema = {
        'fields': options.map((o) => o.toJson()).toList(),
      };
    } else {
      schema = {'questions': []};
    }

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
          'executive_only': executiveOnly,
          if (maxSubmissions != null) 'max_submissions': maxSubmissions,
          if (slug != null) 'slug': slug,
          if (confirmationEmailTemplate != null) 'confirmation_email_template': confirmationEmailTemplate,
          if (notificationEmails != null) 'notification_emails': notificationEmails,
          if (supportingDocuments != null) 'supporting_documents': supportingDocuments,
          // Committee association
          if (committee != null) 'committee': committee,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  Future<void> updateVote(
    String id, {
    String? title,
    String? description,
    // Legacy: simple options list
    List<VotingOption>? options,
    // New: full questions list with different types
    List<Map<String, dynamic>>? questions,
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
    bool? executiveOnly,
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

    // Handle schema update - prefer questions over options
    if (questions != null) {
      updates['schema'] = {'questions': questions};
    } else if (options != null) {
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
    if (executiveOnly != null) updates['executive_only'] = executiveOnly;

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
      // First check if this is an executive-only vote
      final vote = await getVote(votingFormId);

      if (vote.executiveOnly) {
        // Check if the member is on the executive committee
        final memberResponse = await _readClient
            .from('members')
            .select('executive_committee')
            .eq('id', memberId)
            .maybeSingle();

        if (memberResponse == null) {
          return false; // Member not found
        }

        final isExecutiveCommittee = memberResponse['executive_committee'] as bool? ?? false;
        if (!isExecutiveCommittee) {
          return false; // Not an executive committee member
        }
      }

      // Then check other eligibility criteria via RPC
      final response = await _readClient.rpc('can_member_vote', params: {
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
    final response = await _readClient
        .from('votes')
        .select('id')
        .eq('voting_form_id', votingFormId)
        .eq('member_id', memberId)
        .maybeSingle();

    return response != null;
  }

  // Get voters with member details for a vote
  Future<List<Map<String, dynamic>>> getVoters(String votingFormId) async {
    final response = await _readClient
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

  /// Get all votes cast by a specific member, with vote form details
  Future<List<Map<String, dynamic>>> getVotesByMember(String memberId) async {
    final response = await _readClient
        .from('votes')
        .select('''
          id,
          vote_data,
          created_at,
          voting_form_id,
          form_schemas!voting_form_id (
            id,
            title,
            schema,
            voting_starts_at,
            voting_ends_at
          )
        ''')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get vote choice label from vote_data and schema
  static String? getVoteChoiceLabel(
    Map<String, dynamic>? voteData,
    Map<String, dynamic>? schema,
  ) {
    if (voteData == null || voteData.isEmpty) return null;
    if (schema == null) return voteData.values.first?.toString();

    final questions = schema['questions'] as List<dynamic>?;
    if (questions == null || questions.isEmpty) {
      // Try old format with 'fields'
      final fields = schema['fields'] as List<dynamic>?;
      if (fields != null) {
        final firstOptionId = voteData.values.first?.toString();
        for (final field in fields) {
          if (field is Map<String, dynamic> && field['id'] == firstOptionId) {
            return field['label']?.toString();
          }
        }
      }
      return voteData.values.first?.toString();
    }

    final labels = <String>[];
    for (final question in questions) {
      if (question is! Map<String, dynamic>) continue;
      final questionId = question['id'] as String?;
      if (questionId == null) continue;

      final answer = voteData[questionId];
      if (answer == null) continue;

      final options = question['options'] as List<dynamic>?;
      if (options == null) continue;

      for (final option in options) {
        if (option is! Map<String, dynamic>) continue;
        final optionId = option['id'];
        if (answer is String && optionId == answer) {
          final label = option['label']?.toString();
          if (label != null) labels.add(label);
          break;
        } else if (answer is List) {
          for (final ans in answer) {
            if (optionId == ans) {
              final label = option['label']?.toString();
              if (label != null) labels.add(label);
            }
          }
        }
      }
    }

    if (labels.isEmpty) return null;
    if (labels.length == 1) return labels.first;
    return labels.join(', ');
  }

  // ============================================
  // Vote Analytics Methods
  // ============================================

  final _analyticsService = FormAnalyticsService();

  /// Get comprehensive vote analytics
  Future<VoteAnalytics> getVoteAnalytics(String voteId) async {
    try {
      // Get form analytics summary
      final formAnalytics = await _analyticsService.getFormAnalytics(voteId);

      // Get time series data for daily activity
      final timeSeries = await _analyticsService.getSubmissionTimeSeries(voteId);

      // Build daily activity with cumulative counts
      final dailyActivity = <DailyActivityData>[];
      int cumulativeVotes = 0;
      for (final data in timeSeries) {
        cumulativeVotes += data.count;
        dailyActivity.add(DailyActivityData(
          date: data.date,
          views: data.count, // Approximating views with submissions
          submissions: data.count,
          cumulativeVotes: cumulativeVotes,
        ));
      }

      // Get field-level analytics
      final fieldAnalyticsData = await _analyticsService.getFieldAnalytics(voteId);
      final fieldAnalytics = fieldAnalyticsData.map((f) => VoteFieldAnalytics(
        fieldId: f.fieldId,
        fieldLabel: null, // Would need to join with schema
        interactions: f.interactions,
        completions: f.interactions, // Approximate
        averageTimeSpent: 0,
        dropOffRate: 0,
      )).toList();

      return VoteAnalytics.fromFormAnalytics(
        formId: voteId,
        totalViews: formAnalytics.totalViews,
        totalStarts: formAnalytics.totalStarts,
        totalSubmissions: formAnalytics.totalSubmissions,
        totalAbandons: formAnalytics.totalAbandonments,
        fieldAnalytics: fieldAnalytics,
        dailyActivity: dailyActivity,
      );
    } catch (e) {
      print('Error getting vote analytics: $e');
      return VoteAnalytics.empty(voteId);
    }
  }

  /// Get vote results summary with participation metrics
  Future<VoteResultsSummary> getVoteResultsSummary(String voteId) async {
    final vote = await getVote(voteId);
    final voters = await getVoters(voteId);
    final eligibleCount = await getEligibleVotersCount(voteId, vote.eligibleMembers);

    // Calculate results per question
    final questionResults = <QuestionResultData>[];

    for (final question in vote.questions) {
      final questionId = question['id'] as String? ?? 'default';
      final questionText = question['text'] as String? ?? 'Question';
      final questionType = question['question_type'] as String? ?? 'multiple_choice';
      final options = (question['options'] as List<dynamic>?) ?? [];

      // Count votes per option
      final optionCounts = <String, int>{};
      for (final option in options) {
        final optId = (option as Map<String, dynamic>)['id'] as String?;
        if (optId != null) {
          optionCounts[optId] = 0;
        }
      }

      // Count from voter data
      for (final voter in voters) {
        final voteData = voter['vote_data'] as Map<String, dynamic>?;
        if (voteData == null) continue;

        final answer = voteData[questionId];
        if (answer is String) {
          optionCounts[answer] = (optionCounts[answer] ?? 0) + 1;
        } else if (answer is List) {
          for (final item in answer) {
            if (item is String) {
              optionCounts[item] = (optionCounts[item] ?? 0) + 1;
            }
          }
        }
      }

      // Calculate percentages and find winner
      final totalForQuestion = optionCounts.values.fold(0, (a, b) => a + b);
      String? winner;
      int maxVotes = 0;

      final optionResults = <OptionResultData>[];
      for (final option in options) {
        final optMap = option as Map<String, dynamic>;
        final optId = optMap['id'] as String?;
        final optLabel = optMap['label'] as String? ?? optId ?? 'Option';
        final count = optionCounts[optId] ?? 0;
        final percentage = totalForQuestion > 0
            ? (count / totalForQuestion * 100)
            : 0.0;

        if (count > maxVotes) {
          maxVotes = count;
          winner = optId;
        }

        optionResults.add(OptionResultData(
          value: optId ?? '',
          label: optLabel,
          count: count,
          percentage: percentage,
        ));
      }

      questionResults.add(QuestionResultData(
        fieldId: questionId,
        question: questionText,
        questionType: questionType,
        options: optionResults,
        winner: questionType == 'multiple_choice' ? winner : null,
      ));
    }

    return VoteResultsSummary.fromVoteData(
      formId: voteId,
      totalVotes: voters.length,
      eligibleVoters: eligibleCount,
      questionResults: questionResults,
    );
  }

  /// Get count of eligible voters for a vote
  Future<int> getEligibleVotersCount(
    String voteId,
    Map<String, dynamic>? eligibleMembers, {
    bool? executiveOnly,
  }) async {
    try {
      // If executiveOnly is not provided, fetch the vote to check
      bool isExecutiveOnly = executiveOnly ?? false;
      if (executiveOnly == null) {
        try {
          final vote = await getVote(voteId);
          isExecutiveOnly = vote.executiveOnly;
        } catch (e) {
          // If we can't fetch the vote, continue without executive filter
        }
      }

      // Calculate the cutoff date for age 36 (members must be 36 or younger)
      final now = DateTime.now();
      final cutoffDate = DateTime(now.year - 36, now.month, now.day);
      final cutoffDateStr = cutoffDate.toIso8601String().split('T').first;

      if (eligibleMembers == null || eligibleMembers.isEmpty) {
        if (isExecutiveOnly) {
          // For executive-only votes, only count executive committee members
          final response = await _readClient
              .from('members')
              .select('id')
              .eq('executive_committee', true);
          return (response as List).length;
        } else {
          // For regular votes, count members who are 36 or younger
          // date_of_birth must be >= cutoffDate (born on or after the cutoff)
          final response = await _readClient
              .from('members')
              .select('id')
              .gte('date_of_birth', cutoffDateStr);
          return (response as List).length;
        }
      }

      // Custom eligibility filter
      if (isExecutiveOnly) {
        // For executive-only votes with custom filters
        var query = _readClient.from('members').select('id').eq('executive_committee', true);

        // Apply eligibility filters
        final chapterNames = eligibleMembers['chapter_names'] as List<dynamic>?;
        if (chapterNames != null && chapterNames.isNotEmpty) {
          query = query.inFilter('chapter_name', chapterNames.cast<String>());
        }

        final membershipStatus = eligibleMembers['membership_status'] as String?;
        if (membershipStatus != null) {
          query = query.eq('current_chapter_member', membershipStatus);
        }

        final response = await query;
        return (response as List).length;
      } else {
        // For regular votes with custom filters, include age filter
        var query = _readClient
            .from('members')
            .select('id')
            .gte('date_of_birth', cutoffDateStr);

        // Apply eligibility filters
        final chapterNames = eligibleMembers['chapter_names'] as List<dynamic>?;
        if (chapterNames != null && chapterNames.isNotEmpty) {
          query = query.inFilter('chapter_name', chapterNames.cast<String>());
        }

        final membershipStatus = eligibleMembers['membership_status'] as String?;
        if (membershipStatus != null) {
          query = query.eq('current_chapter_member', membershipStatus);
        }

        final response = await query;
        return (response as List).length;
      }
    } catch (e) {
      print('Error getting eligible voters count: $e');
      return 0;
    }
  }

  /// Export votes to CSV format
  Future<String> exportVotesToCsv(String voteId) async {
    final vote = await getVote(voteId);
    final voters = await getVoters(voteId);
    final questions = vote.questions;

    // Build CSV header
    final headers = ['Voter Name', 'Email', 'County', 'Voted At'];
    for (final question in questions) {
      final questionText = question['text'] as String? ?? 'Question';
      headers.add(questionText);
    }

    final lines = [headers.map(_escapeCSV).join(',')];

    // Build CSV rows
    for (final voter in voters) {
      final memberData = voter['members'] as Map<String, dynamic>?;
      final voteData = voter['vote_data'] as Map<String, dynamic>?;
      final createdAt = voter['created_at'] as String?;

      final row = [
        _escapeCSV(memberData?['name']?.toString() ?? ''),
        _escapeCSV(memberData?['email']?.toString() ?? ''),
        _escapeCSV(memberData?['county']?.toString() ?? ''),
        createdAt ?? '',
      ];

      for (final question in questions) {
        final questionId = question['id'] as String? ?? 'default';
        final options = (question['options'] as List<dynamic>?) ?? [];
        final answer = voteData?[questionId];

        String answerDisplay = '';
        if (answer is String) {
          // Look up label
          for (final opt in options) {
            if ((opt as Map<String, dynamic>)['id'] == answer) {
              answerDisplay = opt['label'] as String? ?? answer;
              break;
            }
          }
          if (answerDisplay.isEmpty) answerDisplay = answer;
        } else if (answer is List) {
          final labels = <String>[];
          for (final ans in answer) {
            for (final opt in options) {
              if ((opt as Map<String, dynamic>)['id'] == ans) {
                labels.add(opt['label'] as String? ?? ans.toString());
                break;
              }
            }
          }
          answerDisplay = labels.join('; ');
        }

        row.add(_escapeCSV(answerDisplay));
      }

      lines.add(row.join(','));
    }

    return lines.join('\n');
  }

  /// Escape a value for CSV
  String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
