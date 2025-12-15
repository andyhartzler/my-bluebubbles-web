import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_notification_log.freezed.dart';
part 'job_notification_log.g.dart';

/// Represents a log entry for a job notification
@freezed
class JobNotificationLog with _$JobNotificationLog {
  const JobNotificationLog._();

  const factory JobNotificationLog({
    required String id,
    String? templateId,
    required String triggerType,
    String? recipientMemberId,
    required String recipientEmail,
    String? recipientPhone,
    String? recipientName,
    String? jobId,
    String? applicationId,
    required String channel,
    String? subjectRendered,
    String? bodyRendered,
    @Default('pending') String status,
    String? errorMessage,
    String? externalId,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
  }) = _JobNotificationLog;

  factory JobNotificationLog.fromJson(Map<String, dynamic> json) {
    return JobNotificationLog(
      id: json['id'] as String,
      templateId: json['template_id'] as String?,
      triggerType: json['trigger_type'] as String,
      recipientMemberId: json['recipient_member_id'] as String?,
      recipientEmail: json['recipient_email'] as String,
      recipientPhone: json['recipient_phone'] as String?,
      recipientName: json['recipient_name'] as String?,
      jobId: json['job_id'] as String?,
      applicationId: json['application_id'] as String?,
      channel: json['channel'] as String,
      subjectRendered: json['subject_rendered'] as String?,
      bodyRendered: json['body_rendered'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      errorMessage: json['error_message'] as String?,
      externalId: json['external_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'trigger_type': triggerType,
      'recipient_member_id': recipientMemberId,
      'recipient_email': recipientEmail,
      'recipient_phone': recipientPhone,
      'recipient_name': recipientName,
      'job_id': jobId,
      'application_id': applicationId,
      'channel': channel,
      'subject_rendered': subjectRendered,
      'body_rendered': bodyRendered,
      'status': status,
      'error_message': errorMessage,
      'external_id': externalId,
      'created_at': createdAt?.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
    };
  }

  /// Get a human-readable label for the trigger type
  String get triggerTypeLabel {
    switch (triggerType) {
      case 'job_submitted':
        return 'Job Submitted';
      case 'job_approved':
        return 'Job Approved';
      case 'job_rejected':
        return 'Job Rejected';
      case 'job_expiring_soon':
        return 'Job Expiring Soon';
      case 'job_expired':
        return 'Job Expired';
      case 'application_received':
        return 'Application Received';
      case 'application_submitted':
        return 'Application Submitted';
      case 'application_status_changed':
        return 'Application Status Changed';
      default:
        return triggerType;
    }
  }

  /// Get a human-readable label for the channel
  String get channelLabel {
    switch (channel) {
      case 'email':
        return 'Email';
      case 'sms':
        return 'SMS';
      default:
        return channel;
    }
  }

  /// Get a human-readable label for the status
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  /// Check if the notification was successful
  bool get isSuccess => status == 'sent' || status == 'delivered';

  /// Check if the notification failed
  bool get isFailed => status == 'failed';

  /// Check if the notification is pending
  bool get isPending => status == 'pending';
}
