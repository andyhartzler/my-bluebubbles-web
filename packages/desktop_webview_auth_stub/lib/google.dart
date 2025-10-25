library desktop_webview_auth_google;

class GoogleSignInArgs {
  final String clientId;
  final String redirectUri;
  final String scope;

  GoogleSignInArgs({required this.clientId, required this.redirectUri, required this.scope});
}
