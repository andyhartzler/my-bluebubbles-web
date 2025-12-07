import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CredentialStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _listmonkUsernameKey = 'listmonk_username';
  static const _listmonkPasswordKey = 'listmonk_password';

  static Future<void> initializeListmonkCredentials() async {
    final existingUsername = await _storage.read(key: _listmonkUsernameKey);
    if (existingUsername == null) {
      await _storage.write(key: _listmonkUsernameKey, value: 'admin');
      await _storage.write(key: _listmonkPasswordKey, value: 'fucktrump67');
    }
  }

  static Future<String?> getListmonkUsername() async {
    return await _storage.read(key: _listmonkUsernameKey);
  }

  static Future<String?> getListmonkPassword() async {
    return await _storage.read(key: _listmonkPasswordKey);
  }
}
