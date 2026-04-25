import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class DeleteAuthorityOidcSuccess extends UIState {}

class DeleteAuthorityOidcFailure extends FeatureFailure {

  DeleteAuthorityOidcFailure(dynamic exception) : super(exception: exception);
}