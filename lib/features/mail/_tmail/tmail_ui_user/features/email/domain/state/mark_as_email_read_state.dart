import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/read_actions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/mark_read_action.dart';

class MarkAsEmailReadSuccess extends UIState {
  final EmailId emailId;
  final ReadActions readActions;
  final MarkReadAction markReadAction;
  final MailboxId? mailboxId;

  MarkAsEmailReadSuccess(
    this.emailId,
    this.readActions,
    this.markReadAction,
    this.mailboxId,
  );

  @override
  List<Object?> get props => [emailId, readActions, markReadAction, mailboxId];
}

class MarkAsEmailReadFailure extends FeatureFailure {
  final ReadActions readActions;

  MarkAsEmailReadFailure(this.readActions, {dynamic exception}) : super(exception: exception);

  @override
  List<Object?> get props => [readActions, ...super.props];
}