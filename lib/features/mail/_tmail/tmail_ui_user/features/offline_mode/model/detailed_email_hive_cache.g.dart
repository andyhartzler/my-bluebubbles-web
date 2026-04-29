// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'detailed_email_hive_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DetailedEmailHiveCacheAdapter
    extends TypeAdapter<DetailedEmailHiveCache> {
  @override
  final typeId = 17;

  @override
  DetailedEmailHiveCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DetailedEmailHiveCache(
      emailId: fields[0] as String,
      timeSaved: fields[1] as DateTime,
      attachments: (fields[2] as List?)?.cast<AttachmentHiveCache>(),
      emailContentPath: fields[3] as String?,
      headers: (fields[4] as List?)?.cast<EmailHeaderHiveCache>(),
      keywords: (fields[5] as Map?)?.cast<String, bool>(),
      messageId: (fields[6] as List?)?.cast<String>(),
      references: (fields[7] as List?)?.cast<String>(),
      inlineImages: (fields[8] as List?)?.cast<AttachmentHiveCache>(),
      sMimeStatusHeader: (fields[9] as Map?)?.cast<String, String?>(),
      identityHeader: (fields[10] as Map?)?.cast<String, String?>(),
    );
  }

  @override
  void write(BinaryWriter writer, DetailedEmailHiveCache obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.emailId)
      ..writeByte(1)
      ..write(obj.timeSaved)
      ..writeByte(2)
      ..write(obj.attachments)
      ..writeByte(3)
      ..write(obj.emailContentPath)
      ..writeByte(4)
      ..write(obj.headers)
      ..writeByte(5)
      ..write(obj.keywords)
      ..writeByte(6)
      ..write(obj.messageId)
      ..writeByte(7)
      ..write(obj.references)
      ..writeByte(8)
      ..write(obj.inlineImages)
      ..writeByte(9)
      ..write(obj.sMimeStatusHeader)
      ..writeByte(10)
      ..write(obj.identityHeader);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailedEmailHiveCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
