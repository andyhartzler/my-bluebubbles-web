// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_cache_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IdentityCacheModel _$IdentityCacheModelFromJson(Map<String, dynamic> json) =>
    IdentityCacheModel(
      identity: json['identity'] == null
          ? null
          : Identity.fromJson(json['identity'] as Map<String, dynamic>),
      identityActionType: $enumDecode(
        _$IdentityActionTypeEnumMap,
        json['identityActionType'],
      ),
      isDefault: json['isDefault'] as bool,
      publicAssetsInIdentityArgumentsModel:
          json['publicAssetsInIdentityArgumentsModel'] == null
          ? null
          : PublicAssetsInIdentityArgumentsModel.fromJson(
              json['publicAssetsInIdentityArgumentsModel']
                  as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$IdentityCacheModelToJson(IdentityCacheModel instance) =>
    <String, dynamic>{
      'identity': ?instance.identity?.toJson(),
      'identityActionType':
          _$IdentityActionTypeEnumMap[instance.identityActionType]!,
      'isDefault': instance.isDefault,
      'publicAssetsInIdentityArgumentsModel': ?instance
          .publicAssetsInIdentityArgumentsModel
          ?.toJson(),
    };

const _$IdentityActionTypeEnumMap = {
  IdentityActionType.create: 'create',
  IdentityActionType.edit: 'edit',
};
