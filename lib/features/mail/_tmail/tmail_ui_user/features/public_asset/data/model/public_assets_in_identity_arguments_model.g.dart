// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_assets_in_identity_arguments_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicAssetsInIdentityArgumentsModel
_$PublicAssetsInIdentityArgumentsModelFromJson(Map<String, dynamic> json) =>
    PublicAssetsInIdentityArgumentsModel(
      htmlSignature: json['htmlSignature'] as String,
      preExistingPublicAssetIds:
          (json['preExistingPublicAssetIds'] as List<dynamic>)
              .map((e) => const IdConverter().fromJson(e as String))
              .toList(),
      newlyPickedPublicAssetIds:
          (json['newlyPickedPublicAssetIds'] as List<dynamic>)
              .map((e) => const IdConverter().fromJson(e as String))
              .toList(),
    );

Map<String, dynamic> _$PublicAssetsInIdentityArgumentsModelToJson(
  PublicAssetsInIdentityArgumentsModel instance,
) => <String, dynamic>{
  'htmlSignature': instance.htmlSignature,
  'preExistingPublicAssetIds': instance.preExistingPublicAssetIds
      .map(const IdConverter().toJson)
      .toList(),
  'newlyPickedPublicAssetIds': instance.newlyPickedPublicAssetIds
      .map(const IdConverter().toJson)
      .toList(),
};
