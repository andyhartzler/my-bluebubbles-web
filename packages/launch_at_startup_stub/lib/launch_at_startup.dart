library launch_at_startup;

class LaunchAtStartup {
  LaunchAtStartup._();
  static final LaunchAtStartup instance = LaunchAtStartup._();

  Future<void> enable() async {}
  Future<void> disable() async {}

  Future<void> setup({required String appName, required String appPath, List<String> args = const []}) async {}
}
