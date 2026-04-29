// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_registration_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FirebaseRegistrationCacheAdapter
    extends TypeAdapter<FirebaseRegistrationCache> {
  @override
  final typeId = 14;

  @override
  FirebaseRegistrationCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FirebaseRegistrationCache(
      deviceClientId: fields[0] as String,
      id: fields[1] as String?,
      token: fields[2] as String?,
      expires: fields[3] as DateTime?,
      types: (fields[4] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, FirebaseRegistrationCache obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.deviceClientId)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.token)
      ..writeByte(3)
      ..write(obj.expires)
      ..writeByte(4)
      ..write(obj.types);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebaseRegistrationCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
