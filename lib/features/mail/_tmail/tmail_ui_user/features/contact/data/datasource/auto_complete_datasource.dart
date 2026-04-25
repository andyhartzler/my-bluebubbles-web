
import 'package:jmap_dart_client/jmap/mail/email/email_address.dart';
import 'package:bluebubbles/features/mail/_tmail/model/autocomplete/auto_complete_pattern.dart';

abstract class AutoCompleteDataSource {
  Future<List<EmailAddress>> getAutoComplete(AutoCompletePattern autoCompletePattern);
}