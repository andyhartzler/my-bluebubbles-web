// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keychain_sharing_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeychainSharingSession _$KeychainSharingSessionFromJson(
  Map<String, dynamic> json,
) => KeychainSharingSession(
  accountId: const AccountIdConverter().fromJson(json['accountId'] as String),
  userName: const UserNameConverter().fromJson(json['userName'] as String),
  authenticationType: $enumDecode(
    _$AuthenticationTypeEnumMap,
    json['authenticationType'],
  ),
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
  KeychainSharingSession instance,
) => <String, dynamic>{
  'accountId': const AccountIdConverter().toJson(instance.accountId),
  'userName': const UserNameConverter().toJson(instance.userName),
  'authenticationType':
      _$AuthenticationTypeEnumMap[instance.authenticationType]!,
  'apiUrl': instance.apiUrl,
  'emailState': ?instance.emailState,
  'emailDeliveryState': ?instance.emailDeliveryState,
  'tokenOIDC': ?instance.tokenOIDC?.toJson(),
  'basicAuth': ?instance.basicAuth,
  'tokenEndpoint': ?instance.tokenEndpoint,
  'oidcScopes': ?instance.oidcScopes,
  'mailboxIdsBlockNotification': ?instance.mailboxIdsBlockNotification
      ?.map(const MailboxIdConverter().toJson)
      .toList(),
  'isTWP': instance.isTWP,
};

const _$AuthenticationTypeEnumMap = {
  AuthenticationType.basic: 'basic',
  AuthenticationType.oidc: 'oidc',
  AuthenticationType.none: 'none',
};
