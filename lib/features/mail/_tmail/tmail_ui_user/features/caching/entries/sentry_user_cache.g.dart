// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentry_user_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SentryUserCacheAdapter extends TypeAdapter<SentryUserCache> {
  @override
  final typeId = 22;

  @override
  SentryUserCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SentryUserCache(
      id: fields[0] as String,
      name: fields[1] as String,
      username: fields[2] as String,
      email: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SentryUserCache obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(obj.email);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SentryUserCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
