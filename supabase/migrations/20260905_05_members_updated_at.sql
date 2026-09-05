-- APPLIED TO PRODUCTION 2026-09-05.
--
-- public.members had created_at but no updated_at, so nothing could tell that a
-- row had moved under an editor. The CRM member profile now lets any exec edit
-- any member, and without this the only possible policy was last write wins: two
-- execs on the same member silently overwrite each other, undetectably.
--
-- Added with a DEFAULT rather than backfilled with an UPDATE on purpose. An
-- UPDATE across 434 rows would fire every trigger on this table, including the
-- async Mautic sync, enqueueing 434 outbound contact syncs to repair a column
-- nobody was reading yet.
alter table public.members
  add column if not exists updated_at timestamptz not null default now();

-- tg_set_updated_at already exists and is what the outreach tables use, so this
-- is the same mechanism rather than a second one that can drift from it.
drop trigger if exists trg_members_updated_at on public.members;
create trigger trg_members_updated_at
  before update on public.members
  for each row execute function public.tg_set_updated_at();

comment on column public.members.updated_at is
  'Maintained by trg_members_updated_at. Exists so the CRM member editor can detect that a row changed under it and refuse to clobber another exec.';
