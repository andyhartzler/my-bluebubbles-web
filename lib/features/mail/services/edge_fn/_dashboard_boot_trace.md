# MailboxDashBoardController boot path trace

Traced against `lib/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/mailbox_dashboard_controller.dart` (3522 lines) as of commit `bac6a9a53` and the EdgeFn data sources at HEAD. The controller extends `ReloadableController` (which extends `BaseController`), so boot also runs that hierarchy's field initializers.

Marker legend:
- ✅ Wired — calls a method we've implemented end-to-end against an edge function
- ⚠️ No-op success — runs without calling our edge fns; returns harmless empty/identity data
- ❌ UnimplementedError — `_todo(name)` throw; would crash if exercised
- 🔘 Cache no-op — Hive-cache slot in tmail's repo, never reaches our EdgeFn impls
- 🪞 Local-only — hits a Hive/SharedPreferences-backed datasource, no JMAP/edge fn

---

## 0. Constructor field initializers (synchronous Get.find)

Resolved at `Get.find<MailboxDashBoardController>()` time (when `MailboxDashBoardBindings.bindingsController()` runs). Order is the order the `final` fields appear in the class.

Lines 253-266 (controller body):

| # | Line | `Get.find<X>()` | Registered by |
|---|------|-----------------|---------------|
| 1 | 253 | `RemoveEmailDraftsInteractor` | `MailboxDashBoardBindings.bindingsInteractor()` ✅ |
| 2 | 254 | `EmailReceiveManager` | `CoreBindings.dependencies()` ✅ |
| 3 | 255 | `search.SearchController` | `MailboxDashBoardBindings.bindingsController()` ✅ |
| 4 | 256 | `DownloadController` | `DownloadInteractorBindings.dependencies()` (transitive) ✅ |
| 5 | 257 | `AppGridDashboardController` | `MailboxDashBoardBindings.bindingsController()` ✅ |
| 6 | 258 | `SpamReportController` | `MailboxDashBoardBindings.bindingsController()` ✅ |
| 7 | 259 | `NetworkConnectionController` | `NetWorkConnectionBindings` (step 7 of `MailScreenTmailBindings`) ✅ |
| 8 | 260 | `LabelController` | `MailboxDashBoardBindings.bindingsController()` ✅ |
| 9 | 261 | `ComposerManager` | `MailboxDashBoardBindings.bindingsController()` ✅ |
| 10 | 263 | `GetAuthenticationInfoInteractor` | `CredentialBindings.dependencies()` ✅ |
| 11 | 265 | `GetStoredOidcConfigurationInteractor` | `CredentialBindings.dependencies()` ✅ |
| 12 | 266 | `GetTokenOIDCInteractor` | `CredentialBindings.dependencies()` ✅ |

Plus 4 inherited from `ReloadableController` (lines 30-33):

| # | `Get.find<X>()` | Registered by |
|---|-----------------|---------------|
| 13 | `GetSessionInteractor` | `SessionBindings.dependencies()` ✅ |
| 14 | `GetAuthenticatedAccountInteractor` | `CredentialBindings.dependencies()` ✅ |
| 15 | `UpdateAccountCacheInteractor` | `CredentialBindings.dependencies()` ✅ |
| 16 | `GetOidcUserInfoInteractor` | `CredentialBindings.dependencies()` ✅ |

`BaseController` adds further `Get.find()` calls for `dynamicUrlInterceptors`, `authorizationInterceptors`, `imagePaths`, `responsiveUtils`, `appToast`, `toastManager`, `twakeAppManager`, `cachingManager`, `sessionStorageManager`, `localStorageManager`, `keychainSharingManager`, `verifyNameInteractor`. All are wired by `CoreBindings`/`LocalBindings`/`NetworkBindings`.

**No interactor.execute() runs in the constructor body.** All 16 finds resolve cleanly under the binding chain.

---

## 1. onInit() execution order

Source lines 408-425. Web is the only target relevant here (PlatformInfo.isMobile branch is dead).

1. (line 418) `_registerStreamListener()` — wires three stream subscriptions, NO interactor execution:
   - `progressState.listen(...)` — internal `StreamController<Either<Failure,Success>>`. No data source touched.
   - `_refreshActionEventController.stream.debounceTime(...).listen(_handleRefreshActionWhenBackToApp)` — internal stream.
   - `_registerLocalNotificationStreamListener()` — `LocalNotificationManager.instance.localNotificationStream.listen(...)`. No data source touched.
   - `_registerDownloadUIActionListener()` — `ever(downloadController.downloadUIAction, ...)`. Adds Worker; safe.
2. (line 419) `registerLabelReactiveObxListener()` — `ever(labelController.isLabelSettingEnabled, ...)`. Worker added; no execute.
3. (line 420) `BackButtonInterceptor.add(...)` — pure registration, no datasource calls.
4. (line 421) `WidgetsBinding.instance.addPostFrameCallback((_) async { await ApplicationManager().initUserAgent(); })` — runs after first frame; no data source calls (reads platform user agent).
5. (line 424) `super.onInit()` — `BaseController.onInit()` is empty.

**onInit() interactor.execute() count: 0. No EdgeFn data source method invoked.**

---

## 2. onReady() execution order

Source lines 432-447. Web branch (PlatformInfo.isWeb).

1. (line 435) `listSearchFilterScrollController = ScrollController();` — pure Flutter, no data source.
2. (line 436) `twakeAppManager.setExecutingBeforeReconnect(false);` — TwakeAppManager state, no data source.
3. (line 437) `registerReactiveObxVariableListener()` — adds two `ever()` workers on `searchController.isAdvancedSearchViewOpen` / `isSearchInputFocused`. No execute.
4. (line 438) `initialTextFormattingMenuState()`:
   - `getTextFormattingMenuStateInteractor = getBinding<GetTextFormattingMenuStateInteractor>();` — registered by `SettingInteractorBindings` (transitive of `MailboxDashBoardBindings`).
   - `consumeState(getTextFormattingMenuStateInteractor!.execute());` — calls `ManageAccountRepository.getLocalSettings()` which reads from `LocalSettingsService` (SharedPreferences). 🪞 Local-only; no EdgeFn touch.
5. (line 443) `_handleArguments()`:
   - On web with no `Get.arguments` Session, falls into the `else if (PlatformInfo.isWeb)` branch (line 862-864):
     - `dispatchRoute(DashboardRoutes.thread)` — UI state mutation; no data source.
     - `getAuthenticationInfoRedirect()` → `consumeState(getAuthenticationInfoInteractor.execute())`. Hits `AuthenticationOIDCRepository.getAuthenticationInfo()` which reads the platform's auth-info pref. 🪞 Local-only; no EdgeFn touch.
     - On success, `handleSuccessViewState` chains: `getStoredOidcConfiguration()` → `getStoredOidcConfigurationInteractor.execute()` → `AuthenticationOIDCRepository.getStoredOidcConfiguration()`. 🪞 Local-only (reads OIDC config from `OidcDataSource` — Hive/secure storage).
     - On `GetStoredOidcConfigurationSuccess` → `getTokenOIDCAction(config)` → `getTokenOIDCInteractor.execute(...)`. 🪞 Local-only (reads stored token).
     - On any failure in the OIDC chain (very likely — empty Hive in our environment), `handleFailureViewState` matches `isGetTokenOIDCFailure` and calls `backToHomeScreen()` → `pushAndPopAll(AppRoutes.home)`. **This is a routing concern, not an EdgeFn data source crash.** See Routing risk note below.
6. (line 444) `_loadAppGrid()`:
   - Web branch gated on `AppConfig.appGridDashboardAvailable`, which reads dotenv `APP_GRID_AVAILABLE`. Default is `'unsupported'` → `false` → method returns without calling anything. ⚠️ No-op by environment.
   - Even if enabled, `appGridDashboardController.loadAppDashboardConfiguration()` calls `GetAppDashboardConfigurationInteractor.execute()` which fetches a static JSON file via `AppGridRepository.getLinagoraApplicationsFromEnvironment(path)` — does NOT hit our EdgeFn data sources.
7. (line 445) `loadAIScribeConfig()`:
   - `getAIScribeConfigInteractor = getBinding<GetAIScribeConfigInteractor>();` — registered by `SettingInteractorBindings`.
   - `consumeState(getAIScribeConfigInteractor!.execute());` → `ManageAccountRepository.getAiScribeConfigLocalSettings()`. 🪞 Local-only (SharedPreferences).
8. (line 446) `super.onReady()` — `BaseController.onReady()` is essentially empty (line 103-104).

**onReady() interactor.execute() count: 4 (getTextFormattingMenuState, getAuthenticationInfo, getStoredOidcConfiguration if first succeeds, getAIScribeConfig).** All four are 🪞 local-only — no EdgeFn data source method invoked.

`loadStoredEmailSortOrder()` and `getServerSetting()` are NOT called from onReady on web; they're invoked from `_setUpComponentsFromSession()` which only runs when the controller receives a `Session` via `Get.arguments` (web auth-redirect path doesn't go that way at boot).

---

## 3. handleOnForegroundGained() execution order

Source line 2547-2550.

1. (line 2549) `refreshActionWhenBackToApp()` →
   - `_refreshActionEventController.add(RefreshActionViewEvent());`
   - That stream is wired in onInit with a 1500 ms `debounceTime`. After the debounce, `_handleRefreshActionWhenBackToApp` (line 2459) runs:
     - `dispatchEmailUIAction(RefreshChangeEmailAction(newState: ...))` — pushes a UI action. The active `EmailController` / `ThreadController` will read this and may call `getChanges` / `getAllEmail` on our `EdgeFnThreadDataSource`. ✅ Both are wired (no-op `getChanges`, real `getAllEmail` via mail-list).
     - `dispatchMailboxUIAction(RefreshChangeMailboxAction(newState: ...))` — same idea. Active `MailboxController` will call `getChanges` / `getAllMailbox` on our `EdgeFnMailboxDataSource`. ✅ Both wired (no-op `getChanges`, synthetic mailboxes via `getAllMailbox`).

**handleOnForegroundGained() interactor.execute() count: 0 (direct).** Indirect via UI actions: at most `getChanges`/`getAllEmail`/`getAllMailbox` — all already implemented.

---

## ❌ Runtime crash risks at boot

**None.** The boot path of `MailboxDashBoardController` (constructor + onInit + onReady + handleOnForegroundGained) does not invoke any `_todo()` method on our EdgeFn data sources.

The four interactor.execute() calls at boot all hit local Hive/SharedPreferences-backed repositories owned by tmail (auth_oidc, manage_account/local_settings) — they bypass the `EmailDataSource`/`ThreadDataSource`/`MailboxDataSource` slots entirely.

The auth-redirect chain (`getAuthenticationInfoRedirect`) WILL fail on first mount because no OIDC config has been stored, and the failure handler routes to `AppRoutes.home` (`backToHomeScreen`). That's a **routing concern** for `MailScreen` integration (kicks the user out of the dashboard), not a data-source crash. Suggest the parent agent either:
- Inject a synthetic `Session` via `Get.arguments` so `_handleArguments` takes the `Session` branch, or
- Override `_handleArguments`/`getAuthenticationInfoRedirect` for our environment, or
- Pre-seed Hive with a stub OIDC config so the chain succeeds.

---

## 🛑 Routing risk note (out of scope for EdgeFn data sources)

`web_auth_redirect_processor_extension.dart:14` runs `getAuthenticationInfoInteractor.execute()` from onReady. The success branch chains into OIDC config → token retrieval; the failure branch calls `tryGetAuthenticatedAccountToUseApp()` (which goes through the Hive credential cache and likely also fails, then `goToLogin()`). Either way, when no creds exist in Hive the controller will navigate away from `AppRoutes.dashboard`.

To mount the dashboard standalone (without hitting tmail's home route on boot), the parent code needs one of:
- Pre-populate the OIDC/credential Hive boxes with stub data, OR
- Pass `Session` via `Get.arguments` before mounting `MailboxDashBoardView`, OR
- Override the dashboard route to no-op the auth redirect (subclass + override of `_handleArguments`).

Recommended: pass `Session` via `Get.arguments`. That triggers `_handleSessionFromArguments` → `_setUpComponentsFromSession` which DOES call `getServerSetting()` and `loadStoredEmailSortOrder()` — those are still 🪞 local-only / 🔘 cache-no-op, no EdgeFn crash. It also invokes `_getAllIdentities()` → `_getAllIdentitiesInteractor.execute(session, accountId)` which DOES eventually call `IdentityDataSource.getAllIdentities()` (network slot). That's separate from our EdgeFn email/thread/mailbox data sources — would need an `EdgeFnIdentityDataSource` or a stub. Track separately.

---

## Recommendations

### EdgeFn methods upgraded from `_todo` throw → safe behavior

These methods were previously throwing `UnimplementedError` via `_todo(name)`. None fire during the dashboard controller's own boot, but they are reachable from sibling controllers' boot paths (e.g. `MailboxController.onReady` retry chains, `EmailController.getEmailContent` cache-then-network fallback, `SendingQueueController` reconciliation). Leaving them as `_todo` throws would crash those sibling boots even though our dashboard controller itself stays clean.

| Method | Old behavior | New behavior |
|--------|-------------|--------------|
| `EdgeFnEmailDataSource.getStoredOpenedEmail` | `throw UnimplementedError` | `throw StateError(...)` — caller catches and falls through to network slot via `getEmailContent`. |
| `EdgeFnEmailDataSource.getStoredNewEmail` | `throw UnimplementedError` | `throw StateError(...)` — same fall-through pattern. |
| `EdgeFnEmailDataSource.storeSendingEmail` | `throw UnimplementedError` | `return sendingEmail` (identity, no persistence). |
| `EdgeFnEmailDataSource.updateSendingEmail` | `throw UnimplementedError` | `return newSendingEmail` (identity). |
| `EdgeFnEmailDataSource.updateMultipleSendingEmail` | `throw UnimplementedError` | `return newSendingEmails` (identity). |
| `EdgeFnEmailDataSource.getStoredSendingEmail` | `throw UnimplementedError` | `throw StateError(...)` — caller treats as "missing" and reconciles via `getAllSendingEmails` (`[]`). |
| `EdgeFnEmailDataSource.unsubscribeMail` | `throw UnimplementedError` | `async {}` — Gmail List-Unsubscribe shim is future work. |

### EdgeFn methods left as `_todo` throws (only fire from explicit user action, never at boot)

These are harmless to leave as `_todo` until a UI path actually exercises them — they will crash loudly the moment the user clicks a feature we haven't shipped yet, which is what we want during Phase 1:

- `saveEmailAsDrafts`, `updateEmailDrafts`, `saveEmailAsTemplate`, `updateEmailTemplate` — fire on Composer save action.
- `restoreDeletedMessage`, `getRestoredDeletedMessage` — fire on user-initiated "restore deleted" action.
- `generatePreviewEmailEMLContent`, `getPreviewEmailEMLContentShared`, `getPreviewEMLContentInMemory` — fire on EML preview menu action.
- `exportAllAttachments`, `generateEntireMessageAsDocument` — fire on user-initiated export.

### Get.find dependencies

All 16 `Get.find` calls in the constructor + parent `ReloadableController` resolve cleanly via `MailScreenTmailBindings.initialize()`. No unsatisfied finds. Verified by `dashboard_controller_fixups.dart:registerDashboardControllerFixups()` which also runs assertions for the seven dashboard collaborators after the bindings chain.

### Future hardening

If we mount the dashboard for real (i.e. `Session` passed via `Get.arguments`), `_setUpComponentsFromSession` will trigger `_getAllIdentities()` → `_getAllIdentitiesInteractor.execute(session, accountId)` which dispatches to `IdentityDataSource` (a separate datasource we have NOT implemented). Track as a separate edge-fn data source (`EdgeFnIdentityDataSource`) or stub the interactor at the bindings level.
