library flutter_acrylic;

enum WindowEffect {
  disabled,
  transparent,
  acrylic,
  aero,
  mica,
  tabbed,
}

class WindowEffectOptions {
  final WindowEffect effect;
  final int color;
  final bool dark;

  const WindowEffectOptions({
    required this.effect,
    required this.color,
    required this.dark,
  });
}

class Window {
  static Future<void> initialize() async {}
  static Future<void> hideWindowControls() async {}

  static Future<void> setEffect({required WindowEffect effect, int? color, bool dark = false}) async {}
}
