import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:bluebubbles/features/mail/_tmail/model/email/mark_star_action.dart';

class MarkAsStarEmailSuccess extends UIState {
  final MarkStarAction markStarAction;
  final EmailId emailId;

  MarkAsStarEmailSuccess(this.markStarAction, this.emailId);

  @override
  List<Object?> get props => [markStarAction, emailId];
}

class MarkAsStarEmailFailure extends FeatureFailure {
  final MarkStarAction markStarAction;

  MarkAsStarEmailFailure(this.markStarAction, {dynamic exception}) : super(exception: exception);

  @override
  List<Object?> get props => [markStarAction, ...super.props];
}