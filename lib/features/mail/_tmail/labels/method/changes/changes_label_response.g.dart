// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'changes_label_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangesLabelResponse _$ChangesLabelResponseFromJson(
        Map<String, dynamic> json) =>
    ChangesLabelResponse(
      const AccountIdConverter().fromJson(json['accountId'] as String),
      const StateConverter().fromJson(json['oldState'] as String),
      const StateConverter().fromJson(json['newState'] as String),
      json['hasMoreChanges'] as bool,
      (json['created'] as List<dynamic>)
          .map((e) => const IdConverter().fromJson(e as String))
          .toSet(),
      (json['updated'] as List<dynamic>)
          .map((e) => const IdConverter().fromJson(e as String))
          .toSet(),
      (json['destroyed'] as List<dynamic>)
          .map((e) => const IdConverter().fromJson(e as String))
          .toSet(),
    );
