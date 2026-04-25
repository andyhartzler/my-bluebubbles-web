import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/namespace.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/presentation/mailbox_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/presentation/model/mailbox_node.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/presentation/model/mailbox_tree.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/routes/route_navigation.dart';

mixin HandleTeamMailboxMixin {
  MailboxTree? get _teamMailboxesTree =>
      getBinding<MailboxController>()?.teamMailboxesTree.value;

  MailboxNode? _findTeamMailboxNodeByNamespaceOnFirstLevel(
    Namespace namespace,
  ) {
    return _teamMailboxesTree?.findNodeOnFirstLevel(
      (node) => node.item.namespace == namespace,
    );
  }

  PresentationMailbox? _findDefaultMailboxInTeamMailbox({
    required Namespace namespace,
    required String mailboxName,
  }) {
    final teamMailboxNode =
        _findTeamMailboxNodeByNamespaceOnFirstLevel(namespace);
    if (teamMailboxNode == null) return null;

    final mailboxNode = teamMailboxNode.findNodeOnFirstLevel(
      (node) =>
          node.mailboxNameAsString.toLowerCase() == mailboxName.toLowerCase(),
    );
    if (mailboxNode == null) return null;

    return mailboxNode.item;
  }

  MailboxId? findDefaultMailboxIdInTeamMailbox({
    required Namespace namespace,
    required String mailboxName,
  }) {
    final teamMailbox = _findDefaultMailboxInTeamMailbox(
      namespace: namespace,
      mailboxName: mailboxName,
    );
    return teamMailbox?.id;
  }

  String? getTeamMailboxNodePathWithSeparator({
    required MailboxId mailboxId,
    String pathSeparator = '/',
  }) {
    return _teamMailboxesTree?.getNodePath(mailboxId, pathSeparator);
  }
}
