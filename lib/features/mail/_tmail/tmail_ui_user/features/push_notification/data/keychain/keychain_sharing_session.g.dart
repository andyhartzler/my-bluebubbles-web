// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keychain_sharing_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeychainSharingSession _$KeychainSharingSessionFromJson(
        Map<String, dynamic> json) =>
    KeychainSharingSession(
      accountId:
          const AccountIdConverter().fromJson(json['accountId'] as String),
      userName: const UserNameConverter().fromJson(json['userName'] as String),
      authenticationType:
          $enumDecode(_$AuthenticationTypeEnumMap, json['authenticationType']),
      apiUrl: json['apiUrl'] as String,
      emailState: json['emailState'] as String?,
      emailDeliveryState: json['emailDeliveryState'] as String?,
      tokenOIDC: json['tokenOIDC'] == null
          ? null
          : TokenOIDC.fromJson(json['tokenOIDC'] as Map<String, dynamic>),
      basicAuth: json['basicAuth'] as String?,
      tokenEndpoint: json['tokenEndpoint'] as String?,
      oidcScopes: (json['oidcScopes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      mailboxIdsBlockNotification:
          (json['mailboxIdsBlockNotification'] as List<dynamic>?)
              ?.map((e) => const MailboxIdConverter().fromJson(e as String))
              .toList(),
      isTWP: json['isTWP'] as bool? ?? false,
    );

Map<String, dynamic> _$KeychainSharingSessionToJson(
        KeychainSharingSession instance) =>
    <String, dynamic>{
      'accountId': const AccountIdConverter().toJson(instance.accountId),
      'userName': const UserNameConverter().toJson(instance.userName),
      'authenticationType':
          _$AuthenticationTypeEnumMap[instance.authenticationType]!,
      'apiUrl': instance.apiUrl,
      if (instance.emailState case final value?) 'emailState': value,
      if (instance.emailDeliveryState case final value?)
        'emailDeliveryState': value,
      if (instance.tokenOIDC?.toJson() case final value?) 'tokenOIDC': value,
      if (instance.basicAuth case final value?) 'basicAuth': value,
      if (instance.tokenEndpoint case final value?) 'tokenEndpoint': value,
      if (instance.oidcScopes case final value?) 'oidcScopes': value,
      if (instance.mailboxIdsBlockNotification
              ?.map(const MailboxIdConverter().toJson)
              .toList()
          case final value?)
        'mailboxIdsBlockNotification': value,
      'isTWP': instance.isTWP,
    };

const _$AuthenticationTypeEnumMap = {
  AuthenticationType.basic: 'basic',
  AuthenticationType.oidc: 'oidc',
  AuthenticationType.none: 'none',
};
