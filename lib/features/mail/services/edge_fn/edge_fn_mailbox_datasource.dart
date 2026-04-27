// Edge-function-backed implementation of tmail's MailboxDataSource.
//
// We don't expose JMAP mailboxes — Gmail's INBOX/SENT/DRAFTS/TRASH/SPAM
// labels are mapped to a synthetic Mailbox tree that tmail's UI can
// render. Any mailbox creation / rename / delete throws — those are
// Gmail label operations and not Phase 1.

import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/error/set_error.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/properties/properties.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/unsigned_int.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';
import 'package:jmap_dart_client/jmap/mail/email/email.dart';
import 'package:jmap_dart_client/jmap/mail/mailbox/mailbox.dart';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/data/datasource/mailbox_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/data/model/mailbox_change_response.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/create_new_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/get_mailbox_by_role_response.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/jmap_mailbox_response.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/mailbox_right_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/move_folder_content_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/move_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/rename_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/subscribe_mailbox_request.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/domain/model/subscribe_multiple_mailbox_request.dart';

class EdgeFnMailboxDataSource extends MailboxDataSource {
  // Stable mailbox IDs for the synthetic tree — anything UUID-shaped
  // works; we use simple strings that pass jmap_dart_client's Id regex.
  static final _inboxId = MailboxId(Id('inbox'));
  static final _sentId = MailboxId(Id('sent'));
  static final _draftsId = MailboxId(Id('drafts'));
  static final _trashId = MailboxId(Id('trash'));
  static final _spamId = MailboxId(Id('spam'));

  List<Mailbox> _syntheticMailboxes() => [
        Mailbox(
          id: _inboxId,
          name: MailboxName('Inbox'),
          role: Role('inbox'),
          sortOrder: SortOrder(sortValue: 0),
        ),
        Mailbox(
          id: _sentId,
          name: MailboxName('Sent'),
          role: Role('sent'),
          sortOrder: SortOrder(sortValue: 1),
        ),
        Mailbox(
          id: _draftsId,
          name: MailboxName('Drafts'),
          role: Role('drafts'),
          sortOrder: SortOrder(sortValue: 2),
        ),
        Mailbox(
          id: _trashId,
          name: MailboxName('Trash'),
          role: Role('trash'),
          sortOrder: SortOrder(sortValue: 3),
        ),
        Mailbox(
          id: _spamId,
          name: MailboxName('Spam'),
          role: Role('junk'),
          sortOrder: SortOrder(sortValue: 4),
        ),
      ];

  @override
  Future<JmapMailboxResponse> getAllMailbox(
    Session session,
    AccountId accountId, {
    Properties? properties,
  }) async {
    return JmapMailboxResponse(
      mailboxes: _syntheticMailboxes(),
      state: State(DateTime.now().millisecondsSinceEpoch.toString()),
    );
  }

  @override
  Future<List<Mailbox>> getAllMailboxCache(
    AccountId accountId,
    UserName userName,
  ) async =>
      _syntheticMailboxes();

  @override
  Future<MailboxChangeResponse> getChanges(
    Session session,
    AccountId accountId,
    State sinceState, {
    Properties? properties,
  }) async {
    return MailboxChangeResponse(
      newStateChanges: sinceState,
      newStateMailbox: sinceState,
    );
  }

  @override
  Future<void> update(
    AccountId accountId,
    UserName userName, {
    List<Mailbox>? updated,
    List<Mailbox>? created,
    List<MailboxId>? destroyed,
  }) async {}

  @override
  Future<Mailbox?> createNewMailbox(
    Session session,
    AccountId accountId,
    CreateNewMailboxRequest newMailboxRequest,
  ) async =>
      null;

  @override
  Future<Map<Id, SetError>> deleteMultipleMailbox(
    Session session,
    AccountId accountId,
    List<MailboxId> mailboxIds,
  ) async =>
      const {};

  @override
  Future<bool> renameMailbox(
    Session session,
    AccountId accountId,
    RenameMailboxRequest request,
  ) async =>
      false;

  @override
  Future<bool> moveMailbox(
    Session session,
    AccountId accountId,
    MoveMailboxRequest request,
  ) async =>
      false;

  @override
  Future<void> moveFolderContent({
    required Session session,
    required AccountId accountId,
    required MoveFolderContentRequest request,
    StreamController<dartz.Either<Failure, Success>>? onProgressController,
  }) async {}

  @override
  Future<List<EmailId>> markAsMailboxRead(
    Session session,
    AccountId accountId,
    MailboxId mailboxId,
    int totalEmailUnread,
    StreamController<dartz.Either<Failure, Success>> onProgressController,
  ) async =>
      const [];

  @override
  Future<bool> subscribeMailbox(
    Session session,
    AccountId accountId,
    SubscribeMailboxRequest request,
  ) async =>
      true;

  @override
  Future<List<MailboxId>> subscribeMultipleMailbox(
    Session session,
    AccountId accountId,
    SubscribeMultipleMailboxRequest subscribeRequest,
  ) async =>
      const [];

  @override
  Future<bool> handleMailboxRightRequest(
    Session session,
    AccountId accountId,
    MailboxRightRequest request,
  ) async =>
      true;

  @override
  Future<(List<Mailbox> mailboxes, Map<Id, SetError> mapErrors)>
      createDefaultMailbox(
    Session session,
    AccountId accountId,
    Map<Id, Role> mapRoles,
  ) async {
    // tmail's MailboxController calls this when default roles (outbox,
    // templates) are missing from the result of getAllMailbox. We don't
    // support those roles, but we MUST return an empty list — returning
    // _syntheticMailboxes() here causes each caller to APPEND the existing
    // 5 mailboxes onto allMailboxes via _handleCreateDefaultFolderIfMissingSuccess
    // (mailbox_controller.dart:771). The boot path calls getAllMailbox up
    // to 3 times (ever-worker + explicit boot call + re-fires from create),
    // so the sidebar ends up with 3× every system folder. Returning empty
    // here makes the success handler short-circuit at the "isEmpty" guard
    // (mailbox_controller.dart:755) and just rebuild the tree from the
    // existing collection — exactly what we want.
    return (const <Mailbox>[], <Id, SetError>{});
  }

  @override
  Future<(List<Mailbox> mailboxes, Map<Id, SetError> mapErrors)>
      setRoleDefaultMailbox(
    Session session,
    AccountId accountId,
    List<Mailbox> listMailbox,
  ) async {
    return (listMailbox, <Id, SetError>{});
  }

  @override
  Future<GetMailboxByRoleResponse> getMailboxByRole(
    Session session,
    AccountId accountId,
    Role role,
  ) async {
    final match = _syntheticMailboxes().firstWhere(
      (m) => m.role?.value == role.value,
      orElse: () => _syntheticMailboxes().first,
    );
    return GetMailboxByRoleResponse(mailbox: match);
  }

  @override
  Future<void> clearAllMailboxCache(
    AccountId accountId,
    UserName userName,
  ) async {}

  @override
  Future<UnsignedInt> clearMailbox(
    Session session,
    AccountId accountId,
    MailboxId mailboxId,
  ) async =>
      UnsignedInt(0);
}
