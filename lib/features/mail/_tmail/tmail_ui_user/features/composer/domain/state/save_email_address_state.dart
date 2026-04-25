import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class SaveEmailAddressSuccess extends UIState {}

class SaveEmailAddressFailure extends FeatureFailure {

  SaveEmailAddressFailure(dynamic exception) : super(exception: exception);
}