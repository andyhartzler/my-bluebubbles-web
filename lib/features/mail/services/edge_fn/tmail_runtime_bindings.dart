// Step 4d binding glue. Registers our EdgeFn-backed data source impls
// in tmail's GetX registry under the abstract interface keys. Also
// constructs a synthetic Session + AccountId + UserName so tmail
// controllers that read these from Get.find see something valid.
//
// Call this once on first MailScreen mount, BEFORE tmail's MailboxBindings
// runs — registering the abstract types via Get.put(permanent: true)
// makes Get.lazyPut() in tmail's binding skip our entries.

import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/account/account.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_identifier.dart';
import 'package:jmap_dart_client/jmap/core/capability/capability_properties.dart';
import 'package:jmap_dart_client/jmap/core/id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/state.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';

import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/email/data/datasource/email_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox/data/datasource/mailbox_datasource.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/data/datasource/identity_data_source.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/data/datasource/thread_datasource.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_email_datasource.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_identity_datasource.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_mailbox_datasource.dart';
import 'package:bluebubbles/features/mail/services/edge_fn/edge_fn_thread_datasource.dart';

/// Synthetic AccountId + UserName for our Supabase-auth context. tmail's
/// JMAP layer expects a concrete account; we provide one shaped enough
/// for the dashboard controller's startup sequence.
class TmailRuntimeContext {
  TmailRuntimeContext._();
  static final accountId = AccountId(Id('moyd-crm-account'));
  static final userName = UserName('crm@moyoungdemocrats.org');

  /// Synthetic Session with the api/upload/download URLs pointing at
  /// invalid hosts — our edge fns are called via dart Supabase client,
  /// so tmail never actually fetches these. Capabilities map carries the
  /// minimum mail capability so MailboxDashBoardController's startup
  /// gates pass.
  static final session = Session(
    const <CapabilityIdentifier, CapabilityProperties>{},
    {accountId: Account(AccountName('MOYD CRM'), false, false, {})},
    {},
    userName,
    Uri.parse('https://faajpcarasilbfndzkmd.functions.supabase.co/'),
    Uri.parse('https://faajpcarasilbfndzkmd.functions.supabase.co/'),
    Uri.parse('https://faajpcarasilbfndzkmd.functions.supabase.co/'),
    Uri.parse('https://faajpcarasilbfndzkmd.functions.supabase.co/'),
    State('0'),
  );
}

/// Registers our EdgeFn data sources in GetX. Uses `permanent: true` so
/// they survive subsequent Bindings() invocations from tmail's route
/// transitions.
void registerEdgeFnDataSources() {
  if (!Get.isRegistered<EmailDataSource>()) {
    Get.put<EmailDataSource>(EdgeFnEmailDataSource(), permanent: true);
  }
  if (!Get.isRegistered<ThreadDataSource>()) {
    Get.put<ThreadDataSource>(EdgeFnThreadDataSource(), permanent: true);
  }
  if (!Get.isRegistered<MailboxDataSource>()) {
    Get.put<MailboxDataSource>(EdgeFnMailboxDataSource(), permanent: true);
  }
  if (!Get.isRegistered<IdentityDataSource>()) {
    Get.put<IdentityDataSource>(EdgeFnIdentityDataSource(), permanent: true);
  }
}
