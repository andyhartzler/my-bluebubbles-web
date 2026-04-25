import 'package:bluebubbles/features/mail/_tmail/core/core.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:bluebubbles/features/mail/_tmail/model/mailbox/presentation_mailbox.dart';

class GetAllMailboxLoading extends LoadingState {}

class GetAllMailboxSuccess extends UIState {
  final List<PresentationMailbox> mailboxList;
  final State? currentMailboxState;

  GetAllMailboxSuccess({
    required this.mailboxList,
    required this.currentMailboxState
  });

  @override
  List<Object?> get props => [mailboxList, currentMailboxState];
}

class GetAllMailboxFailure extends FeatureFailure {

  GetAllMailboxFailure(dynamic exception, {super.onRetry}) : super(exception: exception);
}