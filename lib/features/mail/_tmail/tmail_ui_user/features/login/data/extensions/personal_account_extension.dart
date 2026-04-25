import 'package:bluebubbles/features/mail/_tmail/model/account/personal_account.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/login/data/model/account_cache.dart';

extension PersonalAccountExtension on PersonalAccount {
  AccountCache toCache() {
    return AccountCache(
      id,
      authenticationType.name,
      isSelected: isSelected,
      accountId: accountId?.id.value,
      apiUrl: apiUrl,
      userName: userName?.value);
  }
}