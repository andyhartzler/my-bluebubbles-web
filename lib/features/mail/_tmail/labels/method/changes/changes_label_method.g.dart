// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changes_label_method.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangesLabelMethod _$ChangesLabelMethodFromJson(Map<String, dynamic> json) =>
    ChangesLabelMethod(
      const AccountIdConverter().fromJson(json['accountId'] as String),
      const StateConverter().fromJson(json['sinceState'] as String),
      maxChanges: const UnsignedIntNullableConverter().fromJson(
        (json['maxChanges'] as num?)?.toInt(),
      ),
    );

Map<String, dynamic> _$ChangesLabelMethodToJson(ChangesLabelMethod instance) =>
    <String, dynamic>{
      'accountId': const AccountIdConverter().toJson(instance.accountId),
      'sinceState': const StateConverter().toJson(instance.sinceState),
      'maxChanges': ?const UnsignedIntNullableConverter().toJson(
        instance.maxChanges,
      ),
    };
