// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'oidc_configuration_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OidcConfigurationCacheAdapter
    extends TypeAdapter<OidcConfigurationCache> {
  @override
  final typeId = 20;

  @override
  OidcConfigurationCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OidcConfigurationCache(fields[0] as String, fields[1] as bool);
  }

  @override
  void write(BinaryWriter writer, OidcConfigurationCache obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.authority)
      ..writeByte(1)
      ..write(obj.isTWP);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OidcConfigurationCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
