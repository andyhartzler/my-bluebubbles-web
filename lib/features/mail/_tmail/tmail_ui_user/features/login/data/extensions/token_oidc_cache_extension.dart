import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_id.dart';
import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_oidc.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/data/model/token_oidc_cache.dart';

extension TokenOidcCacheExtension on TokenOidcCache {
  TokenOIDC toTokenOidc() {
    return TokenOIDC(token, TokenId(tokenId), refreshToken, expiredTime: expiredTime);
  }
}