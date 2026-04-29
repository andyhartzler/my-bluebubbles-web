// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attachment_hive_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttachmentHiveCacheAdapter extends TypeAdapter<AttachmentHiveCache> {
  @override
  final typeId = 15;

  @override
  AttachmentHiveCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttachmentHiveCache(
      partId: fields[0] as String?,
      blobId: fields[1] as String?,
      size: (fields[2] as num?)?.toInt(),
      name: fields[3] as String?,
      type: fields[4] as String?,
      cid: fields[5] as String?,
      disposition: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AttachmentHiveCache obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.partId)
      ..writeByte(1)
      ..write(obj.blobId)
      ..writeByte(2)
      ..write(obj.size)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.cid)
      ..writeByte(6)
      ..write(obj.disposition);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentHiveCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
