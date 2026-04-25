// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'autocomplete_capability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AutocompleteCapability _$AutocompleteCapabilityFromJson(
        Map<String, dynamic> json) =>
    AutocompleteCapability(
      minInputLength: const UnsignedIntNullableConverter()
          .fromJson((json['minInputLength'] as num?)?.toInt()),
    );

Map<String, dynamic> _$AutocompleteCapabilityToJson(
        AutocompleteCapability instance) =>
    <String, dynamic>{
      if (const UnsignedIntNullableConverter().toJson(instance.minInputLength)
          case final value?)
        'minInputLength': value,
    };
