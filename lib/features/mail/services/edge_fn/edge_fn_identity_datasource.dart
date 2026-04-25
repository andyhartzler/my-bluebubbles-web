// Edge-function-backed implementation of tmail's IdentityDataSource.
//
// MOYD CRM provisions exactly one mail alias per exec via the
// `mail_aliases` table (alias_email + display_name). We expose that
// row to tmail as a single synthetic JMAP Identity so the dashboard's
// _getAllIdentitiesInteractor and the composer's "From:" picker can
// resolve cleanly.
//
// Phase 1 constraints:
//   - No multi-identity per user (each exec has exactly one alias).
//   - No identity mutation (create/edit/delete) — From: is pinned
//     server-side by the mail-send edge function, so client-side
//     CRUD would be cosmetic at best and confusing at worst.
//   - No signature customization. textSignature/htmlSignature are
//     null; transformHtmlSignature is a passthrough.

import 'dart:async';

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
import 'package:bluebubbles/services/crm/supabase_service.dart';

class EdgeFnIdentityDataSource extends IdentityDataSource {
  EdgeFnIdentityDataSource({CRMSupabaseService? supabase})
      : _supabase = supabase ?? CRMSupabaseService();

  final CRMSupabaseService _supabase;

  // Cache the synthetic Identity for the duration of the session — the
  // alias row doesn't change mid-session and tmail calls getAllIdentities
  // a few times during dashboard boot. State is also cached so the
  // IdentitiesResponse.hasData() check (which requires a non-null state)
  // succeeds.
  Identity? _cached;
  final State _state = State('1');

  /// Slugify alias_email into a valid JMAP `Id` value.
  /// `Id` requires a-zA-Z0-9_- only; the @ and . in an email break it.
  static String _slugForAlias(String aliasEmail) {
    final sanitized = aliasEmail
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return sanitized.isEmpty ? 'caller' : sanitized;
  }

  /// Read the caller's `mail_aliases` row and build a synthetic Identity.
  /// Returns null when the user has no provisioned alias (e.g. members
  /// who somehow reach the mail screen — the nav gate should prevent
  /// this, but we degrade gracefully rather than throw).
  Future<Identity?> _loadIdentityForCaller() async {
    if (_cached != null) return _cached;
    if (!_supabase.isInitialized) return null;
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _supabase.client
        .from('mail_aliases')
        .select('alias_email, display_name, revoked_at')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    if (row['revoked_at'] != null) return null;

    final aliasEmail = row['alias_email'] as String?;
    if (aliasEmail == null || aliasEmail.isEmpty) return null;
    final displayName = (row['display_name'] as String?) ?? aliasEmail;

    _cached = Identity(
      id: IdentityId(Id('moyd-${_slugForAlias(aliasEmail)}')),
      name: displayName,
      email: aliasEmail,
      // No bcc / replyTo / signatures in Phase 1 — the mail-send edge
      // function pins From: server-side, so client overrides are moot.
      bcc: null,
      replyTo: null,
      textSignature: null,
      htmlSignature: null,
      // mayDelete=false signals to tmail's UI that the delete affordance
      // should be hidden; combined with deleteIdentity throwing, this
      // prevents accidental destructive flows.
      mayDelete: false,
    );
    return _cached;
  }

  @override
  Future<IdentitiesResponse> getAllIdentities(
    Session session,
    AccountId accountId, {
    Properties? properties,
  }) async {
    final identity = await _loadIdentityForCaller();
    if (identity == null) {
      // No alias: return an empty list with a state so hasData() returns
      // false and the controller skips the "select default" path.
      return IdentitiesResponse(identities: const <Identity>[], state: _state);
    }
    return IdentitiesResponse(identities: [identity], state: _state);
  }

  @override
  Future<Identity> createNewIdentity(
    Session session,
    AccountId accountId,
    CreateNewIdentityRequest identityRequest,
  ) async {
    // Phase 1: not supported. The composer's "From:" is pinned server-
    // side; allowing arbitrary identities would let users construct
    // From-headers that the mail-send edge function would just discard.
    throw UnsupportedError(
      'EdgeFnIdentityDataSource: createNewIdentity is not supported in Phase 1',
    );
  }

  @override
  Future<bool> deleteIdentity(
    Session session,
    AccountId accountId,
    IdentityId identityId,
  ) async {
    throw UnsupportedError(
      'EdgeFnIdentityDataSource: deleteIdentity is not supported in Phase 1',
    );
  }

  @override
  Future<bool> editIdentity(
    Session session,
    AccountId accountId,
    EditIdentityRequest editIdentityRequest,
  ) async {
    throw UnsupportedError(
      'EdgeFnIdentityDataSource: editIdentity is not supported in Phase 1',
    );
  }

  @override
  Future<IdentitySignature> transformHtmlSignature(
    IdentitySignature identitySignature,
  ) async {
    // No html→html transform pipeline; we don't store or render
    // signatures in Phase 1. Return the input unchanged so callers
    // that pipe through this never crash.
    return identitySignature;
  }
}
