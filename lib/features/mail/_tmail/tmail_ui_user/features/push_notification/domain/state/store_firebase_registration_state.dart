
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';

class StoreFirebaseRegistrationLoading extends LoadingState {}

class StoreFirebaseRegistrationSuccess extends UIState {}

class StoreFirebaseRegistrationFailure extends FeatureFailure {

  StoreFirebaseRegistrationFailure(dynamic exception) : super(exception: exception);
}