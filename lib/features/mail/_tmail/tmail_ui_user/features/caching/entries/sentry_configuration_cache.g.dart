// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentry_configuration_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SentryConfigurationCacheAdapter
    extends TypeAdapter<SentryConfigurationCache> {
  @override
  final int typeId = 21;

  @override
  SentryConfigurationCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SentryConfigurationCache(
      dsn: fields[0] as String,
      environment: fields[1] as String,
      release: fields[2] as String,
      tracesSampleRate: (fields[3] as num).toDouble(),
      profilesSampleRate: (fields[4] as num).toDouble(),
      enableLogs: fields[5] as bool,
      isDebug: fields[6] as bool,
      attachScreenshot: fields[7] as bool,
      isAvailable: fields[8] as bool,
      sessionSampleRate: (fields[9] as num).toDouble(),
      onErrorSampleRate: (fields[10] as num).toDouble(),
      enableFramesTracking: fields[11] as bool,
      dist: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SentryConfigurationCache obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.dsn)
      ..writeByte(1)
      ..write(obj.environment)
      ..writeByte(2)
      ..write(obj.release)
      ..writeByte(3)
      ..write(obj.tracesSampleRate)
      ..writeByte(4)
      ..write(obj.profilesSampleRate)
      ..writeByte(5)
      ..write(obj.enableLogs)
      ..writeByte(6)
      ..write(obj.isDebug)
      ..writeByte(7)
      ..write(obj.attachScreenshot)
      ..writeByte(8)
      ..write(obj.isAvailable)
      ..writeByte(9)
      ..write(obj.sessionSampleRate)
      ..writeByte(10)
      ..write(obj.onErrorSampleRate)
      ..writeByte(11)
      ..write(obj.enableFramesTracking)
      ..writeByte(12)
      ..write(obj.dist);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SentryConfigurationCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
