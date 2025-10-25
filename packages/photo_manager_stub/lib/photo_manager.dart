library photo_manager;

class PermissionState {
  final bool hasAccess;

  const PermissionState._(this.hasAccess);
}

class PhotoManager {
  static Future<PermissionState> requestPermissionExtend() async => const PermissionState._(true);
  static Future<List<AssetPathEntity>> getAssetPathList({bool onlyAll = false}) async => const <AssetPathEntity>[];
}

class AssetPathEntity {
  const AssetPathEntity();

  Future<List<AssetEntity>> getAssetListRange({required int start, required int end}) async => const <AssetEntity>[];
}

class AssetEntity {
  final String? id;
  final String? mimeType;
  final AssetType type;

  const AssetEntity({this.id, this.mimeType, this.type = AssetType.other});

  DateTime get modifiedDateTime => DateTime.now();
  Future<dynamic> get file async => null;
}

enum AssetType { other, image, video, audio }
