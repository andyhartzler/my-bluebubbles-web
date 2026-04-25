import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';

class RemoveEmailDraftsSuccess extends UIState {
  final MailboxId? draftMailboxId;

  RemoveEmailDraftsSuccess(this.draftMailboxId);

  @override
  List<Object?> get props => [draftMailboxId];
}

class RemoveEmailDraftsFailure extends FeatureFailure {

  RemoveEmailDraftsFailure(dynamic exception) : super(exception: exception);
}