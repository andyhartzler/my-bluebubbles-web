// Edge-function-backed implementation of tmail's ContactDataSource.
//
// Wires the composer's To/Cc/Bcc recipient autocomplete to the MOYD CRM
// members directory. As the user types in a recipient field tmail calls
// `getContactSuggestions(AutoCompletePattern)`; we round-trip the query
// to the `mail-contact-search` edge fn and shape the response into tmail's
// abstract Contact model.
//
// Mapping: each row returned by the edge fn is `(id, name, email, phone)`.
// tmail's Contact model only carries `displayName` + `email` — id and phone
// are dropped on the floor here (they're not surfaced in the recipient
// chip UI). We materialize each row as a `DeviceContact`, which is the
// existing concrete subclass tmail uses for "contact from a non-JMAP
// source"; it satisfies the abstract Contact interface and equality is
// keyed on (displayName, email) which matches our needs.
//
// The previous wiring went through tmail's ContactDataSourceImpl (mobile
// device contacts via `contacts_service`, web JMAP via `users.contacts.search`).
// On our setup neither path works: there's no JMAP backend, and contacts_service
// has been stubbed for web. Result was an empty autocomplete forever — this
// data source replaces that path entirely.

import 'dart:async';

import 'package:bluebubbles/features/mail/_tmail/model/model.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/data/datasource/contact_datasource.dart';
import 'package:bluebubbles/features/mail/services/mail_api_client.dart';

class EdgeFnContactDataSource extends ContactDataSource {
  EdgeFnContactDataSource({MailApiClient? api})
      : _api = api ?? MailApiClient();

  final MailApiClient _api;

  @override
  Future<List<Contact>> getContactSuggestions(
    AutoCompletePattern autoCompletePattern,
  ) async {
    final raw = autoCompletePattern.word.trim();
    if (raw.isEmpty) return const <Contact>[];

    // tmail's AutoCompletePattern.limit is nullable; default to 10 (matches
    // the edge fn default). The edge fn enforces a hard cap of 25 regardless.
    final limit = autoCompletePattern.limit ?? 10;

    try {
      final results = await _api.searchContacts(q: raw, limit: limit);
      return results
          .map((r) => DeviceContact(r.name, r.email))
          .cast<Contact>()
          .toList();
    } catch (e, st) {
      // Match the swallowing behavior of tmail's ContactDataSourceImpl —
      // an autocomplete miss should not break the composer. Log + return
      // empty so the user keeps typing without a red error overlay.
      // ignore: avoid_print
      print('[EdgeFnContactDataSource] search failed for "$raw": $e\n$st');
      return const <Contact>[];
    }
  }
}
