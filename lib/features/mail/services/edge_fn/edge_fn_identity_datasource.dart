// Edge-function-backed implementation of tmail's IdentityDataSource.
//
// Returns the caller's verified Gmail send-as identities so tmail's
// composer "From:" picker can show all of them.
//
//   - shared_alias mailboxes (15 execs sharing crm@): exactly one
//     identity is returned — the caller's own alias_email. The shared
//     mailbox holds N sendAs entries server-side, but the trust
//     boundary keeps each exec pinned to their own.
//
//   - self_owned mailboxes (Andrew/Dustin/Landon): every verified
//     sendAs identity on their seat (primary + every alias with
//     verificationStatus=accepted in users.settings.sendAs.list).
//
// The actual list is fetched once per session via the
// `mail-identities-get` edge fn and cached in-process.
//
// We deliberately do NOT support createNewIdentity / editIdentity /
// deleteIdentity — sendAs identities live in Google Workspace, not
// in Supabase, and managing them from inside the CRM would require
// re-implementing Gmail's settings.sendAs flow (not in scope here).
// transformHtmlSignature is a passthrough; signatures aren't stored.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/identities/identity.dart';

import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/data/datasource/identity_data_source.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/create_new_identity_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/edit_identity_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/identities_response.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/identity_signature.dart';
import 'package:bluebubbles/features/mail/services/mail_api_client.dart';

class EdgeFnIdentityDataSource extends IdentityDataSource {
  EdgeFnIdentityDataSource({MailApiClient? api})
      : _api = api ?? MailApiClient();

  final MailApiClient _api;

  // Cached for the duration of the session — sendAs lists rarely change
  // mid-session and tmail's controller calls getAllIdentities a few times
  // during dashboard boot. State is also cached so the
  // IdentitiesResponse.hasData() check (which requires a non-null state)
  // succeeds.
  List<Identity>? _cached;
  final State _state = State('1');

  /// Slugify an email into a valid JMAP `Id` (a-zA-Z0-9_-).
  static String _slugForEmail(String email) {
    final sanitized = email
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return sanitized.isEmpty ? 'caller' : sanitized;
  }

  Future<List<Identity>> _loadIdentities() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final resp = await _api.getIdentities();
      // Sort: primary first, then default (if different), then verified
      // alphabetical. Keeps the From: picker stable + predictable.
      final sorted = [...resp.identities];
      sorted.sort((a, b) {
        if (a.email == resp.primary) return -1;
        if (b.email == resp.primary) return 1;
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return a.email.compareTo(b.email);
      });

      final identities = sorted
          .map((i) => Identity(
                id: IdentityId(Id('moyd-${_slugForEmail(i.email)}')),
                name: i.displayName.isNotEmpty ? i.displayName : i.email,
                email: i.email,
                bcc: null,
                replyTo: null,
                textSignature: null,
                htmlSignature: null,
                // Server controls the verified set; client must not
                // delete identities — tmail's UI hides the affordance
                // when mayDelete=false.
                mayDelete: false,
              ))
          .toList(growable: false);
      _cached = identities;
      return identities;
    } catch (e, st) {
      debugPrint('[EdgeFnIdentityDataSource] getIdentities failed: $e');
      debugPrint('${st.toString().split('\n').take(5).join('\n')}');
      // Fail closed — composer falls back to empty list, which the
      // controller treats as "no identities" rather than crashing.
      _cached = const <Identity>[];
      return const <Identity>[];
    }
  }

  @override
  Future<IdentitiesResponse> getAllIdentities(
    Session session,
    AccountId accountId, {
    Properties? properties,
  }) async {
    final identities = await _loadIdentities();
    return IdentitiesResponse(identities: identities, state: _state);
  }

  @override
  Future<Identity> createNewIdentity(
    Session session,
    AccountId accountId,
    CreateNewIdentityRequest identityRequest,
  ) async {
    // Identities live in Google Workspace, not in Supabase. Surfacing
    // a creation flow here would need Gmail settings.sendAs.create
    // wiring — out of scope for the CRM mail UI.
    throw UnsupportedError(
      'EdgeFnIdentityDataSource: createNewIdentity is not supported',
    );
  }

  @override
  Future<bool> deleteIdentity(
    Session session,
    AccountId accountId,
    IdentityId identityId,
  ) async {
    throw UnsupportedError(
      'EdgeFnIdentityDataSource: deleteIdentity is not supported',
    );
  }

  @override
  Future<bool> editIdentity(
    Session session,
    AccountId accountId,
    EditIdentityRequest editIdentityRequest,
  ) async {
    throw UnsupportedError(
      'EdgeFnIdentityDataSource: editIdentity is not supported',
    );
  }

  @override
  Future<IdentitySignature> transformHtmlSignature(
    IdentitySignature identitySignature,
  ) async {
    return identitySignature;
  }
}
