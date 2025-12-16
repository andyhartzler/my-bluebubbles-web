import 'package:freezed_annotation/freezed_annotation.dart';

part 'job_notification_template.freezed.dart';
part 'job_notification_template.g.dart';

@freezed
class JobNotificationTemplate with _$JobNotificationTemplate {
  const factory JobNotificationTemplate({
    required String id,
    @JsonKey(name: 'trigger_type') required String triggerType,
    @JsonKey(name: 'recipient_type') required String recipientType,
    required String name,
    String? description,
    @JsonKey(name: 'email_enabled') @Default(true) bool emailEnabled,
    @JsonKey(name: 'email_subject') String? emailSubject,
    @JsonKey(name: 'email_html') String? emailHtml,
    @JsonKey(name: 'email_plain_text') String? emailPlainText,
    @JsonKey(name: 'sms_enabled') @Default(false) bool smsEnabled,
    @JsonKey(name: 'sms_body') String? smsBody,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_default') @Default(false) bool isDefault,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'updated_by') String? updatedBy,
  }) = _JobNotificationTemplate;

  const JobNotificationTemplate._();

  factory JobNotificationTemplate.fromJson(Map<String, dynamic> json) =>
      _$JobNotificationTemplateFromJson(json);

  /// Get a display label for trigger type
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
      case 'new_job_alert':
        return 'New Job Alert';
      default:
        return triggerType;
    }
  }

  /// Get a display label for recipient type
  String get recipientTypeLabel {
    switch (recipientType) {
      case 'job_submitter':
        return 'Job Poster';
      case 'job_applicant':
        return 'Job Applicant';
      case 'job_subscriber':
        return 'Job Subscribers';
      default:
        return recipientType;
    }
  }

  /// Get icon for trigger type
  static String triggerTypeIcon(String type) {
    switch (type) {
      case 'job_submitted':
        return '📥';
      case 'job_approved':
        return '✅';
      case 'job_rejected':
        return '❌';
      case 'job_expiring_soon':
        return '⏰';
      case 'job_expired':
        return '📅';
      case 'application_received':
        return '📋';
      case 'application_submitted':
        return '📤';
      case 'application_status_changed':
        return '🔄';
      case 'new_job_alert':
        return '🔔';
      default:
        return '📧';
    }
  }

  /// Get description for trigger type
  static String triggerTypeDescription(String type) {
    switch (type) {
      case 'job_submitted':
        return 'Sent when someone submits a new job listing';
      case 'job_approved':
        return 'Sent when a job listing is approved';
      case 'job_rejected':
        return 'Sent when a job listing is rejected';
      case 'job_expiring_soon':
        return 'Sent when a job listing is about to expire';
      case 'job_expired':
        return 'Sent when a job listing has expired';
      case 'application_received':
        return 'Sent to job poster when someone applies';
      case 'application_submitted':
        return 'Confirmation sent to applicant after applying';
      case 'application_status_changed':
        return 'Sent when application status is updated';
      case 'new_job_alert':
        return 'Sent to subscribers when a new job is approved';
      default:
        return '';
    }
  }

  /// All available trigger types
  static const List<String> triggerTypes = [
    'job_submitted',
    'job_approved',
    'job_rejected',
    'job_expiring_soon',
    'job_expired',
    'application_received',
    'application_submitted',
    'application_status_changed',
    'new_job_alert',
  ];

  /// All available recipient types
  static const List<String> recipientTypes = [
    'job_submitter',
    'job_applicant',
    'job_subscriber',
  ];

  /// Get recipient type label
  static String getRecipientLabel(String type) {
    switch (type) {
      case 'job_submitter':
        return 'Job Poster';
      case 'job_applicant':
        return 'Job Applicant';
      case 'job_subscriber':
        return 'Job Subscribers';
      default:
        return type;
    }
  }

  /// Get trigger type label
  static String getTriggerLabel(String type) {
    switch (type) {
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
      case 'new_job_alert':
        return 'New Job Alert';
      default:
        return type;
    }
  }
}
