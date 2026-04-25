
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/email_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/list_attachment_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/detailed_email.dart';

extension EmailExtension on Email {
  DetailedEmail toDetailedEmail({String? htmlEmailContent}) {
    return DetailedEmail(
      emailId: id!,
      createdTime: receivedAt?.value ?? DateTime.now(),
      attachments: allAttachments.getListAttachmentsDisplayedOutside(htmlBodyAttachments),
      headers: headers,
      keywords: keywords,
      htmlEmailContent: htmlEmailContent,
      messageId: messageId,
      references: references,
      inlineImages: allAttachments.listAttachmentsDisplayedInContent,
      sMimeStatusHeader: sMimeStatusHeader,
      identityHeader: identityHeader,
    );
  }
}