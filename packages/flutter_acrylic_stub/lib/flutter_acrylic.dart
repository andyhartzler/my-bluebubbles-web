library flutter_acrylic;

import 'dart:ui';

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
  final Color? color;
  final bool dark;

  const WindowEffectOptions({
    required this.effect,
    this.color,
    this.dark = false,
  });
}

class Window {
  static Future<void> initialize() async {}
  static Future<void> hideWindowControls() async {}

  static Future<void> setEffect({required WindowEffect effect, Color? color, bool dark = false}) async {}
}
