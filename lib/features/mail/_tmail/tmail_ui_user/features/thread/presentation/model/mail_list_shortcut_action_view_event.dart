import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/email_action_type.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/presentation_email.dart';

class MailListShortcutActionViewEvent extends ViewEvent {
  final EmailActionType actionType;
  final List<PresentationEmail> listPresentationEmail;

  MailListShortcutActionViewEvent(this.actionType, this.listPresentationEmail);

  @override
  List<Object?> get props => [actionType, listPresentationEmail];
}