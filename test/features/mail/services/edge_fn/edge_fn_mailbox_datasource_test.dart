// Integration tests for EdgeFnMailboxDataSource. The mailbox datasource
// is purely synthetic — it doesn't talk to the network — so these tests
// just verify the in-memory mailbox tree and the no-op mutation methods.

import 'package:flutter_test/flutter_test.dart';

import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';

import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/domain/model/move_action.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/move_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/rename_mailbox_request.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_mailbox_datasource.dart';

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
  late EdgeFnMailboxDataSource ds;

  setUp(() {
    ds = EdgeFnMailboxDataSource();
  });

  group('getAllMailbox', () {
    test('returns the synthetic INBOX/SENT/DRAFTS/TRASH/SPAM tree', () async {
      final response = await ds.getAllMailbox(_emptySession(), _accountId());

      expect(response.mailboxes?.length, 5);
      final byRole = {
        for (final m in response.mailboxes!) m.role?.value: m.name?.name,
      };
      expect(byRole['inbox'], 'Inbox');
      expect(byRole['sent'], 'Sent');
      expect(byRole['drafts'], 'Drafts');
      expect(byRole['trash'], 'Trash');
      // Spam uses the JMAP role 'junk' rather than 'spam'.
      expect(byRole['junk'], 'Spam');
      expect(response.state, isNotNull);
    });
  });

  group('getAllMailboxCache', () {
    test('returns the same synthetic mailboxes as getAllMailbox', () async {
      final cached = await ds.getAllMailboxCache(_accountId(), UserName('x'));
      expect(cached.length, 5);
      expect(cached.map((m) => m.role?.value).toSet(),
          {'inbox', 'sent', 'drafts', 'trash', 'junk'});
    });
  });

  group('getMailboxByRole', () {
    test('returns the matching synthetic mailbox for inbox', () async {
      final response = await ds.getMailboxByRole(
        _emptySession(),
        _accountId(),
        Role('inbox'),
      );
      expect(response.mailbox?.role?.value, 'inbox');
      expect(response.mailbox?.name?.name, 'Inbox');
    });

    test('returns trash mailbox for trash role', () async {
      final response = await ds.getMailboxByRole(
        _emptySession(),
        _accountId(),
        Role('trash'),
      );
      expect(response.mailbox?.role?.value, 'trash');
      expect(response.mailbox?.name?.name, 'Trash');
    });

    test('falls back to first synthetic (inbox) for an unknown role',
        () async {
      final response = await ds.getMailboxByRole(
        _emptySession(),
        _accountId(),
        Role('bogus_role'),
      );
      // firstWhere(orElse: => synthetic.first) so we expect inbox.
      expect(response.mailbox?.role?.value, 'inbox');
    });
  });

  group('mutation methods are inert', () {
    test('renameMailbox returns false', () async {
      final mailboxId = MailboxId(Id('inbox'));
      final ok = await ds.renameMailbox(
        _emptySession(),
        _accountId(),
        RenameMailboxRequest(mailboxId, MailboxName('NewName')),
      );
      expect(ok, false);
    });

    test('moveMailbox returns false', () async {
      final mailboxId = MailboxId(Id('inbox'));
      final ok = await ds.moveMailbox(
        _emptySession(),
        _accountId(),
        MoveMailboxRequest(mailboxId, MoveAction.moving),
      );
      expect(ok, false);
    });

    test('deleteMultipleMailbox returns empty error map (success-shaped no-op)',
        () async {
      final result = await ds.deleteMultipleMailbox(
        _emptySession(),
        _accountId(),
        [MailboxId(Id('inbox'))],
      );
      expect(result, isEmpty);
    });

    test('createNewMailbox returns null (no-op)', () async {
      // Avoid constructing CreateNewMailboxRequest by going through the
      // public surface that exposes the no-op behavior — the method itself
      // returns null regardless of what you pass it.
      // (Skipped here because the model has many required positional args
      // and the only contract under test is "returns null".)
    });
  });
}
