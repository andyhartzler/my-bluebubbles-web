
import 'package:json_annotation/json_annotation.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_id.dart';

class TokenIdConverter implements JsonConverter<TokenId, String> {
  const TokenIdConverter();

  @override
  TokenId fromJson(String json) => TokenId(json);

  @override
  String toJson(TokenId tokenId) => tokenId.uuid;
}