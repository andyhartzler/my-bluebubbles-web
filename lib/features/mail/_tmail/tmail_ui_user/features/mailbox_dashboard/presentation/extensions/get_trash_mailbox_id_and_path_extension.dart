import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/presentation_mailbox_extension.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/state/move_to_mailbox_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';

extension GetTrashMailboxIdAndPathExtension on MailboxDashBoardController {
  ({MailboxId? trashId, String? trashPath}) getTrashMailboxIdAndPath(
    PresentationMailbox emailMailbox,
  ) {
    final defaultResult = (
      trashId: mapDefaultMailboxIdByRole[PresentationMailbox.roleTrash],
      trashPath: null as String?,
    );

    if (emailMailbox.isPersonal) return defaultResult;

    final namespace = emailMailbox.namespace;
    if (namespace == null) return defaultResult;

    final trashId = findDefaultMailboxIdInTeamMailbox(
      namespace: namespace,
      mailboxName: PresentationMailbox.trashRole,
    );
    if (trashId == null) return defaultResult;

    final trashPath = getTeamMailboxNodePathWithSeparator(
      mailboxId: trashId,
    );
    return (trashId: trashId, trashPath: trashPath);
  }

  void emitMoveToTrashFailure(Exception exception) {
    emitFailure(
      controller: this,
      failure: MoveToMailboxFailure(
        EmailActionType.moveToTrash,
        exception: exception,
      ),
    );
  }
}
