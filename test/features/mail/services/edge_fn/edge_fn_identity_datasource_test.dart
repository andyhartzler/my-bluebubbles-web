// Integration tests for EdgeFnIdentityDataSource. Mocks MailApiClient
// (the `mail-identities-get` edge fn wrapper) so we can assert that the
// caller's verified sendAs identities are translated into JMAP
// Identities, without hitting a live Supabase.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/identities/identity.dart';

import 'package:bluebubbles/features/mail/_tmail/model/identity/identity_request_dto.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/create_new_identity_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/edit_identity_request.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_identity_datasource.dart';
import 'package:bluebubbles/features/mail/services/mail_api_client.dart';

class _MockMailApiClient extends Mock implements MailApiClient {}

Session _emptySession() => Session(
      const {},
      const {},
      const {},
      UserName('andrew@moyd.org'),
      Uri.parse('https://example.com/api'),
      Uri.parse('https://example.com/download'),
      Uri.parse('https://example.com/upload'),
      Uri.parse('https://example.com/event'),
      State('0'),
    );

AccountId _accountId() => AccountId(Id('acct-1'));

void main() {
  late _MockMailApiClient api;

  setUp(() {
    api = _MockMailApiClient();
  });

  group('getAllIdentities', () {
    test('returns Identities built from the sendAs list, primary first', () async {
      when(() => api.getIdentities()).thenAnswer(
        (_) async => const MailIdentitiesResponse(
          identities: [
            MailSendAsIdentity(
              email: 'alias@moyd.org',
              displayName: 'MOYD Alias',
              isDefault: false,
              verified: true,
            ),
            MailSendAsIdentity(
              email: 'andrew@moyd.org',
              displayName: 'Andrew Moyd',
              isDefault: true,
              verified: true,
            ),
          ],
          primary: 'andrew@moyd.org',
        ),
      );

      final ds = EdgeFnIdentityDataSource(api: api);
      final response = await ds.getAllIdentities(_emptySession(), _accountId());

      expect(response.identities?.length, 2);
      // Primary sorts to the front.
      final identity = response.identities!.first;
      expect(identity.email, 'andrew@moyd.org');
      expect(identity.name, 'Andrew Moyd');
      // Slug derived from the email — non-alphanumeric becomes a single
      // dash, then the slug is prefixed with `moyd-`.
      expect(identity.id?.id.value, 'moyd-andrew-moyd-org');
      expect(identity.mayDelete, false);
      expect(identity.textSignature, isNull);
      expect(identity.htmlSignature, isNull);

      expect(response.identities!.last.email, 'alias@moyd.org');

      verify(() => api.getIdentities()).called(1);
    });

    test('returns an empty list when no sendAs identities exist', () async {
      when(() => api.getIdentities()).thenAnswer(
        (_) async => const MailIdentitiesResponse(
          identities: [],
          primary: 'andrew@moyd.org',
        ),
      );

      final ds = EdgeFnIdentityDataSource(api: api);
      final response = await ds.getAllIdentities(_emptySession(), _accountId());

      expect(response.identities, isEmpty);
    });

    test('fails closed to an empty list when the edge fn errors', () async {
      when(() => api.getIdentities()).thenThrow(Exception('edge fn down'));

      final ds = EdgeFnIdentityDataSource(api: api);
      final response = await ds.getAllIdentities(_emptySession(), _accountId());

      expect(response.identities, isEmpty);
    });

    test('caches the identity list for the session', () async {
      when(() => api.getIdentities()).thenAnswer(
        (_) async => const MailIdentitiesResponse(
          identities: [
            MailSendAsIdentity(
              email: 'andrew@moyd.org',
              displayName: 'Andrew Moyd',
              isDefault: true,
              verified: true,
            ),
          ],
          primary: 'andrew@moyd.org',
        ),
      );

      final ds = EdgeFnIdentityDataSource(api: api);
      await ds.getAllIdentities(_emptySession(), _accountId());
      await ds.getAllIdentities(_emptySession(), _accountId());

      verify(() => api.getIdentities()).called(1);
    });
  });

  group('mutation methods throw UnsupportedError', () {
    late EdgeFnIdentityDataSource ds;

    setUp(() {
      ds = EdgeFnIdentityDataSource(api: api);
    });

    test('createNewIdentity throws', () async {
      expect(
        () => ds.createNewIdentity(
          _emptySession(),
          _accountId(),
          CreateNewIdentityRequest(
            Id('creation-1'),
            Identity(name: 'x', email: 'x@x.com'),
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('deleteIdentity throws', () async {
      expect(
        () => ds.deleteIdentity(
          _emptySession(),
          _accountId(),
          IdentityId(Id('moyd-someone')),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('editIdentity throws', () async {
      expect(
        () => ds.editIdentity(
          _emptySession(),
          _accountId(),
          EditIdentityRequest(
            identityId: IdentityId(Id('moyd-someone')),
            identityRequest: IdentityRequestDto(name: 'updated'),
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
