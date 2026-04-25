
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:bluebubbles/features/mail/_tmail/model/model.dart';

extension AuthorizationTokenResponseExtension on AuthorizationTokenResponse {

  TokenOIDC toTokenOIDC() {
    return TokenOIDC(
      accessToken ?? '',
      TokenId(idToken ?? ''),
      refreshToken ?? '',
      expiredTime: accessTokenExpirationDateTime ?? DateTime.now());
  }
}