import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';

class CreateDefaultMailboxLoading extends LoadingState {}

class CreateDefaultMailboxAllSuccess extends UIState {

  final List<Mailbox> listMailbox;

  CreateDefaultMailboxAllSuccess(this.listMailbox);

  @override
  List<Object?> get props => [listMailbox];
}

class CreateDefaultMailboxFailure extends FeatureFailure {

  CreateDefaultMailboxFailure(dynamic exception) : super(exception: exception);
}