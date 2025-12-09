/// Form submission model with manual JSON serialization
/// Note: Converted from Freezed to manual to avoid build_runner dependency issues
class FormSubmission {
  final String id;
  final DateTime createdAt;
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
  final String status;
  final Map<String, dynamic>? members;

  const FormSubmission({
    required this.id,
    required this.createdAt,
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
    this.status = 'submitted',
    this.members,
  });

  factory FormSubmission.fromJson(Map<String, dynamic> json) {
    return FormSubmission(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
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
      status: (json['status'] as String?) ?? 'submitted',
      members: json['members'] as Map<String, dynamic>?,
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
      'status': status,
      'members': members,
    };
  }

  FormSubmission copyWith({
    String? id,
    DateTime? createdAt,
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
    String? status,
    Map<String, dynamic>? members,
  }) {
    return FormSubmission(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
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
      status: status ?? this.status,
      members: members ?? this.members,
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
      final firstName = members!['first_name'] as String?;
      final lastName = members!['last_name'] as String?;
      if (firstName != null || lastName != null) {
        return [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ');
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
    if (members != null) {
      return members!['email'] as String?;
    }
    return null;
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
