// Integration tests for EdgeFnIdentityDataSource. Mocks CRMSupabaseService
// + the SupabaseClient/Postgrest chain so we can assert that the alias
// row is read and translated into a JMAP Identity, without hitting a
// live Supabase.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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
import 'package:bluebubbles/services/crm/supabase_service.dart';

class _MockCRMSupabaseService extends Mock implements CRMSupabaseService {}

class _MockSupabaseClient extends Mock implements supabase.SupabaseClient {}

class _MockGoTrue extends Mock implements supabase.GoTrueClient {}

class _MockUser extends Mock implements supabase.User {}

class _MockQueryBuilder extends Mock
    implements supabase.SupabaseQueryBuilder {}

class _MockSelectFilterBuilder extends Mock
    implements supabase.PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

/// `maybeSingle()` returns a `PostgrestTransformBuilder<Map<String, dynamic>?>`,
/// which itself implements `Future<Map<String, dynamic>?>`. Mocking the Future
/// implementation directly is messy, so we redirect every Future-shape method
/// the awaiter actually exercises (`then`, `catchError`, `whenComplete`,
/// `timeout`, `asStream`) onto a real Future provided by the test setup.
class _AwaitableTransformBuilder extends Mock
    implements supabase.PostgrestTransformBuilder<Map<String, dynamic>?> {
  _AwaitableTransformBuilder(this._future);
  final Future<Map<String, dynamic>?> _future;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(Map<String, dynamic>?) onValue, {
    Function? onError,
  }) =>
      _future.then(onValue, onError: onError);

  @override
  Future<Map<String, dynamic>?> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) =>
      _future.catchError(onError, test: test);

  @override
  Future<Map<String, dynamic>?> whenComplete(FutureOr<void> Function() action) =>
      _future.whenComplete(action);

  @override
  Stream<Map<String, dynamic>?> asStream() => _future.asStream();

  @override
  Future<Map<String, dynamic>?> timeout(
    Duration timeLimit, {
    FutureOr<Map<String, dynamic>?> Function()? onTimeout,
  }) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);
}

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
  late _MockCRMSupabaseService crm;
  late _MockSupabaseClient client;
  late _MockGoTrue auth;
  late _MockUser user;
  late _MockQueryBuilder fromBuilder;
  late _MockSelectFilterBuilder selectBuilder;
  late _MockSelectFilterBuilder eqBuilder;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    crm = _MockCRMSupabaseService();
    client = _MockSupabaseClient();
    auth = _MockGoTrue();
    user = _MockUser();
    fromBuilder = _MockQueryBuilder();
    selectBuilder = _MockSelectFilterBuilder();
    eqBuilder = _MockSelectFilterBuilder();

    when(() => crm.isInitialized).thenReturn(true);
    when(() => crm.client).thenReturn(client);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.id).thenReturn('user-uuid-1');

    // Every PostgrestBuilder in the chain implements Future<T>. mocktail
    // rejects `thenReturn` for Future-typed values, so each link uses
    // `thenAnswer` to hand the next mock back.
    when(() => client.from(any())).thenAnswer((_) => fromBuilder);
    when(() => fromBuilder.select(any())).thenAnswer((_) => selectBuilder);
    when(() => selectBuilder.eq(any(), any())).thenAnswer((_) => eqBuilder);
  });

  /// Convenience wrapper: stub `eqBuilder.maybeSingle()` to surface `row`
  /// when awaited. The runtime-typed return is a Future-implementing
  /// PostgrestTransformBuilder, so we wrap a real Future and forward
  /// `then` / `catchError` / `whenComplete` to it.
  void stubMaybeSingle(Map<String, dynamic>? row) {
    // mocktail forbids `thenReturn` for Future-typed values (the helper
    // implements Future), so we hand it back via `thenAnswer` instead.
    when(() => eqBuilder.maybeSingle())
        .thenAnswer((_) => _AwaitableTransformBuilder(Future.value(row)));
  }

  group('getAllIdentities', () {
    test('returns one Identity built from the mail_aliases row', () async {
      // The eq() chain ends in maybeSingle() returning the row map.
      stubMaybeSingle({
        'alias_email': 'andrew@moyd.org',
        'display_name': 'Andrew Moyd',
        'revoked_at': null,
      });

      final ds = EdgeFnIdentityDataSource(supabase: crm);
      final response = await ds.getAllIdentities(_emptySession(), _accountId());

      expect(response.identities?.length, 1);
      final identity = response.identities!.first;
      expect(identity.email, 'andrew@moyd.org');
      expect(identity.name, 'Andrew Moyd');
      // Slug derived from the email — non-alphanumeric becomes a single
      // dash, then the slug is prefixed with `moyd-`.
      expect(identity.id?.id.value, 'moyd-andrew-moyd-org');
      expect(identity.mayDelete, false);
      expect(identity.textSignature, isNull);
      expect(identity.htmlSignature, isNull);

      verify(() => client.from('mail_aliases')).called(1);
      verify(() => selectBuilder.eq('user_id', 'user-uuid-1')).called(1);
    });

    test('returns an empty list when no alias row exists', () async {
      stubMaybeSingle(null);

      final ds = EdgeFnIdentityDataSource(supabase: crm);
      final response = await ds.getAllIdentities(_emptySession(), _accountId());

      expect(response.identities, isEmpty);
    });

    test('returns empty when the row exists but is revoked', () async {
      stubMaybeSingle({
        'alias_email': 'andrew@moyd.org',
        'display_name': 'Andrew',
        'revoked_at': '2026-01-01T00:00:00Z',
      });

      final ds = EdgeFnIdentityDataSource(supabase: crm);
      final response = await ds.getAllIdentities(_emptySession(), _accountId());

      expect(response.identities, isEmpty);
    });
  });

  group('mutation methods throw UnsupportedError', () {
    late EdgeFnIdentityDataSource ds;

    setUp(() {
      ds = EdgeFnIdentityDataSource(supabase: crm);
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
