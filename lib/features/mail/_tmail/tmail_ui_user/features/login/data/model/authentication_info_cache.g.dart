// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication_info_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AuthenticationInfoCacheAdapter
    extends TypeAdapter<AuthenticationInfoCache> {
  @override
  final int typeId = 11;

  @override
  AuthenticationInfoCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AuthenticationInfoCache(
      fields[0] as String,
      fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AuthenticationInfoCache obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.password);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticationInfoCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
