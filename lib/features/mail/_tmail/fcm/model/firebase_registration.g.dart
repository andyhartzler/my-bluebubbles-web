// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirebaseRegistration _$FirebaseRegistrationFromJson(
  Map<String, dynamic> json,
) => FirebaseRegistration(
  id: const FirebaseRegistrationIdNullableConverter().fromJson(
    json['id'] as String?,
  ),
  token: const FcmTokenNullableConverter().fromJson(json['token'] as String?),
  deviceClientId: const DeviceClientIdNullableConverter().fromJson(
    json['deviceClientId'] as String?,
  ),
  expires: const FirebaseRegistrationExpiredTimeNullableConverter().fromJson(
    json['expires'] as String?,
  ),
  types: (json['types'] as List<dynamic>?)
      ?.map((e) => const TypeNameConverter().fromJson(e as String))
      .toList(),
);

Map<String, dynamic> _$FirebaseRegistrationToJson(
  FirebaseRegistration instance,
) => <String, dynamic>{
  'id': ?const FirebaseRegistrationIdNullableConverter().toJson(instance.id),
  'token': ?const FcmTokenNullableConverter().toJson(instance.token),
  'deviceClientId': ?const DeviceClientIdNullableConverter().toJson(
    instance.deviceClientId,
  ),
  'expires': ?const FirebaseRegistrationExpiredTimeNullableConverter().toJson(
    instance.expires,
  ),
  'types': ?instance.types?.map(const TypeNameConverter().toJson).toList(),
};
