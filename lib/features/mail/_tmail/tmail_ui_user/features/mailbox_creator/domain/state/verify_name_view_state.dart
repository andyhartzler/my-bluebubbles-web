import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class VerifyNameViewState extends UIState {}

class VerifyNameFailure extends FeatureFailure {

  VerifyNameFailure(dynamic exception) : super(exception: exception);
}