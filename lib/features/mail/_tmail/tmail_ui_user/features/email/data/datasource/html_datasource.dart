import 'package:bluebubbles/features/mail/_tmail/core/presentation/utils/html_transformer/transform_configuration.dart';
import 'package:dartz/dartz.dart';
import 'package:jmap_dart_client/jmap/mail/email/email_body_part.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/attachment.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_content.dart';

abstract class HtmlDataSource {
  Future<EmailContent> transformEmailContent(
    EmailContent emailContent,
    Map<String, String> mapCidImageDownloadUrl,
    TransformConfiguration transformConfiguration
  );

  Future<String> transformHtmlEmailContent(
    String htmlContent,
    TransformConfiguration configuration
  );

  Future<Tuple2<String, Set<EmailBodyPart>>> replaceImageBase64ToImageCID({
    required String emailContent,
    required Map<String, Attachment> inlineAttachments,
    required Uri? uploadUri,
  });

  Future<String> removeCollapsedExpandedSignatureEffect({required String emailContent});

  Future<String> removeStyleLazyLoadDisplayInlineImages({required String emailContent});
}