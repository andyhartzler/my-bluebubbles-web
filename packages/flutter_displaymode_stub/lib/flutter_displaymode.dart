library flutter_displaymode;

class DisplayMode {
  final int width;
  final int height;
  final double refreshRate;

  const DisplayMode({this.width = 1920, this.height = 1080, this.refreshRate = 60});
}

class FlutterDisplayMode {
  static Future<List<DisplayMode>> get supported async => const [DisplayMode()];
  static Future<DisplayMode> get active async => const DisplayMode();
  static Future<void> setPreferredMode(DisplayMode mode) async {}
}
