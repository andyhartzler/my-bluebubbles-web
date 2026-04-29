// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sending_email_hive_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SendingEmailHiveCacheAdapter extends TypeAdapter<SendingEmailHiveCache> {
  @override
  final typeId = 18;

  @override
  SendingEmailHiveCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SendingEmailHiveCache(
      fields[0] as String,
      fields[1] as String,
      fields[2] as String,
      fields[3] as DateTime,
      fields[4] as String?,
      fields[5] as String?,
      fields[6] as String?,
      fields[7] as String?,
      fields[8] as String?,
      fields[9] as String,
      fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SendingEmailHiveCache obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.sendingId)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.emailActionType)
      ..writeByte(3)
      ..write(obj.createTime)
      ..writeByte(4)
      ..write(obj.sentMailboxId)
      ..writeByte(5)
      ..write(obj.emailIdDestroyed)
      ..writeByte(6)
      ..write(obj.emailIdAnsweredOrForwarded)
      ..writeByte(7)
      ..write(obj.identityId)
      ..writeByte(8)
      ..write(obj.mailboxNameRequest)
      ..writeByte(9)
      ..write(obj.sendingState)
      ..writeByte(10)
      ..write(obj.previousEmailId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SendingEmailHiveCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
