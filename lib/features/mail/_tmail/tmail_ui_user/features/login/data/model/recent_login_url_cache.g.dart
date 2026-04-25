// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_login_url_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecentLoginUrlCacheAdapter extends TypeAdapter<RecentLoginUrlCache> {
  @override
  final int typeId = 12;

  @override
  RecentLoginUrlCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentLoginUrlCache(
      fields[0] as String,
      fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecentLoginUrlCache obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.url)
      ..writeByte(1)
      ..write(obj.creationDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentLoginUrlCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
