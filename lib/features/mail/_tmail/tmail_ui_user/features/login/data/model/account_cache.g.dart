// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccountCacheAdapter extends TypeAdapter<AccountCache> {
  @override
  final int typeId = 9;

  @override
  AccountCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccountCache(
      fields[0] as String,
      fields[1] as String,
      isSelected: fields[2] as bool,
      accountId: fields[3] as String?,
      apiUrl: fields[4] as String?,
      userName: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AccountCache obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.authenticationType)
      ..writeByte(2)
      ..write(obj.isSelected)
      ..writeByte(3)
      ..write(obj.accountId)
      ..writeByte(4)
      ..write(obj.apiUrl)
      ..writeByte(5)
      ..write(obj.userName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
