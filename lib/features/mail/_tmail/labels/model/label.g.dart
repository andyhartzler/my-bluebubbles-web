// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Label _$LabelFromJson(Map<String, dynamic> json) => Label(
      id: _$JsonConverterFromJson<String, Id>(
          json['id'], const IdConverter().fromJson),
      keyword: const KeywordIdentifierNullableConverter()
          .fromJson(json['keyword'] as String?),
      displayName: json['displayName'] as String?,
      color:
          const HexColorNullableConverter().fromJson(json['color'] as String?),
      description: json['description'] as String?,
      readOnly: json['readOnly'] as bool?,
    );

Map<String, dynamic> _$LabelToJson(Label instance) => <String, dynamic>{
      if (_$JsonConverterToJson<String, Id>(
              instance.id, const IdConverter().toJson)
          case final value?)
        'id': value,
      if (const KeywordIdentifierNullableConverter().toJson(instance.keyword)
          case final value?)
        'keyword': value,
      if (instance.displayName case final value?) 'displayName': value,
      if (const HexColorNullableConverter().toJson(instance.color)
          case final value?)
        'color': value,
      if (instance.description case final value?) 'description': value,
      if (instance.readOnly case final value?) 'readOnly': value,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) =>
    value == null ? null : toJson(value);
