import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:flutter/widgets.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';

class OpenMailboxViewEvent extends ViewEvent {
  final BuildContext buildContext;
  final PresentationMailbox presentationMailbox;

  OpenMailboxViewEvent(this.buildContext, this.presentationMailbox);

  @override
  List<Object?> get props => [buildContext, presentationMailbox];
}