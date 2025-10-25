library windows_taskbar;

enum TaskbarProgressMode { noProgress, indeterminate, normal, error, paused }

enum TaskbarFlashMode { none, all, timernofg }

class WindowsTaskbar {
  static Future<void> resetOverlayIcon() async {}

  static Future<void> setOverlayIcon(ThumbnailToolbarAssetIcon icon) async {}

  static Future<void> setProgressMode(TaskbarProgressMode mode) async {}

  static Future<void> setProgress(int completed, int total) async {}

  static Future<void> setFlashTaskbarAppIcon({TaskbarFlashMode mode = TaskbarFlashMode.none}) async {}
}

class ThumbnailToolbarAssetIcon {
  final String asset;

  ThumbnailToolbarAssetIcon(this.asset);
}
