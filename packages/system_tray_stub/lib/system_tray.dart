library system_tray;

class SystemTray {
  Future<void> initSystemTray({required String iconPath, String? toolTip}) async {}
  Future<void> registerSystemTrayEventHandler(void Function(String eventName) handler) async {}
  Future<void> setContextMenu(Menu menu) async {}
  Future<void> setIcon(String path) async {}
  Future<void> setToolTip(String toolTip) async {}
  Future<void> popUpContextMenu() async {}
  Future<void> destroySystemTray() async {}
}

class Menu {
  final List<MenuItemBase> items;

  Menu({this.items = const []});

  void buildFrom(List<MenuItemBase> menuItems) {}
}

abstract class MenuItemBase {}

class MenuItemLabel extends MenuItemBase {
  final String label;
  final Future<void> Function(MenuItemBase menuItem)? onClicked;

  MenuItemLabel({required this.label, this.onClicked});
}

class MenuSeparator extends MenuItemBase {}

const String kSystemTrayEventClick = 'click';
const String kSystemTrayEventRightClick = 'rightClick';
