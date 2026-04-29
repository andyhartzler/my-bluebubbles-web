// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tmail_forward.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TMailForward _$TMailForwardFromJson(Map<String, dynamic> json) => TMailForward(
  id: const ForwardIdNullableConverter().fromJson(json['id'] as String?),
  localCopy: json['localCopy'] as bool?,
  forwards: (json['forwards'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toSet(),
);

Map<String, dynamic> _$TMailForwardToJson(TMailForward instance) =>
    <String, dynamic>{
      'id': ?const ForwardIdNullableConverter().toJson(instance.id),
      'localCopy': ?instance.localCopy,
      'forwards': ?instance.forwards?.toList(),
    };
