library tray_manager;

class TrayManager {
  TrayManager._();

  static final TrayManager instance = TrayManager._();

  Future<void> setIcon(String iconPath) async {}
  Future<void> setContextMenu(Menu menu) async {}
  Future<void> popUpContextMenu() async {}

  void addListener(TrayListener listener) {}
  void removeListener(TrayListener listener) {}
}

final TrayManager trayManager = TrayManager.instance;

abstract class TrayListener {
  void onTrayIconMouseDown() {}
  void onTrayIconRightMouseDown() {}
  void onTrayMenuItemClick(MenuItem menuItem) {}
}

class Menu {
  final List<MenuItem> items;

  const Menu({this.items = const []});
}

class MenuItem {
  final String label;
  final String? key;
  final bool isSeparator;

  const MenuItem({required this.label, this.key}) : isSeparator = false;
  const MenuItem.separator()
      : label = '',
        key = null,
        isSeparator = true;
}
