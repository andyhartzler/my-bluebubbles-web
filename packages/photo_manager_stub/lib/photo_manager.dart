library photo_manager;

class PermissionState {
  final bool hasAccess;

  const PermissionState._(this.hasAccess);
}

class PhotoManager {
  static Future<PermissionState> requestPermissionExtend() async => const PermissionState._(true);
  static Future<List<AssetPathEntity>> getAssetPathList({bool onlyAll = false}) async => const [];
}

class AssetPathEntity {
  const AssetPathEntity();

  Future<List<AssetEntity>> getAssetListRange({required int start, required int end}) async => const [];
}

class AssetEntity {
  DateTime get modifiedDateTime => DateTime.now();
  Future<dynamic> get file async => null;
}
