# MOYD CRM UX Audit — 2026-04-22

Scope: `/Users/moyd/my-bluebubbles-web/lib/screens/crm/` plus `lib/features/committees/theme/`.

Read-only catalog. No fixes applied. Line numbers are against current file state.

---

## Crash-prone patterns

These are the "ThemeData.dark() + ColorScheme.copyWith" combos that match the one we just removed from `donor_command_center.dart`. Whether they actually crash depends on which widgets are children; they are the same shape as the known crashing pattern and should be audited individually.

- `lib/screens/crm/candidate_detail_screen.dart:3991-3999` — `showDatePicker` builder wraps child in `Theme(data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(primary: sunriseGold, surface: unityBlue)))`. Risk: the date-picker subtree includes ExpansionTile-like widgets (month picker animations) that pick up these values.
- `lib/screens/crm/finances_page.dart:1940-1949` — identical `showDateRangePicker` wrapper with `ThemeData.dark()` + `ColorScheme.dark(primary: momentumBlue, onPrimary: white, surface: 0xFF1E3A5F)`. Same risk; date-range pickers historically more finicky than single-date ones.
- `lib/screens/crm/dialogs/donor_export_dialog.dart:150-156` — uses `Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: _unityBlue))` inside `showDatePicker` builder. Lighter footprint (no `ThemeData.dark()`) but still the `colorScheme.copyWith` call-site flagged in the donor_command_center comment. Lower risk but worth verifying before the next donor-export usage.

Other crash-adjacent observations:

- `lib/screens/crm/donor_profile_screen.dart:1791` — bare `ExpansionTile` with no Theme wrapper, rendered on a navy `BrandedBackground`. Will render white/grey default Material text, not navy-theme text. Not a crash — but it's the same class of ExpansionTile-on-dark issue that was bugging Andrew.
- `lib/screens/crm/members_list_screen.dart:1793-1800` — `Card` wrapping `Theme(dividerColor: transparent)` → `ExpansionTile`. Renders inside a Card (light background) so is fine visually, but be careful if the parent ever changes to the navy theme.
- `lib/screens/crm/meeting_detail_screen.dart:656-676` and `852-865` — two `Theme(dividerColor: transparent)` + `ExpansionTile` sites inside `Card()`s. Safe today.
- `lib/screens/crm/survey_results_widget.dart:1044-1046` — `Theme(dividerColor: transparent)` + `ExpansionTile`. Inside a white Card container; safe today.
- `lib/screens/crm/voter_file/voter_file_card.dart:93-118` — debug-only ExpansionTile with manual iconColor overrides. OK.
- `lib/screens/crm/donor_profile_screen.dart:89-104` (`_load()` flow in MECDonorScreen analog) — no null-check on `profile['mo_voter_file_id']` or `profile['id']` before `as String?` casts. Supabase can return `dynamic`; casts work for String/null but would throw on an unexpected `int`. Low risk since schema is stable.

---

## Visual inconsistencies

### Solid `Colors.white` buttons / fills rendered against navy

These are the "breaks the dark theme" patterns. `Colors.white.withOpacity(0.xx)` is the Slack-style translucency we want — those are fine. The entries below are fully opaque white.

- `lib/screens/crm/member_portal/member_portal_management_screen.dart:950` — `ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _unityBlue)`. Save button stamped white-on-navy. Fix: translucent pill `Colors.white.withOpacity(0.15)` + white text, matching the command-center's chip style.
- `lib/screens/crm/member_portal/member_portal_management_screen.dart:2810` — `CircleAvatar(backgroundColor: Colors.white)` behind a `NetworkImage`. White halo around member photos on the navy page. Fix: `Colors.white.withOpacity(0.1)` or `BrandColors.unityBlue`.
- `lib/screens/crm/member_detail_screen.dart:3288` — wallet "Send push" ElevatedButton with `backgroundColor: Colors.white, foregroundColor: _walletAccentColor`. Same issue — harsh white pill on navy tab. Fix: use `FilledButton` with the accent color as the fill, white foreground.
- `lib/screens/crm/surveys_screen.dart:702` — retry button `backgroundColor: Colors.white, foregroundColor: BrandColors.unityBlue`. Fix: same as above.
- `lib/screens/crm/survey_results_widget.dart:913` — `TextField` `fillColor: Colors.white`. This widget is embedded in the surveys detail view where the parent is sometimes a white Card, sometimes a gradient backdrop — field toggles between readable and invisible depending on view mode.
- `lib/screens/crm/survey_results_widget.dart:1021` — FilterChip `backgroundColor: Colors.white` inside the results panel. Looks fine on white cards; will look detached if ever moved to the navy area.
- `lib/screens/crm/email_campaigns/widgets/campaign_html_preview_stub.dart:16` — body `backgroundColor: Colors.white` for the HTML preview. Acceptable because it's emulating an email client, but call it out: on the navy tabs it reads as a bright rectangle with no framing.

### `Colors.white.withOpacity(0.05–0.08)` text field fills lacking border visibility

These are aesthetically OK but barely visible; worth noting as a consistency concern (Andrew tends to want these bumped to 0.12 like the donor sidebar fix).

- `lib/screens/crm/candidate_detail_screen.dart:705, 4061` — 0.08 fills for TextField.
- `lib/screens/crm/candidate_new_dialog.dart:216, 255` — 0.05 fills.
- `lib/screens/crm/candidate_edit_dialog.dart:439, 477` — 0.05 fills.
- `lib/screens/crm/candidates_page.dart:2884` — 0.08 fill.
- `lib/screens/crm/mec_committee_picker.dart:187` — 0.05 fill.

### Legacy `DonorsListScreen` visual duplication

- `lib/screens/crm/donors_list_screen.dart` — full navy-tabbed CRM donors screen that was superseded by `DonorCommandCenter`. It is still reachable via `lib/features/committees/screens/tabs/committee_donors_tab.dart:13` (`DonorsListScreen(embed: true)`). Two near-identical fundraising/research/call-time/committees tab containers is why styling drifts. Consolidate or delete one.

### `DonorDetailScreen` vs `DonorProfileScreen` — two different donor detail pages

- `lib/screens/crm/donor_detail_screen.dart` — light-theme Material Card donor detail keyed by `donor.id` (the legacy `donors` table). Routed from `fundraising_tab.dart:444, 753`.
- `lib/screens/crm/donor_profile_screen.dart` — navy-gradient `DonorProfileScreen` keyed by `profileId` (the new `donor_profiles` table). Routed from the DonorCommandCenter.
- Two detail pages live side-by-side with inconsistent visual languages. Users tapping a donor in FundraisingTab (inside DonorCommandCenter) get the legacy light-theme page; tapping in the main results grid gets the navy page. Same entity, two UIs.

### Plain `Card` vs `BrandedCard` drift

- Total `Card(...)` call sites: **387** across 45 files.
- `BrandedCard(...)` call sites: **31** across 6 files.
- Heaviest plain-Card users that probably should be BrandedCard: `candidate_detail_screen.dart` (27), `candidates_page.dart` (28), `event_detail_screen.dart` (23), `candidate_analytics_screen.dart` (23), `donor_profile_screen.dart` (24), `finances_page.dart` (23), `member_portal_management_screen.dart` (26), `candidate_detail_screen.dart` (27). Some of these are intentional (white inner cards on a gradient) but the ratio is lopsided.

### Miscellaneous

- `lib/screens/crm/candidate_detail_screen.dart:5320`, `lib/screens/crm/meeting_detail_screen.dart:502`, `lib/screens/crm/chapter_detail_screen.dart:940`, `lib/screens/crm/candidates_page.dart:1501`, `lib/screens/crm/members_list_screen.dart:2137-2164` — avatar/chip backgrounds at `Colors.white.withOpacity(0.18-0.25)` are fine; flagging for inventory only.

---

## Broken default states

- `lib/screens/crm/donors_list_screen.dart` — legacy 4-tab container never preloads stats. `FundraisingTab`, `CommitteesTab`, `CallTimeTab` each have their own initState loaders; `DonorsListScreen` itself renders an empty gradient tab strip on mount. Acceptable; flagging for awareness since the same shell exists in `DonorCommandCenter` which DOES preload stats.
- `lib/screens/crm/donor_command_center.dart:91-96, 106-112` — good: loads stats + search + tags on mount; no blank-on-open.
- `lib/screens/crm/tabs/mec_research_tab.dart:76-85` — good: `WidgetsBinding.instance.addPostFrameCallback` kicks off "top 50 Democrat donors" default view. Model to copy elsewhere.
- `lib/screens/crm/mec_committee_picker.dart:40-44` — good: runs an empty search on mount, so the dialog shows recent committees instead of blank.
- `lib/screens/crm/bulk_email_screen.dart` (entire screen) — opens with no recipients selected and no template chosen. Common usage is "send to all members"; this default could be preselected (or at least highlighted as a chip) instead of blank-on-open.
- `lib/screens/crm/bulk_message_screen.dart` — same pattern as bulk_email_screen. Blank recipient list on mount.
- `lib/screens/crm/wallet_notification_composer.dart` — opens empty; no recipient preview, no template picker pre-populated.
- `lib/screens/crm/candidate_messaging_screen.dart` — Compose tab and Templates tab both blank until the user types or picks; could show a "draft in progress" or last-template-used hint.
- `lib/screens/crm/candidates_page.dart` — loads candidates; fine.
- `lib/screens/crm/surveys_screen.dart:204-231` — opens with `_loading=true`, then renders a `TabBarView` of 4 copies of `_buildSurveyList()`. All four tabs show identical data because the filter isn't passed into `_buildSurveyList()` (reviewed at line 230 — `List.generate(4, (_) => _buildSurveyList())`). This is either a bug (every tab shows the same list) or the tabs are placeholder. Worth verifying.
- `lib/screens/crm/donor_detail_screen.dart:134-136` — empty state is `Text('Unable to load donor.')` with no retry button. `_buildBody` does have error-state retry at 116-131, but the `_donor == null` branch just prints text. Silent failure if the donor row is missing.
- `lib/screens/crm/donor_detail_screen.dart:1315` — "Search for a member to link." prompt with no search pre-populated; user has to type before seeing anything. If donor has `name`/`email`, we could pre-search.

---

## TabBarView catalog (for the global fix agent)

Missing `physics: const NeverScrollableScrollPhysics()`:

- `lib/screens/crm/donor_profile_screen.dart:296` — 6-tab donor profile.
- `lib/screens/crm/candidate_analytics_screen.dart:115` — tabs inside FadeTransition.
- `lib/screens/crm/candidate_detail_screen.dart:931` — candidate detail body.
- `lib/screens/crm/dialogs/donor_export_dialog.dart:350` — 2-tab export dialog.
- `lib/screens/crm/candidate_messaging_screen.dart:370` — Compose/Templates.
- `lib/screens/crm/surveys_screen.dart:228` — 4 identical survey list tabs (see "Broken default states" note).
- `lib/screens/crm/member_detail_screen.dart:2117` — 4-tab member detail.
- `lib/screens/crm/email_campaigns/email_campaign_detail_screen.dart:197` — campaign detail tabs.

Already has `physics: NeverScrollableScrollPhysics()`:

- `lib/screens/crm/donors_list_screen.dart:87`
- `lib/screens/crm/event_detail_screen.dart:3503`
- `lib/screens/crm/donor_command_center.dart:354`
- `lib/screens/crm/finances_page.dart:693`
- `lib/screens/crm/member_portal/member_portal_management_screen.dart:227`
- `lib/screens/crm/subscribers_screen.dart:266`

---

## Unreachable / dead code

- `lib/screens/crm/donors_list_screen.dart` — only remaining reference is `committee_donors_tab.dart:13` (`DonorsListScreen(embed: true)`). The main CRM route (`/crm/donors`) and dashboard card now point at `DonorCommandCenter`. Consider demoting to shared `DonorsTabsShell` or deleting.
- `lib/screens/crm/candidate_detail_painters.dart` — only referenced from `candidate_detail_screen.dart`. Not dead.
- `lib/screens/crm/candidate_ui_helpers.dart` — used broadly. Not dead.
- `lib/screens/crm/receipt_viewer_stub.dart` and `receipt_viewer_web.dart` — conditional-import pair; both reachable through platform conditional exports. Not dead.
- `lib/screens/crm/file_picker_materializer_web_fallback_stub.dart` and `_web_fallback.dart` — conditional-import pair, only referenced from `file_picker_materializer.dart:9`. Wired correctly, but note the naming is confusing: the `_stub.dart` is the non-web stub (used on mobile/desktop), the `.dart` (no stub) is the real web fallback. Easy to trip over.
- `lib/screens/crm/member_portal/member_portal_text_utils.dart`, `member_portal_content_tiles.dart` — used by `member_portal_management_screen.dart`. Not dead.
- `lib/screens/crm/member_detail/slack_user_search_screen.dart` — only referenced from `slack_activity_tab.dart`. Reachable.
- `lib/screens/crm/editors/` — all sheets referenced from their respective detail screens. None orphaned.
- `lib/screens/crm/voter_file/` — all cards used from `donor_profile_screen.dart`, `member_detail_screen.dart`, `mec_donor_screen.dart`. None orphaned.

### Imports worth double-checking

- `lib/screens/crm/mec_committee_screen.dart` imports `candidate_detail_screen.dart` and `mec_donor_screen.dart`. Used in the navigation callbacks at 73-88. OK.
- `lib/screens/crm/donor_detail_screen.dart:4-5` imports `chat_creator.dart` and `theme_switcher.dart` — Flutter app-wide wrappers, not CRM-specific. Fine but indicates this is a "pre-CRM refactor" screen; goes hand-in-hand with the DonorDetailScreen-vs-DonorProfileScreen duality noted above.

---

## Summary counts

- Crash-prone Theme+ColorScheme wrappers: **3** (candidate_detail, finances_page, donor_export_dialog).
- Fully-opaque `Colors.white` button/fill hits on navy surfaces: **6** (member_portal x2, member_detail, surveys, donor_export_dialog title bar, html_preview_stub).
- ExpansionTiles on dark parents lacking Theme overrides: **1 active risk** (`donor_profile_screen.dart:1791`); others are OK because parents are light.
- TabBarViews missing `NeverScrollableScrollPhysics`: **8**.
- Duplicate "donor detail" screens: **2** (`DonorDetailScreen`, `DonorProfileScreen`).
- Duplicate "donors container" screens: **2** (`DonorsListScreen`, `DonorCommandCenter`).
- Plain Card vs BrandedCard ratio: **387 : 31**.
- Blank-on-open screens: **4** (bulk_email, bulk_message, wallet_notification_composer, candidate_messaging).
