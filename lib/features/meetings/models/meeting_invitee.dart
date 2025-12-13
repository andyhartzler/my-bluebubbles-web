/// Model for a meeting invitee
class MeetingInvitee {
  final String id;
  final DateTime createdAt;
  final String meetingId;
  final String? email;
  final String? phone;
  final String? name;
  final String? memberId;
  final bool emailSent;
  final DateTime? emailSentAt;
  final bool smsSent;
  final DateTime? smsSentAt;

  const MeetingInvitee({
    required this.id,
    required this.createdAt,
    required this.meetingId,
    this.email,
    this.phone,
    this.name,
    this.memberId,
    this.emailSent = false,
    this.emailSentAt,
    this.smsSent = false,
    this.smsSentAt,
  });

  /// Creates a MeetingInvitee from JSON data
  factory MeetingInvitee.fromJson(Map<String, dynamic> json) {
    return MeetingInvitee(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      meetingId: json['meeting_id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      memberId: json['member_id'] as String?,
      emailSent: json['email_sent'] as bool? ?? false,
      emailSentAt: json['email_sent_at'] != null
          ? DateTime.parse(json['email_sent_at'] as String).toLocal()
          : null,
      smsSent: json['sms_sent'] as bool? ?? false,
      smsSentAt: json['sms_sent_at'] != null
          ? DateTime.parse(json['sms_sent_at'] as String).toLocal()
          : null,
    );
  }

  /// Converts this MeetingInvitee to JSON for database insertion
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toUtc().toIso8601String(),
      'meeting_id': meetingId,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (name != null) 'name': name,
      if (memberId != null) 'member_id': memberId,
      'email_sent': emailSent,
      if (emailSentAt != null) 'email_sent_at': emailSentAt!.toUtc().toIso8601String(),
      'sms_sent': smsSent,
      if (smsSentAt != null) 'sms_sent_at': smsSentAt!.toUtc().toIso8601String(),
    };
  }

  /// Creates a copy of this invitee with the given fields replaced
  MeetingInvitee copyWith({
    String? id,
    DateTime? createdAt,
    String? meetingId,
    String? email,
    String? phone,
    String? name,
    String? memberId,
    bool? emailSent,
    DateTime? emailSentAt,
    bool? smsSent,
    DateTime? smsSentAt,
  }) {
    return MeetingInvitee(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      meetingId: meetingId ?? this.meetingId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      memberId: memberId ?? this.memberId,
      emailSent: emailSent ?? this.emailSent,
      emailSentAt: emailSentAt ?? this.emailSentAt,
      smsSent: smsSent ?? this.smsSent,
      smsSentAt: smsSentAt ?? this.smsSentAt,
    );
  }

  /// Returns the display name or email for this invitee
  String get displayName => name ?? email ?? phone ?? 'Unknown';

  /// Returns true if this invitee has an email address
  bool get hasEmail => email != null && email!.isNotEmpty;

  /// Returns true if this invitee has a phone number
  bool get hasPhone => phone != null && phone!.isNotEmpty;
}
