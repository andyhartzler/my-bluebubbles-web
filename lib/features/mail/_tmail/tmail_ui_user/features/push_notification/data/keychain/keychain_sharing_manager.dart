
import 'dart:convert';

import 'package:bluebubbles/features/mail/_tmail/_stubs/sentry_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:bluebubbles/features/mail/_tmail/model/extensions/account_id_extensions.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/push_notification/data/keychain/keychain_sharing_session.dart';

class KeychainSharingManager {
  final FlutterSecureStorage _secureStorage;

  KeychainSharingManager(this._secureStorage);

  Future<void> saveSharingSession(KeychainSharingSession keychainSharingSession) => _secureStorage.write(
    key: keychainSharingSession.accountId.asString,
    value: jsonEncode(keychainSharingSession.toJson()),
  );

  Future<void> saveSentryConfig(SentryConfig sentryConfig) => _secureStorage.write(
    key: SentryConfig.sentryConfigKeyChain,
    value: jsonEncode(sentryConfig.toJson()),
  );

  Future<bool> isSessionExist(AccountId accountId) =>
    _secureStorage.containsKey(key: accountId.asString);

  Future<KeychainSharingSession?> getSharingSession(AccountId accountId) async {
    final jsonData = await _secureStorage.read(key: accountId.asString);
    if (jsonData?.isNotEmpty == true) {
      return KeychainSharingSession.fromJson(jsonDecode(jsonData!));
    } else {
      return null;
    }
  }

  Future<void> delete({String? accountId}) {
    if (accountId != null) {
      return _secureStorage.delete(key: accountId);
    } else {
      return _secureStorage.deleteAll();
    }
  }
}