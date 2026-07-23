-- Money-intelligence knowledge base.
--
-- Researched profiles for the money-graph entities: donors (public.mec_donors),
-- committees (public.mec_committees / finance summaries), normalized payees
-- (public.mec_committee_payee_aggregate), and FEC committees
-- (public.fec_committees). Each row is a human-researched, source-cited
-- knowledge-base article plus structured facts and DB-derived stat blocks.
--
-- money_profile_queue drives the research backlog (rank_metric + tier).
--
-- Public schema only. Additive / non-destructive. Staff-only read via the
-- wrapped (SELECT is_staff()) form; service_role writes from the research
-- pipeline.

-- 1. Knowledge-base table -----------------------------------------------------
create table if not exists public.money_profiles (
  id            bigint generated always as identity primary key,
  entity_type   text not null check (entity_type in ('donor','committee','payee','fec_committee')),
  entity_key    text not null,
  display_name  text,
  headline      text,
  narrative_md  text,
  profile       jsonb,
  stat_block    jsonb,
  sources       jsonb,
  confidence    text check (confidence in ('high','medium','low')),
  tier          int,
  researched_at timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (entity_type, entity_key)
);

comment on table public.money_profiles is
  'Researched money-intelligence knowledge base. One row per money-graph entity (donor / committee / payee / fec_committee). narrative_md is the source-cited article; profile = structured facts; stat_block = DB-derived numbers; sources = [{url,title}]. Public-record research only.';
comment on column public.money_profiles.entity_key is
  'mec_donors.id::text (donor) / mec_id (committee) / normalized payee name (payee) / fec cmte_id (fec_committee).';
comment on column public.money_profiles.headline is 'One-line who-this-is.';
comment on column public.money_profiles.profile is
  'Structured: {occupation, employer, business_interests[], civic_roles[], giving_pattern, party_lean, notable[]}.';
comment on column public.money_profiles.stat_block is 'DB-derived numbers (lifetime totals, counts, etc.).';
comment on column public.money_profiles.sources is 'Array of {url, title} citations.';

-- 2. Research queue -----------------------------------------------------------
create table if not exists public.money_profile_queue (
  entity_type  text not null check (entity_type in ('donor','committee','payee','fec_committee')),
  entity_key   text not null,
  display_name text,
  rank_metric  numeric,
  tier         int,
  status       text not null default 'pending' check (status in ('pending','done','skipped')),
  queued_at    timestamptz not null default now(),
  primary key (entity_type, entity_key)
);

comment on table public.money_profile_queue is
  'Research backlog for money_profiles. rank_metric orders the work (e.g. lifetime giving / total_raised / payee spend); tier buckets priority; status tracks progress.';

-- 3. RLS ----------------------------------------------------------------------
alter table public.money_profiles enable row level security;

drop policy if exists money_profiles_staff_read on public.money_profiles;
create policy money_profiles_staff_read
  on public.money_profiles
  for select
  to authenticated
  using ((select public.is_staff()));

drop policy if exists money_profiles_service on public.money_profiles;
create policy money_profiles_service
  on public.money_profiles
  for all
  to service_role
  using (true)
  with check (true);

alter table public.money_profile_queue enable row level security;

drop policy if exists money_profile_queue_staff_read on public.money_profile_queue;
create policy money_profile_queue_staff_read
  on public.money_profile_queue
  for select
  to authenticated
  using ((select public.is_staff()));

drop policy if exists money_profile_queue_service on public.money_profile_queue;
create policy money_profile_queue_service
  on public.money_profile_queue
  for all
  to service_role
  using (true)
  with check (true);

grant select on public.money_profiles to authenticated;
grant select on public.money_profile_queue to authenticated;

-- 4. Accessor RPC -------------------------------------------------------------
create or replace function public.get_money_profile(p_entity_type text, p_entity_key text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row jsonb;
begin
  if not public.is_staff() then
    return null;
  end if;

  select to_jsonb(mp) into v_row
  from public.money_profiles mp
  where mp.entity_type = p_entity_type
    and mp.entity_key  = p_entity_key;

  return v_row;
end;
$$;

comment on function public.get_money_profile(text, text) is
  'Staff-gated fetch of a single money_profiles row as jsonb (NULL if none / not staff).';

grant execute on function public.get_money_profile(text, text) to authenticated;
