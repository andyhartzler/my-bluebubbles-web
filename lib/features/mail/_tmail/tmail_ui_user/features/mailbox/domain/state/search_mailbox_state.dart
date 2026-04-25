import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';

class LoadingSearchMailbox extends LoadingState {}

class SearchMailboxSuccess extends UIState {

  final List<PresentationMailbox> mailboxesSearched;

  SearchMailboxSuccess(this.mailboxesSearched);

  @override
  List<Object?> get props => [mailboxesSearched];
}

class SearchMailboxFailure extends FeatureFailure {

  SearchMailboxFailure(dynamic exception) : super(exception: exception);
}