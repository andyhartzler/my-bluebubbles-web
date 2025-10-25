library bitsdojo_window;

import 'package:flutter/material.dart';

final appWindow = _AppWindow();

class _AppWindow {
  final double titleBarHeight = 32;
  final Size titleBarButtonSize = const Size(46, 32);
  bool get isVisible => true;

  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> close() async {}
  Future<void> minimize() async {}
}

void doWhenWindowReady(Future<void> Function() callback) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await callback();
  });
}

class WindowBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double width;

  const WindowBorder({super.key, required this.child, this.color = Colors.transparent, this.width = 0});

  @override
  Widget build(BuildContext context) => child;
}

class WindowTitleBarBox extends StatelessWidget {
  final Widget child;

  const WindowTitleBarBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

class MoveWindow extends StatelessWidget {
  const MoveWindow({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class WindowButtonColors {
  final Color iconNormal;
  final Color? iconMouseOver;
  final Color? iconMouseDown;
  final Color? mouseOver;
  final Color? mouseDown;

  const WindowButtonColors({
    required this.iconNormal,
    this.iconMouseOver,
    this.iconMouseDown,
    this.mouseOver,
    this.mouseDown,
  });
}

class _WindowButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final WindowButtonColors? colors;
  final bool animate;
  final IconData icon;

  const _WindowButton({
    required this.icon,
    this.onPressed,
    this.colors,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) => IconButton(onPressed: onPressed, icon: Icon(icon));
}

class MinimizeWindowButton extends _WindowButton {
  const MinimizeWindowButton({super.onPressed, super.colors, super.animate}) : super(icon: Icons.minimize);
}

class MaximizeWindowButton extends _WindowButton {
  const MaximizeWindowButton({super.onPressed, super.colors, super.animate}) : super(icon: Icons.crop_square);
}

class CloseWindowButton extends _WindowButton {
  const CloseWindowButton({super.onPressed, super.colors, super.animate}) : super(icon: Icons.close);
}
