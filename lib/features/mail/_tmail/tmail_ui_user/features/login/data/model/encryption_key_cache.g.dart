// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encryption_key_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EncryptionKeyCacheAdapter extends TypeAdapter<EncryptionKeyCache> {
  @override
  final int typeId = 10;

  @override
  EncryptionKeyCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EncryptionKeyCache(
      fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EncryptionKeyCache obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptionKeyCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
