import 'dart:convert';

import 'package:bluebubbles/models/crm/member.dart';

class PortalAttachment {
  final String name;
  final String url;

  const PortalAttachment({required this.name, required this.url});

  factory PortalAttachment.fromJson(dynamic value) {
    if (value is PortalAttachment) return value;
    if (value is Map<String, dynamic>) {
      return PortalAttachment(
        name: value['name']?.toString() ?? '',
        url: value['url']?.toString() ?? '',
      );
    }
    throw const FormatException('Invalid attachment payload');
  }

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
}

class MemberPortalMeeting {
  final String id;
  final String meetingId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String memberTitle;
  final String? memberDescription;
  final String? memberSummary;
  final String? memberKeyPoints;
  final String? memberActionItems;
  final bool visibleToAll;
  final bool visibleToAttendeesOnly;
  final bool visibleToExecutives;
  final bool isPublished;
  final bool? showRecording;
  final List<PortalAttachment> attachments;
  final DateTime? publishedAt;
  final String? publishedBy;
  final String? meetingTitle;
  final DateTime? meetingDate;
  final int? attendeeCount;
  final String? recordingEmbedUrl;
  final String? recordingUrl;

  const MemberPortalMeeting({
    required this.id,
    required this.meetingId,
    required this.createdAt,
    this.updatedAt,
    required this.memberTitle,
    this.memberDescription,
    this.memberSummary,
    this.memberKeyPoints,
    this.memberActionItems,
    this.visibleToAll = false,
    this.visibleToAttendeesOnly = true,
    this.visibleToExecutives = true,
    this.isPublished = false,
    this.showRecording,
    this.attachments = const [],
    this.publishedAt,
    this.publishedBy,
    this.meetingTitle,
    this.meetingDate,
    this.attendeeCount,
    this.recordingEmbedUrl,
    this.recordingUrl,
  });

  factory MemberPortalMeeting.fromJson(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'];
    final attachments = <PortalAttachment>[];
    if (attachmentsRaw is List) {
      for (final item in attachmentsRaw) {
        try {
          attachments.add(PortalAttachment.fromJson(item));
        } catch (_) {}
      }
    } else if (attachmentsRaw is String && attachmentsRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(attachmentsRaw);
        if (parsed is List) {
          attachments.addAll(parsed.map(PortalAttachment.fromJson));
        }
      } catch (_) {}
    }

    final meeting = json['meetings'] as Map<String, dynamic>?;
    final meetingDateValue = meeting?["meeting_date"] ?? json['meeting_date'];
    final meetingTitleValue = meeting?["meeting_title"] ?? json['meeting_title'];
    final attendanceCountValue = meeting?["attendance_count"] ?? json['attendance_count'];
    final embedUrlValue = meeting?["recording_embed_url"] ?? json['recording_embed_url'];
    final recordingUrlValue = meeting?["recording_url"] ?? json['recording_url'];

    return MemberPortalMeeting(
      id: json['id'].toString(),
      meetingId: json['meeting_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      memberTitle: json['member_title']?.toString() ?? '',
      memberDescription: json['member_description']?.toString(),
      memberSummary: json['member_summary']?.toString(),
      memberKeyPoints: json['member_key_points']?.toString(),
      memberActionItems: json['member_action_items']?.toString(),
      visibleToAll: _normalizeBool(json['visible_to_all']) ?? false,
      visibleToAttendeesOnly: _normalizeBool(json['visible_to_attendees_only']) ?? true,
      visibleToExecutives: _normalizeBool(json['visible_to_executives']) ?? true,
      isPublished: _normalizeBool(json['is_published']) ?? false,
      showRecording: _normalizeBool(json['show_recording']),
      attachments: List<PortalAttachment>.unmodifiable(attachments),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      publishedBy: json['published_by']?.toString(),
      meetingTitle: meetingTitleValue?.toString(),
      meetingDate: DateTime.tryParse(meetingDateValue?.toString() ?? ''),
      attendeeCount: _normalizeInt(attendanceCountValue),
      recordingEmbedUrl: embedUrlValue?.toString(),
      recordingUrl: recordingUrlValue?.toString(),
    );
  }

  MemberPortalMeeting copyWith({
    bool? visibleToAll,
    bool? visibleToAttendeesOnly,
    bool? isPublished,
    bool? showRecording,
    List<PortalAttachment>? attachments,
    String? memberTitle,
    String? memberDescription,
    String? memberSummary,
    String? memberKeyPoints,
    String? memberActionItems,
    DateTime? publishedAt,
    String? publishedBy,
    bool? visibleToExecutives,
    String? recordingEmbedUrl,
    String? recordingUrl,
  }) {
    return MemberPortalMeeting(
      id: id,
      meetingId: meetingId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      memberTitle: memberTitle ?? this.memberTitle,
      memberDescription: memberDescription ?? this.memberDescription,
      memberSummary: memberSummary ?? this.memberSummary,
      memberKeyPoints: memberKeyPoints ?? this.memberKeyPoints,
      memberActionItems: memberActionItems ?? this.memberActionItems,
      visibleToAll: visibleToAll ?? this.visibleToAll,
      visibleToAttendeesOnly: visibleToAttendeesOnly ?? this.visibleToAttendeesOnly,
      visibleToExecutives: visibleToExecutives ?? this.visibleToExecutives,
      isPublished: isPublished ?? this.isPublished,
      showRecording: showRecording ?? this.showRecording,
      attachments: attachments ?? this.attachments,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      meetingTitle: meetingTitle,
      meetingDate: meetingDate,
      attendeeCount: attendeeCount,
      recordingEmbedUrl: recordingEmbedUrl ?? this.recordingEmbedUrl,
      recordingUrl: recordingUrl ?? this.recordingUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'member_title': memberTitle,
      'member_description': memberDescription,
      'member_summary': memberSummary,
      'member_key_points': memberKeyPoints,
      'member_action_items': memberActionItems,
      'visible_to_all': visibleToAll,
      'visible_to_attendees_only': visibleToAttendeesOnly,
      'visible_to_executives': visibleToExecutives,
      'is_published': isPublished,
      'show_recording': showRecording,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'published_at': publishedAt?.toIso8601String(),
      'published_by': publishedBy,
      'recording_embed_url': recordingEmbedUrl,
      'recording_url': recordingUrl,
    }..removeWhere((key, value) => value == null);
  }
}

class MemberSubmittedEvent {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String submittedBy;
  final String title;
  final String? description;
  final DateTime eventDate;
  final DateTime? eventEndDate;
  final String? location;
  final String? locationAddress;
  final String? eventType;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? publicEventId;
  final String? submissionNotes;
  final String? adminNotes;

  const MemberSubmittedEvent({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.submittedBy,
    required this.title,
    this.description,
    required this.eventDate,
    this.eventEndDate,
    this.location,
    this.locationAddress,
    this.eventType,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.approvalStatus = 'pending',
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.publicEventId,
    this.submissionNotes,
    this.adminNotes,
  });

  factory MemberSubmittedEvent.fromJson(Map<String, dynamic> json) {
    return MemberSubmittedEvent(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      submittedBy: json['submitted_by']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      eventDate: DateTime.tryParse(json['event_date']?.toString() ?? '') ?? DateTime.now(),
      eventEndDate: DateTime.tryParse(json['event_end_date']?.toString() ?? ''),
      location: json['location']?.toString(),
      locationAddress: json['location_address']?.toString(),
      eventType: json['event_type']?.toString(),
      contactName: json['contact_name']?.toString(),
      contactEmail: json['contact_email']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      approvalStatus: json['approval_status']?.toString() ?? 'pending',
      approvedBy: json['approved_by']?.toString(),
      approvedAt: DateTime.tryParse(json['approved_at']?.toString() ?? ''),
      rejectionReason: json['rejection_reason']?.toString(),
      publicEventId: json['public_event_id']?.toString(),
      submissionNotes: json['submission_notes']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
    );
  }

  MemberSubmittedEvent copyWith({
    String? approvalStatus,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    String? publicEventId,
    String? adminNotes,
  }) {
    return MemberSubmittedEvent(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      submittedBy: submittedBy,
      title: title,
      description: description,
      eventDate: eventDate,
      eventEndDate: eventEndDate,
      location: location,
      locationAddress: locationAddress,
      eventType: eventType,
      contactName: contactName,
      contactEmail: contactEmail,
      contactPhone: contactPhone,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      publicEventId: publicEventId ?? this.publicEventId,
      submissionNotes: submissionNotes,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submitted_by': submittedBy,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'event_end_date': eventEndDate?.toIso8601String(),
      'location': location,
      'location_address': locationAddress,
      'event_type': eventType,
      'contact_name': contactName,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'approval_status': approvalStatus,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'public_event_id': publicEventId,
      'submission_notes': submissionNotes,
      'admin_notes': adminNotes,
    }..removeWhere((key, value) => value == null);
  }
}

class MemberPortalResource {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String title;
  final String? description;
  final String resourceType;
  final String? url;
  final String? storageUrl;
  final bool isVisible;
  final int? sortOrder;
  final String? category;
  final String? iconUrl;
  final String? thumbnailUrl;
  final int? fileSizeBytes;
  final String? fileType;
  final String? version;
  final DateTime? lastUpdatedDate;
  final bool requiresExecutiveAccess;

  const MemberPortalResource({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.title,
    this.description,
    required this.resourceType,
    this.url,
    this.storageUrl,
    this.isVisible = false,
    this.sortOrder,
    this.category,
    this.iconUrl,
    this.thumbnailUrl,
    this.fileSizeBytes,
    this.fileType,
    this.version,
    this.lastUpdatedDate,
    this.requiresExecutiveAccess = false,
  });

  factory MemberPortalResource.fromJson(Map<String, dynamic> json) {
    return MemberPortalResource(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      resourceType: json['resource_type']?.toString() ?? 'digital_toolkit',
      url: json['url']?.toString(),
      storageUrl: json['storage_url']?.toString(),
      isVisible: _normalizeBool(json['is_visible']) ?? false,
      sortOrder: _normalizeInt(json['sort_order']),
      category: json['category']?.toString(),
      iconUrl: json['icon_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      fileSizeBytes: _normalizeInt(json['file_size_bytes']),
      fileType: json['file_type']?.toString(),
      version: json['version']?.toString(),
      lastUpdatedDate: DateTime.tryParse(json['last_updated_date']?.toString() ?? ''),
      requiresExecutiveAccess:
          _normalizeBool(json['requires_executive_access']) ?? false,
    );
  }

  MemberPortalResource copyWith({
    String? title,
    String? description,
    String? resourceType,
    String? url,
    String? storageUrl,
    bool? isVisible,
    int? sortOrder,
    String? category,
    String? iconUrl,
    String? thumbnailUrl,
    int? fileSizeBytes,
    String? fileType,
    String? version,
    DateTime? lastUpdatedDate,
    bool? requiresExecutiveAccess,
  }) {
    return MemberPortalResource(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      title: title ?? this.title,
      description: description ?? this.description,
      resourceType: resourceType ?? this.resourceType,
      url: url ?? this.url,
      storageUrl: storageUrl ?? this.storageUrl,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      category: category ?? this.category,
      iconUrl: iconUrl ?? this.iconUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileType: fileType ?? this.fileType,
      version: version ?? this.version,
      lastUpdatedDate: lastUpdatedDate ?? this.lastUpdatedDate,
      requiresExecutiveAccess:
          requiresExecutiveAccess ?? this.requiresExecutiveAccess,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.isEmpty ? null : id,
      'title': title,
      'description': description,
      'resource_type': resourceType,
      'url': url,
      'storage_url': storageUrl,
      'is_visible': isVisible,
      'sort_order': sortOrder,
      'category': category,
      'icon_url': iconUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size_bytes': fileSizeBytes,
      'file_type': fileType,
      'version': version,
      'last_updated_date': lastUpdatedDate?.toIso8601String(),
      'requires_executive_access': requiresExecutiveAccess,
    }..removeWhere((key, value) => value == null);
  }
}

class MemberProfileChange {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String memberId;
  final String fieldName;
  final String? displayLabel;
  final String? fieldCategory;
  final String? oldValue;
  final String? newValue;
  final String changeType;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime? appliedAt;

  const MemberProfileChange({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.memberId,
    required this.fieldName,
    this.displayLabel,
    this.fieldCategory,
    this.oldValue,
    this.newValue,
    required this.changeType,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.appliedAt,
  });

  factory MemberProfileChange.fromJson(Map<String, dynamic> json) {
    final visibility = json['member_portal_field_visibility'] as Map<String, dynamic>?;
    return MemberProfileChange(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      memberId: json['member_id']?.toString() ?? '',
      fieldName: json['field_name']?.toString() ?? '',
      displayLabel: visibility?['display_label']?.toString(),
      fieldCategory: visibility?['field_category']?.toString(),
      oldValue: json['old_value']?.toString(),
      newValue: json['new_value']?.toString(),
      changeType: json['change_type']?.toString() ?? 'update',
      status: json['status']?.toString() ?? 'pending',
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      rejectionReason: json['rejection_reason']?.toString(),
      appliedAt: DateTime.tryParse(json['applied_at']?.toString() ?? ''),
    );
  }
}

class MemberPortalFieldVisibility {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String fieldName;
  final String displayLabel;
  final String? fieldCategory;
  final bool isVisible;
  final bool isEditable;
  final bool isRequired;
  final int? sortOrder;
  final String? helpText;

  const MemberPortalFieldVisibility({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    required this.fieldName,
    required this.displayLabel,
    this.fieldCategory,
    this.isVisible = false,
    this.isEditable = false,
    this.isRequired = false,
    this.sortOrder,
    this.helpText,
  });

  factory MemberPortalFieldVisibility.fromJson(Map<String, dynamic> json) {
    return MemberPortalFieldVisibility(
      id: json['id'].toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      fieldName: json['field_name']?.toString() ?? '',
      displayLabel: json['display_label']?.toString() ?? '',
      fieldCategory: json['field_category']?.toString(),
      isVisible: _normalizeBool(json['is_visible']) ?? false,
      isEditable: _normalizeBool(json['is_editable']) ?? false,
      isRequired: _normalizeBool(json['is_required']) ?? false,
      sortOrder: _normalizeInt(json['sort_order']),
      helpText: json['help_text']?.toString(),
    );
  }

  MemberPortalFieldVisibility copyWith({
    bool? isVisible,
    bool? isEditable,
    bool? isRequired,
    int? sortOrder,
    String? helpText,
  }) {
    return MemberPortalFieldVisibility(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt,
      fieldName: fieldName,
      displayLabel: displayLabel,
      fieldCategory: fieldCategory,
      isVisible: isVisible ?? this.isVisible,
      isEditable: isEditable ?? this.isEditable,
      isRequired: isRequired ?? this.isRequired,
      sortOrder: sortOrder ?? this.sortOrder,
      helpText: helpText ?? this.helpText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'field_name': fieldName,
      'display_label': displayLabel,
      'field_category': fieldCategory,
      'is_visible': isVisible,
      'is_editable': isEditable,
      'is_required': isRequired,
      'sort_order': sortOrder,
      'help_text': helpText,
    }..removeWhere((key, value) => value == null);
  }
}

class MemberPortalDashboardStats {
  final int pendingProfileChanges;
  final int pendingEventSubmissions;
  final int publishedMeetings;
  final int visibleResources;

  const MemberPortalDashboardStats({
    required this.pendingProfileChanges,
    required this.pendingEventSubmissions,
    required this.publishedMeetings,
    required this.visibleResources,
  });

  static const empty = MemberPortalDashboardStats(
    pendingProfileChanges: 0,
    pendingEventSubmissions: 0,
    publishedMeetings: 0,
    visibleResources: 0,
  );
}

class MemberPortalRecentSignIn {
  final String id;
  final String name;
  final String? email;
  final String? chapterName;
  final List<MemberProfilePhoto> profilePictures;
  final DateTime lastSignInAt;

  const MemberPortalRecentSignIn({
    required this.id,
    required this.name,
    required this.lastSignInAt,
    this.email,
    this.chapterName,
    this.profilePictures = const [],
  });

  factory MemberPortalRecentSignIn.fromJson(Map<String, dynamic> json) {
    final profilePictures = (json['profile_pictures'] as List?)
            ?.map((value) => MemberProfilePhoto.fromJson(value))
            .toList() ??
        const <MemberProfilePhoto>[];

    return MemberPortalRecentSignIn(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Member',
      email: json['email']?.toString(),
      chapterName: json['chapter_name']?.toString(),
      profilePictures: profilePictures,
      lastSignInAt:
          DateTime.tryParse(json['last_sign_in_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}

bool? _normalizeBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1' || lower == 't';
  }
  return null;
}

int? _normalizeInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
