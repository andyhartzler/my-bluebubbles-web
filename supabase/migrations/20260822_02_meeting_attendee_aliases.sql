-- Durable Zoom display-name -> member aliases.
--
-- Why this exists: meetings-zap matches a Zoom participant to a member by
-- email, then by name. Two things defeat that and put an executive committee
-- member in "Guest Participants" every single month:
--   1. A device display name ("James iPhone") is short-circuited before any
--      matching is attempted at all.
--   2. The member fetch is capped, so a member outside the fetched window is
--      invisible to name matching.
-- Both are fixed in the function, but neither fix can cover a display name
-- that simply is not derivable from the member's name. Once a human resolves
-- one, it must be remembered forever. That is this table.
--
-- Lookup key is the same normalization meetings-zap applies in JS:
-- lowercase, NFD, drop everything that is not [a-z0-9].

create table if not exists public.meeting_attendee_aliases (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  display_name_key text not null,
  member_id uuid not null references public.members(id) on delete cascade,
  learned_from_meeting_id uuid references public.meetings(id) on delete set null,
  confirmed_by uuid,
  confirmed_by_label text,
  confirmed_at timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.meeting_attendee_aliases is
  'Zoom display name -> member. Written when a human resolves a guest participant to a member; read by meetings-zap before any fuzzy matching. One member per display name.';
comment on column public.meeting_attendee_aliases.display_name_key is
  'Normalized lookup key: lower(normalize(display_name, NFD)) with all non [a-z0-9] removed. Matches normalizeString() in meetings-zap.';
comment on column public.meeting_attendee_aliases.learned_from_meeting_id is
  'The meeting whose guest list this alias was resolved from.';
comment on column public.meeting_attendee_aliases.confirmed_by is
  'auth.uid() of the executive who confirmed it, when resolved in the CRM. Null for aliases seeded by backfill.';

create or replace function public.meeting_attendee_alias_key(p_name text)
returns text
language sql
immutable
set search_path = public
as $$
  select regexp_replace(lower(normalize(coalesce(p_name, ''), NFD)), '[^a-z0-9]', '', 'g')
$$;

comment on function public.meeting_attendee_alias_key(text) is
  'Normalization shared by meeting_attendee_aliases and meetings-zap. Keep in sync with normalizeString() in supabase/functions/meetings-zap/index.ts.';

create or replace function public.meeting_attendee_aliases_set_key()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.display_name_key := public.meeting_attendee_alias_key(new.display_name);
  if new.display_name_key = '' then
    raise exception 'display_name must contain at least one alphanumeric character';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists meeting_attendee_aliases_key_trg on public.meeting_attendee_aliases;
create trigger meeting_attendee_aliases_key_trg
  before insert or update on public.meeting_attendee_aliases
  for each row execute function public.meeting_attendee_aliases_set_key();

-- One member per display name. A second, different answer for the same name
-- is a contradiction rather than a rejoin, so it must fail loudly.
create unique index if not exists meeting_attendee_aliases_key_uidx
  on public.meeting_attendee_aliases (display_name_key);

create index if not exists meeting_attendee_aliases_member_idx
  on public.meeting_attendee_aliases (member_id);

alter table public.meeting_attendee_aliases enable row level security;

drop policy if exists meeting_attendee_aliases_exec_all on public.meeting_attendee_aliases;
create policy meeting_attendee_aliases_exec_all
  on public.meeting_attendee_aliases
  for all
  to authenticated
  using (public.is_executive())
  with check (public.is_executive());

grant select, insert, update, delete on public.meeting_attendee_aliases to authenticated;
grant execute on function public.meeting_attendee_alias_key(text) to authenticated;
