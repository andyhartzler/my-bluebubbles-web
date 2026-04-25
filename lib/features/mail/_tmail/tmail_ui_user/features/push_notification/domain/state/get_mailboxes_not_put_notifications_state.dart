
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';

class GetMailboxesNotPutNotificationsLoading extends UIState {}

class GetMailboxesNotPutNotificationsSuccess extends UIState {

  final List<PresentationMailbox> mailboxes;
  final UserName userName;

  GetMailboxesNotPutNotificationsSuccess(this.mailboxes, this.userName);

  @override
  List<Object> get props => [mailboxes, userName];
}

class GetMailboxesNotPutNotificationsFailure extends FeatureFailure {

  final UserName userName;

  GetMailboxesNotPutNotificationsFailure(exception, this.userName) : super(exception: exception);
}