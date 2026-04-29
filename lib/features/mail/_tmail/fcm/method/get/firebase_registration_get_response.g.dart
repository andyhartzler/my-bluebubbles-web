// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_registration_get_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirebaseRegistrationGetResponse _$FirebaseRegistrationGetResponseFromJson(
  Map<String, dynamic> json,
) => FirebaseRegistrationGetResponse(
  (json['list'] as List<dynamic>)
      .map((e) => FirebaseRegistration.fromJson(e as Map<String, dynamic>))
      .toList(),
  (json['notFound'] as List<dynamic>?)
      ?.map((e) => const IdConverter().fromJson(e as String))
      .toList(),
);

Map<String, dynamic> _$FirebaseRegistrationGetResponseToJson(
  FirebaseRegistrationGetResponse instance,
) => <String, dynamic>{
  'list': instance.list.map((e) => e.toJson()).toList(),
  'notFound': instance.notFound?.map(const IdConverter().toJson).toList(),
};
