// ============================================================================
// MailScreenTmailBindings
// ============================================================================
//
// Drives tmail's full GetX dependency graph so that
// `MailboxDashBoardController` can be instantiated against our EdgeFn-backed
// data sources. Idempotent — safe to call from `MailScreen.initState()` on
// every mount.
//
// ORDER MATTERS. We register our EdgeFn data source impls under tmail's
// abstract data source interfaces FIRST, with `permanent: true`, so that when
// tmail's bindings later call `Get.lazyPut<EmailDataSource>(...)` the
// existing slot is preserved (GetX skips lazyPut if already registered).
//
// Bindings invoked (and what each contributes):
//   1. registerEdgeFnDataSources()
//        - EmailDataSource     -> EdgeFnEmailDataSource     (permanent)
//        - ThreadDataSource    -> EdgeFnThreadDataSource    (permanent)
//        - MailboxDataSource   -> EdgeFnMailboxDataSource   (permanent)
//        - Session, AccountId, UserName from TmailRuntimeContext (permanent)
//
//   2. CoreBindings (async)
//        - SharedPreferences, ImagePaths, ResponsiveUtils, AppToast,
//          ToastManager, DeviceInfoPlugin, DeviceManager, PermissionService,
//          Uuid, CompressFileUtils, AppConfigLoader, FileUtils, PrintUtils,
//          BeforeReconnectManager, PreviewEmlFileUtils, TwakeAppManager,
//          FlutterSecureStorage, LocalStorageManager, SessionStorageManager,
//          and registers the EmailReceiveManager (we replace this below
//          with a no-op if EmailReceiveManager itself fails to construct
//          on web — guarded via try/catch).
//
//   3. LocalBindings
//        - All Hive cache clients + cache managers (Mailbox, State, Email,
//          NewEmail, OpenedEmail, SendingEmail, Session, FCM, OIDC, etc.),
//          CachingManager, KeychainSharingManager, NewEmail/OpenedEmail
//          worker queues, CacheExceptionThrower, VerifyNameInteractor.
//
//   4. NetworkBindings
//        - Connectivity, BaseOptions, Dio, DioClient, FlutterAppAuth,
//          AppAuthWebPlugin, OIDCHttpClient, AuthenticationClientBase,
//          IOSSharingManager, DynamicUrlInterceptors, AuthorizationInterceptors,
//          HttpClient, DownloadClient, DownloadManager, MailboxAPI, EmailAPI,
//          ThreadAPI, ContactAPI, IdentityAPI, MdnAPI, ForwardingAPI,
//          QuotasAPI, FcmApi, ServerSettingsAPI, WebSocketApi, RuleFilterAPI,
//          VacationAPI, LinagoraEcosystemApi, RemoteExceptionThrower,
//          SendEmailExceptionThrower, HtmlEscape, HtmlTransform,
//          DnsLookupManager, PromptService, SessionAPI.
//        - NOTE: these APIs receive a Dio configured with our edge-functions
//          base URL via the synthetic Session in TmailRuntimeContext. Tmail
//          never actually calls them — our EdgeFn DataSources short-circuit
//          the API layer.
//
//   5. CredentialBindings
//        - GetCredentialInteractor, AuthenticationInteractor,
//          GetAuthenticatedAccountInteractor, GetTokenOIDCInteractor,
//          GetAuthenticationInfoInteractor, GetStoredOidcConfigurationInteractor,
//          plus AccountRepository/AuthenticationRepository/CredentialRepository/
//          AuthenticationOIDCRepository and their data sources/impls.
//
//   6. SessionBindings
//        - SessionDataSource, SessionRepository, GetSessionInteractor.
//
//   7. NetWorkConnectionBindings
//        - NetworkConnectionController.
//
//   8. MailboxDashBoardBindings (super-binding — invokes most others)
//        Transitively calls:
//          - CleanupBindings, SendingQueueBindings, MailboxBindings,
//            ThreadBindings, EmailBindings, SearchEmailBindings,
//            QuotasBindings, ThreadDetailBindings, IdentityInteractorsBindings,
//            PaywallBindings, DownloadInteractorBindings,
//            SettingInteractorBindings, EmailActionInteractorBindings,
//            LinagoraEcosystemInteractorBindings, SendingQueueInteractorBindings.
//        Registers the controller itself plus AppGridDashboardController,
//        DownloadController, SearchController, SpamReportController,
//        LabelController, ComposerManager, AdvancedFilterController,
//        LocalSettingsService, AddListLabelToListEmailsDelegate.
//
// Stubs registered (environment-specific managers we don't ship):
//   - None at present. If subsequent runtime errors surface (e.g. FCM,
//     Sentry, Firebase wiring), add `_NoOp<X>` impls below and pre-register
//     them with `permanent: true` BEFORE the chain runs.
//
// ============================================================================

import 'package:get/get.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:jmap_dart_client/jmap/core/session/session.dart';
import 'package:jmap_dart_client/jmap/core/user_name.dart';

import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/core/core_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/credential/credential_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/local/local_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/network/network_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/network/network_isolate_binding.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/network_connection/network_connection_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/main/bindings/session/session_bindings.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/bindings/mailbox_dashboard_bindings.dart';

import 'package:bluebubbles/features/mail/services/edge_fn/tmail_runtime_bindings.dart';

/// Single entry point that boots the entire tmail GetX graph required to
/// mount `MailboxDashBoardView`. Idempotent.
class MailScreenTmailBindings {
  MailScreenTmailBindings._();

  static bool _initialized = false;

  /// Initializes ALL the tmail GetX deps needed to mount
  /// `MailboxDashBoardView`. Idempotent — safe to call repeatedly. Call from
  /// `MailScreen.initState()`.
  static Future<void> initialize() async {
    if (_initialized) return;

    // ------------------------------------------------------------------
    // 1. Synthetic JMAP session/account/user must exist before tmail
    //    bindings run. Multiple bindings call `Get.find<Session>()` etc.
    //    during construction, and AuthorizationInterceptors expects an
    //    AccountId.
    // ------------------------------------------------------------------
    if (!Get.isRegistered<Session>()) {
      Get.put<Session>(TmailRuntimeContext.session, permanent: true);
    }
    if (!Get.isRegistered<AccountId>()) {
      Get.put<AccountId>(TmailRuntimeContext.accountId, permanent: true);
    }
    if (!Get.isRegistered<UserName>()) {
      Get.put<UserName>(TmailRuntimeContext.userName, permanent: true);
    }

    // ------------------------------------------------------------------
    // 2. EdgeFn data source impls — registered FIRST under abstract type
    //    keys with `permanent: true` so tmail's later `Get.lazyPut<...>()`
    //    are preempted. See registerEdgeFnDataSources() docstring.
    // ------------------------------------------------------------------
    registerEdgeFnDataSources();

    // ------------------------------------------------------------------
    // 3. CoreBindings — image paths, responsive utils, toast, device info,
    //    file utils, secure storage, local/session storage managers.
    //    Async because of SharedPreferences.getInstance().
    // ------------------------------------------------------------------
    await CoreBindings().dependencies();

    // ------------------------------------------------------------------
    // 4. LocalBindings — every Hive cache client/manager + the umbrella
    //    CachingManager + KeychainSharingManager + cache exception
    //    thrower. Required by NetworkBindings (which constructs
    //    IOSSharingManager).
    // ------------------------------------------------------------------
    LocalBindings().dependencies();

    // ------------------------------------------------------------------
    // 5. NetworkBindings — Dio + every JMAP API class. Configured with
    //    edge-functions base URL but never actually called because our
    //    EdgeFn DataSources bypass the API layer.
    // ------------------------------------------------------------------
    NetworkBindings().dependencies();

    // ------------------------------------------------------------------
    // 5b. NetworkIsolateBindings — registers HtmlAnalyzer, FileUploader,
    //     ThreadIsolateWorker, MailboxIsolateWorker, plus the isolate-tag
    //     variants of Dio/DioClient/HttpClient/EmailAPI/ThreadAPI used
    //     by the upload + composer paths. The composer's Get.find<HtmlAnalyzer>
    //     comes from here — without this, MailboxDashBoardBindings explodes
    //     with "minified:jDb not found" (jDb = HtmlAnalyzer's runtime type).
    //     On web (PlatformInfo.isMobile == false) the IsolateWorker constructors
    //     resolve their ThreadAPI/EmailAPI from the untagged registrations
    //     NetworkBindings already made.
    // ------------------------------------------------------------------
    NetworkIsolateBindings().dependencies();

    // ------------------------------------------------------------------
    // 6. CredentialBindings — credential/account/auth interactors. The
    //    dashboard controller calls `Get.find<GetAuthenticationInfoInteractor>()`
    //    etc. in its constructor body.
    // ------------------------------------------------------------------
    CredentialBindings().dependencies();

    // ------------------------------------------------------------------
    // 7. SessionBindings — SessionRepository + GetSessionInteractor for
    //    tmail's session refresh code path.
    // ------------------------------------------------------------------
    SessionBindings().dependencies();

    // ------------------------------------------------------------------
    // 8. NetWorkConnectionBindings — NetworkConnectionController, used
    //    directly by the dashboard controller.
    // ------------------------------------------------------------------
    NetWorkConnectionBindings().dependencies();

    // ------------------------------------------------------------------
    // 9. The big one. MailboxDashBoardBindings transitively wires
    //    Cleanup, SendingQueue, Mailbox, Thread, Email, SearchEmail,
    //    Quotas, ThreadDetail, Identity, Paywall, Download, Setting,
    //    EmailAction, LinagoraEcosystem, SendingQueueInteractor — and
    //    registers MailboxDashBoardController itself.
    // ------------------------------------------------------------------
    MailboxDashBoardBindings().dependencies();

    _initialized = true;
  }
}
