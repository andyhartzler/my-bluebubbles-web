library local_auth;

class AuthenticationOptions {
  final bool stickyAuth;

  const AuthenticationOptions({this.stickyAuth = false});
}

class LocalAuthentication {
  Future<bool> authenticate({required String localizedReason, AuthenticationOptions options = const AuthenticationOptions()}) async => false;

  Future<bool> get canCheckBiometrics async => false;

  Future<bool> isDeviceSupported() async => false;
}
