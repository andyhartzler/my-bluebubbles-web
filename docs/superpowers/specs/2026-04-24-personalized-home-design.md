# Personalized Home + Multi-Page Dashboard — Design Spec

**Status:** Draft for build
**Author:** moyd-claude (Opus 4.7)
**Date:** 2026-04-24
**Authoritative directive:** Andrew, in Telegram thread on 2026-04-24

## 1. Goals

Build three customization surfaces for executive members of the MOYD CRM, all powered by the same persistence and drag-drop primitives:

1. **Personalized Home Screen** (NEW) — per-user landing page on sign-in. Profile header (name, photo, title), Assignments panel, Meeting History panel, plus an optional drag-drop area where the user can add Dashboard metric tiles.
2. **Universal Dashboard** (UNCHANGED) — the existing `DashboardScreen` stays bit-identical. Same global, single-row layout backed by `crm_dashboard_metrics.dashboard_layout`. No behavioral or visual changes.
3. **Personal Dashboard Pages** (NEW) — each user can hit "Add Page" and create personal duplicates of the universal layout, then customize the duplicates. The Dashboard tab becomes a tabbed shell: Tab 1 = "Universal" (existing screen unchanged), Tabs 2..N = "My Pages". Superadmins can also create personal pages on behalf of any user.

## 2. Non-Goals

- Replacing or modifying the existing `DashboardScreen`. Andrew was emphatic: it must continue to render and behave identically. Wrap-don't-modify.
- Mobile app native shells. Web is the target.
- Tightening the existing permissive RLS on `crm_dashboard_metrics` (separate hardening pass, not in scope).
- Per-user analytics or A/B variants of the universal dashboard.

## 3. User-facing surfaces

### 3.1 Personalized Home Screen

Default landing for any executive after sign-in. Layout:

- **Profile header** (top, fixed): avatar (round, 64dp), full name, title (auto-derived from `members.executive_committee` + `members.committee` + role), committee badges. Edit-photo affordance opens an upload dialog (writes to `member-photos/{user_id}/avatar.{ext}` and stores the URL in `members.avatar_url`).
- **Assignments panel** (split into "Assigned to me" and "Assigned by me"):
  - **Explicit** (from `assignments` table): editable cards with title, note, status, priority, due date, deep-link to `entity_url`, status pill, mark-as-done.
  - **Auto-inferred** (read-only, deep-link only): items derived from existing tables — see §6.
- **Meeting history panel** (three sections):
  - Past meetings I attended (from `meeting_attendance` joined to `meetings`)
  - Upcoming meetings I'm invited to (from `meeting_invitees` joined to `scheduled_meetings`, filtered to future + status=scheduled)
  - Meetings I created/host (from `meetings.meeting_host` and `scheduled_meetings.created_by`)
- **Optional metric tiles** (drag-drop grid): user can add any of the 60+ dashboard data sources as tiles, persisted in `user_home_preferences.layout`.

A "Customize" button toggles edit mode for the optional tiles area only. Profile/Assignments/Meeting panels are always visible (toggleable via prefs but not drag-rearrangeable in v1).

### 3.2 Universal Dashboard

Untouched. Same `DashboardScreen` file, same drag-drop edit mode (unchanged), same persistence to `crm_dashboard_metrics.dashboard_layout` / `dashboard_layout_mobile`. The dashboard simply gets wrapped inside `DashboardShellScreen` so it's the first tab in a tab bar. The Universal tab does not show "Add Page" or any multi-page chrome — it looks exactly as it does today.

### 3.3 Personal Dashboard Pages

When the user opens the Dashboard navigation entry, they see `DashboardShellScreen`:

- TabBar at top: `[Universal] [My Page 1] [My Page 2] ... [+]`
- Tab 0 ("Universal"): renders `DashboardScreen()` unchanged.
- Tab 1..N: renders `PersonalDashboardPageView(pageId)` — same widget renderer as universal, but reads/writes `dashboard_pages.layout` for that page row.
- Tab N+1 ("+"): button. On tap → "Create new page" dialog: name (default "My Dashboard"), seed-from (universal / blank / specific existing page). Creates a `dashboard_pages` row, switches to that tab, opens edit mode.

Tabs are reorderable (long-press drag updates `position`). Long-press a tab → context menu: Rename, Duplicate, Delete.

Superadmin path: in the Superadmin → Members detail, a new "Dashboard Pages" section lists pages assigned to that member with a "Create page for this user" button. Same `dashboard_pages` row shape; superadmin sets `user_id` to the target user, `created_by = auth.uid()`. The recipient sees it as one of their personal tabs the next time they open the Dashboard.

## 4. Data model

### 4.1 New tables

```sql
-- 4.1.1 Per-user home screen preferences
CREATE TABLE public.user_home_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  layout jsonb NOT NULL DEFAULT '{"widgets":[],"columns":4}'::jsonb,
  layout_mobile jsonb NOT NULL DEFAULT '{"widgets":[],"columns":2}'::jsonb,
  show_profile_header boolean NOT NULL DEFAULT true,
  show_assignments boolean NOT NULL DEFAULT true,
  show_meeting_history boolean NOT NULL DEFAULT true,
  show_optional_tiles boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 4.1.2 Per-user dashboard pages (the "Add Page" feature)
CREATE TABLE public.dashboard_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL DEFAULT 'My Dashboard',
  position integer NOT NULL DEFAULT 0,
  layout jsonb NOT NULL DEFAULT '{"widgets":[],"columns":4}'::jsonb,
  layout_mobile jsonb NOT NULL DEFAULT '{"widgets":[],"columns":2}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_dashboard_pages_user_id ON public.dashboard_pages(user_id, position);

-- 4.1.3 Explicit assignments
CREATE TABLE public.assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assigned_to uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  note text,
  entity_type text,                                            -- 'candidate', 'bill', 'event', 'meeting', 'free', etc.
  entity_id text,                                              -- uuid string of the source row, or NULL
  entity_url text,                                             -- optional in-app deep link
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','done','cancelled')),
  priority text CHECK (priority IN ('low','medium','high')),
  due_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_assignments_assigned_to ON public.assignments(assigned_to, status);
CREATE INDEX idx_assignments_assigned_by ON public.assignments(assigned_by);
```

### 4.2 Column additions

```sql
-- User-uploaded headshot (separate from the auto-fetched profile_pictures jsonb)
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS avatar_url text;

-- Convert candidates.moyd_assigned_to from text to uuid + add FK
-- (Currently 0 rows populated; safe per Supabase audit.)
ALTER TABLE public.candidates
  ALTER COLUMN moyd_assigned_to TYPE uuid USING NULLIF(moyd_assigned_to, '')::uuid;
ALTER TABLE public.candidates
  ADD CONSTRAINT candidates_moyd_assigned_to_fkey
  FOREIGN KEY (moyd_assigned_to) REFERENCES public.members(id) ON DELETE SET NULL;
```

### 4.3 RLS posture

Enable RLS on all three new tables. Reuse existing helpers `is_staff()`, `current_user_is_superadmin()`.

```sql
ALTER TABLE public.user_home_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY uhp_self_all ON public.user_home_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin())
  WITH CHECK (user_id = auth.uid() OR public.current_user_is_superadmin());
CREATE POLICY uhp_service_role ON public.user_home_preferences
  FOR ALL TO service_role USING (true) WITH CHECK (true);

ALTER TABLE public.dashboard_pages ENABLE ROW LEVEL SECURITY;
CREATE POLICY dp_select ON public.dashboard_pages
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin());
CREATE POLICY dp_insert ON public.dashboard_pages
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND (user_id = auth.uid() OR public.current_user_is_superadmin())
  );
CREATE POLICY dp_update ON public.dashboard_pages
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin())
  WITH CHECK (user_id = auth.uid() OR public.current_user_is_superadmin());
CREATE POLICY dp_delete ON public.dashboard_pages
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin());
CREATE POLICY dp_service_role ON public.dashboard_pages
  FOR ALL TO service_role USING (true) WITH CHECK (true);

ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY assn_select ON public.assignments
  FOR SELECT TO authenticated
  USING (
    assigned_to = auth.uid()
    OR assigned_by = auth.uid()
    OR public.current_user_is_superadmin()
  );
CREATE POLICY assn_insert ON public.assignments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_staff()
    AND assigned_by IS NOT NULL
    AND assigned_by = auth.uid()
  );
CREATE POLICY assn_update ON public.assignments
  FOR UPDATE TO authenticated
  USING (
    assigned_to = auth.uid()
    OR assigned_by = auth.uid()
    OR public.current_user_is_superadmin()
  )
  WITH CHECK (
    assigned_to = auth.uid()
    OR assigned_by = auth.uid()
    OR public.current_user_is_superadmin()
  );
CREATE POLICY assn_delete ON public.assignments
  FOR DELETE TO authenticated
  USING (assigned_by = auth.uid() OR public.current_user_is_superadmin());
CREATE POLICY assn_service_role ON public.assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);
```

Members self-read/write of meeting tables for the meeting history panel: add additive policies (do NOT remove existing staff-all policies):

```sql
CREATE POLICY meetings_self_attended ON public.meetings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.meeting_attendance ma
      JOIN public.members m ON m.id = ma.member_id
      WHERE ma.meeting_id = meetings.id AND m.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = meetings.meeting_host AND m.user_id = auth.uid()
    )
  );

CREATE POLICY scheduled_meetings_self_invited ON public.scheduled_meetings
  FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.meeting_invitees mi
      JOIN public.members m ON m.id = mi.member_id
      WHERE mi.meeting_id = scheduled_meetings.id AND m.user_id = auth.uid()
    )
  );

CREATE POLICY meeting_attendance_self_select ON public.meeting_attendance
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = meeting_attendance.member_id AND m.user_id = auth.uid()
    )
  );

CREATE POLICY meeting_invitees_self_select ON public.meeting_invitees
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = meeting_invitees.member_id AND m.user_id = auth.uid()
    )
  );
```

### 4.4 Audit trigger attachments

```sql
CREATE TRIGGER trg_audit_user_home_preferences
  AFTER INSERT OR UPDATE OR DELETE ON public.user_home_preferences
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

CREATE TRIGGER trg_audit_dashboard_pages
  AFTER INSERT OR UPDATE OR DELETE ON public.dashboard_pages
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

CREATE TRIGGER trg_audit_assignments
  AFTER INSERT OR UPDATE OR DELETE ON public.assignments
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();
```

### 4.5 Storage policy refinement (members avatar)

Tighten `storage.objects` for the `member-photos` bucket so users can only write to `<their_user_id>/...` (does not affect the existing scrape-write paths used by service_role):

```sql
DROP POLICY IF EXISTS "Authenticated users can upload member photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update member photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete member photos" ON storage.objects;

CREATE POLICY "Authenticated users upload own folder member photos" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY "Authenticated users update own folder member photos" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
CREATE POLICY "Authenticated users delete own folder member photos" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
```

The existing `Public read` policy stays (avatars must be readable by anyone in the app). The `service_role` policies stay (the auto-scrape continues to work).

## 5. Dart architecture

### 5.1 New files

```
lib/screens/crm/personalized_home/
  personalized_home_screen.dart           # main landing
  widgets/
    profile_header.dart                   # avatar + name + title + committees
    assignments_panel.dart                # split: assigned to me / by me; explicit + auto-inferred
    assignment_card.dart                  # individual assignment tile
    auto_inferred_panel.dart              # the read-only "things waiting on me" rollup
    meeting_history_panel.dart            # past attended / upcoming / hosted
    optional_tiles_section.dart           # drag-drop area for added metric tiles
    home_customize_dialog.dart            # toggle which top-level panels are visible
    avatar_upload_dialog.dart             # upload to member-photos/<user_id>/avatar.<ext>
    assignment_create_dialog.dart         # used both from home and from any deep entity (candidate, bill, etc.)

lib/screens/crm/dashboard_shell/
  dashboard_shell_screen.dart             # tab bar: Universal + per-user pages + Add
  personal_dashboard_page_view.dart       # renders one of the per-user pages (drag-drop reused)
  dashboard_widget_renderer.dart          # PUBLIC dispatcher mapping DashboardWidgetType + config + metrics → Widget
                                          # (read-only mirror of the dispatch logic in DashboardScreen,
                                          #  uses public widget classes from screens/dashboard/widgets/dashboard_widgets.dart)
  add_page_dialog.dart                    # name + seed-from
  rename_page_dialog.dart

lib/services/crm/
  assignments_service.dart                # CRUD + realtime channel
  user_home_preferences_service.dart      # fetch/upsert
  dashboard_pages_service.dart            # CRUD + reorder
  auto_inferred_assignments_service.dart  # the 6 parallel queries that synthesize "auto" items

lib/models/crm/
  assignment.dart                         # data class, JSON ser/de
  user_home_preferences.dart              # data class
  dashboard_page.dart                     # data class
```

### 5.2 Files modified (minimal)

- **`lib/main.dart`** — add `_HomeSection.home` as new index 0; shift `_HomeSection.dashboard` to index 1; default landing becomes `_HomeSection.home`. Add new IndexedStack child at index 0 (`PersonalizedHomeScreen`). Replace IndexedStack child at the dashboard index with `DashboardShellScreen` (it wraps the existing `DashboardScreen`, so visually identical for users who never click "+"). Add nav button. **Constraint:** the existing `_HomeSection` enum order stays semantically the same — only `home` is prepended; everything else shifts down by one index, but since the nav uses enum values not raw integers, this is safe.

- **`lib/services/crm/dashboard_metrics_service.dart`** — add `fetchUserDashboardPages(userId)`, `createUserDashboardPage(...)`, `saveUserDashboardPageLayout(pageId, layout, isMobile)`, `deleteUserDashboardPage(pageId)`, `reorderUserDashboardPages(orderedIds)`. The existing `fetchDashboardLayout` / `saveDashboardLayout` (global) remain unchanged.

- **`lib/models/crm/member.dart`** — add `final String? avatarUrl` field, with effective-avatar getter that falls back to `profilePictures['instagram']` then `profilePictures['twitter']`.

- **`lib/screens/crm/superadmin/`** — add a "Dashboard Pages" panel in the Members detail view (or as a new tab) that lists pages owned by that member and lets the superadmin create one on their behalf.

### 5.3 Untouched (proven by review)

- `lib/screens/dashboard/dashboard_screen.dart` — bit-identical.
- `lib/screens/dashboard/widgets/dashboard_widgets.dart` — already has public widget classes; no changes.
- `lib/screens/dashboard/models/dashboard_widget_config.dart` — already has full JSON serialization.

## 6. Auto-inferred assignment sources

The auto-inferred panel runs six parallel queries. All read-only, all deep-link to the source. None duplicate items already present in `assignments`.

| Source table | Trigger condition (what makes it appear) | Deep-link |
|---|---|---|
| `candidates.moyd_assigned_to = me` | a candidate is assigned to this member | `/candidates/<id>` |
| `member_profile_changes` | `status = 'pending'` AND member is staff (anyone on EC can review) | `/members/<member_id>?changes=pending` |
| `member_submitted_events` | `approval_status = 'pending'` AND member is staff | `/events?tab=pending` |
| `legislation_bill_notes` | `mentioned_member_ids @> ARRAY[<my_member_id>]` (deviates from initial brief which said author; being mentioned is more actionable) | `/bills/<bill_id>?note=<id>` |
| `jobs.approved_by IS NULL` | a job application is awaiting approval AND member is staff | `/jobs?tab=pending` |
| `scheduled_meetings.created_by = auth.uid()` AND `status = 'scheduled'` | meetings I created that are upcoming | (already in meeting history; suppress here) |

For tables driven by `member_id` (the CRM `members.id` rather than `auth.users.id`), the service translates `auth.uid()` → `members.id` once per session via `MemberRepository`.

## 7. Interaction patterns

- **Create assignment from anywhere**: A `+ Assign` action in candidate/bill/event/meeting detail toolbars opens `assignment_create_dialog` pre-filled with `entity_type`, `entity_id`, `entity_url`. The dialog lets the user pick the assignee from a member autocomplete (anyone with an auth user). `assigned_by = auth.uid()` enforced server-side via RLS check.
- **Mark as done**: cards inline-update `status` to `done` via optimistic UI + Supabase update; audit trigger captures the change.
- **Edit an assignment**: only the assignee or assigner (or superadmin) can edit, per RLS UPDATE policy. The dialog reuses `assignment_create_dialog` in edit mode.
- **Add Page**: Opens `add_page_dialog`. On confirm, calls `dashboardPagesService.create(...)` with a copy of the universal `dashboard_layout` (or empty if "blank" was chosen). Tab bar refreshes; the new tab is selected and edit mode auto-engages.
- **Reorder tabs**: long-press a personal tab → enter reorder mode; drag horizontally to reorder; on release, `reorderUserDashboardPages` writes the new positions.
- **Superadmin assigns a page to user X**: from Superadmin → Members → X → "Dashboard Pages" panel → "Create page". Same flow, but the resulting row has `user_id = X`, `created_by = auth.uid()`. X sees it on their next dashboard load (or via real-time).

## 8. Build order

Phased so each phase can be tested independently. Each phase ends with `flutter analyze`-clean state.

- **Phase 0 — Migrations**: write and apply the SQL migration (§4) to prod Supabase. Verify with `\d public.assignments`, `\d public.dashboard_pages`, `\d public.user_home_preferences`. Confirm RLS via `SELECT ... ` as `authenticated`.
- **Phase 1 — Models + Services**: create the 3 model classes, 4 service classes, plus the `Member.avatarUrl` extension. Add new methods to `DashboardMetricsService`.
- **Phase 2 — DashboardWidgetRenderer**: extract a public renderer (mirror of dispatch in `_DashboardScreenState`) into `dashboard_widget_renderer.dart`. Verify by writing a smoke widget test.
- **Phase 3 — DashboardShellScreen**: build the tab bar shell. Tab 0 wraps existing `DashboardScreen()` (untouched). Tab 1..N renders `PersonalDashboardPageView`. Tab N+1 = "+". Verify by stubbing the page list with empty and one fake row.
- **Phase 4 — PersonalizedHomeScreen + sub-widgets**: profile header, assignments panel, meeting history panel, optional tiles section, customize dialog. Wire to services.
- **Phase 5 — main.dart wiring**: insert `_HomeSection.home` and `PersonalizedHomeScreen` as default landing. Replace dashboard child with `DashboardShellScreen`. Update top-bar / mobile nav.
- **Phase 6 — Superadmin admin surface**: add Dashboard Pages panel to Members detail in superadmin area; add Assignments admin panel.
- **Phase 7 — Code review pass**: spawn `code-reviewer` agent on the diff; fix every high-confidence finding.
- **Phase 8 — Build verify + commit + push**: `flutter analyze` + `flutter build web --release`; commit; push to master; Netlify auto-deploys.

## 9. Risk register

| Risk | Mitigation |
|---|---|
| Existing `DashboardScreen` rendered inside a TabBarView misbehaves with its own scaffold/AppBar | Render with no enclosing AppBar in shell; if conflicts arise, wrap in a Material widget with appropriate scaffolding |
| Per-user dashboard pages explode in number, slowing tab bar | Cap at 10 pages per user (enforced client-side, no DB constraint) |
| Auto-inferred queries hammer DB | Each query already filters tightly; cache results for 30s in `auto_inferred_assignments_service`. Surface as a single function that returns a typed bundle |
| `_HomeSection` enum reorder breaks anything that depended on the integer index | Audit reveals only `_currentSection.index` is used (in IndexedStack). Adding `home` at index 0 shifts all others by 1 — IndexedStack children list shifts in lockstep, so functionally consistent. `PageStorageKey`s preserve scroll position. |
| RLS infinite recursion (members policies referencing meeting tables that reference members) | None of the new policies create a cycle: `meetings_self_attended` reads `members` directly via `m.user_id = auth.uid()` (not via another policy on members) |
| `members.user_id` is nullable for ghost rows; some assignments could orphan | `assignments.assigned_to` references `auth.users.id` (NOT NULL) — orphan via a dropped auth user → `ON DELETE CASCADE` removes the assignment cleanly |
| Avatar upload exceeds Supabase Storage size limits | Client-side resize to 512×512 max before upload; size cap at 1 MB |
| Migrating `candidates.moyd_assigned_to` from text→uuid fails because of a non-empty bad value | The Supabase audit confirmed 0 rows; `NULLIF(moyd_assigned_to, '')::uuid` handles edge cases gracefully |

## 10. Out-of-scope explicitly

- Dashboard widget creation UI (we reuse the existing one in `DashboardScreen`'s edit mode).
- Real-time push notification when an assignment is created (uses Supabase realtime channel; client subscribes when home screen mounts).
- A separate "Notifications" surface — assignments + auto-inferred *are* the notifications surface.
- Cross-org sharing of dashboard pages.
- Reverting `crm_dashboard_metrics` permissive RLS (Andrew has explicitly deferred RLS Phase 2 hardening to a later pass).

## 11. Implementation defaults Andrew did not specify

| Question | Default chosen | Rationale |
|---|---|---|
| Photo source | `members.avatar_url` (user-uploaded, with `profile_pictures` jsonb fallback) | Matches Andrew's "user can customize" intent; doesn't conflict with the existing IG/X scrape; bucket already exists |
| Meeting history scope | All three (past attended + upcoming invited + hosted) | Andrew's brief said "meeting history" without bounding; showing all three is more useful and easy |
| Auto-inferred sources | All six listed in §6 | Each is a real "thing waiting on me" pattern in the existing data model; deep-linkable |
| Customization model | Drag-drop grid for the optional-tiles section + global toggles for which top-level panels are visible. Universal Dashboard remains the seed for new personal pages | Matches Andrew's stated preference for the Dashboard's existing UI patterns |
| Superadmin-imposed default home layout | NOT in v1 — superadmin can create personal Dashboard pages for users, but cannot dictate their home screen | Reduces complexity; can add later if requested |

## 12. Verification plan

- `flutter analyze` — zero errors, zero warnings on the new files
- Smoke test in browser:
  - Sign in as Andrew → land on `PersonalizedHomeScreen` (not Dashboard)
  - Profile header renders Andrew's name + photo + title
  - Open Dashboard → see Universal tab + ability to "+ Add Page"
  - Create a personal page from universal seed → tab appears, edit mode engages
  - Edit, save, refresh → layout persists
  - Create an assignment to Andrew via candidate detail page → appears on home assignments panel within ~5s (realtime)
  - Auto-inferred panel populates from the 6 sources
  - Meeting history shows past + upcoming + hosted
  - Avatar upload writes to `member-photos/<user_id>/avatar.png` and persists URL
- Database verification (psql):
  - `SELECT count(*) FROM public.assignments WHERE assigned_to = '<my_uid>'` from a non-superadmin auth context returns only that user's rows
  - Audit log captures inserts/updates/deletes on all three new tables
- RLS sanity:
  - From an anon connection, `SELECT * FROM assignments` returns 0 rows / fails policy

## 13. Open items deferred for follow-up

- Hardening RLS on `crm_dashboard_metrics` (anyone authenticated can currently overwrite global layout).
- Drag-drop reorder of top-level home panels (v1: only the optional-tiles section is drag-drop; profile/assignments/meeting are fixed-order with toggles).
- Notifications channel / email digest of pending assignments.
- Mobile drag-drop UX polish for tabbed dashboards on small screens.
