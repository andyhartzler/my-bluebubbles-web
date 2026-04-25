
import 'package:bluebubbles/features/mail/_tmail/model/model.dart';

abstract class ContactRepository {
  Future<List<Contact>> getContactSuggestions(AutoCompletePattern autoCompletePattern);
}