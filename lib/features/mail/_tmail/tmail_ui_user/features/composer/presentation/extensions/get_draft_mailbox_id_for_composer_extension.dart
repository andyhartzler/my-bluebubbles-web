import 'package:collection/collection.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/presentation_mailbox_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/composer_controller.dart';

extension GetDraftMailboxIdForComposerExtension on ComposerController {
  MailboxId? getDraftMailboxIdForComposer() {
    final savedDraftMailboxId = composerArguments.value?.savedDraftMailboxId;

    if (currentEmailActionType == EmailActionType.editDraft &&
        savedDraftMailboxId != null) {
      return savedDraftMailboxId;
    }

    final defaultDraftsMailbox = mailboxDashBoardController.mapDefaultMailboxIdByRole[
      PresentationMailbox.roleDrafts
    ];
    final lowercaseDraftsRole = PresentationMailbox.roleDrafts.value.toLowerCase();

    final identityEmail = identitySelected.value?.email;
    return mailboxDashBoardController.mapMailboxById.entries
      .firstWhereOrNull((entry) {
        if (identityEmail == null) return false;
        final mailbox = entry.value;
        return mailbox.emailTeamMailBoxes == identityEmail &&
          mailbox.name?.name.toLowerCase() == lowercaseDraftsRole;
      })
      ?.key ?? defaultDraftsMailbox;
  }
}