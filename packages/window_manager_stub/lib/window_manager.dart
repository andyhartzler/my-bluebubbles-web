library window_manager;

import 'package:flutter/material.dart';

enum TitleBarStyle { hidden, normal }

enum WindowEvent { show, hide }

class WindowManager {
  WindowManager._();

  static final WindowManager instance = WindowManager._();

  Future<void> ensureInitialized() async {}
  Future<void> setPreventClose(bool value) async {}
  Future<void> setTitle(String title) async {}
  Future<void> setTitleBarStyle(TitleBarStyle style) async {}
  Future<void> setMinimumSize(Size size) async {}
  Future<Size> getSize() async => const Size(800, 600);
  Future<void> setSize(Size size) async {}
  Future<void> setAlignment(Alignment alignment) async {}
  Future<Offset> getPosition() async => Offset.zero;
  Future<void> setPosition(Offset position, {bool animate = false}) async {}
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> minimize() async {}
  Future<void> close() async {}
  Future<bool> isPreventClose() async => false;

  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
}

final WindowManager windowManager = WindowManager.instance;

abstract class WindowListener {
  void onWindowFocus() {}
  void onWindowBlur() {}
  void onWindowResized() {}
  void onWindowMoved() {}
  void onWindowEvent(String eventName) {}
  void onWindowClose() {}
}
