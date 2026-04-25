import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/mailbox_subscribe_action_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/mailbox_subscribe_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/subscribe_request.dart';

class SubscribeMailboxRequest extends SubscribeRequest {

  final MailboxId mailboxId;

  SubscribeMailboxRequest(
    this.mailboxId,
    MailboxSubscribeState subscribeState,
    MailboxSubscribeAction subscribeAction,
  ) : super(subscribeState, subscribeAction);
  
  @override
  List<Object?> get props => [
    mailboxId,
    super.props
  ];
}
