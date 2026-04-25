
import 'package:bluebubbles/features/mail/_tmail/fcm/model/device_client_id.dart';
import 'package:bluebubbles/features/mail/_tmail/fcm/model/fcm_token.dart';
import 'package:bluebubbles/features/mail/_tmail/fcm/model/firebase_registration.dart';
import 'package:bluebubbles/features/mail/_tmail/fcm/model/type_name.dart';

extension FirebaseRegistrationExtension on FirebaseRegistration {

  FirebaseRegistration syncProperties({
    DeviceClientId? newDeviceId,
    FcmToken? newFcmToken,
    List<TypeName>? newTypes,
  }) {
    return FirebaseRegistration(
      id: id,
      token: newFcmToken ?? token,
      deviceClientId: newDeviceId ?? deviceClientId,
      expires: expires,
      types: newTypes ?? types
    );
  }
}