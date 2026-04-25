import 'package:equatable/equatable.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';

class MailboxCreatorArguments with EquatableMixin {
  final List<PresentationMailbox> listMailboxes;
  final PresentationMailbox? selectedMailbox;

  MailboxCreatorArguments(this.listMailboxes, this.selectedMailbox);

  @override
  List<Object?> get props => [listMailboxes, selectedMailbox];
}
