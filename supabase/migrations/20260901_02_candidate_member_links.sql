-- CANDIDATE MEMBER LINKS: which members are the volunteer base for a nominee.
--
-- Distinct from candidates.member_id, which says "this candidate IS this
-- member" and is singular. This says "this member will work for this
-- candidate", and is many-to-many.
--
-- Area-wide linking is materialized, not stored as a query: linking a county
-- inserts one row per member in it, sharing a batch_id and stamped with the
-- region that produced them. That keeps the count stable, keeps single-member
-- removal possible, and keeps an audit trail. See the spec for the argument.

create table if not exists public.candidate_member_links (
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,

  -- Provenance of the gesture. Null mode/id means the member was linked
  -- individually rather than as part of a region.
  source_region_mode text
    check (source_region_mode in ('county', 'congressional', 'senate', 'house')),
  source_region_id text,
  batch_id uuid,

  note text,

  -- Both id spaces, same rule as outreach_touchpoints: never assign one to the
  -- other.
  created_by_user_id uuid references auth.users(id),
  created_by_member_id uuid references public.members(id),
  created_at timestamptz not null default now(),

  primary key (candidate_id, member_id)
);

create index if not exists candidate_member_links_member_idx
  on public.candidate_member_links (member_id);
create index if not exists candidate_member_links_batch_idx
  on public.candidate_member_links (batch_id);

alter table public.candidate_member_links enable row level security;

drop policy if exists candidate_member_links_service_role on public.candidate_member_links;
create policy candidate_member_links_service_role on public.candidate_member_links
  as permissive for all to service_role
  using (true) with check (true);

drop policy if exists candidate_member_links_staff_all on public.candidate_member_links;
create policy candidate_member_links_staff_all on public.candidate_member_links
  as permissive for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on public.candidate_member_links from anon;
grant select, insert, update, delete on public.candidate_member_links to authenticated;

comment on table public.candidate_member_links is
  'Which members form the volunteer base for a nominee. Many-to-many, materialized at link time with the region that produced the batch. Distinct from candidates.member_id, which is candidate identity. Executive-committee-only.';

-- The two id spaces are both bare uuids and are trivially confusable. Say which
-- is which in the catalog, so anyone reading the table with \d+ sees it without
-- opening this file.
comment on column public.candidate_member_links.created_by_user_id is
  'auth.users.id of the exec who made the link. NOT a members.id. Source in Flutter: UserSessionProvider.authUserId.';
comment on column public.candidate_member_links.created_by_member_id is
  'members.id of the exec who made the link. NOT an auth.users.id. Source in Flutter: UserSessionProvider.currentMember!.id.';

comment on column public.candidate_member_links.batch_id is
  'Shared by every row one link gesture inserted, so that gesture can be named, counted and undone as a unit. A one-member link is a batch of one.';
