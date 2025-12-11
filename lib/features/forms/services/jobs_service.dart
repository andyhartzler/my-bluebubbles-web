import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';
import '../../../services/crm/supabase_service.dart';

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

    // TODO: Send approval email to submitter
  }

  Future<void> rejectJob(String id, String reason) async {
    await _writeClient.from('jobs').update({
      'status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', id);

    // TODO: Send rejection email to submitter
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

    if (updates.isNotEmpty) {
      await _writeClient.from('jobs').update(updates).eq('id', id);
    }
  }
}
