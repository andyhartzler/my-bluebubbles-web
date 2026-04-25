
import 'package:bluebubbles/features/mail/_tmail/model/account/personal_account.dart';

abstract class AccountRepository {
  Future<PersonalAccount> getCurrentAccount();

  Future<void> setCurrentAccount(PersonalAccount newCurrentAccount);

  Future<void> deleteCurrentAccount(String hashId);
}