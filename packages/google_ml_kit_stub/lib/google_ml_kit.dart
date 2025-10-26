library google_ml_kit;

import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';

export 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';

class GoogleMlKit {
  GoogleMlKit._();
  static final nlp = _Nlp();
}

class _Nlp {
  EntityExtractor entityExtractor(EntityExtractorLanguage language) => EntityExtractor._();

  SmartReply smartReply() => SmartReply();
}

enum EntityExtractorLanguage { english }

enum EntityType { unknown, address, phone, email, url, dateTime, trackingNumber, flightNumber }

class Entity {
  final String rawValue;
  final EntityType type;

  Entity({required this.rawValue, this.type = EntityType.unknown});
}

class AddressEntity extends Entity {
  AddressEntity({required String rawValue}) : super(rawValue: rawValue, type: EntityType.address);
}

class PhoneEntity extends Entity {
  PhoneEntity({required String rawValue}) : super(rawValue: rawValue, type: EntityType.phone);
}

class EmailEntity extends Entity {
  EmailEntity({required String rawValue}) : super(rawValue: rawValue, type: EntityType.email);
}

class UrlEntity extends Entity {
  UrlEntity({required String rawValue}) : super(rawValue: rawValue, type: EntityType.url);
}

class DateTimeEntity extends Entity {
  final int? timestamp;
  DateTimeEntity({required String rawValue, this.timestamp}) : super(rawValue: rawValue, type: EntityType.dateTime);
}

class TrackingNumberEntity extends Entity {
  final String? carrier;
  final String? number;
  TrackingNumberEntity({required String rawValue, this.carrier, this.number}) : super(rawValue: rawValue, type: EntityType.trackingNumber);
}

class TrackingCarrier {
  final String name;

  const TrackingCarrier(this.name);
}

class FlightNumberEntity extends Entity {
  final String? airlineCode;
  final String? flightNumber;
  FlightNumberEntity({required String rawValue, this.airlineCode, this.flightNumber}) : super(rawValue: rawValue, type: EntityType.flightNumber);
}

class EntityAnnotation {
  final int start;
  final int end;
  final String text;
  final List<Entity> entities;

  EntityAnnotation({required this.start, required this.end, required this.text, this.entities = const []});
}

class EntityExtractor {
  EntityExtractor._();

  Future<List<EntityAnnotation>> annotateText(String text) async => const [];
  Future<void> close() async {}
}

class EntityExtractorModelManager {
  Future<bool> isModelDownloaded(String model) async => true;
  Future<void> downloadModel(String model, {bool isWifiRequired = true}) async {}
}
