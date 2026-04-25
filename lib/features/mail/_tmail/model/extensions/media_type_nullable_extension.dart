import 'package:http_parser/http_parser.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_content_type.dart';

extension MediaTypeNullableExtension on MediaType? {

  EmailContentType toEmailContentType() {
    if (this == null) {
      return EmailContentType.textHtml;
    } else {
      switch(this!.mimeType) {
        case 'text/html':
          return EmailContentType.textHtml;
        case 'text/plain':
          return EmailContentType.textPlain;
        default:
          return EmailContentType.other;
      }
    }
  }
}