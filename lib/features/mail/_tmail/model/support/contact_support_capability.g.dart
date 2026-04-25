// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_support_capability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ContactSupportCapability _$ContactSupportCapabilityFromJson(
        Map<String, dynamic> json) =>
    ContactSupportCapability(
      httpLink: json['httpLink'] as String?,
      supportMailAddress: json['supportMailAddress'] as String?,
    );

Map<String, dynamic> _$ContactSupportCapabilityToJson(
        ContactSupportCapability instance) =>
    <String, dynamic>{
      if (instance.httpLink case final value?) 'httpLink': value,
      if (instance.supportMailAddress case final value?)
        'supportMailAddress': value,
    };
