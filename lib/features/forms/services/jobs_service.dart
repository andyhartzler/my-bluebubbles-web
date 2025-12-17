import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';
import '../models/job_application.dart';
import '../models/job_notification_template.dart';
import '../models/job_notification_log.dart';
import '../models/job_analytics.dart';
import '../../../models/crm/member.dart';
import '../../../services/crm/supabase_service.dart';
import '../../../services/crm/crm_email_service.dart';

class JobsService {
  final _supabase = Supabase.instance.client;
  final _crmService = CRMSupabaseService();

  /// Get privileged client for bypassing RLS when reading/writing jobs
  SupabaseClient get _privilegedClient =>
      _crmService.isInitialized && _crmService.hasServiceRole
          ? _crmService.privilegedClient
          : _supabase;

  /// Get privileged client for bypassing RLS when writing jobs
  SupabaseClient get _writeClient => _privilegedClient;

  /// Get privileged client for bypassing RLS when reading jobs
  SupabaseClient get _readClient => _privilegedClient;

  Stream<List<Job>> watchJobs(String statusFilter) {
    // Use a polling approach with the privileged client to bypass RLS
    final controller = StreamController<List<Job>>.broadcast();
    Timer? timer;

    void fetchJobs() async {
      try {
        List<Job> jobs;
        if (statusFilter == 'all') {
          final response = await _readClient
              .from('jobs')
              .select()
              .order('created_at', ascending: false);
          jobs = (response as List).map((json) => Job.fromJson(json)).toList();
        } else {
          final response = await _readClient
              .from('jobs')
              .select()
              .eq('status', statusFilter)
              .order('created_at', ascending: false);
          jobs = (response as List).map((json) => Job.fromJson(json)).toList();
        }
        if (!controller.isClosed) {
          controller.add(jobs);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Initial fetch
    fetchJobs();

    // Poll every 5 seconds for updates
    timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchJobs());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  Stream<int> watchPendingCount() {
    // Use a polling approach with the privileged client to bypass RLS
    final controller = StreamController<int>.broadcast();
    Timer? timer;

    void fetchCount() async {
      try {
        final response = await _readClient
            .from('jobs')
            .select('id')
            .eq('status', 'pending');
        if (!controller.isClosed) {
          controller.add((response as List).length);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Initial fetch
    fetchCount();

    // Poll every 5 seconds for updates
    timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchCount());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  Future<Job> getJob(String id) async {
    final response = await _readClient
        .from('jobs')
        .select()
        .eq('id', id)
        .single();

    return Job.fromJson(response);
  }

  Future<void> approveJob(String id) async {
    await _writeClient.from('jobs').update({
      'status': 'approved',
      'approved_at': DateTime.now().toIso8601String(),
      'approved_by': _supabase.auth.currentUser?.id,
    }).eq('id', id);

    // Send approval notification
    try {
      final job = await getJob(id);
      await notifyJobApproved(job);
    } catch (_) {
      // Don't fail the operation if notification fails
    }
  }

  Future<void> rejectJob(String id, String reason) async {
    await _writeClient.from('jobs').update({
      'status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', id);

    // Send rejection notification
    try {
      final job = await getJob(id);
      await notifyJobRejected(job, reason);
    } catch (_) {
      // Don't fail the operation if notification fails
    }
  }

  Future<void> updateJob(String id, Map<String, dynamic> updates) async {
    await _writeClient
        .from('jobs')
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteJob(String id) async {
    await _writeClient
        .from('jobs')
        .delete()
        .eq('id', id);
  }

  Future<void> toggleFeatured(String id, bool featured) async {
    await _writeClient
        .from('jobs')
        .update({'featured': featured})
        .eq('id', id);
  }

  Future<String> createJob({
    required String title,
    required String organization,
    required String description,
    required String jobType,
    String? location,
    String? locationType,
    bool isPaid = false,
    String? salaryRange,
    String? hourlyRate,
    String? requirements,
    String? qualifications,
    required String contactEmail,
    String? contactName,
    String? contactPhone,
    String? applicationUrl,
    String? applicationInstructions,
    DateTime? expiresAt,
    String status = 'pending',
    required String submitterName,
    required String submitterEmail,
    String? submitterOrganization,
    String? submitterPhone,
    String? slug,
    bool featured = false,
    List<String>? tags,
    List<Map<String, dynamic>>? customQuestions,
    bool? resumeEnabled,
    bool? resumeRequired,
    bool? coverLetterEnabled,
    bool? coverLetterRequired,
    bool? useExternalApply,
  }) async {
    final response = await _writeClient
        .from('jobs')
        .insert({
          'title': title,
          'organization': organization,
          'description': description,
          'job_type': jobType,
          if (location != null) 'location': location,
          if (locationType != null) 'location_type': locationType,
          'is_paid': isPaid,
          if (salaryRange != null) 'salary_range': salaryRange,
          if (hourlyRate != null) 'hourly_rate': hourlyRate,
          if (requirements != null) 'requirements': requirements,
          if (qualifications != null) 'qualifications': qualifications,
          'contact_email': contactEmail,
          if (contactName != null) 'contact_name': contactName,
          if (contactPhone != null) 'contact_phone': contactPhone,
          if (applicationUrl != null) 'application_url': applicationUrl,
          if (applicationInstructions != null) 'application_instructions': applicationInstructions,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
          'status': status,
          'submitter_name': submitterName,
          'submitter_email': submitterEmail,
          if (submitterOrganization != null) 'submitter_organization': submitterOrganization,
          if (submitterPhone != null) 'submitter_phone': submitterPhone,
          if (slug != null) 'slug': slug,
          'featured': featured,
          if (tags != null) 'tags': tags,
          'custom_questions': customQuestions ?? [],
          if (resumeEnabled != null) 'resume_enabled': resumeEnabled,
          if (resumeRequired != null) 'resume_required': resumeRequired,
          if (coverLetterEnabled != null) 'cover_letter_enabled': coverLetterEnabled,
          if (coverLetterRequired != null) 'cover_letter_required': coverLetterRequired,
          if (useExternalApply != null) 'use_external_apply': useExternalApply,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  Future<void> updateJobDetails(
    String id, {
    String? title,
    String? organization,
    String? description,
    String? jobType,
    String? location,
    bool clearLocation = false,
    String? locationType,
    bool clearLocationType = false,
    bool? isPaid,
    String? salaryRange,
    bool clearSalaryRange = false,
    String? hourlyRate,
    bool clearHourlyRate = false,
    String? requirements,
    bool clearRequirements = false,
    String? qualifications,
    bool clearQualifications = false,
    String? contactEmail,
    String? contactName,
    bool clearContactName = false,
    String? contactPhone,
    bool clearContactPhone = false,
    String? applicationUrl,
    bool clearApplicationUrl = false,
    String? applicationInstructions,
    bool clearApplicationInstructions = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? status,
    String? submitterName,
    String? submitterEmail,
    String? submitterOrganization,
    bool clearSubmitterOrganization = false,
    String? submitterPhone,
    bool clearSubmitterPhone = false,
    String? slug,
    bool clearSlug = false,
    bool? featured,
    List<String>? tags,
    bool clearTags = false,
    List<Map<String, dynamic>>? customQuestions,
    bool? resumeEnabled,
    bool? resumeRequired,
    bool? coverLetterEnabled,
    bool? coverLetterRequired,
    bool? useExternalApply,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) updates['title'] = title;
    if (organization != null) updates['organization'] = organization;
    if (description != null) updates['description'] = description;
    if (jobType != null) updates['job_type'] = jobType;
    if (location != null) {
      updates['location'] = location;
    } else if (clearLocation) {
      updates['location'] = null;
    }
    if (locationType != null) {
      updates['location_type'] = locationType;
    } else if (clearLocationType) {
      updates['location_type'] = null;
    }
    if (isPaid != null) updates['is_paid'] = isPaid;
    if (salaryRange != null) {
      updates['salary_range'] = salaryRange;
    } else if (clearSalaryRange) {
      updates['salary_range'] = null;
    }
    if (hourlyRate != null) {
      updates['hourly_rate'] = hourlyRate;
    } else if (clearHourlyRate) {
      updates['hourly_rate'] = null;
    }
    if (requirements != null) {
      updates['requirements'] = requirements;
    } else if (clearRequirements) {
      updates['requirements'] = null;
    }
    if (qualifications != null) {
      updates['qualifications'] = qualifications;
    } else if (clearQualifications) {
      updates['qualifications'] = null;
    }
    if (contactEmail != null) updates['contact_email'] = contactEmail;
    if (contactName != null) {
      updates['contact_name'] = contactName;
    } else if (clearContactName) {
      updates['contact_name'] = null;
    }
    if (contactPhone != null) {
      updates['contact_phone'] = contactPhone;
    } else if (clearContactPhone) {
      updates['contact_phone'] = null;
    }
    if (applicationUrl != null) {
      updates['application_url'] = applicationUrl;
    } else if (clearApplicationUrl) {
      updates['application_url'] = null;
    }
    if (applicationInstructions != null) {
      updates['application_instructions'] = applicationInstructions;
    } else if (clearApplicationInstructions) {
      updates['application_instructions'] = null;
    }
    if (expiresAt != null) {
      updates['expires_at'] = expiresAt.toIso8601String();
    } else if (clearExpiresAt) {
      updates['expires_at'] = null;
    }
    if (status != null) updates['status'] = status;
    if (submitterName != null) updates['submitter_name'] = submitterName;
    if (submitterEmail != null) updates['submitter_email'] = submitterEmail;
    if (submitterOrganization != null) {
      updates['submitter_organization'] = submitterOrganization;
    } else if (clearSubmitterOrganization) {
      updates['submitter_organization'] = null;
    }
    if (submitterPhone != null) {
      updates['submitter_phone'] = submitterPhone;
    } else if (clearSubmitterPhone) {
      updates['submitter_phone'] = null;
    }
    if (slug != null) {
      updates['slug'] = slug;
    } else if (clearSlug) {
      updates['slug'] = null;
    }
    if (featured != null) updates['featured'] = featured;
    if (tags != null) {
      updates['tags'] = tags;
    } else if (clearTags) {
      updates['tags'] = null;
    }
    if (customQuestions != null) {
      updates['custom_questions'] = customQuestions;
    }
    if (resumeEnabled != null) updates['resume_enabled'] = resumeEnabled;
    if (resumeRequired != null) updates['resume_required'] = resumeRequired;
    if (coverLetterEnabled != null) updates['cover_letter_enabled'] = coverLetterEnabled;
    if (coverLetterRequired != null) updates['cover_letter_required'] = coverLetterRequired;
    if (useExternalApply != null) updates['use_external_apply'] = useExternalApply;

    if (updates.isNotEmpty) {
      await _writeClient.from('jobs').update(updates).eq('id', id);
    }
  }

  // ==================== JOB APPLICATIONS ====================

  /// Get all applications for a specific job
  Future<List<JobApplication>> getJobApplications(String jobId) async {
    final response = await _readClient
        .from('job_applications')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get applications for a job filtered by status
  Future<List<JobApplication>> getJobApplicationsByStatus(
    String jobId,
    String status,
  ) async {
    final response = await _readClient
        .from('job_applications')
        .select()
        .eq('job_id', jobId)
        .eq('status', status)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single job application by ID
  Future<JobApplication> getJobApplication(String id) async {
    final response = await _readClient
        .from('job_applications')
        .select()
        .eq('id', id)
        .single();

    return JobApplication.fromJson(response);
  }

  /// Watch applications for a specific job
  Stream<List<JobApplication>> watchJobApplications(String jobId) {
    final controller = StreamController<List<JobApplication>>.broadcast();
    Timer? timer;

    void fetchApplications() async {
      try {
        final applications = await getJobApplications(jobId);
        if (!controller.isClosed) {
          controller.add(applications);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Initial fetch
    fetchApplications();

    // Poll every 5 seconds for updates
    timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchApplications());

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  /// Get application count for a job
  Future<int> getApplicationCount(String jobId) async {
    final response = await _readClient
        .from('job_applications')
        .select('id')
        .eq('job_id', jobId);

    return (response as List).length;
  }

  /// Get application counts by status for a job
  Future<Map<String, int>> getApplicationCountsByStatus(String jobId) async {
    final response = await _readClient
        .from('job_applications')
        .select('status')
        .eq('job_id', jobId);

    final counts = <String, int>{
      'submitted': 0,
      'reviewed': 0,
      'shortlisted': 0,
      'rejected': 0,
      'accepted': 0,
    };

    for (final row in response as List) {
      final status = row['status'] as String? ?? 'submitted';
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  /// Update application status
  Future<void> updateApplicationStatus(String applicationId, String status) async {
    // Get current application to find old status
    final currentApp = await getJobApplication(applicationId);
    final oldStatus = currentApp.status;

    await _writeClient
        .from('job_applications')
        .update({'status': status})
        .eq('id', applicationId);

    // Send notification if status actually changed
    if (oldStatus != status) {
      try {
        final job = await getJob(currentApp.jobId);
        final updatedApp = await getJobApplication(applicationId);
        await notifyApplicationStatusChanged(job, updatedApp, oldStatus);
      } catch (_) {
        // Don't fail the operation if notification fails
      }
    }
  }

  /// Delete a job application
  Future<void> deleteJobApplication(String id) async {
    await _writeClient
        .from('job_applications')
        .delete()
        .eq('id', id);
  }

  /// Get all applications across all jobs (for overview)
  Future<List<JobApplication>> getAllApplications({
    String? statusFilter,
    int limit = 100,
  }) async {
    var query = _readClient.from('job_applications').select();

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => JobApplication.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get jobs with their application counts
  Future<List<Map<String, dynamic>>> getJobsWithApplicationCounts(String statusFilter) async {
    List<Job> jobs;
    if (statusFilter == 'all') {
      final response = await _readClient
          .from('jobs')
          .select()
          .order('created_at', ascending: false);
      jobs = (response as List).map((json) => Job.fromJson(json)).toList();
    } else {
      final response = await _readClient
          .from('jobs')
          .select()
          .eq('status', statusFilter)
          .order('created_at', ascending: false);
      jobs = (response as List).map((json) => Job.fromJson(json)).toList();
    }

    // Fetch application counts for each job
    final result = <Map<String, dynamic>>[];
    for (final job in jobs) {
      final count = await getApplicationCount(job.id);
      result.add({
        'job': job,
        'applicationCount': count,
      });
    }

    return result;
  }

  // ==================== MEMBER LOOKUP ====================

  /// Get member by ID
  Future<Member?> getMemberById(String memberId) async {
    try {
      final response = await _readClient
          .from('members')
          .select()
          .eq('id', memberId)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Get members for a list of member IDs
  Future<Map<String, Member>> getMembersByIds(List<String> memberIds) async {
    if (memberIds.isEmpty) return {};

    try {
      final response = await _readClient
          .from('members')
          .select()
          .inFilter('id', memberIds);

      final members = <String, Member>{};
      for (final row in response as List) {
        final member = Member.fromJson(row);
        members[member.id] = member;
      }
      return members;
    } catch (e) {
      print('⚠️ Error fetching members by IDs: $e');
      return {};
    }
  }

  /// Get applications with their associated members
  Future<List<Map<String, dynamic>>> getApplicationsWithMembers(String jobId) async {
    final applications = await getJobApplications(jobId);
    final memberIds = applications
        .where((a) => a.memberId != null)
        .map((a) => a.memberId!)
        .toList();

    final members = await getMembersByIds(memberIds);

    return applications.map((app) => {
      'application': app,
      'member': app.memberId != null ? members[app.memberId] : null,
    }).toList();
  }

  // ==================== NOTIFICATION TEMPLATES ====================

  /// Get all notification templates
  Future<List<JobNotificationTemplate>> getNotificationTemplates() async {
    final response = await _readClient
        .from('job_notification_templates')
        .select()
        .order('trigger_type')
        .order('recipient_type');

    return (response as List)
        .map((json) => JobNotificationTemplate.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get templates by trigger type
  Future<List<JobNotificationTemplate>> getTemplatesByTrigger(String triggerType) async {
    final response = await _readClient
        .from('job_notification_templates')
        .select()
        .eq('trigger_type', triggerType)
        .order('recipient_type');

    return (response as List)
        .map((json) => JobNotificationTemplate.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get the default template for a trigger/recipient combination
  Future<JobNotificationTemplate?> getDefaultTemplate(
    String triggerType,
    String recipientType,
  ) async {
    try {
      final response = await _readClient
          .from('job_notification_templates')
          .select()
          .eq('trigger_type', triggerType)
          .eq('recipient_type', recipientType)
          .eq('is_active', true)
          .eq('is_default', true)
          .maybeSingle();

      if (response == null) return null;
      return JobNotificationTemplate.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Get a single template by ID
  Future<JobNotificationTemplate?> getTemplate(String id) async {
    try {
      final response = await _readClient
          .from('job_notification_templates')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return JobNotificationTemplate.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Create a new notification template
  Future<String> createTemplate({
    required String triggerType,
    required String recipientType,
    required String name,
    String? description,
    bool emailEnabled = true,
    String? emailSubject,
    String? emailHtml,
    String? emailPlainText,
    bool smsEnabled = false,
    String? smsBody,
    bool isActive = true,
    bool isDefault = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;

    final response = await _writeClient
        .from('job_notification_templates')
        .insert({
          'trigger_type': triggerType,
          'recipient_type': recipientType,
          'name': name,
          if (description != null) 'description': description,
          'email_enabled': emailEnabled,
          if (emailSubject != null) 'email_subject': emailSubject,
          if (emailHtml != null) 'email_html': emailHtml,
          if (emailPlainText != null) 'email_plain_text': emailPlainText,
          'sms_enabled': smsEnabled,
          if (smsBody != null) 'sms_body': smsBody,
          'is_active': isActive,
          'is_default': isDefault,
          if (userId != null) 'created_by': userId,
        })
        .select()
        .single();

    return response['id'] as String;
  }

  /// Update an existing template
  Future<void> updateTemplate(
    String id, {
    String? name,
    String? description,
    bool? emailEnabled,
    String? emailSubject,
    String? emailHtml,
    String? emailPlainText,
    bool? smsEnabled,
    String? smsBody,
    bool? isActive,
    bool? isDefault,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (emailEnabled != null) updates['email_enabled'] = emailEnabled;
    if (emailSubject != null) updates['email_subject'] = emailSubject;
    if (emailHtml != null) updates['email_html'] = emailHtml;
    if (emailPlainText != null) updates['email_plain_text'] = emailPlainText;
    if (smsEnabled != null) updates['sms_enabled'] = smsEnabled;
    if (smsBody != null) updates['sms_body'] = smsBody;
    if (isActive != null) updates['is_active'] = isActive;
    if (isDefault != null) updates['is_default'] = isDefault;
    if (userId != null) updates['updated_by'] = userId;

    if (updates.isNotEmpty) {
      await _writeClient.from('job_notification_templates').update(updates).eq('id', id);
    }
  }

  /// Delete a template
  Future<void> deleteTemplate(String id) async {
    await _writeClient.from('job_notification_templates').delete().eq('id', id);
  }

  /// Get template variables for a trigger type
  Future<List<Map<String, dynamic>>> getTemplateVariables(String triggerType) async {
    final response = await _readClient
        .from('job_notification_template_variables')
        .select()
        .eq('trigger_type', triggerType)
        .order('variable_name');

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Get all template variables
  Future<Map<String, List<Map<String, dynamic>>>> getAllTemplateVariables() async {
    final response = await _readClient
        .from('job_notification_template_variables')
        .select()
        .order('trigger_type')
        .order('variable_name');

    final result = <String, List<Map<String, dynamic>>>{};
    for (final row in response as List) {
      final triggerType = row['trigger_type'] as String;
      result.putIfAbsent(triggerType, () => []).add(row as Map<String, dynamic>);
    }
    return result;
  }

  /// Toggle template active status
  Future<void> toggleTemplateActive(String id, bool isActive) async {
    await _writeClient
        .from('job_notification_templates')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  /// Set a template as default (and unset others for same trigger/recipient)
  Future<void> setTemplateAsDefault(String id) async {
    final template = await getTemplate(id);
    if (template == null) return;

    // Unset other defaults for this trigger/recipient combo
    await _writeClient
        .from('job_notification_templates')
        .update({'is_default': false})
        .eq('trigger_type', template.triggerType)
        .eq('recipient_type', template.recipientType);

    // Set this one as default
    await _writeClient
        .from('job_notification_templates')
        .update({'is_default': true})
        .eq('id', id);
  }

  // ==================== NOTIFICATION SENDING ====================

  final _emailService = CRMEmailService();

  /// Send notification for a job event
  Future<void> sendJobNotification({
    required String triggerType,
    required String recipientType,
    required Job job,
    JobApplication? application,
    Member? member,
    Map<String, String>? additionalVariables,
  }) async {
    // Get the default active template for this trigger/recipient combo
    final template = await getDefaultTemplate(triggerType, recipientType);
    if (template == null || !template.isActive) {
      return; // No active template configured
    }

    // Build variable substitution map
    final variables = _buildVariables(
      job: job,
      application: application,
      member: member,
      additionalVariables: additionalVariables,
    );

    // Determine recipient email
    String? recipientEmail;
    String? recipientName;

    if (recipientType == 'job_submitter') {
      recipientEmail = job.submitterEmail;
      recipientName = job.submitterName;
    } else if (recipientType == 'job_applicant' && application != null) {
      recipientEmail = application.applicantEmail;
      recipientName = application.applicantName;
    }

    if (recipientEmail == null) {
      return; // No recipient email available
    }

    // Send email if enabled
    if (template.emailEnabled && template.emailSubject != null) {
      try {
        final subject = _substituteVariables(template.emailSubject!, variables);
        final htmlBody = template.emailHtml != null
            ? _substituteVariables(template.emailHtml!, variables)
            : null;
        final textBody = template.emailPlainText != null
            ? _substituteVariables(template.emailPlainText!, variables)
            : null;

        await _emailService.sendEmail(
          to: [recipientEmail],
          subject: subject,
          htmlBody: htmlBody,
          textBody: textBody,
        );

        // Log the notification
        await _logNotification(
          templateId: template.id,
          triggerType: triggerType,
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          jobId: job.id,
          applicationId: application?.id,
          channel: 'email',
          status: 'sent',
          subjectRendered: subject,
        );
      } catch (e) {
        // Log failed notification
        await _logNotification(
          templateId: template.id,
          triggerType: triggerType,
          recipientEmail: recipientEmail,
          recipientName: recipientName,
          jobId: job.id,
          applicationId: application?.id,
          channel: 'email',
          status: 'failed',
          errorMessage: e.toString(),
        );
      }
    }

    // TODO: Add SMS sending when SMS service is integrated
  }

  /// Build variable map for template substitution
  Map<String, String> _buildVariables({
    required Job job,
    JobApplication? application,
    Member? member,
    Map<String, String>? additionalVariables,
  }) {
    final variables = <String, String>{
      'job_title': job.title,
      'job_organization': job.organization,
      'job_type': job.jobType,
      'job_location': job.location ?? 'Remote',
      'job_url': 'https://moyd.org/jobs/${job.slug ?? job.id}',
      'submitter_name': job.submitterName,
      'submitter_email': job.submitterEmail,
    };

    if (application != null) {
      variables.addAll({
        'applicant_name': application.applicantName,
        'applicant_email': application.applicantEmail,
        'applicant_phone': application.applicantPhone ?? '',
        'applicant_city': application.applicantCity ?? '',
        'status': application.status,
      });
    }

    if (member != null) {
      variables['member_name'] = member.name;
    }

    if (additionalVariables != null) {
      variables.addAll(additionalVariables);
    }

    return variables;
  }

  /// Substitute {{variable}} placeholders with actual values
  String _substituteVariables(String template, Map<String, String> variables) {
    var result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    // Remove any unsubstituted variables
    result = result.replaceAll(RegExp(r'\{\{[^}]+\}\}'), '');
    return result;
  }

  /// Log a notification to the notification_log table
  Future<void> _logNotification({
    required String templateId,
    required String triggerType,
    required String recipientEmail,
    String? recipientName,
    required String jobId,
    String? applicationId,
    required String channel,
    required String status,
    String? errorMessage,
    String? subjectRendered,
  }) async {
    try {
      await _writeClient.from('job_notification_log').insert({
        'template_id': templateId,
        'trigger_type': triggerType,
        'job_id': jobId,
        if (applicationId != null) 'application_id': applicationId,
        'recipient_email': recipientEmail,
        if (recipientName != null) 'recipient_name': recipientName,
        'channel': channel,
        'status': status,
        if (errorMessage != null) 'error_message': errorMessage,
        if (subjectRendered != null) 'subject_rendered': subjectRendered,
        'sent_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Ignore logging errors
    }
  }

  /// Send job submitted notification to submitter
  /// NOTE: This is handled by Supabase edge function, not called from CRM
  /// Kept here for reference and potential manual triggering
  Future<void> notifyJobSubmitted(Job job) async {
    await sendJobNotification(
      triggerType: 'job_submitted',
      recipientType: 'job_submitter',
      job: job,
    );
  }

  /// Send job approved notification to submitter
  Future<void> notifyJobApproved(Job job) async {
    await sendJobNotification(
      triggerType: 'job_approved',
      recipientType: 'job_submitter',
      job: job,
    );
  }

  /// Send job rejected notification to submitter
  Future<void> notifyJobRejected(Job job, String reason) async {
    await sendJobNotification(
      triggerType: 'job_rejected',
      recipientType: 'job_submitter',
      job: job,
      additionalVariables: {'rejection_reason': reason},
    );
  }

  /// Send application received notification to job poster
  /// NOTE: This is handled by Supabase edge function, not called from CRM
  /// Kept here for reference and potential manual triggering
  Future<void> notifyApplicationReceived(Job job, JobApplication application) async {
    await sendJobNotification(
      triggerType: 'application_received',
      recipientType: 'job_submitter',
      job: job,
      application: application,
    );
  }

  /// Send application submitted confirmation to applicant
  /// NOTE: This is handled by Supabase edge function, not called from CRM
  /// Kept here for reference and potential manual triggering
  Future<void> notifyApplicationSubmitted(Job job, JobApplication application) async {
    await sendJobNotification(
      triggerType: 'application_submitted',
      recipientType: 'job_applicant',
      job: job,
      application: application,
    );
  }

  /// Send application status changed notification to applicant
  Future<void> notifyApplicationStatusChanged(
    Job job,
    JobApplication application,
    String oldStatus,
  ) async {
    await sendJobNotification(
      triggerType: 'application_status_changed',
      recipientType: 'job_applicant',
      job: job,
      application: application,
      additionalVariables: {'old_status': oldStatus},
    );
  }

  // ============================================================================
  // Notification Log Methods
  // ============================================================================

  /// Get notification logs for a specific job
  Future<List<JobNotificationLog>> getNotificationLogsForJob(String jobId) async {
    final response = await _readClient
        .from('job_notification_log')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => JobNotificationLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get notification logs for a specific application
  Future<List<JobNotificationLog>> getNotificationLogsForApplication(
      String applicationId) async {
    final response = await _readClient
        .from('job_notification_log')
        .select()
        .eq('application_id', applicationId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => JobNotificationLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Watch notification logs for a specific job
  Stream<List<JobNotificationLog>> watchNotificationLogsForJob(String jobId) {
    return _readClient
        .from('job_notification_log')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => JobNotificationLog.fromJson(json))
            .toList());
  }

  /// Get recent notification logs (for admin view)
  Future<List<JobNotificationLog>> getRecentNotificationLogs({
    int limit = 50,
    String? statusFilter,
  }) async {
    var query = _readClient
        .from('job_notification_log')
        .select();

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => JobNotificationLog.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get notification log count for a job
  Future<int> getNotificationLogCountForJob(String jobId) async {
    final response = await _readClient
        .from('job_notification_log')
        .select()
        .eq('job_id', jobId)
        .count(CountOption.exact);

    return response.count;
  }

  // ============================================================================
  // Job Analytics Methods
  // ============================================================================

  /// Get analytics summary for a job (calculated from member interactions)
  Future<JobAnalyticsSummary> getJobAnalyticsSummary(String jobId) async {
    try {
      final interactions = await getJobMemberInteractions(jobId, limit: 1000);
      print('📊 Loaded ${interactions.length} member interactions for job $jobId');
      return JobAnalyticsSummary.fromInteractions(jobId, interactions);
    } catch (e) {
      print('⚠️ Error fetching job analytics summary: $e');
      return JobAnalyticsSummary(jobId: jobId);
    }
  }

  /// Get recent analytics events for a job
  Future<List<JobAnalyticsEvent>> getJobAnalyticsEvents(
    String jobId, {
    int limit = 100,
    String? eventType,
  }) async {
    try {
      var query = _readClient
          .from('job_analytics_events')
          .select()
          .eq('job_id', jobId);

      if (eventType != null) {
        query = query.eq('event_type', eventType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => JobAnalyticsEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('⚠️ Error fetching job analytics events: $e');
      return [];
    }
  }

  /// Get member interactions for a job (with member info)
  Future<List<JobMemberInteraction>> getJobMemberInteractions(
    String jobId, {
    int limit = 50,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final orderColumn = sortBy ?? 'last_viewed_at';

      // Fetch interactions first
      final response = await _readClient
          .from('job_member_interactions')
          .select()
          .eq('job_id', jobId)
          .order(orderColumn, ascending: ascending)
          .limit(limit);

      final interactionData = (response as List).cast<Map<String, dynamic>>();

      if (interactionData.isEmpty) {
        return [];
      }

      // Collect unique member IDs
      final memberIds = interactionData
          .map((json) => json['member_id'] as String)
          .toSet()
          .toList();

      // Fetch member data using the existing getMembersByIds method
      final memberMap = await getMembersByIds(memberIds);

      // Build interactions with member data enriched
      return interactionData.map((json) {
        final data = Map<String, dynamic>.from(json);
        final memberId = data['member_id'] as String;
        final member = memberMap[memberId];

        if (member != null) {
          data['memberName'] = member.name;
          data['memberEmail'] = member.email;
          data['memberCity'] = member.city;
          data['memberState'] = member.state;

          // Get profile photo URL from the Member model
          if (member.profilePhotos.isNotEmpty) {
            data['memberProfilePhotoUrl'] = member.profilePhotos.first.publicUrl;
          }
        }

        return JobMemberInteraction.fromJson(data);
      }).toList();
    } catch (e) {
      print('⚠️ Error fetching job member interactions: $e');
      return [];
    }
  }

  /// Get analytics events for a specific member on a job
  Future<List<JobAnalyticsEvent>> getMemberEventsForJob(
    String jobId,
    String memberId, {
    int limit = 50,
  }) async {
    try {
      final response = await _readClient
          .from('job_analytics_events')
          .select()
          .eq('job_id', jobId)
          .eq('member_id', memberId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => JobAnalyticsEvent.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get top engaged members for a job
  Future<List<JobMemberInteraction>> getTopEngagedMembers(
    String jobId, {
    int limit = 10,
  }) async {
    try {
      final interactions = await getJobMemberInteractions(
        jobId,
        limit: limit * 2,
      );

      // Sort by engagement score (calculated in the model)
      interactions.sort((a, b) => b.engagementScore.compareTo(a.engagementScore));

      return interactions.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get analytics event counts by type for a job
  Future<Map<String, int>> getEventCountsByType(String jobId) async {
    try {
      final response = await _readClient
          .from('job_analytics_events')
          .select('event_type')
          .eq('job_id', jobId);

      final counts = <String, int>{};
      for (final row in response as List) {
        final eventType = row['event_type'] as String;
        counts[eventType] = (counts[eventType] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      return {};
    }
  }

  /// Get daily view counts for a job (last N days)
  Future<List<Map<String, dynamic>>> getDailyViewCounts(
    String jobId, {
    int days = 30,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await _readClient
          .from('job_analytics_events')
          .select('created_at')
          .eq('job_id', jobId)
          .eq('event_type', 'view')
          .gte('created_at', startDate.toIso8601String())
          .order('created_at');

      // Group by date
      final dailyCounts = <String, int>{};
      for (final row in response as List) {
        final date = DateTime.parse(row['created_at'] as String);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
      }

      // Convert to list with all dates in range
      final result = <Map<String, dynamic>>[];
      for (var i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: days - 1 - i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        result.add({
          'date': dateKey,
          'count': dailyCounts[dateKey] ?? 0,
        });
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Get location breakdown for a job
  Future<Map<String, int>> getLocationBreakdown(String jobId) async {
    try {
      final interactions = await getJobMemberInteractions(jobId, limit: 1000);
      final locationCounts = <String, int>{};

      for (final interaction in interactions) {
        final location = interaction.lastCountry ?? 'Unknown';
        locationCounts[location] = (locationCounts[location] ?? 0) + 1;
      }

      return locationCounts;
    } catch (e) {
      return {};
    }
  }

  /// Get browser breakdown for a job
  Future<Map<String, int>> getBrowserBreakdown(String jobId) async {
    try {
      final interactions = await getJobMemberInteractions(jobId, limit: 1000);
      final browserCounts = <String, int>{};

      for (final interaction in interactions) {
        final browser = interaction.lastBrowser ?? 'Unknown';
        browserCounts[browser] = (browserCounts[browser] ?? 0) + 1;
      }

      return browserCounts;
    } catch (e) {
      return {};
    }
  }

  /// Get device type breakdown for a job
  Future<Map<String, int>> getDeviceBreakdown(String jobId) async {
    try {
      final interactions = await getJobMemberInteractions(jobId, limit: 1000);
      final deviceCounts = <String, int>{};

      for (final interaction in interactions) {
        final device = interaction.lastDeviceType ?? 'Unknown';
        deviceCounts[device] = (deviceCounts[device] ?? 0) + 1;
      }

      return deviceCounts;
    } catch (e) {
      return {};
    }
  }

  /// Get referrer breakdown for a job
  Future<Map<String, int>> getReferrerBreakdown(String jobId) async {
    try {
      final interactions = await getJobMemberInteractions(jobId, limit: 1000);
      final referrerCounts = <String, int>{};

      for (final interaction in interactions) {
        final referrer = interaction.firstReferrerDomain ?? 'Direct';
        referrerCounts[referrer] = (referrerCounts[referrer] ?? 0) + 1;
      }

      return referrerCounts;
    } catch (e) {
      return {};
    }
  }
}
