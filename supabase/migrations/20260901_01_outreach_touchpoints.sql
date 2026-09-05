-- OUTREACH TOUCHPOINTS: what an exec actually sent, and what they are still
-- writing.
--
-- Distinct from outreach_activities on purpose. An activity is planned field
-- work with a roster and attendance. A touchpoint is one bulk contact: it has
-- recipients, a body, an outcome, and an author. It is written automatically by
-- the Mobilize Desk rather than by a human filling a form, which is why it
-- carries composer state (subject, body, recipient list) that an activity has
-- no business holding.
--
-- A sent touchpoint can be promoted into an activity (activity_id below). The
-- reverse never happens.

create table if not exists public.outreach_touchpoints (
  id uuid primary key default gen_random_uuid(),

  channel text not null check (channel in ('sms', 'email')),

  -- draft      : being composed, resumable, never sent
  -- sending    : a send is in flight. Set by compare-and-set from 'draft', so a
  --              double-tap or a retried request cannot send twice.
  -- sent       : every recipient succeeded
  -- partial    : some recipients failed (sms only; email is one batched call)
  -- failed     : the send threw, or every recipient failed
  -- discarded  : the exec abandoned the draft. Kept for the audit trail.
  status text not null default 'draft'
    check (status in ('draft', 'sending', 'sent', 'partial', 'failed', 'discarded')),

  -- Composer state. This is what makes "pick up where they left off" real.
  subject text,                       -- email only
  body_text text,                     -- sms body, or the email plain-text part
  body_html text,                     -- email only
  recipient_member_ids uuid[] not null default '{}',

  -- Outcome, written once when the send resolves.
  attempted_count integer not null default 0,
  delivered_count integer not null default 0,
  failed_member_ids uuid[] not null default '{}',
  error_detail text,

  -- Who. Two id spaces, deliberately both stored: actor_member_id is a
  -- members.id (what the workspace displays and groups by), actor_user_id is an
  -- auth.users.id (what RLS and the audit log speak). Never assign one to the
  -- other.
  actor_member_id uuid not null references public.members(id),
  actor_user_id uuid not null references auth.users(id),

  -- Where. Same key shapes as outreach_activities: county names, bare-digit
  -- district numbers.
  counties text[] not null default '{}',
  congressional_districts text[] not null default '{}',
  senate_districts text[] not null default '{}',
  house_districts text[] not null default '{}',

  -- Which nominees this was for. An array rather than a join table: a
  -- touchpoint is written on the send path, and keeping it a single-row upsert
  -- is what makes the compare-and-set in 3.5 atomic without an RPC. The
  -- tradeoff is no referential integrity on these ids; a candidate row cannot
  -- be deleted while outreach_activity_candidates references it anyway, and the
  -- UI omits an id it cannot resolve.
  candidate_ids uuid[] not null default '{}',

  -- Promotion and retry lineage.
  activity_id uuid references public.outreach_activities(id) on delete set null,
  retry_of uuid references public.outreach_touchpoints(id) on delete set null,

  created_at timestamptz not null default now(),
  last_edited_at timestamptz not null default now(),
  sent_at timestamptz,
  updated_at timestamptz not null default now()
);

-- The exec's desk: their drafts, then their recent sends. Both are
-- "mine, newest first".
create index if not exists outreach_touchpoints_actor_idx
  on public.outreach_touchpoints (actor_member_id, status, last_edited_at desc);

-- Region sections read "@> array[$1]" exactly like the activities do.
create index if not exists outreach_touchpoints_counties_idx
  on public.outreach_touchpoints using gin (counties);
create index if not exists outreach_touchpoints_congressional_idx
  on public.outreach_touchpoints using gin (congressional_districts);
create index if not exists outreach_touchpoints_senate_idx
  on public.outreach_touchpoints using gin (senate_districts);
create index if not exists outreach_touchpoints_house_idx
  on public.outreach_touchpoints using gin (house_districts);
create index if not exists outreach_touchpoints_candidates_idx
  on public.outreach_touchpoints using gin (candidate_ids);
create index if not exists outreach_touchpoints_recipients_idx
  on public.outreach_touchpoints using gin (recipient_member_ids);

create index if not exists outreach_touchpoints_sent_idx
  on public.outreach_touchpoints (sent_at desc);

drop trigger if exists trg_outreach_touchpoints_updated_at on public.outreach_touchpoints;
create trigger trg_outreach_touchpoints_updated_at
  before update on public.outreach_touchpoints
  for each row execute function public.tg_set_updated_at();

drop trigger if exists trg_audit_outreach_touchpoints on public.outreach_touchpoints;
create trigger trg_audit_outreach_touchpoints
  after insert or update or delete on public.outreach_touchpoints
  for each row execute function public.fn_audit_log_trigger();

alter table public.outreach_touchpoints enable row level security;

drop policy if exists outreach_touchpoints_service_role on public.outreach_touchpoints;
create policy outreach_touchpoints_service_role on public.outreach_touchpoints
  as permissive for all to service_role
  using (true) with check (true);

-- Exec-committee-wide, matching outreach_activities. Deliberately NOT
-- author-scoped: Andrew asked that this work be "tracked and monitored within
-- the crm", which means the exec committee can see each other's outreach. The
-- desk filters to "mine" in the UI, not in the policy.
drop policy if exists outreach_touchpoints_staff_all on public.outreach_touchpoints;
create policy outreach_touchpoints_staff_all on public.outreach_touchpoints
  as permissive for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on public.outreach_touchpoints from anon;
grant select, insert, update, delete on public.outreach_touchpoints to authenticated;

comment on table public.outreach_touchpoints is
  'One bulk contact from the Mobilize Desk: its composer state while a draft, its outcome once sent, its author and the regions and nominees it covered. Executive-committee-only. Distinct from outreach_activities, which is planned field work with a roster.';

-- The two id spaces are both bare uuids and are trivially confusable. Say which
-- is which in the catalog, so anyone reading the table with \d+ sees it without
-- opening this file.
comment on column public.outreach_touchpoints.actor_member_id is
  'members.id of the exec who composed and sent this. NOT an auth.users.id. Source in Flutter: UserSessionProvider.currentMember!.id.';
comment on column public.outreach_touchpoints.actor_user_id is
  'auth.users.id of the exec who composed and sent this. NOT a members.id. Source in Flutter: UserSessionProvider.authUserId.';
