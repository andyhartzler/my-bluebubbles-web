import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/model/account/password.dart';

abstract class AuthenticationDataSource {
  Future<UserName> authenticationUser(Uri baseUrl, UserName userName, Password password);
}