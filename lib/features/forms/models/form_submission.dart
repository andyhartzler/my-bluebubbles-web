import 'package:bluebubbles/models/crm/member.dart';

/// Form submission model with manual JSON serialization
/// Note: Converted from Freezed to manual to avoid build_runner dependency issues
class FormSubmission {
  final String id;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? thankyouSentAt;
  final String formId;
  final String? memberId;
  final Map<String, dynamic> data;
  final String? submitterEmail;
  final String? submitterName;
  final String? submitterPhone;
  final String? ipAddress;
  final String? userAgent;
  final List<String>? fileUrls;
  final Map<String, dynamic>? pageData;
  final String? subscriberId;
  final String? candidateId;
  final String status;
  final Map<String, dynamic>? members;
  final Map<String, dynamic>? subscribers;

  const FormSubmission({
    required this.id,
    required this.createdAt,
    this.updatedAt,
    this.thankyouSentAt,
    required this.formId,
    this.memberId,
    required this.data,
    this.submitterEmail,
    this.submitterName,
    this.submitterPhone,
    this.ipAddress,
    this.userAgent,
    this.fileUrls,
    this.pageData,
    this.subscriberId,
    this.candidateId,
    this.status = 'submitted',
    this.members,
    this.subscribers,
  });

  factory FormSubmission.fromJson(Map<String, dynamic> json) {
    return FormSubmission(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      thankyouSentAt: json['thankyou_sent_at'] != null
          ? DateTime.tryParse(json['thankyou_sent_at'] as String)
          : null,
      formId: json['form_id'] as String,
      memberId: json['member_id'] as String?,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      submitterEmail: json['submitter_email'] as String?,
      submitterName: json['submitter_name'] as String?,
      submitterPhone: json['submitter_phone'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      fileUrls: (json['file_urls'] as List<dynamic>?)?.map((e) => e as String).toList(),
      pageData: json['page_data'] as Map<String, dynamic>?,
      subscriberId: json['subscriber_id'] as String?,
      candidateId: json['candidate_id'] as String?,
      status: (json['status'] as String?) ?? 'submitted',
      members: json['members'] as Map<String, dynamic>?,
      subscribers: json['subscribers'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'form_id': formId,
      'member_id': memberId,
      'data': data,
      'submitter_email': submitterEmail,
      'submitter_name': submitterName,
      'submitter_phone': submitterPhone,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'file_urls': fileUrls,
      'page_data': pageData,
      'subscriber_id': subscriberId,
      'candidate_id': candidateId,
      'status': status,
      'members': members,
      'subscribers': subscribers,
    };
  }

  FormSubmission copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? thankyouSentAt,
    String? formId,
    String? memberId,
    Map<String, dynamic>? data,
    String? submitterEmail,
    String? submitterName,
    String? submitterPhone,
    String? ipAddress,
    String? userAgent,
    List<String>? fileUrls,
    Map<String, dynamic>? pageData,
    String? subscriberId,
    String? candidateId,
    String? status,
    Map<String, dynamic>? members,
    Map<String, dynamic>? subscribers,
  }) {
    return FormSubmission(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      thankyouSentAt: thankyouSentAt ?? this.thankyouSentAt,
      formId: formId ?? this.formId,
      memberId: memberId ?? this.memberId,
      data: data ?? this.data,
      submitterEmail: submitterEmail ?? this.submitterEmail,
      submitterName: submitterName ?? this.submitterName,
      submitterPhone: submitterPhone ?? this.submitterPhone,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      fileUrls: fileUrls ?? this.fileUrls,
      pageData: pageData ?? this.pageData,
      subscriberId: subscriberId ?? this.subscriberId,
      candidateId: candidateId ?? this.candidateId,
      status: status ?? this.status,
      members: members ?? this.members,
      subscribers: subscribers ?? this.subscribers,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormSubmission && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FormSubmission(id: $id, formId: $formId, submitterName: $submitterName)';
  }
}

/// Extension to get display name from submission
extension FormSubmissionDisplay on FormSubmission {
  String get displayName {
    // Try submitter name first
    if (submitterName != null && submitterName!.isNotEmpty) {
      return submitterName!;
    }
    // Try member name from joined data
    if (members != null) {
      final name = members!['name']?.toString();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // Try subscriber name from joined data
    if (subscribers != null) {
      final name = subscribers!['name']?.toString();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    // Try email
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail!;
    }
    // Fallback
    return 'Anonymous';
  }

  String? get displayEmail {
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail;
    }
    if (members != null && members!['email'] != null) {
      return members!['email']?.toString();
    }
    if (subscribers != null && subscribers!['email'] != null) {
      return subscribers!['email']?.toString();
    }
    return null;
  }

  String? get displayPhone {
    if (submitterPhone != null && submitterPhone!.isNotEmpty) {
      return submitterPhone;
    }
    if (members != null && members!['phone'] != null) {
      return members!['phone']?.toString();
    }
    if (subscribers != null && subscribers!['phone'] != null) {
      return subscribers!['phone']?.toString();
    }
    return null;
  }

  /// The joined member's primary profile photo, or null.
  ///
  /// ONE parsing rule, shared with [Member.primaryProfilePhotoUrl]:
  /// [MemberProfilePhoto.parseList] already handles every shape
  /// `members.profile_pictures` is stored in (a full array entry, a metadata
  /// array entry, a bare social-handle object, an empty object, a JSON string)
  /// and already promotes the first entry when no row carries `primary`.
  ///
  /// The hand-rolled shape guessing this replaced took `.first` blindly, so a
  /// member whose primary photo was not the first array element showed the
  /// wrong face, and it duplicated the storage-URL construction that
  /// [MemberProfilePhoto.publicUrl] already owns.
  String? get displayPhotoUrl {
    final photos = MemberProfilePhoto.parseList(members?['profile_pictures']);
    if (photos.isEmpty) return null;
    final primary =
        photos.firstWhere((p) => p.isPrimary, orElse: () => photos.first);
    return primary.publicUrl;
  }

  String get displayInitial {
    final name = displayName;
    if (name.isNotEmpty && name != 'Anonymous') {
      return name[0].toUpperCase();
    }
    if (submitterEmail != null && submitterEmail!.isNotEmpty) {
      return submitterEmail![0].toUpperCase();
    }
    return '?';
  }
}
