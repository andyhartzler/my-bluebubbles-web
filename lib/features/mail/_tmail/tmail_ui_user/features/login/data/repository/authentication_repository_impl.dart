import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:bluebubbles/features/mail/_tmail/model/account/password.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/data/datasource/authentication_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/domain/repository/authentication_repository.dart';

class AuthenticationRepositoryImpl extends AuthenticationRepository {
  final AuthenticationDataSource loginDataSource;

  AuthenticationRepositoryImpl(this.loginDataSource);

  @override
  Future<UserName> authenticationUser(Uri baseUrl, UserName userName, Password password) {
    return loginDataSource.authenticationUser(baseUrl, userName, password);
  }
}