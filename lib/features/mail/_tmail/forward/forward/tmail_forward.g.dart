// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tmail_forward.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TMailForward _$TMailForwardFromJson(Map<String, dynamic> json) => TMailForward(
      id: const ForwardIdNullableConverter().fromJson(json['id'] as String?),
      localCopy: json['localCopy'] as bool?,
      forwards:
          (json['forwards'] as List<dynamic>?)?.map((e) => e as String).toSet(),
    );

Map<String, dynamic> _$TMailForwardToJson(TMailForward instance) =>
    <String, dynamic>{
      if (const ForwardIdNullableConverter().toJson(instance.id)
          case final value?)
        'id': value,
      if (instance.localCopy case final value?) 'localCopy': value,
      if (instance.forwards?.toList() case final value?) 'forwards': value,
    };
