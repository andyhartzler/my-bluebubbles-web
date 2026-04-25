import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class DeleteCredentialSuccess extends UIState {}

class DeleteCredentialFailure extends FeatureFailure {

  DeleteCredentialFailure(dynamic exception) : super(exception: exception);
}