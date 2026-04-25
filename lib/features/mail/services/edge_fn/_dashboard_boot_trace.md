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

---

# ComposerController boot path trace

Traced against `lib/features/mail/_tmail/tmail_ui_user/features/composer/presentation/composer_controller.dart` (2389 lines) and `composer_bindings.dart` (406 lines) at HEAD.

The composer is reached on web by `MailboxDashBoardController.openComposer()` → `_openComposerOnWeb()` → `composerManager.addComposer(args)`. `ComposerManager.addComposer` (composer_manager.dart:23) generates a `composerId` from `DateTime.now().millisecondsSinceEpoch.toString()`, runs `ComposerBindings(composerId, composerArguments).dependencies()` (which is the full BaseBindings chain — DataSourceImpl, DataSource, RepositoryImpl, Repository, Interactor, Controller — all `lazyPut` with `tag: composerId`), then inserts a `ComposerView` keyed by that `composerId` into `composers` `RxMap`. The ComposerView's `controller` getter (composer_view_web.dart:53) lazy-resolves the controller via `Get.find<ComposerController>(tag: composerId)` on first build, which triggers the GetX lazy chain and runs the controller constructor → `onInit` → `onReady`.

**Important**: every Get.find inside ComposerBindings/ComposerController is **tagged with `composerId`**. That means the composer's repos and data sources are NEW instances distinct from the dashboard's untagged ones. The EdgeFn data sources we registered in `tmail_runtime_bindings.dart:registerEdgeFnDataSources()` are registered without a tag — they back the dashboard, but the composer's tagged `IdentityDataSource` lazyPut creates a separate slot pointed at the JMAP `IdentityDataSourceImpl` (which is what `IdentityInteractorsBindings.bindingsDataSource` registers). See section 3 below.

---

## 0. Constructor field initializers (synchronous Get.find at controller-construction)

When `Get.find<ComposerController>(tag: composerId)` is first called from `ComposerView`, GetX runs the lazy factory in `ComposerBindings.bindingsController()`. That factory:

1. Resolves the 14 positional + 2 named dependencies from the tagged registry (all `lazyPut` registered in `bindingsInteractor` / `bindingsRepository` / `bindingsController` of the same `ComposerBindings`). Each lazyPut transitively triggers `Get.find<...>()` for the upstream graph (RemoteExceptionThrower, EmailAPI, MailboxAPI, FileUploader, Uuid, HtmlAnalyzer, etc.). All upstream finds resolve to instances registered by `MailScreenTmailBindings.initialize()` — verified clean.

2. Calls `ComposerController(...)` with the 14+2 constructor args.

The controller body's field initializers (composer_controller.dart:140-142) run during construction, before `onInit`:

| # | Line | `Get.find<X>()` (untagged) | Registered by |
|---|------|---------------------------|---------------|
| 1 | 140 | `MailboxDashBoardController` | `MailboxDashBoardBindings.bindingsController()` ✅ |
| 2 | 141 | `NetworkConnectionController` | `NetWorkConnectionBindings` ✅ |
| 3 | 142 | `BeforeReconnectManager` | `CoreBindings` ✅ |

Plus the `BaseController` superclass field initializers — same set as the dashboard trace (CachingManager, AuthorizationInterceptors x2, DynamicUrlInterceptors, DeleteCredentialInteractor, LogoutOidcInteractor, DeleteAuthorityOidcInteractor, AppToast, ImagePaths, ResponsiveUtils, Uuid, ToastManager, TwakeAppManager, LanguageCacheManager, MailNotificationManager). All are registered by `CoreBindings` / `LocalBindings` / `NetworkBindings` / `CredentialBindings`.

**No interactor.execute() runs in the constructor body.** All finds resolve cleanly.

The 16 args injected into ComposerController via the lazyPut factory are themselves resolved with `tag: composerId` and back the per-composer interactor chain. Their construction does NOT execute any data source method.

---

## 1. onInit() execution order

Source lines 295-311. Web is the only target.

1. (line 296) `super.onInit()` — `BaseController.onInit()` is empty.
2. (line 298) `responsiveContainerKey = GlobalKey()` — pure Flutter.
3. (line 299) `richTextWebController = getBinding<RichTextWebController>(tag: composerId)` — registered by `ComposerBindings.bindingsController()` ✅.
4. (line 300) `restoreEmailInlineImagesInteractor = getBinding<RestoreEmailInlineImagesInteractor>(tag: composerId)` — registered by `ComposerBindings.bindingsInteractor()` ✅.
5. (line 301) `menuMoreOptionController = CustomPopupMenuController()` — pure widget util.
6. (line 305) `createFocusNodeInput()` — instantiates FocusNodes, no data source.
7. (line 306) `scrollControllerEmailAddress.addListener(...)` — pure listener registration.
8. (line 307) `_listenStreamEvent()` — wires `uploadInlineImageWorker = ever(uploadController.uploadInlineViewState, ...)` (composer_controller.dart:441-449). Worker only; no execute.
9. (line 308) `_beforeReconnectManager.addListener(onBeforeReconnect)` — listener registration only.
10. (line 309) `_injectBinding()` (composer_controller.dart:631-636) — calls `injectAutoCompleteBindings(session, accountId)` (BaseController:326). Wrapped in try/catch. Internally: `ContactAutoCompleteBindings().dependencies()` registers `ContactDataSourceImpl` / `ContactRepositoryImpl` / `GetDeviceContactSuggestionsInteractor` (all `Get.put` with no tag). No execute. Then `requireCapability(...)` — with our synthetic `Session` having an empty capabilities map, this throws `NotSupportFeatureException`, the catch swallows it, and `TMailAutoCompleteBindings().dependencies()` is skipped. ⚠️ Safe by design (try/catch).
11. (line 310) `onKeyboardShortcutInit()` (handle_keyboard_shortcut_actions_extension.dart:19) — assigns `keyboardShortcutFocusNode = FocusNode()`. Pure Flutter.

**onInit() interactor.execute() count: 0. No EdgeFn data source method invoked.**

---

## 2. onReady() execution order

Source lines 314-323.

1. (line 316) `_triggerBrowserEventListener()` (composer_controller.dart:452-489) — registers 5 `html.window.on*` listeners (DragEnter, DragOver, DragLeave, Drop, Blur). Pure browser event registration.
2. (line 318) `setupComposer()` — see section 2a below. **THIS is where the only execute fires.**
3. `super.onReady()` — `BaseController.onReady()` registers two more `html.window.on*` listeners (BeforeUnload, Unload). Browser event registration only.

### 2a. `setupComposer()` (composer_controller.dart:638-672)

For the standard "compose" button click → `composerArguments.value.emailActionType == EmailActionType.compose` (default action type when `controller.openComposer(ComposerArguments())` is called from `mailbox_dashboard_view_web.dart:127`):

1. `setupEmailSubject(arguments)` — Rxn assignment, no execute.
2. `setupEmailRecipients(arguments)` — list copies, no execute.
3. `setupEmailImportantFlag(arguments)` — Rx assignment, no execute.
4. `setupEmailAttachments(arguments)` — invokes `uploadController.initializeUploadAttachments(...)` only if attachments are present (compose=empty), no execute.
5. `setupEmailOtherComponents(arguments)` (setup_email_other_components_extension.dart:8) — for `.compose` falls into `default:` branch → just sets `minInputLengthAutocomplete`. No execute.
6. `setupEmailRequestReadReceiptFlag(arguments)` (setup_email_request_read_receipt_flag_extension.dart:12) — for `.compose` action type, falls into the `else if (currentEmailActionType != editDraft && != editAsNewEmail)` branch. Guarded by `mailboxDashBoardController.isServerSettingsCapabilitySupported`, which (manage_account_dashboard_controller.dart:338) checks `capabilityServerSettings.isSupported(session, accountId)`. **Our synthetic Session has an empty capabilities map → returns false → `getServerSetting()` skipped.** ⚠️ No-op by environment.
7. `setupEmailTemplateId(arguments)` — assigns `currentTemplateEmailId`. No execute.
8. `await setupListIdentities(arguments)` (setup_list_identities_extension.dart:10) — **fires the only execute at composer boot:**
   - Reads `arguments.identities` (set via `MailboxDashBoardController.openComposer` → `arguments.withIdentity(identities: List.from(listIdentities), ...)`).
   - In our environment the dashboard's `_getAllIdentities()` is only called from `_setUpComponentsFromSession` which fires when a `Session` is passed via `Get.arguments`. `MailScreen` does NOT pass a Session → dashboard's `_identities` stays null → `dashboard.listIdentities` returns `[]` → `arguments.identities` is empty.
   - With empty identities, falls into `getAllIdentitiesAsSynchronize()` (line 19) which calls `getAllIdentitiesInteractor.execute(session, accountId).last`.
   - The `GetAllIdentitiesInteractor` is registered with `tag: composerId` and depends on `IdentityRepository(tag)` → `IdentityDataSource(tag)`. **`IdentityInteractorsBindings.bindingsDataSource()` (identity_interactors_bindings.dart:38-47) registers a tagged `IdentityDataSource` slot pointing at `IdentityDataSourceImpl` (the JMAP impl) — NOT our untagged `EdgeFnIdentityDataSource` registered in `registerEdgeFnDataSources()`.**
   - `IdentityDataSourceImpl.getAllIdentities` calls `IdentityAPI.getAllIdentities` over Dio against the synthetic Supabase functions URL with no auth → throws an HTTP-level exception → caught by `_exceptionThrower.throwException` → re-thrown as a `Failure` → interactor emits `Left(GetAllIdentitiesFailure(...))`.
   - Back in `getAllIdentitiesAsSynchronize`, the `if (uiState is GetAllIdentitiesSuccess)` branch is skipped. The `else if (uiState is GetAllIdentitiesFailure)` branch dispatches the failure to `consumeState` for telemetry. No exception bubbles out. ⚠️ Safe by environment — composer boots with empty `listFromIdentities`.
9. `await setupEmailContent(arguments)` (setup_email_content_extension.dart:26) — switch on `currentEmailActionType`. For `.compose` (and any not in the listed cases) falls into the `default:` branch → just sets `emailContentsViewState.value = Right(LoadEmailContentCompleted())`. **No interactor execute.** Other action types (editDraft / editAsNewEmail / reply* / forward / reopenComposerBrowser / etc.) DO fire `getEmailContentInteractor.execute` (which routes through `EmailRepositoryImpl(tag)` → tagged `EmailDataSource` → composer's `EmailDataSourceImpl(tag)` over JMAP, NOT our EdgeFn) — but those only run when the composer is opened from a draft/reply/forward action, not from the new-compose button.
10. The `if (screenDisplayMode.value.isNotContentVisible() && ...isWebDesktop) { await setupSelectedIdentityWithoutApplySignature(); }` block — `setupSelectedIdentityWithoutApplySignature()` (setup_selected_identity_extension.dart:47) only does Rx mutations on `identitySelected`. No execute.
11. `richTextWebController?.updateFormattingOptions(...)` — UI state, no execute.

**onReady() interactor.execute() count: 1 (`getAllIdentitiesInteractor.execute`). The call routes to a TAGGED JMAP `IdentityDataSourceImpl` — not our EdgeFn impl. Fails with HTTP exception, caught and converted to a Failure. No crash.**

---

## 3. EdgeFn DataSource cross-reference

| DataSource method | Fires at composer boot? | EdgeFn impl status |
|-------------------|------------------------|---------------------|
| `EmailDataSource.*` (any) | No | N/A — not invoked at compose-action boot |
| `ThreadDataSource.*` (any) | No | N/A |
| `MailboxDataSource.*` (any) | No | N/A |
| `IdentityDataSource.getAllIdentities` | **Yes**, but routed to JMAP `IdentityDataSourceImpl(tag: composerId)` instead of `EdgeFnIdentityDataSource` | ✅ EdgeFn impl exists (untagged), but the tagged composer slot bypasses it. Failure caught; safe. |

**Total interactor.execute calls at composer boot: 1.**

**❌ count fired at boot: 0** — the one execute that fires hits the JMAP path (not our EdgeFn), and the JMAP impl's HTTP failure is caught by the interactor's `_exceptionThrower` chain.

**No `_todo`/UnimplementedError throw fires at composer boot.** No EdgeFn email/thread/mailbox method is invoked. Composer boots cleanly without crashing.

---

## 4. Recommendations

### EdgeFn DataSource changes for composer boot
**None required.** The composer-boot path doesn't invoke any `_todo` method on our EdgeFn data sources.

### Functional gap (NOT a crash, but UX-degrading)
The composer's `From:` dropdown (`listFromIdentities`) is empty at boot because:
1. `MailScreen` doesn't pass a `Session` via `Get.arguments`, so `MailboxDashBoardController._setUpComponentsFromSession` never runs at dashboard boot, so `dashboard.listIdentities` is always `[]`.
2. `MailboxDashBoardController.openComposer` therefore injects an empty `identities` list into the args.
3. Composer's `setupListIdentities` falls back to `getAllIdentitiesAsSynchronize`, which routes through the **tagged** JMAP `IdentityDataSourceImpl` (registered by `IdentityInteractorsBindings.bindingsDataSource`), not our untagged `EdgeFnIdentityDataSource`. JMAP call fails → empty list.

Fix options (NOT applied here — out of scope for the boot-trace task; flagging only):
- Surgical patch `_tmail/.../identity_interactors_bindings.dart:bindingsDataSource()` to delegate the tagged `IdentityDataSource` slot to the untagged global registration when present (similar pattern to `web_auth_redirect_processor_extension` neutralization in commit `d48713c3c`).
- OR: register the EdgeFn impl with every dynamically-allocated composer tag — requires intercepting `ComposerManager.addComposer` to pre-populate the tagged slot before `ComposerBindings.dependencies()` runs.
- OR: trigger `MailboxDashBoardController._getAllIdentities()` (untagged) at dashboard mount via a fix-up in `dashboard_controller_fixups.dart`. This populates `_identities` so that `openComposer` injects them via `withIdentity`, short-circuiting the JMAP fetch. Cheapest fix; recommended.

### Get.find dependencies
All Get.find calls in `ComposerController`'s constructor body, field initializers, and inherited `BaseController` field initializers resolve cleanly under `MailScreenTmailBindings.initialize()` + the per-composer `ComposerBindings(...).dependencies()` chain. **No unsatisfied finds.**

### Interactor execute calls at composer boot (summary)

| # | Call site | Interactor | Tagged DataSource | EdgeFn Status | Boot risk |
|---|-----------|------------|-------------------|---------------|-----------|
| 1 | `setupListIdentities` → `getAllIdentitiesAsSynchronize` | `GetAllIdentitiesInteractor` | `IdentityDataSourceImpl(JMAP)` (tagged) | Bypassed; EdgeFn untagged not used | Safe — failure caught |

**Composer is expected to boot and render without crashing for the standard "compose" button click.** The user will see an empty `From:` dropdown until one of the three fix options above lands. Other action types (editDraft / reply / forward) will additionally invoke `getEmailContentInteractor.execute` against a tagged JMAP `EmailDataSourceImpl` — that path is NOT exercised at vanilla compose-button boot, but should be tracked separately if/when those flows are wired.
