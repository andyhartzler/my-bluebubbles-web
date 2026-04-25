import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/email/keyword_identifier.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/presentation/extensions/presentation_email_extension.dart';

extension PresentationEmailMapExtension on Map<EmailId, PresentationEmail?> {
  Map<EmailId, PresentationEmail?> toggleEmailKeywordById({
    required EmailId emailId,
    required KeyWordIdentifier keyword,
    required bool remove,
  }) {
    final newMap = Map<EmailId, PresentationEmail?>.from(this);
    final email = newMap[emailId];
    if (email != null) {
      newMap[emailId] = email.toggleKeyword(keyword, remove);
    }
    return newMap;
  }

  Map<EmailId, PresentationEmail?> toggleListEmailsKeywordByIds({
    required List<EmailId> emailIds,
    required KeyWordIdentifier keyword,
    required bool remove,
  }) {
    final updatedMap = Map<EmailId, PresentationEmail?>.from(this);

    for (final emailId in emailIds) {
      final email = updatedMap[emailId];
      if (email == null) continue;

      updatedMap[emailId] = email.toggleKeyword(keyword, remove);
    }

    return updatedMap;
  }
}
