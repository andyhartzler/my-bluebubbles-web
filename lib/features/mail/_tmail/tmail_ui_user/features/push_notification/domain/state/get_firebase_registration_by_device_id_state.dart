
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/fcm/model/fcm_token.dart';
import 'package:bluebubbles/features/mail/_tmail/fcm/model/firebase_registration.dart';

class GetFirebaseRegistrationByDeviceIdLoading extends LoadingState {}

class GetFirebaseRegistrationByDeviceIdSuccess extends UIState {

  final FirebaseRegistration firebaseRegistration;
  final FcmToken? newFcmToken;

  GetFirebaseRegistrationByDeviceIdSuccess(this.firebaseRegistration, this.newFcmToken);

  @override
  List<Object?> get props => [firebaseRegistration, newFcmToken];
}

class GetFirebaseRegistrationByDeviceIdFailure extends FeatureFailure {
  final FcmToken? newFcmToken;

  GetFirebaseRegistrationByDeviceIdFailure(dynamic exception, this.newFcmToken) : super(exception: exception);

  @override
  List<Object?> get props => [newFcmToken, ...super.props];
}