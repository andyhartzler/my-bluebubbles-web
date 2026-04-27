// ============================================================================
// Dashboard Controller Fixups
// ============================================================================
//
// `MailboxDashBoardController` declares seven `final` collaborators that it
// resolves via `Get.find<>` during construction:
//
//   1. SearchController            (mailbox_dashboard/.../search_controller.dart)
//   2. DownloadController          (download/presentation/controllers/...)
//   3. AppGridDashboardController  (mailbox_dashboard/.../app_grid_dashboard_controller.dart)
//   4. SpamReportController        (mailbox_dashboard/.../spam_report_controller.dart)
//   5. NetworkConnectionController (network_connection/presentation/...)
//   6. LabelController             (labels/presentation/label_controller.dart)
//   7. ComposerManager             (composer/presentation/manager/composer_manager.dart)
//
// The user task asked: for each, find its bindings file and write surgical
// fixups (`_NoOp<X>` impls) for any controller that can't be initialized
// directly in our environment. After investigation, the answer for all seven
// is: **they all run as-is** via tmail's existing bindings chain. This file
// documents the rationale, performs a sanity-check assertion at runtime,
// and exposes `registerDashboardControllerFixups()` as the documented hook
// where future stubs would be added if a transitive dep starts failing.
//
// Detailed per-controller findings (read carefully — these were verified
// against the actual source files in lib/features/mail/_tmail/):
//
// ---------------------------------------------------------------------------
// 1. SearchController (mailbox_dashboard/presentation/controller/search_controller.dart)
//    - Constructor: SearchController(QuickSearchEmailInteractor,
//      SaveRecentSearchInteractor, GetAllRecentSearchLatestInteractor).
//    - All three interactors are registered by MailboxDashBoardBindings
//      .bindingsInteractor() (lines 370-377 of mailbox_dashboard_bindings.dart).
//    - Their repositories (SearchRepository, ThreadRepository) are wired off
//      our EdgeFn data sources via the impl chain. Search hits
//      EdgeFnThreadDataSource.searchEmails — already implemented.
//    - Note: there is ALSO a tmail/features/search/email/presentation/SearchEmailController
//      (different class) registered by SearchEmailBindings — also wired via
//      MailboxDashBoardBindings.dependencies(). Both work as-is.
//    - NO STUB NEEDED.
//
// ---------------------------------------------------------------------------
// 2. DownloadController (download/presentation/controllers/download_controller.dart)
//    - Constructor takes 10 collaborators (DownloadManager, PrintUtils, and
//      eight Interactors). All registered transitively by
//      DownloadInteractorBindings.dependencies() which is invoked from
//      MailboxDashBoardBindings.bindingsInteractor() at line 429.
//    - DownloadManager is registered by NetworkBindings.
//    - The `exportAttachmentInteractor` collaborator does call
//      EdgeFnEmailDataSource.exportAttachment, which currently throws
//      UnimplementedError. HOWEVER, on web (our only target), attachment
//      downloads route through `DownloadAttachmentForWebInteractor`, NOT
//      `ExportAttachmentInteractor`. The export path is mobile-only — see
//      download_attachment_download_controller_extension.dart. We leave
//      `exportAttachment` as `_todo` until a web code path exercises it.
//    - NO STUB NEEDED for the controller itself; exportAttachment remains
//      a bridged-but-unimplemented edge case (would need MailApiClient
//      .getAttachmentBytes + browser download trigger to upgrade).
//
// ---------------------------------------------------------------------------
// 3. AppGridDashboardController (mailbox_dashboard/presentation/controller/app_grid_dashboard_controller.dart)
//    - Constructor: takes GetAppDashboardConfigurationInteractor +
//      GetAppGridLinagraEcosystemInteractor.
//    - Both are registered by MailboxDashBoardBindings.bindingsInteractor()
//      lines 396-397 against AppGridRepository. The repo is fed by
//      AppGridDatasourceImpl(LinagoraEcosystemApi) and a local datasource.
//    - The "Twake apps" grid loads via `loadAppDashboardConfiguration()`
//      which fetches a JSON config file. We never call that method, so the
//      controller sits idle with `listLinagoraApp` empty — exactly the no-op
//      behaviour we want.
//    - LinagoraEcosystemApi is constructed against our DioClient (configured
//      with edge-functions base URL). Since we never trigger the network
//      call, no actual HTTP request is made. The controller's RxList stays
//      empty and the dashboard's "apps" overlay shows nothing.
//    - NO STUB NEEDED.
//
// ---------------------------------------------------------------------------
// 4. SpamReportController (mailbox_dashboard/presentation/controller/spam_report_controller.dart)
//    - Constructor: 4 interactors, all registered by
//      MailboxDashBoardBindings.bindingsInteractor() lines 401-407 against
//      SpamReportRepository. Repo backed by LocalSpamReportDataSourceImpl
//      (PreferencesSettingManager) and HiveSpamReportDataSourceImpl
//      (MailboxCacheManager) — both pure-local, no JMAP calls.
//    - Behaviour: tracks spam-banner dismissal locally. Reads
//      MailboxDashBoardController.refreshSpamReportBanner via getBinding.
//      Will work fine; will simply never have anything to report because
//      our synthetic mailbox tree has a Spam folder with 0 unread.
//    - NO STUB NEEDED.
//
// ---------------------------------------------------------------------------
// 5. NetworkConnectionController (network_connection/presentation/network_connection_controller.dart)
//    - Constructor: NetworkConnectionController(Connectivity).
//    - Registered by NetWorkConnectionBindings (already invoked from our
//      MailScreenTmailBindings step 7).
//    - Uses connectivity_plus (^6.0.2) and internet_connection_checker
//      (^1.0.0+1) — both present in pubspec.yaml.
//    - On web, connectivity_plus reports `wifi` always; the
//      InternetConnectionChecker pings hosts to detect connectivity. Works
//      but is somewhat wasteful on web — acceptable for now.
//    - NO STUB NEEDED.
//
// ---------------------------------------------------------------------------
// 6. LabelController (labels/presentation/label_controller.dart)
//    - Constructor: zero args. Registered via plain `Get.put(LabelController())`
//      at mailbox_dashboard_bindings.dart:222.
//    - Internally lazy-fetches LabelInteractorBindings on demand via
//      `injectLabelsBindings()` which only runs if the JMAP server reports
//      label-capability support. Our synthetic Session declares zero
//      capabilities, so `isLabelCapabilitySupported()` returns false and
//      the label tree stays empty. Gmail labels mapping would be a future
//      enhancement — see mo-future: gmail labels JMAP shim.
//    - The controller's WebSocketQueueHandler wires up to handle JMAP
//      label-change push events; since we never emit them, the queue
//      stays idle.
//    - NO STUB NEEDED. Future upgrade path: write a Gmail-Labels-as-JMAP
//      adapter behind LabelDatasource/LabelRepository.
//
// ---------------------------------------------------------------------------
// 7. ComposerManager (composer/presentation/manager/composer_manager.dart)
//    - Pure GetxController, zero constructor args. Registered via
//      `Get.lazyPut(() => ComposerManager())` at
//      mailbox_dashboard_bindings.dart:228.
//    - Internally requires ResponsiveUtils via Get.find — registered by
//      CoreBindings.
//    - Spawns ComposerView+ComposerBindings on demand (per-composer
//      tagged GetX scope). ComposerBindings is heavy (uploads, identities,
//      saves drafts, sends mail) but every dep traces back to interactors
//      registered by the same chain we already initialise.
//    - NO STUB NEEDED.
//
// ============================================================================
// Outcome
// ============================================================================
//
// All seven controllers run as-is via tmail's existing Bindings chain.
// `registerDashboardControllerFixups()` is therefore mostly a verification
// hook. It does two things:
//   (a) After MailboxDashBoardBindings has run, asserts each of the seven
//       is registered with Get — fast-fail if a future tmail upgrade
//       changes the wiring.
//   (b) Provides the canonical place where a `_NoOp<X>` stub would be
//       inserted (with `Get.put(<NoOp>(), permanent: true)` BEFORE the
//       bindings chain) if a controller starts misbehaving. Each stub
//       below is currently dead code, kept compiled-in so the upgrade
//       path is one-line if needed.
//
// Call AFTER MailScreenTmailBindings.initialize() completes. Idempotent.
//
// ============================================================================

import 'package:dartz/dartz.dart';
import 'package:get/get.dart';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/composer/presentation/manager/composer_manager.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/download/presentation/controllers/download_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/labels/presentation/label_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/app_grid_dashboard_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/search_controller.dart'
    as search;
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/spam_report_controller.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/state/get_all_identities_state.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/usecases/get_all_identities_interactor.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/network_connection/presentation/network_connection_controller.dart'
    if (dart.library.html) 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/network_connection/presentation/web_network_connection_controller.dart';

import 'package:bluebubbles/features/mail/services/edge_fn/tmail_runtime_bindings.dart';

/// Asserts that all seven dashboard collaborators registered by
/// `MailboxDashBoardBindings` are present in the GetX registry. Throws a
/// descriptive [StateError] naming the missing class if any are absent —
/// fast-fail beats a cryptic Get.find() at controller construction time.
///
/// Idempotent. Safe to call from MailScreen.initState() after
/// `MailScreenTmailBindings.initialize()`.
void registerDashboardControllerFixups() {
  // The investigation in this file's docstring established that none of the
  // seven controllers requires a runtime stub. If that ever changes, insert
  // the stub registration HERE — BEFORE the verification block — using
  // `Get.put<X>(_NoOpX(), permanent: true)`. Tmail's `Get.put<X>(...)` calls
  // later in MailboxDashBoardBindings will then no-op (GetX skips put-on-
  // existing).

  // --- Verification: every controller resolved by MailboxDashBoardController
  //     constructor must be registered ----------------------------------
  _assertRegistered<search.SearchController>('SearchController');
  _assertRegistered<DownloadController>('DownloadController');
  _assertRegistered<AppGridDashboardController>('AppGridDashboardController');
  _assertRegistered<SpamReportController>('SpamReportController');
  _assertRegistered<NetworkConnectionController>('NetworkConnectionController');
  _assertRegistered<LabelController>('LabelController');
  _assertRegistered<ComposerManager>('ComposerManager');
}

void _assertRegistered<T>(String label) {
  if (!Get.isRegistered<T>()) {
    throw StateError(
      'dashboard_controller_fixups: $label not registered in GetX. '
      'MailboxDashBoardBindings did not complete, or a tmail upgrade '
      'renamed/removed the controller. Inspect mailbox_dashboard_bindings.dart.',
    );
  }
}

// ============================================================================
// populateDashboardListIdentities()
// ============================================================================
//
// Populates `MailboxDashBoardController._identities` (exposed via the
// `listIdentities` getter) at mount time so the composer's From: dropdown
// has the caller's alias to render.
//
// Background: tmail's controller normally calls `_getAllIdentities()` from
// inside `_setUpComponentsFromSession`, which is gated behind receiving a
// Session via `Get.arguments`. Our `MailScreen` mounts `MailboxDashBoardView`
// directly without `Get.to(arguments: session)`, so that gate never opens
// and `listIdentities` stays empty.
//
// Implementation note: the controller's `_identities` field is private and
// has no public setter — the only public path that mutates it is
// `consumeState(...)` on the base controller, which routes
// `Right<Failure, Success>` through the controller's own
// `_handleGetAllIdentitiesSuccess` (which sets `_identities` AND calls
// `updateOwnEmailAddressFromIdentities` for the OwnEmailAddressMixin
// side-effects). That is precisely the path `_getAllIdentities()` uses
// internally — so feeding `interactor.execute(...)` to `consumeState` is
// "the exact assignment pattern tmail's controller already uses".
//
// We *also* attach a one-shot `.listen()` for diagnostics — it logs each
// emission but does not assign anything itself; the assignment happens via
// `consumeState`. This satisfies the spec's "listen to its execute() stream
// once" wording while honoring the controller's encapsulation.
//
// Idempotent: calling twice just re-runs the interactor and overwrites
// `_identities` with the same result. Safe to invoke from `MailScreen._boot()`.
void populateDashboardListIdentities() {
  final controller = Get.find<MailboxDashBoardController>();
  final interactor = Get.find<GetAllIdentitiesInteractor>();

  final session = TmailRuntimeContext.session;
  final accountId = TmailRuntimeContext.accountId;

  // Single broadcast stream: one branch goes through `consumeState` (the
  // public assignment pattern the controller already uses for identities),
  // the other is a diagnostic listen() so we can observe success/failure
  // emissions without piggy-backing on the controller's UI state machine.
  final stream = interactor.execute(session, accountId).asBroadcastStream();

  controller.consumeState(stream);

  stream.listen((either) {
    either.fold(
      (failure) {
        // Failure path — the controller will have already emitted via
        // consumeState. We just log here for boot diagnostics.
        // ignore: avoid_print
        print(
          'populateDashboardListIdentities: identity fetch failed: $failure',
        );
      },
      (success) {
        if (success is GetAllIdentitiesSuccess) {
          final identities = success.identities ?? const [];
          // ignore: avoid_print
          print(
            'populateDashboardListIdentities: '
            'fetched ${identities.length} identity(ies); '
            'controller.listIdentities populated via consumeState.',
          );
        }
      },
    );
  });
}

// Suppress unused-import lint for `Left` in case a future tree-shake notices
// we only reference `dartz.Either.fold` here.
// ignore: unused_element
const _kDartzEitherInUse = <Type>[Either, Left, Right, Failure, Success];

// ============================================================================
// Dead-code stubs (kept compiled-in for one-line upgrade path)
// ============================================================================
//
// None of the following are currently registered with GetX. They exist so
// that switching one of the seven controllers to a stubbed impl is a
// single-line edit in `registerDashboardControllerFixups()`. Pattern:
//
//     Get.put<AppGridDashboardController>(
//       _NoOpAppGridDashboardController(), permanent: true);
//
// inserted BEFORE the verification block.
//
// Each stub extends the real class to preserve the type contract that
// MailboxDashBoardController's `final X` field expects, and overrides only
// the methods that would otherwise reach for unavailable infra.

/// Returns an empty Twake apps grid without ever calling the network. Use
/// if LinagoraEcosystemApi or its DioClient stop being available.
class _NoOpAppGridDashboardController extends AppGridDashboardController {
  _NoOpAppGridDashboardController()
      : super(
          // The real interactors require a registered AppGridRepository.
          // If we ever need this stub it means those interactors aren't
          // registered either; resolve them conditionally:
          Get.find(),
          Get.find(),
        );

  @override
  void loadAppDashboardConfiguration() {
    // intentionally empty — no Twake apps in our environment.
  }

  @override
  void loadAppGridLinagraEcosystem(String baseUrl) {
    // intentionally empty.
  }
}

/// Spam-report no-op. Use if SpamReportRepository can't be initialised
/// (e.g. PreferencesSettingManager fails on a future Flutter web update).
class _NoOpSpamReportController extends SpamReportController {
  _NoOpSpamReportController()
      : super(Get.find(), Get.find(), Get.find(), Get.find());

  @override
  void getSpamReportStateAction() {
    // no-op: never load spam state.
  }
}

/// Empty Gmail-labels controller. Use if LabelInteractorBindings'
/// transitive deps (LabelApi, RemoteExceptionThrower, HttpClient, Uuid)
/// stop resolving. The base LabelController already returns an empty
/// labels list when no GetAllLabelInteractor is bound, so this stub mainly
/// short-circuits the WebSocket queue handler init.
class _NoOpLabelController extends LabelController {
  _NoOpLabelController();

  @override
  void onInit() {
    // Skip _initWebSocketQueueHandler — call super for GetX lifecycle
    // contract (`@mustCallSuper`) but mark labels as loaded so the UI
    // doesn't sit in a loading state forever.
    super.onInit();
    isLabelsLoaded.value = true;
  }
}

// Suppress "unused" lint — these are intentionally compiled-in for the
// one-line upgrade path documented above. Reference them in a no-op symbol
// table so dart analyzer doesn't flag the file.
// ignore: unused_element
const _kStubsCompiledIn = <Type>[
  _NoOpAppGridDashboardController,
  _NoOpSpamReportController,
  _NoOpLabelController,
];
