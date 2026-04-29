// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'email_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EmailCacheAdapter extends TypeAdapter<EmailCache> {
  @override
  final typeId = 5;

  @override
  EmailCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmailCache(
      fields[0] as String,
      keywords: (fields[1] as Map?)?.cast<String, bool>(),
      size: (fields[2] as num?)?.toInt(),
      receivedAt: fields[3] as DateTime?,
      hasAttachment: fields[4] as bool?,
      preview: fields[5] as String?,
      subject: fields[6] as String?,
      sentAt: fields[7] as DateTime?,
      from: (fields[8] as List?)?.cast<EmailAddressHiveCache>(),
      to: (fields[9] as List?)?.cast<EmailAddressHiveCache>(),
      cc: (fields[10] as List?)?.cast<EmailAddressHiveCache>(),
      bcc: (fields[11] as List?)?.cast<EmailAddressHiveCache>(),
      replyTo: (fields[12] as List?)?.cast<EmailAddressHiveCache>(),
      mailboxIds: (fields[13] as Map?)?.cast<String, bool>(),
      headerCalendarEvent: (fields[14] as Map?)?.cast<String, String?>(),
      blobId: fields[15] as String?,
      xPriorityHeader: (fields[16] as Map?)?.cast<String, String?>(),
      importanceHeader: (fields[17] as Map?)?.cast<String, String?>(),
      priorityHeader: (fields[18] as Map?)?.cast<String, String?>(),
      threadId: fields[19] as String?,
      unsubscribeHeader: (fields[20] as Map?)?.cast<String, String?>(),
      messageId: (fields[21] as List?)?.cast<String>(),
      references: (fields[22] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, EmailCache obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.keywords)
      ..writeByte(2)
      ..write(obj.size)
      ..writeByte(3)
      ..write(obj.receivedAt)
      ..writeByte(4)
      ..write(obj.hasAttachment)
      ..writeByte(5)
      ..write(obj.preview)
      ..writeByte(6)
      ..write(obj.subject)
      ..writeByte(7)
      ..write(obj.sentAt)
      ..writeByte(8)
      ..write(obj.from)
      ..writeByte(9)
      ..write(obj.to)
      ..writeByte(10)
      ..write(obj.cc)
      ..writeByte(11)
      ..write(obj.bcc)
      ..writeByte(12)
      ..write(obj.replyTo)
      ..writeByte(13)
      ..write(obj.mailboxIds)
      ..writeByte(14)
      ..write(obj.headerCalendarEvent)
      ..writeByte(15)
      ..write(obj.blobId)
      ..writeByte(16)
      ..write(obj.xPriorityHeader)
      ..writeByte(17)
      ..write(obj.importanceHeader)
      ..writeByte(18)
      ..write(obj.priorityHeader)
      ..writeByte(19)
      ..write(obj.threadId)
      ..writeByte(20)
      ..write(obj.unsubscribeHeader)
      ..writeByte(21)
      ..write(obj.messageId)
      ..writeByte(22)
      ..write(obj.references);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
