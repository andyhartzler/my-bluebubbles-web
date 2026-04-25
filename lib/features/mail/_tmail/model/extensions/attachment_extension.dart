
import 'package:jmap_dart_client/jmap/mail/email/email_body_part.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/list_attachment_extension.dart';

extension AttachmentExtension on Attachment {
  EmailBodyPart toEmailBodyPart({String? charset}) => EmailBodyPart(
    partId: partId,
    blobId: blobId,
    size: size,
    name: name,
    type: type,
    cid: cid,
    charset: charset ?? this.charset,
    disposition: disposition?.name ?? ContentDisposition.attachment.name);

  Attachment toAttachmentWithDisposition({
    ContentDisposition? disposition,
    String? cid
  }) {
    return Attachment(
        partId: partId,
        blobId: blobId,
        size: size,
        name: name,
        type: type,
        cid: cid ?? this.cid,
        disposition: disposition ?? this.disposition,
        charset: charset
    );
  }

  bool isOutsideAttachment(List<Attachment> htmlBodyAttachments) {
    return (noCid() || !isDispositionInlined()) &&
      !isApplicationRTFInlined() &&
      !htmlBodyAttachments.include(this);
  }
}