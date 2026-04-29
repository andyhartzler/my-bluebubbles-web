// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saas_account_capability.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaaSAccountCapability _$SaaSAccountCapabilityFromJson(
  Map<String, dynamic> json,
) => SaaSAccountCapability(
  isPaying: json['isPaying'] as bool? ?? false,
  canUpgrade: json['canUpgrade'] as bool? ?? false,
);

Map<String, dynamic> _$SaaSAccountCapabilityToJson(
  SaaSAccountCapability instance,
) => <String, dynamic>{
  'isPaying': instance.isPaying,
  'canUpgrade': instance.canUpgrade,
};
