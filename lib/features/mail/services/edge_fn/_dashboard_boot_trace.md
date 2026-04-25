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

---

# ThreadController boot path trace

Traced against `lib/features/mail/_tmail/tmail_ui_user/features/thread/presentation/thread_controller.dart` (1677 lines) at HEAD. ThreadController extends `BaseController with EmailActionController`. Its lifecycle on web:

1. `MailboxDashBoardBindings.bindingsController()` runs (transitively from `MailScreenTmailBindings.initialize()`) and lazyPuts ThreadController construction.
2. `MailboxDashBoardController.dispatchRoute(DashboardRoutes.thread)` triggers a re-render that mounts the inbox view → which Get.finds the ThreadController → triggers field initializers + `onInit` + `onReady`.
3. User taps a thread tile → ThreadController routes through `EmailActionController.previewEmail()` → `MailboxDashBoardController.openEmailDetailedView` → SingleEmailController constructed.

---

## 0. Constructor field initializers (synchronous Get.find)

| # | Line | `Get.find<X>()` | Registered by |
|---|------|-----------------|---------------|
| 1 | 91 | `NetworkConnectionController` | `NetWorkConnectionBindings` ✅ |

Plus 7 positional interactor args injected via `ThreadBindings.bindingsController()`:

| # | Interactor | Registered by |
|---|------------|---------------|
| 2 | `GetEmailsInMailboxInteractor` | `ThreadBindings.bindingsInteractor()` ✅ |
| 3 | `RefreshChangesEmailsInMailboxInteractor` | same ✅ |
| 4 | `LoadMoreEmailsInMailboxInteractor` | same ✅ |
| 5 | `SearchEmailInteractor` | same ✅ |
| 6 | `SearchMoreEmailInteractor` | same ✅ |
| 7 | `GetEmailByIdInteractor` | same ✅ |
| 8 | `CleanAndGetEmailsInMailboxInteractor` | same ✅ |

Plus `BaseController` field initializers — same set as the dashboard trace (cachingManager, interceptors, imagePaths, etc.). All wired by `CoreBindings`/`LocalBindings`/`NetworkBindings`.

The `EmailActionController` mixin reads `mailboxDashBoardController` and `_moveToMailboxInteractor` lazily via getter; no extra Get.find at construction.

**No interactor.execute() runs in the constructor body.**

---

## 1. onInit() execution order

Source lines 149-158.

1. (line 151) `_registerObxStreamListener()` (lines 279-439) — registers FIVE `ever()` workers + `appProviderContainer.listen` for local settings:
   - `ever(mailboxDashBoardController.selectedMailbox, ...)` — fires on selectedMailbox change. The handler calls `getAllEmailAction(...)` (line 287) which IS an `interactor.execute` BUT only fires if/when selectedMailbox is mutated to a non-null Mailbox. At cold boot, selectedMailbox starts null → no execute fires from this worker initially. Once the dashboard's mailbox loader populates a default selectedMailbox (via `mailboxDashBoardController.setSelectedMailbox`), this worker WILL fire and call `_getEmailsInMailboxInteractor.execute`. That hits our `EdgeFnThreadDataSource.getAllEmail` ✅.
   - `ever(searchController.searchState, ...)` — internal UI state, no execute.
   - `ever(mailboxDashBoardController.dashBoardAction, ...)` — dashboard action dispatch, no execute at boot. Click-tile path goes through `OpenEmailDetailedFromSuggestionQuickSearchAction` and `HandleEmailActionTypeAction` here.
   - `ever(mailboxDashBoardController.emailUIAction, ...)` — handles `RefreshChangeEmailAction` / `RefreshAllEmailAction`. Both reach `getAllEmailAction()` or `_refreshEmailChanges()` — websocket-driven, not boot.
   - `ever(mailboxDashBoardController.viewState, ...)` — handles UI side-effects from MarkAsMailboxRead / MoveToMailbox / DeleteMultipleEmailsPermanently UI states. No execute at boot.
   - `ever(mailboxDashBoardController.emailsInCurrentMailbox, ...)` — pure local state tracking. No execute.
   - `_registerLocalSettingsListener()` (line 438) — `appProviderContainer.listen(localSettingsNotifierProvider, ...)`. Riverpod listener; no execute.
2. (line 152) `if (PlatformInfo.isWeb)` — runs:
   - (line 153) `_registerBrowserResizeListener()` — `html.window.onResize.listen(...)` for auto-load-more on resize. No data source touch.
   - (line 154) `onKeyboardShortcutInit()` — `keyboardFocusNode = FocusNode()` + `shortcutActionEventController = StreamController<MailListShortcutActionViewEvent>.broadcast()` + a stream listener for keyboard shortcuts. Stream subscription only; no execute.
3. (line 156) `_initWebSocketQueueHandler()` — `WebSocketQueueHandler(processMessageCallback: _handleWebSocketMessage, onErrorCallback: onError)`. Pure constructor; no execute. The handler doesn't subscribe to any websocket here — it's a passive queue used by `_refreshEmailChanges` to enqueue messages later.
4. (line 157) `super.onInit()` — `BaseController.onInit()` is empty.

**onInit() interactor.execute() count: 0.** No EdgeFn data source method invoked. Workers are registered but won't fire until upstream Rx values mutate.

---

## 2. onReady() execution order

Source lines 160-164.

1. (line 162) `consumeState(Stream.value(Right(GetAllEmailLoading())))` — emits a synthetic loading state via the controller's `consumeState` chain. Internal Rx update; **no interactor.execute, no data source method.**
2. (line 163) `super.onReady()` — `BaseController.onReady()` is essentially empty.

**onReady() interactor.execute() count: 0.** No EdgeFn data source method invoked.

---

## 3. First-data-fetch (post-boot, when selectedMailbox is populated)

When `MailboxDashBoardController` populates `selectedMailbox.value` (e.g. when its mailbox loader picks an inbox via `setSelectedMailbox`), the worker registered in step 1 above fires:

```
ever(mailboxDashBoardController.selectedMailbox, (mailbox) {
  _currentMemoryMailboxId = mailbox.id;
  consumeState(Stream.value(Right(GetAllEmailLoading())));
  resetToOriginalValue();
  getAllEmailAction(getLatestChanges: ..., forceEmailQuery: ...);
});
```

`getAllEmailAction` (line 698) calls `_getEmailsInMailboxInteractor.execute(session, accountId, ...)`. That dispatches to `ThreadRepositoryImpl.getAllEmail`:
- First reads `mapDataSource[local].getAllEmailCache(...)` — `LocalThreadDataSourceImpl` backed by Hive `EmailCacheManager`. Returns `[]` when empty / Hive not init.
- Then calls `mapDataSource[network].getAllEmail(...)` — that's our `EdgeFnThreadDataSource.getAllEmail` ✅.
- Eventually writes to `mapDataSource[local].update(...)` — Hive write; tmail's `LocalThreadDataSourceImpl.update` swallows exceptions via `CacheExceptionThrower`.

**Total interactor.execute calls in first-data-fetch: 1 (`getAllEmailAction` → `_getEmailsInMailboxInteractor.execute`).** Routes through our EdgeFn ✅.

---

## 4. Click-thread (preview email) flow

User taps a thread tile in `ThreadView` → emits `EmailActionType.preview` via `controller.handleEmailActionType` (thread_view.dart:646, 735) → `ThreadController.handleEmailActionType` (line 1384) switches on action type:

For a normal preview (mailbox is NOT drafts/templates):
1. `previewEmail(presentationEmail)` (mixin, email_action_controller.dart:69) →
2. `mailboxDashBoardController.openEmailDetailedView(presentationEmail)` (dashboard, line 1024) →
3. `setSelectedEmail(presentationEmail)` — Rx update.
4. `dispatchRoute(DashboardRoutes.threadDetailed)` — Rx update; `MailboxDashBoardView` listens and switches its body slot to `ThreadDetailController` / `EmailView`.
5. On web, `RouteUtils.replaceBrowserHistory(...)` updates the URL bar — pure history.replaceState, no data source.

The actual data fetch happens inside `SingleEmailController.onInit` (next section). **`ThreadController` itself does NOT invoke any data source method on click** — it only mutates Rx state.

If mailbox is drafts → `editDraftEmail` opens composer with `EmailActionType.editDraft` → composer's `setupEmailContent` invokes `getEmailContentInteractor.execute` against the COMPOSER's tagged JMAP `EmailDataSourceImpl`. Same caveat as composer trace; not our EdgeFn.

---

## 5. Other user actions on thread tiles

- `markAsEmailRead` / `markAsStarEmail` → routes to `mailboxDashBoardController.markAsEmailRead` / `markAsStarEmail` → `_markAsEmailReadInteractor.execute` → `EmailRepositoryImpl.markAsRead` → `emailDataSource[network].markAsRead` (our EdgeFn — returns identity-success no-op ⚠️). Then writes to `emailDataSource[hiveCache].markAsRead` (tmail's Hive, not us).
- `moveToTrash` / `moveToSpam` / `archiveMessage` / `moveToMailbox` → `_moveToMailboxInteractor.execute` → `EmailRepositoryImpl` → `emailDataSource[network].moveToMailbox` (our EdgeFn — returns empty success ⚠️).
- `deleteEmailPermanently` → `_deleteEmailPermanentlyInteractor.execute` → `emailDataSource[network].deleteEmailPermanently` (our EdgeFn — returns false ⚠️). UI proceeds optimistically.
- `addLabelToEmail` / `removeLabelFromEmail` / `addLabelToThread` / etc. → `emailDataSource[network]` (our EdgeFn — async no-op or identity success ⚠️).
- `unSpam` → routes to `mailboxDashBoardController.moveToMailbox` (already covered).

All paths reach methods we've implemented as safe no-ops on `EdgeFnEmailDataSource`. **No `_todo`/UnimplementedError fires from any tile-click action.**

---

## 6. EdgeFn DataSource cross-reference (ThreadController scope)

| DataSource method | When fires (boot/click/etc.) | EdgeFn impl status |
|-------------------|------------------------------|---------------------|
| `ThreadDataSource.getAllEmail` | First-data-fetch when selectedMailbox populated | ✅ Wired (mail-list edge fn) |
| `ThreadDataSource.getAllEmailCache` | Same path (local slot read first) — uses `LocalThreadDataSourceImpl`, NOT our EdgeFn | N/A — bypassed |
| `ThreadDataSource.getChanges` | `_refreshChangesEmailsInMailboxInteractor` (websocket-driven refresh) | ⚠️ No-op (returns sinceState) |
| `ThreadDataSource.update` | `LocalThreadDataSourceImpl` only — never reaches our EdgeFn slot | N/A — bypassed |
| `ThreadDataSource.searchEmails` | User-triggered search | ⚠️ No-op (returns empty) |
| `ThreadDataSource.getEmailById` | Location-bar deep link (URL with emailId) | ✅ Wired (mail-message-get edge fn) |
| `ThreadDataSource.emptyMailboxFolder` | "Empty trash" user action | ⚠️ No-op (returns []) |
| `ThreadDataSource.clearEmailCacheAndStateCache` | Hive clear; never reaches our EdgeFn | N/A — bypassed |
| `EmailDataSource.markAsRead` | tile click "mark read" | ⚠️ Identity success no-op |
| `EmailDataSource.markAsStar` | tile click "star" | ⚠️ Identity success no-op |
| `EmailDataSource.moveToMailbox` | tile click "move/trash/spam/archive" | ⚠️ Empty success no-op |
| `EmailDataSource.deleteEmailPermanently` | "delete forever" | ⚠️ Returns false |
| `EmailDataSource.addLabelTo*` / `removeLabelFrom*` | label menu | ⚠️ No-op identity success |

**Total interactor.execute calls at ThreadController boot (onInit + onReady): 0.**
**Total interactor.execute calls in first-data-fetch: 1 (`getAllEmailAction`).**

**❌ `_todo`/UnimplementedError fired count at boot: 0.**

---

## 7. Routing risk patches applied

ThreadController has TWO `popAndPush(AppRoutes.unknownRoutePage)` call sites — both in deep-link / location-bar paths:

| Line | Site | Trigger |
|------|------|---------|
| 228 | `handleFailureViewState` GetEmailByIdFailure branch | location-bar URL with bad emailId |
| 1513 | `_getEmailByIdFromLocationBar` session/accountId NULL | location-bar URL while pre-session-init |

Both target `AppRoutes.unknownRoutePage`, a tmail route we never registered with our app's GetX router → would yank the user out of MailScreen entirely (same failure mode as the OIDC path patched in commit `d48713c3c`).

**Patches applied** (same surgical pattern as `web_auth_redirect_processor_extension.dart`):
- Both `popAndPush(AppRoutes.unknownRoutePage)` lines commented out with the explanatory note pointing at `d48713c3c`.

The user simply stays on the current route on these failure conditions; the failure toast (which also fires from the inherited `super.handleFailureViewState`) gives them feedback.

---

## 8. Recommendations

### EdgeFn DataSource changes for ThreadController boot
**None required.** All methods invoked at boot or from normal user clicks are already implemented as either real bridges (`getAllEmail`, `getEmailById`, `getEmailContent`) or safe no-ops.

### ThreadController is expected to function for read + light interactions
- ✅ Inbox list will populate from `mail-list` edge fn once selectedMailbox is set.
- ✅ Click-thread routes correctly to `SingleEmailController`.
- ⚠️ Mark-read / star / move / archive / delete actions will NOT propagate to Gmail (they all return optimistic-success no-ops). UI will display the change locally but a refresh will revert it.
- ⚠️ Search will return empty.
- ⚠️ Empty trash / mark-mailbox-read will no-op silently.

The ⚠️ items are expected Phase 1 gaps; trace for each reachable method is documented above.

---

# SingleEmailController boot path trace

Traced against `lib/features/mail/_tmail/tmail_ui_user/features/email/presentation/controller/single_email_controller.dart` (1639 lines) at HEAD. SingleEmailController extends `BaseController with AppLoaderMixin`.

The controller is constructed via `EmailBindings(currentEmailId: emailId).dependencies()` when the user clicks a thread → `MailboxDashBoardController.openEmailDetailedView` → route dispatches `DashboardRoutes.threadDetailed` → tmail's `ThreadDetailView` instantiates `EmailBindings` for the selected emailId → `Get.put(SingleEmailController(...), tag: emailId)`.

---

## 0. Constructor field initializers (synchronous Get.find)

Line 116 (controller body):

| # | Line | `Get.find<X>()` (untagged) | Registered by |
|---|------|---------------------------|---------------|
| 1 | 116 | `MailboxDashBoardController` | `MailboxDashBoardBindings.bindingsController()` ✅ |

Plus 6 positional interactor args injected by `EmailBindings._bindingsController()`:

| # | Interactor | Registered by |
|---|------------|---------------|
| 2 | `GetEmailContentInteractor` | `EmailInteractorBindings.bindingsInteractor()` ✅ |
| 3 | `MarkAsEmailReadInteractor` | same ✅ |
| 4 | `MarkAsStarEmailInteractor` | same ✅ |
| 5 | `GetAllIdentitiesInteractor` (untagged) | `IdentityInteractorsBindings()` (called from EmailInteractorBindings, no composerId tag) ✅ |
| 6 | `StoreOpenedEmailInteractor` | `EmailInteractorBindings.bindingsInteractor()` ✅ |
| 7 | `PrintEmailInteractor` | same ✅ |

Plus `BaseController` field initializers — same set as dashboard.

**No interactor.execute() runs in the constructor body.** All finds resolve cleanly.

`GetAllIdentitiesInteractor` here is the UNTAGGED instance (registered via `IdentityInteractorsBindings(composerId: null).dependencies()` invoked transitively from `EmailInteractorBindings.bindingsInteractor()`). The untagged `IdentityRepository` resolves to the untagged `IdentityRepositoryImpl` which uses the untagged `IdentityDataSource` slot — and that slot is filled by our `EdgeFnIdentityDataSource` (registered with `permanent: true` in `registerEdgeFnDataSources()`). ✅ Composer-flow caveat from the composer trace does NOT apply here — SingleEmailController's identity fetch hits our EdgeFn impl directly.

---

## 1. onInit() execution order

Source lines 197-213.

1. (line 199) `if (PlatformInfo.isWeb) attachmentListKey = GlobalKey();` — pure Flutter.
2. (line 202) `_threadDetailController = getBinding<ThreadDetailController>();` — registered by `ThreadDetailBindings` (transitively from `MailboxDashBoardBindings`). Either resolves or returns null; no execute.
3. (line 203) `_injectCalendarEventBindings(session, accountId)` (line 437) — gated on `CapabilityIdentifier.jamesCalendarEvent.isSupported(session, accountId)`. Our synthetic Session has empty capabilities → returns false → Calendar bindings NOT registered. ⚠️ Safe by environment.
4. (line 204) `_registerObxStreamListener()` (line 285):
   - (line 286) `if (accountId != null) _injectAndGetInteractorBindings(session, accountId!)`:
     - `injectRuleFilterBindings(session, accountId)` — capability-gated; our session has no rule filter capability → no-op.
     - `injectMdnBindings(session, accountId)` — capability-gated; no-op.
     - `_injectCalendarEventBindings(session, accountId)` — same as above; no-op.
     - Then resolves the optional interactor refs (`_createNewEmailRuleFilterInteractor`, `_sendReceiptToSenderInteractor`, `_parseCalendarEventInteractor`, etc.) via `getBinding<...>()`. Each returns null if not registered. No execute, no crash on missing.
   - (line 289) `WidgetsBinding.instance.addPostFrameCallback((_) => _handleOpenEmailDetailedView())` — schedules `_handleOpenEmailDetailedView` for the next frame. **THIS is where the email-content fetch fires.** Detailed in section 2 below.
   - (line 293) Three `obxListeners.add(ever(...))` registrations:
     - `ever(mailboxDashBoardController.emailUIAction, ...)` — handles HideEmailContentViewAction / ShowEmailContentViewAction / various thread-detail actions. UI-state-driven; no boot execute.
     - `ever(mailboxDashBoardController.viewState, ...)` — listens for `UnsubscribeEmailSuccess`. Reactive; no boot execute.
     - `ever(downloadController.downloadUIAction, ...)` — handles `UpdateAttachmentsViewStateAction`. No boot execute.
5. (line 205) `emailActionReactor = EmailActionReactor(_markAsEmailReadInteractor, ...)` — pure constructor.
6. (line 212) `super.onInit()` — empty.

**onInit() direct interactor.execute() count: 0.** But the post-frame callback scheduled at line 289 will fire `_handleOpenEmailDetailedView` on the very next frame, before any onReady runs.

There is no separate `onReady()` override on SingleEmailController — `BaseController.onReady()` (essentially empty) is the default.

---

## 2. First-frame `_handleOpenEmailDetailedView()`

Source line 394. Runs from the post-frame callback in onInit. This is where the user's "click thread → see email" data flow lives.

1. (line 395) Check `currentEmail` (resolves from `_threadDetailController?.emailIdsPresentation[_currentEmailId]` or `mailboxDashBoardController.selectedEmail.value` on mobile). If null, returns silently — no execute.
2. (line 399) `emailLoadedViewState.value = Right(GetEmailContentLoading())` — Rx update.
3. (line 401) `_resetToOriginalValue()` — resets a bunch of Rx fields.
4. (line 404) `_createSingleEmailView(currentEmail!.id!)` (line 418) → `_getEmailContentAction(emailId)` (line 487):
   - First checks `_threadDetailController?.cachedEmailLoaded[_currentEmailId!]`. On first open this is null — falls through.
   - Calls `consumeState(_getEmailContentInteractor.execute(session!, accountId!, emailId, baseDownloadUrl, transformConfiguration))`.
   - `GetEmailContentInteractor.execute` (line 22):
     - **WEB BRANCH (PlatformInfo.isWeb is true here):** skips `_getStoredOpenedEmail` entirely; goes directly to `_getContentEmailFromServer` (line 42).
     - `_getContentEmailFromServer` calls `emailRepository.getEmailContent(...)` → `EmailRepositoryImpl.getEmailContent` → `emailDataSource[network].getEmailContent(...)` → our **`EdgeFnEmailDataSource.getEmailContent` ✅** (calls `mail-message-get` edge fn).
     - On success: `transformEmailContent` (HTML pipeline), then yields `GetEmailContentSuccess`.
   - On the WEB branch, `_getStoredOpenedEmail` and `_getStoredNewEmail` are NEVER hit. Our EdgeFn's `getStoredOpenedEmail`/`getStoredNewEmail` fallbacks to a `StateError` are dead code on this path.

   **`_getContentEmailFromServer`** also calls `emailRepository.transformEmailContent(...)` — that pipeline lives in `HtmlDataSourceImpl` (uses `HtmlAnalyzer`). Pure local transform; no data source call.

5. (line 408) `if (!currentEmail!.hasRead) markAsEmailRead(currentEmail!, ReadActions.markAsRead, MarkReadAction.tap);` (line 686) →
   - `_markAsEmailReadInteractor.execute(session!, accountId!, emailId, readAction, markReadAction, mailboxId)`.
   - `MarkAsEmailReadInteractor` → `EmailRepositoryImpl.markAsRead` → `emailDataSource[network].markAsRead` → our **`EdgeFnEmailDataSource.markAsRead` ⚠️** (returns identity-success no-op).
   - Then `EmailRepositoryImpl` writes to `emailDataSource[hiveCache].markAsRead` (tmail's Hive impl, not us). May fail if Hive isn't init for that cache slot — `EmailRepositoryImpl` wraps in try/catch and just logs.

6. (line 411) `if (mailboxDashBoardController.listIdentities.isEmpty) _getAllIdentities()` (line 445):
   - `consumeState(_getAllIdentitiesInteractor.execute(session!, accountId!))` — UNTAGGED interactor.
   - `GetAllIdentitiesInteractor` → `IdentityRepositoryImpl.getAllIdentities` → `identityDataSource.getAllIdentities` → our **`EdgeFnIdentityDataSource.getAllIdentities` ✅** (reads `mail_aliases` Supabase row).
   - On success: yields `GetAllIdentitiesSuccess(identities: [...])`.
   - Reaction: `_getAllIdentitiesSuccess` → `_initializeSelectedIdentity` → sets `_identitySelected`. No further data source calls.

   If `mailboxDashBoardController.listIdentities` is already populated (would only be true if dashboard pre-fetched them), skips the fetch and just initializes from the dashboard's cache. Currently the dashboard never pre-fetches so this branch reliably calls our EdgeFn.

**Total interactor.execute calls in `_handleOpenEmailDetailedView`: up to 3:**
1. `_getEmailContentInteractor.execute` (always) — ✅ EdgeFn
2. `_markAsEmailReadInteractor.execute` (only if email is unread) — ⚠️ EdgeFn no-op
3. `_getAllIdentitiesInteractor.execute` (only if listIdentities empty) — ✅ EdgeFn

---

## 3. EdgeFn DataSource cross-reference (SingleEmailController scope)

| DataSource method | When fires | EdgeFn impl status |
|-------------------|------------|---------------------|
| `EmailDataSource.getEmailContent` | First-frame post-onInit | ✅ Wired (mail-message-get edge fn) |
| `EmailDataSource.markAsRead` | First-frame, if email is unread | ⚠️ Identity success no-op |
| `EmailDataSource.getStoredEmail` | Web: NOT called from `_getContentEmailFromServer`. Could be called from `_getStoredOpenedEmail` but that branch is mobile-only. Also reachable via `EmailRepositoryImpl.getStoredEmail` from a future cache-first flow. | ✅ Falls through to `getEmailContent` (network slot) per line 297-302 of EdgeFnEmailDataSource. |
| `EmailDataSource.getStoredOpenedEmail` | Hive cache slot (NOT us). Web's `GetEmailContentInteractor` skips it. | ✅ Our impl already throws `StateError` so `StoreOpenedEmailInteractor._isOpenedEmailAlreadyStored` correctly catches and treats as "not stored". (Mobile-only path via `_storeOpenedEmailAction`.) |
| `EmailDataSource.markAsStar` | User clicks star icon | ⚠️ Identity success no-op |
| `EmailDataSource.moveToMailbox` | User clicks move | ⚠️ Empty success no-op |
| `EmailDataSource.unsubscribeMail` | User clicks unsubscribe | ⚠️ Async no-op |
| `EmailDataSource.parseEmailByBlobIds` | Calendar event parsing (only if email has a calendar attachment) | ⚠️ Returns empty list |
| `IdentityDataSource.getAllIdentities` | First-frame, if dashboard's listIdentities is empty (currently always) | ✅ Wired (`mail_aliases` Supabase) |

**Total interactor.execute calls at SingleEmailController boot (onInit + first frame): up to 3.**

**❌ `_todo`/UnimplementedError fired count at boot: 0.**

The `_todo` throws still in `EdgeFnEmailDataSource` (`saveEmailAsDrafts`, `updateEmailDrafts`, `saveEmailAsTemplate`, `updateEmailTemplate`, `restoreDeletedMessage`, `getRestoredDeletedMessage`, `generatePreviewEmailEMLContent`, `getPreviewEmailEMLContentShared`, `getPreviewEMLContentInMemory`, `exportAllAttachments`, `generateEntireMessageAsDocument`) are all gated behind explicit user-triggered actions (Composer save, EML preview, Export all attachments, etc.) that the SingleEmailController boot path does NOT exercise. They will throw loudly the moment the user clicks one of those affordances — which is what we want during Phase 1 to surface the next gap.

---

## 4. Routing risk patches applied

SingleEmailController itself does NOT call `popAndPush` / `pushAndPopAll` / `Get.offAllNamed`. The route-yank risk surfaces only in `closeEmailView` (line 1098) which uses `dispatchRoute(DashboardRoutes.thread)` — internal Rx-based routing, no GetX navigator yank. **No SingleEmailController patches needed.**

---

## 5. Recommendations

### EdgeFn DataSource changes for SingleEmailController boot
**None required.** All boot-path methods invoked are already implemented as either real bridges or safe no-ops.

### SingleEmailController is expected to function for read + identity-pinned send
- ✅ Email body + attachments load from `mail-message-get` edge fn.
- ✅ "From:" identity resolves from `mail_aliases` Supabase row.
- ⚠️ `markAsRead` is optimistic-only (won't propagate to Gmail).
- ⚠️ Star / move / unsubscribe are optimistic-only no-ops.
- ❌ Composer save (drafts/templates) and Print-with-export will throw `_todo` UnimplementedError when user clicks them — intentional Phase 1 surface for the next adapter wiring.

The full thread-list → click → email-view → reply path is expected to work end-to-end against the live edge functions. Reply send goes through `EdgeFnEmailDataSource.sendEmail` → `mail-send` edge fn ✅.
