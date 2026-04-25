// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirebaseRegistration _$FirebaseRegistrationFromJson(
        Map<String, dynamic> json) =>
    FirebaseRegistration(
      id: const FirebaseRegistrationIdNullableConverter()
          .fromJson(json['id'] as String?),
      token:
          const FcmTokenNullableConverter().fromJson(json['token'] as String?),
      deviceClientId: const DeviceClientIdNullableConverter()
          .fromJson(json['deviceClientId'] as String?),
      expires: const FirebaseRegistrationExpiredTimeNullableConverter()
          .fromJson(json['expires'] as String?),
      types: (json['types'] as List<dynamic>?)
          ?.map((e) => const TypeNameConverter().fromJson(e as String))
          .toList(),
    );

Map<String, dynamic> _$FirebaseRegistrationToJson(
        FirebaseRegistration instance) =>
    <String, dynamic>{
      if (const FirebaseRegistrationIdNullableConverter().toJson(instance.id)
          case final value?)
        'id': value,
      if (const FcmTokenNullableConverter().toJson(instance.token)
          case final value?)
        'token': value,
      if (const DeviceClientIdNullableConverter()
              .toJson(instance.deviceClientId)
          case final value?)
        'deviceClientId': value,
      if (const FirebaseRegistrationExpiredTimeNullableConverter()
              .toJson(instance.expires)
          case final value?)
        'expires': value,
      if (instance.types?.map(const TypeNameConverter().toJson).toList()
          case final value?)
        'types': value,
    };
