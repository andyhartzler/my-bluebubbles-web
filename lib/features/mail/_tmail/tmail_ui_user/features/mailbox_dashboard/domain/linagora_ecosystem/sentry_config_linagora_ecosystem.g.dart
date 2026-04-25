// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentry_config_linagora_ecosystem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SentryConfigLinagoraEcosystem _$SentryConfigLinagoraEcosystemFromJson(
        Map<String, dynamic> json) =>
    SentryConfigLinagoraEcosystem(
      enabled: SentryConfigLinagoraEcosystem._parseBool(json['enabled']),
      dsn: json['dsn'] as String?,
      environment: json['environment'] as String?,
    );

Map<String, dynamic> _$SentryConfigLinagoraEcosystemToJson(
        SentryConfigLinagoraEcosystem instance) =>
    <String, dynamic>{
      if (instance.enabled case final value?) 'enabled': value,
      if (instance.dsn case final value?) 'dsn': value,
      if (instance.environment case final value?) 'environment': value,
    };
