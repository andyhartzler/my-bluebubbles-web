import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/services/crm/crm_message_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

import '../models/form_schema.dart';
import '../models/voting_form.dart';

/// Service responsible for sending confirmation messages and emails
/// after form or vote submissions.
class FormConfirmationService {
  FormConfirmationService._internal();

  static final FormConfirmationService instance = FormConfirmationService._internal();

  factory FormConfirmationService() => instance;

  final _messageService = CRMMessageService();
  final _emailService = CRMEmailService();

  static const String _logTag = 'FormConfirmation';

  /// Send confirmation message and/or email after a form submission.
  ///
  /// Returns a record of (messageSent, emailSent) booleans.
  Future<({bool messageSent, bool emailSent})> sendFormConfirmations({
    required FormSchema form,
    required String? submitterEmail,
    required String? submitterPhone,
    required String? submitterName,
    required Map<String, dynamic> submissionData,
  }) async {
    bool messageSent = false;
    bool emailSent = false;

    // Send confirmation email if template is set and email is provided
    if (form.confirmationEmailTemplate != null &&
        form.confirmationEmailTemplate!.isNotEmpty &&
        submitterEmail != null &&
        submitterEmail.isNotEmpty) {
      emailSent = await _sendConfirmationEmail(
        recipientEmail: submitterEmail,
        recipientName: submitterName,
        subject: 'Thank you for submitting: ${form.title}',
        templateBody: form.confirmationEmailTemplate!,
        formTitle: form.title,
        submissionData: submissionData,
      );
    }

    // For forms, we also check the schema.confirmation settings for a message
    final confirmationMessage = form.schema.confirmation?['sms_message'] as String?;
    if (confirmationMessage != null &&
        confirmationMessage.isNotEmpty &&
        submitterPhone != null &&
        submitterPhone.isNotEmpty) {
      messageSent = await _sendConfirmationMessage(
        phoneNumber: submitterPhone,
        messageTemplate: confirmationMessage,
        recipientName: submitterName,
        formTitle: form.title,
        submissionData: submissionData,
      );
    }

    // Also send notification emails to admins if configured
    if (form.notificationEmails != null && form.notificationEmails!.isNotEmpty) {
      await _sendAdminNotificationEmail(
        adminEmails: form.notificationEmails!,
        formTitle: form.title,
        submitterName: submitterName,
        submitterEmail: submitterEmail,
        submitterPhone: submitterPhone,
        submissionData: submissionData,
        formType: form.formType,
      );
    }

    return (messageSent: messageSent, emailSent: emailSent);
  }

  /// Send confirmation message and/or email after a vote submission.
  ///
  /// Returns a record of (messageSent, emailSent) booleans.
  Future<({bool messageSent, bool emailSent})> sendVoteConfirmations({
    required VotingForm vote,
    required String? voterEmail,
    required String? voterPhone,
    required String? voterName,
    required Map<String, dynamic> voteData,
  }) async {
    bool messageSent = false;
    bool emailSent = false;

    // Send confirmation email if template is set and email is provided
    if (vote.confirmationEmailTemplate != null &&
        vote.confirmationEmailTemplate!.isNotEmpty &&
        voterEmail != null &&
        voterEmail.isNotEmpty) {
      emailSent = await _sendConfirmationEmail(
        recipientEmail: voterEmail,
        recipientName: voterName,
        subject: 'Thank you for voting: ${vote.title}',
        templateBody: vote.confirmationEmailTemplate!,
        formTitle: vote.title,
        submissionData: voteData,
      );
    }

    // Send confirmation message if template is in the vote's settings
    // For votes, the confirmation message is stored directly in confirmationEmailTemplate
    // but we can also check the settings map for an SMS message
    final smsMessage = vote.settings['confirmation_sms'] as String?;
    if (smsMessage != null &&
        smsMessage.isNotEmpty &&
        voterPhone != null &&
        voterPhone.isNotEmpty) {
      messageSent = await _sendConfirmationMessage(
        phoneNumber: voterPhone,
        messageTemplate: smsMessage,
        recipientName: voterName,
        formTitle: vote.title,
        submissionData: voteData,
      );
    }

    // Also send notification emails to admins if configured
    if (vote.notificationEmails != null && vote.notificationEmails!.isNotEmpty) {
      await _sendAdminNotificationEmail(
        adminEmails: vote.notificationEmails!,
        formTitle: vote.title,
        submitterName: voterName,
        submitterEmail: voterEmail,
        submitterPhone: voterPhone,
        submissionData: voteData,
        formType: 'vote',
      );
    }

    return (messageSent: messageSent, emailSent: emailSent);
  }

  /// Send a confirmation email using the CRM email service.
  Future<bool> _sendConfirmationEmail({
    required String recipientEmail,
    String? recipientName,
    required String subject,
    required String templateBody,
    required String formTitle,
    required Map<String, dynamic> submissionData,
  }) async {
    try {
      // Process template with mail merge variables
      final processedBody = _processTemplate(
        templateBody,
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        formTitle: formTitle,
        submissionData: submissionData,
      );

      final result = await _emailService.sendEmail(
        to: [recipientEmail],
        subject: subject,
        htmlBody: _wrapInHtmlEmail(processedBody),
        textBody: processedBody,
        recipients: [
          CRMEmailRecipientPayload(
            email: recipientEmail,
            variables: {
              'first_name': _extractFirstName(recipientName),
              'full_name': recipientName ?? '',
              'email': recipientEmail,
            },
          ),
        ],
      );

      if (result.success) {
        Logger.info(
          'Confirmation email sent to $recipientEmail for form "$formTitle"',
          tag: _logTag,
        );
        return true;
      } else {
        Logger.warn(
          'Failed to send confirmation email to $recipientEmail: HTTP ${result.statusCode}',
          tag: _logTag,
        );
        return false;
      }
    } catch (e, stack) {
      Logger.error(
        'Error sending confirmation email to $recipientEmail',
        error: e,
        trace: stack,
        tag: _logTag,
      );
      return false;
    }
  }

  /// Send a confirmation message using the CRM message service.
  Future<bool> _sendConfirmationMessage({
    required String phoneNumber,
    required String messageTemplate,
    String? recipientName,
    required String formTitle,
    required Map<String, dynamic> submissionData,
  }) async {
    try {
      // Process template with variables
      final processedMessage = _processTemplate(
        messageTemplate,
        recipientName: recipientName,
        formTitle: formTitle,
        submissionData: submissionData,
      );

      // Send using the public sendSimpleMessage method
      final success = await _messageService.sendSimpleMessage(
        phoneNumber: phoneNumber,
        message: processedMessage,
      );

      if (success) {
        Logger.info(
          'Confirmation message sent to $phoneNumber for form "$formTitle"',
          tag: _logTag,
        );
        return true;
      }
      return false;
    } catch (e, stack) {
      Logger.error(
        'Error sending confirmation message to $phoneNumber',
        error: e,
        trace: stack,
        tag: _logTag,
      );
      return false;
    }
  }

  /// Send a simple text message using the message service.
  /// This creates a direct message without any formatting.
  Future<bool> sendSimpleMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      return await _messageService.sendSimpleMessage(
        phoneNumber: phoneNumber,
        message: message,
      );
    } catch (e, stack) {
      Logger.error(
        'Error sending simple message to $phoneNumber',
        error: e,
        trace: stack,
        tag: _logTag,
      );
      return false;
    }
  }

  /// Send notification email to admins about a new submission.
  Future<void> _sendAdminNotificationEmail({
    required List<String> adminEmails,
    required String formTitle,
    String? submitterName,
    String? submitterEmail,
    String? submitterPhone,
    required Map<String, dynamic> submissionData,
    required String formType,
  }) async {
    try {
      final submittedAt = DateTime.now().toIso8601String();
      final formTypeLabel = formType == 'vote' ? 'Vote' : 'Form';

      final bodyLines = <String>[
        'New $formTypeLabel Submission',
        '',
        '$formTypeLabel: $formTitle',
        'Submitted at: $submittedAt',
        '',
        'Submitter Information:',
        '  Name: ${submitterName ?? 'Not provided'}',
        '  Email: ${submitterEmail ?? 'Not provided'}',
        '  Phone: ${submitterPhone ?? 'Not provided'}',
        '',
        'Submission Data:',
      ];

      submissionData.forEach((key, value) {
        bodyLines.add('  $key: $value');
      });

      final textBody = bodyLines.join('\n');

      await _emailService.sendEmail(
        to: adminEmails,
        subject: 'New $formTypeLabel Submission: $formTitle',
        textBody: textBody,
        htmlBody: _wrapInHtmlEmail(textBody.replaceAll('\n', '<br>')),
      );

      Logger.info(
        'Admin notification sent to ${adminEmails.length} recipients for "$formTitle"',
        tag: _logTag,
      );
    } catch (e, stack) {
      Logger.warn(
        'Failed to send admin notification email',
        error: e,
        trace: stack,
        tag: _logTag,
      );
    }
  }

  /// Process a template string by replacing variables with actual values.
  String _processTemplate(
    String template, {
    String? recipientName,
    String? recipientEmail,
    String? formTitle,
    Map<String, dynamic>? submissionData,
  }) {
    var result = template;

    // Replace common variables
    if (recipientName != null) {
      result = result.replaceAll('{{name}}', recipientName);
      result = result.replaceAll('{{full_name}}', recipientName);
      result = result.replaceAll('{{first_name}}', _extractFirstName(recipientName));
    }

    if (recipientEmail != null) {
      result = result.replaceAll('{{email}}', recipientEmail);
    }

    if (formTitle != null) {
      result = result.replaceAll('{{form_title}}', formTitle);
      result = result.replaceAll('{{title}}', formTitle);
    }

    // Replace submission data variables
    if (submissionData != null) {
      submissionData.forEach((key, value) {
        result = result.replaceAll('{{$key}}', value?.toString() ?? '');
      });
    }

    return result;
  }

  /// Extract first name from a full name string.
  String _extractFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '';
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : fullName;
  }

  /// Wrap plain text in a simple HTML email template.
  String _wrapInHtmlEmail(String body) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 16px; line-height: 1.5; color: #333; padding: 20px;">
  <div style="max-width: 600px; margin: 0 auto;">
    $body
  </div>
</body>
</html>
''';
  }
}
