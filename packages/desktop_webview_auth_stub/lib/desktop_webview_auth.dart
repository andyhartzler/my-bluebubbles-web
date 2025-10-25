library desktop_webview_auth;

import 'google.dart';

class DesktopWebviewAuthResult {
  final String? accessToken;
  DesktopWebviewAuthResult({this.accessToken});
}

class DesktopWebviewAuth {
  static Future<DesktopWebviewAuthResult?> signIn(GoogleSignInArgs args, {int? width, int? height}) async => DesktopWebviewAuthResult(accessToken: null);
}
