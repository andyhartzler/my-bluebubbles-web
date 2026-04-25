
import 'package:equatable/equatable.dart';
import 'package:bluebubbles/features/mail/_tmail/model/contact/contact.dart';

class DeviceContact extends Contact implements EquatableMixin {
  DeviceContact(String displayName, String email) : super(displayName, email);
}
