// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_registration_get_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirebaseRegistrationGetMethod _$FirebaseRegistrationGetMethodFromJson(
  Map<String, dynamic> json,
) => FirebaseRegistrationGetMethod()
  ..ids = (json['ids'] as List<dynamic>?)
      ?.map((e) => const IdConverter().fromJson(e as String))
      .toSet()
  ..referenceIds = json['#ids'] == null
      ? null
      : ResultReference.fromJson(json['#ids'] as Map<String, dynamic>)
  ..properties = const PropertiesConverter().fromJson(
    json['properties'] as List<String>?,
  )
  ..referenceProperties = json['#properties'] == null
      ? null
      : ResultReference.fromJson(json['#properties'] as Map<String, dynamic>);

Map<String, dynamic> _$FirebaseRegistrationGetMethodToJson(
  FirebaseRegistrationGetMethod instance,
) => <String, dynamic>{
  'ids': ?instance.ids?.map(const IdConverter().toJson).toList(),
  '#ids': ?instance.referenceIds?.toJson(),
  'properties': ?const PropertiesConverter().toJson(instance.properties),
  '#properties': ?instance.referenceProperties?.toJson(),
};
