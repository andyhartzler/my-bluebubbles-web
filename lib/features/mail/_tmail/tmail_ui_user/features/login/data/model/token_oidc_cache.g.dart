// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_oidc_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TokenOidcCacheAdapter extends TypeAdapter<TokenOidcCache> {
  @override
  final int typeId = 8;

  @override
  TokenOidcCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TokenOidcCache(
      fields[0] as String,
      fields[1] as String,
      fields[3] as String,
      expiredTime: fields[2] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TokenOidcCache obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.token)
      ..writeByte(1)
      ..write(obj.tokenId)
      ..writeByte(2)
      ..write(obj.expiredTime)
      ..writeByte(3)
      ..write(obj.refreshToken);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenOidcCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
