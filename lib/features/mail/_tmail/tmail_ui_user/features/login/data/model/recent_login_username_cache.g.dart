// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_login_username_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecentLoginUsernameCacheAdapter
    extends TypeAdapter<RecentLoginUsernameCache> {
  @override
  final int typeId = 13;

  @override
  RecentLoginUsernameCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecentLoginUsernameCache(
      fields[0] as String,
      fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecentLoginUsernameCache obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.creationDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentLoginUsernameCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
