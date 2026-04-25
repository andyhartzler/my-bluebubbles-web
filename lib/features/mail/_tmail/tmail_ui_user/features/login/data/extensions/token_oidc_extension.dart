import 'package:bluebubbles/features/mail/_tmail/model/oidc/token_oidc.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/data/model/token_oidc_cache.dart';

extension TokenOidcExtension on TokenOIDC {
  TokenOidcCache toTokenOidcCache() {
    return TokenOidcCache(token, tokenId.uuid, refreshToken, expiredTime: expiredTime);
  }
}