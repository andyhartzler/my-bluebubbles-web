// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tmail_contact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TMailContact _$TMailContactFromJson(Map<String, dynamic> json) => TMailContact(
      json['id'] as String,
      json['firstname'] as String?,
      json['surname'] as String?,
      json['emailAddress'] as String,
    );

Map<String, dynamic> _$TMailContactToJson(TMailContact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'emailAddress': instance.emailAddress,
      if (instance.firstname case final value?) 'firstname': value,
      if (instance.surname case final value?) 'surname': value,
    };
