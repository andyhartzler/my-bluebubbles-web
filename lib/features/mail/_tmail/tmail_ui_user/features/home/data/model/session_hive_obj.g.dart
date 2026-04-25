// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_hive_obj.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionHiveObjAdapter extends TypeAdapter<SessionHiveObj> {
  @override
  final int typeId = 19;

  @override
  SessionHiveObj read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionHiveObj(
      value: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SessionHiveObj obj) {
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
      other is SessionHiveObjAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
