library fast_contacts;

import 'dart:typed_data';

class FastContacts {
  static Future<List<FastContact>> getAllContacts({List<ContactField> fields = const []}) async => const [];
  static Future<Uint8List?> getContactImage(String id, {ContactImageSize size = ContactImageSize.small}) async => null;
}

enum ContactField {
  company,
  department,
  jobDescription,
  emailLabels,
  phoneLabels,
  namePrefix,
  givenName,
  middleName,
  familyName,
  nameSuffix,
}

class ContactImageSize {
  final String value;
  const ContactImageSize._(this.value);

  static const small = ContactImageSize._('small');
  static const fullSize = ContactImageSize._('full');
}

class FastContact {
  final String id;
  final String displayName;
  final List<FastContactEmail> emails;
  final List<FastContactPhone> phones;
  final FastStructuredName? structuredName;

  const FastContact({
    required this.id,
    required this.displayName,
    this.emails = const [],
    this.phones = const [],
    this.structuredName,
  });
}

class FastContactEmail {
  final String address;
  const FastContactEmail(this.address);
}

class FastContactPhone {
  final String number;
  const FastContactPhone(this.number);
}

class FastStructuredName {
  final String? namePrefix;
  final String? givenName;
  final String? middleName;
  final String? familyName;
  final String? nameSuffix;

  const FastStructuredName({
    this.namePrefix,
    this.givenName,
    this.middleName,
    this.familyName,
    this.nameSuffix,
  });
}
