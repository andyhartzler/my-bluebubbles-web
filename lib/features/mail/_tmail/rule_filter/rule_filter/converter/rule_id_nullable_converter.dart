import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:bluebubbles/features/mail/_tmail/rule_filter/rule_filter/rule_id.dart';

class RuleIdNullableConverter implements JsonConverter<RuleId?, String?> {
  const RuleIdNullableConverter();

  @override
  RuleId? fromJson(String? json) => json != null ? RuleId(id: Id(json)) : null;

  @override
  String? toJson(RuleId? object) => object?.id.value;
}
