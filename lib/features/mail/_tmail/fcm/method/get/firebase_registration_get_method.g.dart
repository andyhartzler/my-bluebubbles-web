// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_registration_get_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirebaseRegistrationGetMethod _$FirebaseRegistrationGetMethodFromJson(
        Map<String, dynamic> json) =>
    FirebaseRegistrationGetMethod()
      ..ids = (json['ids'] as List<dynamic>?)
          ?.map((e) => const IdConverter().fromJson(e as String))
          .toSet()
      ..referenceIds = json['#ids'] == null
          ? null
          : ResultReference.fromJson(json['#ids'] as Map<String, dynamic>)
      ..properties = const PropertiesConverter()
          .fromJson(json['properties'] as List<String>?)
      ..referenceProperties = json['#properties'] == null
          ? null
          : ResultReference.fromJson(
              json['#properties'] as Map<String, dynamic>);

Map<String, dynamic> _$FirebaseRegistrationGetMethodToJson(
        FirebaseRegistrationGetMethod instance) =>
    <String, dynamic>{
      if (instance.ids?.map(const IdConverter().toJson).toList()
          case final value?)
        'ids': value,
      if (instance.referenceIds?.toJson() case final value?) '#ids': value,
      if (const PropertiesConverter().toJson(instance.properties)
          case final value?)
        'properties': value,
      if (instance.referenceProperties?.toJson() case final value?)
        '#properties': value,
    };
