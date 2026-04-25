
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/fcm/model/firebase_registration.dart';

class GetStoredFirebaseRegistrationLoading extends LoadingState {}

class GetStoredFirebaseRegistrationSuccess extends UIState {

  final FirebaseRegistration firebaseRegistration;

  GetStoredFirebaseRegistrationSuccess(this.firebaseRegistration);

  @override
  List<Object> get props => [firebaseRegistration];
}

class GetStoredFirebaseRegistrationFailure extends FeatureFailure {

  GetStoredFirebaseRegistrationFailure(dynamic exception) : super(exception: exception);
}