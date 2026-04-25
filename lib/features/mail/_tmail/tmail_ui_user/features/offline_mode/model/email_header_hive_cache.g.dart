// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_header_hive_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EmailHeaderHiveCacheAdapter extends TypeAdapter<EmailHeaderHiveCache> {
  @override
  final int typeId = 16;

  @override
  EmailHeaderHiveCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmailHeaderHiveCache(
      name: fields[0] as String,
      value: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EmailHeaderHiveCache obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.value);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailHeaderHiveCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
