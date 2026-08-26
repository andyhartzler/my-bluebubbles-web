-- OUTREACH TRACKING: field activity, the candidates it was for, and who showed up.
--
-- Layer 2 of the Candidate Volunteers overhaul. The map (Layer 1) resolves a
-- region to its members and candidates and hands them to bulk text/email. This
-- subsystem records what was actually done: a canvass, a phone bank, a day of
-- action, tied to the geographies it covered, the candidates it supported, and
-- the members who took part.
--
-- Nothing here is auto-populated. Every row is created by a signed-in
-- executive from the map panel, a post-send prompt, or a candidate/member
-- detail screen, so this file carries none of meeting_commitments' human-edit
-- lock or no-automated-delete guards; there is no automation writing these to
-- protect against. It creates the shape and the executive-only RLS only.
--
-- Modeled on meeting_commitments (geo text[] + GIN) and donor_activity_log
-- (a staff-only activity log keyed to a parent).

create table if not exists public.outreach_activities (
  id uuid primary key default gen_random_uuid(),

  kind text not null check (kind in
    ('canvass', 'phone_bank', 'text_bank', 'email_blast', 'social_blitz',
     'day_of_action', 'volunteer_day', 'other')),
  title text not null,
  description text,
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'completed', 'cancelled')),
  channel text check (channel in ('in_person', 'sms', 'email', 'phone', 'social')),
  scheduled_on date,
  completed_at timestamptz,

  -- The regions this activity covered. Bare-digit district numbers for the
  -- district arrays, county names for counties, matching the map's own keys.
  counties text[] not null default '{}',
  congressional_districts text[] not null default '{}',
  senate_districts text[] not null default '{}',
  house_districts text[] not null default '{}',

  organizer_member_id uuid references public.members(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- GIN indexes on the four geo arrays so `counties @> array[$1]` and the
-- district equivalents stay index-backed, plus a plain index for the default
-- most-recent-first ordering the repository pages on.
create index if not exists outreach_activities_counties_idx
  on public.outreach_activities using gin (counties);
create index if not exists outreach_activities_congressional_idx
  on public.outreach_activities using gin (congressional_districts);
create index if not exists outreach_activities_senate_idx
  on public.outreach_activities using gin (senate_districts);
create index if not exists outreach_activities_house_idx
  on public.outreach_activities using gin (house_districts);
create index if not exists outreach_activities_scheduled_idx
  on public.outreach_activities (scheduled_on desc);

-- Which candidates an activity supported. Composite primary key: a candidate
-- appears at most once per activity, and deleting the activity clears the link.
create table if not exists public.outreach_activity_candidates (
  activity_id uuid not null references public.outreach_activities(id) on delete cascade,
  candidate_id uuid not null references public.candidates(id),
  primary key (activity_id, candidate_id)
);

create index if not exists outreach_activity_candidates_candidate_idx
  on public.outreach_activity_candidates (candidate_id);

-- Who took part, in what role, and whether they showed. attended is nullable so
-- "not yet recorded" is distinct from "did not attend".
create table if not exists public.outreach_participants (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.outreach_activities(id) on delete cascade,
  member_id uuid not null references public.members(id),
  role text not null default 'volunteer'
    check (role in ('volunteer', 'captain', 'organizer')),
  attended boolean,
  created_at timestamptz not null default now(),
  unique (activity_id, member_id)
);

create index if not exists outreach_participants_activity_idx
  on public.outreach_participants (activity_id);
create index if not exists outreach_participants_member_idx
  on public.outreach_participants (member_id);

-- updated_at touch on the parent (the only table here with the column). Copies
-- the generic public.tg_set_updated_at() attach used by 20260424_04.
drop trigger if exists trg_outreach_activities_updated_at on public.outreach_activities;
create trigger trg_outreach_activities_updated_at
  before update on public.outreach_activities
  for each row execute function public.tg_set_updated_at();

-- Audit the parent entity only. public.fn_audit_log_trigger() reads NEW.id /
-- OLD.id, which outreach_activity_candidates does not have (composite PK), and
-- the 20260428_01 pattern audits primary entity tables rather than pure
-- join/attendance tables, so neither join table gets the trigger.
drop trigger if exists trg_audit_outreach_activities on public.outreach_activities;
create trigger trg_audit_outreach_activities
  after insert or update or delete on public.outreach_activities
  for each row execute function public.fn_audit_log_trigger();

-- RLS. The CRM is executive-committee-only, so the gate is is_staff() and the
-- service role has unconditional access, matching meeting_commitments exactly.
alter table public.outreach_activities enable row level security;

drop policy if exists outreach_activities_service_role on public.outreach_activities;
create policy outreach_activities_service_role on public.outreach_activities
  as permissive for all to service_role
  using (true) with check (true);

drop policy if exists outreach_activities_staff_all on public.outreach_activities;
create policy outreach_activities_staff_all on public.outreach_activities
  as permissive for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on public.outreach_activities from anon;
grant select, insert, update, delete on public.outreach_activities to authenticated;

alter table public.outreach_activity_candidates enable row level security;

drop policy if exists outreach_activity_candidates_service_role on public.outreach_activity_candidates;
create policy outreach_activity_candidates_service_role on public.outreach_activity_candidates
  as permissive for all to service_role
  using (true) with check (true);

drop policy if exists outreach_activity_candidates_staff_all on public.outreach_activity_candidates;
create policy outreach_activity_candidates_staff_all on public.outreach_activity_candidates
  as permissive for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on public.outreach_activity_candidates from anon;
grant select, insert, update, delete on public.outreach_activity_candidates to authenticated;

alter table public.outreach_participants enable row level security;

drop policy if exists outreach_participants_service_role on public.outreach_participants;
create policy outreach_participants_service_role on public.outreach_participants
  as permissive for all to service_role
  using (true) with check (true);

drop policy if exists outreach_participants_staff_all on public.outreach_participants;
create policy outreach_participants_staff_all on public.outreach_participants
  as permissive for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on public.outreach_participants from anon;
grant select, insert, update, delete on public.outreach_participants to authenticated;

comment on table public.outreach_activities is
  'One row per field outreach activity (canvass, phone bank, day of action, and so on), tied to the geographies it covered. Executive-committee-only. Layer 2 of Candidate Volunteers.';
comment on table public.outreach_activity_candidates is
  'Which candidates an outreach activity supported. Executive-committee-only.';
comment on table public.outreach_participants is
  'Which members took part in an outreach activity, their role, and attendance. Executive-committee-only.';
