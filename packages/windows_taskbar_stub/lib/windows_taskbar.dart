library windows_taskbar;

class WindowsTaskbar {
  static Future<void> resetOverlayIcon() async {}
  static Future<void> setOverlayIcon(ThumbnailToolbarAssetIcon icon) async {}
}

class ThumbnailToolbarAssetIcon {
  final String asset;

  ThumbnailToolbarAssetIcon(this.asset);
}
