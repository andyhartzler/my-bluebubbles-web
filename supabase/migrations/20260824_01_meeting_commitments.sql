-- MEETING COMMITMENTS BECOME ROWS, SO THAT SOMEONE CAN OWN ONE AND CLOSE IT.
--
-- public.meetings.action_items is a single TEXT column holding one long
-- paragraph per meeting, written by the recap model. Nothing can be assigned
-- from it, nothing can be marked done in it, and nothing about it is checked
-- against the transcript it was derived from. The blob for the 2026-08-12
-- executive meeting names a real person by a Zoom device display name,
-- carries deadlines that are spoken nowhere in the transcript, and assigns
-- work that the chair audibly deferred. A paragraph cannot be wrong in a way
-- anybody notices, because there is no field to disagree with.
--
-- This table is the same information as rows: one owner, one commitment, one
-- status a person sets. The owner is a real public.members id, so a
-- commitment joins to the county the owner actually lives in and to the
-- members they are responsible for.
--
-- NO MEETING CONTENT IS WRITTEN IN THIS FILE. This repository is public. The
-- rows for any given meeting are loaded out of band against the database,
-- where public.meeting_commitments sits behind the same executive-only RLS as
-- the minutes it comes from. This file creates the shape and the guards only.

create table if not exists public.meeting_commitments (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,

  -- 'region'   an area of the state somebody took responsibility for
  -- 'task'     a piece of work somebody took on
  -- 'decision' something the meeting resolved, or explicitly did not
  kind text not null check (kind in ('region', 'task', 'decision')),

  -- DERIVED COLUMNS. Automation may keep these current, subject to the guard
  -- below: once a person edits one, that person owns it for good.
  owner_member_id uuid references public.members(id) on delete set null,
  owner_label text not null,
  commitment text not null,
  counties text[] not null default '{}',
  due_on date,
  evidence text,
  -- True when the commitment was recorded FOR somebody rather than BY them:
  -- assigned while they were absent, or inferred from a grouping they only
  -- half agreed to. An owner clearing this is the confirmation.
  needs_confirmation boolean not null default false,
  sort_order integer not null default 0,

  -- HUMAN COLUMNS. Automation may never write these. Not "should not": the
  -- trigger below puts the old values back.
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'done', 'deferred', 'dropped')),
  progress_note text,

  -- Names the derived columns a signed-in person has taken over. Maintained
  -- by the trigger, never by a client.
  human_edited_fields text[] not null default '{}',
  status_set_by uuid,
  status_set_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists meeting_commitments_meeting_idx
  on public.meeting_commitments (meeting_id, sort_order);
create index if not exists meeting_commitments_owner_idx
  on public.meeting_commitments (owner_member_id)
  where owner_member_id is not null;
create index if not exists meeting_commitments_counties_idx
  on public.meeting_commitments using gin (counties);

-- THE GUARD, IN THE STATEMENT THAT WRITES.
--
-- The rule this enforces was broken in this database within the last two
-- weeks: a person typed a meeting host on 2026-08-12 and a service_role write
-- erased it on 2026-08-20 (see 20260823_03). The value survived only because
-- the audit trigger kept a copy. The lesson taken there is taken here before
-- there is anything to lose: the protection is a trigger, so it holds for
-- PostgREST, psql, the dashboard, edge functions, pg_cron and any client
-- written later, rather than for one Dart screen.
--
-- Automation is identified the same way it is identified in 20260823_03:
-- every edge function calls with the service role and pg_cron carries no JWT,
-- so auth.uid() is null for all of them and non-null only for a signed-in end
-- user. There is no flag a caller can set to claim to be a person.
create or replace function public.fn_meeting_commitments_protect_human_edits()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  -- Columns automation is allowed to derive, until a person disagrees.
  derived_cols constant text[] := array[
    'owner_member_id', 'owner_label', 'commitment', 'counties',
    'due_on', 'evidence', 'needs_confirmation', 'sort_order'
  ];
  -- Columns automation is never allowed to write at all.
  human_cols constant text[] := array[
    'status', 'progress_note', 'human_edited_fields',
    'status_set_by', 'status_set_at'
  ];
  col text;
  new_json jsonb;
  old_json jsonb;
  patched jsonb;
begin
  new.updated_at := now();

  if tg_op = 'INSERT' then
    if auth.uid() is null then
      -- An importer created this row. Nothing here is a person's word yet.
      new.human_edited_fields := '{}';
      return new;
    end if;

    -- A person created this row by hand, so what they filled in is theirs.
    -- Columns left at their empty defaults are not claimed, otherwise a
    -- blank field would be locked against ever being enriched.
    new_json := to_jsonb(new);
    new.human_edited_fields := '{}';
    foreach col in array derived_cols loop
      if (new_json -> col) not in ('null'::jsonb, '""'::jsonb, '[]'::jsonb, '0'::jsonb, 'false'::jsonb) then
        new.human_edited_fields := new.human_edited_fields || col;
      end if;
    end loop;
    if new.status is distinct from 'open' or new.progress_note is not null then
      new.status_set_by := auth.uid();
      new.status_set_at := now();
    end if;
    return new;
  end if;

  new_json := to_jsonb(new);
  old_json := to_jsonb(old);

  if auth.uid() is not null then
    -- A signed-in person. Record which derived columns they changed; those
    -- stop being automation's to refresh from this point on. The list only
    -- grows here, so a client cannot launder a value by clearing it.
    new.human_edited_fields := old.human_edited_fields;
    foreach col in array derived_cols loop
      if (new_json -> col) is distinct from (old_json -> col)
         and not (col = any(new.human_edited_fields)) then
        new.human_edited_fields := new.human_edited_fields || col;
      end if;
    end loop;

    if new.status is distinct from old.status
       or new.progress_note is distinct from old.progress_note then
      new.status_set_by := auth.uid();
      new.status_set_at := now();
    end if;
    return new;
  end if;

  -- Automation. Put back everything that is not automation's to write: the
  -- human columns always, and each derived column a person has taken over.
  patched := new_json;
  foreach col in array (human_cols || old.human_edited_fields) loop
    patched := jsonb_set(patched, array[col], old_json -> col);
  end loop;
  new := jsonb_populate_record(new, patched);
  new.updated_at := now();
  return new;
end;
$function$;

drop trigger if exists trg_meeting_commitments_protect_human_edits
  on public.meeting_commitments;
create trigger trg_meeting_commitments_protect_human_edits
  before insert or update on public.meeting_commitments
  for each row execute function public.fn_meeting_commitments_protect_human_edits();

comment on function public.fn_meeting_commitments_protect_human_edits() is
  'Keeps automation out of the columns a person types. status and progress_note are restored on any service-role or cron UPDATE; so is every derived column a signed-in person has previously changed. Runs for every writer because it is a trigger, not application code.';

-- The UPDATE guard is worth nothing on its own, because the cheapest way to
-- re-derive a meeting is to delete its rows and insert them again, and that
-- destroys a person's status without ever issuing an UPDATE. So automation
-- may only delete rows nobody has touched. A re-derivation now has to update
-- in place, which is the path the guard above covers.
create or replace function public.fn_meeting_commitments_no_automated_delete()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
begin
  if auth.uid() is null
     and (old.human_edited_fields <> '{}'
          or old.status is distinct from 'open'
          or old.progress_note is not null) then
    raise exception
      'meeting_commitments %: a person has worked this row; automation may not delete it', old.id
      using errcode = 'check_violation',
            hint = 'Update the derived columns in place, or set status to dropped as a signed-in user.';
  end if;
  return old;
end;
$function$;

drop trigger if exists trg_meeting_commitments_no_automated_delete
  on public.meeting_commitments;
create trigger trg_meeting_commitments_no_automated_delete
  before delete on public.meeting_commitments
  for each row execute function public.fn_meeting_commitments_no_automated_delete();

comment on function public.fn_meeting_commitments_no_automated_delete() is
  'Stops a re-derivation routing around the human-edit guard by deleting and re-inserting the row.';

-- RLS. The CRM is executive-committee-only and these rows are minutes, so the
-- gate is is_staff() and there is deliberately no self-read policy: a member
-- who merely attended the meeting gets nothing, which is how meetings
-- themselves should read too but do not yet.
alter table public.meeting_commitments enable row level security;

drop policy if exists meeting_commitments_service_role on public.meeting_commitments;
create policy meeting_commitments_service_role on public.meeting_commitments
  as permissive for all to service_role
  using (true) with check (true);

drop policy if exists meeting_commitments_staff_all on public.meeting_commitments;
create policy meeting_commitments_staff_all on public.meeting_commitments
  as permissive for all to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

revoke all on public.meeting_commitments from anon;
grant select, insert, update, delete on public.meeting_commitments to authenticated;

comment on table public.meeting_commitments is
  'One row per thing a meeting actually committed somebody to. Replaces reading meetings.action_items as a paragraph. Executive-committee-only.';

-- WHERE NOBODY IS COVERING.
--
-- The point of recording an area owner as a row rather than a sentence is
-- that it can be subtracted from the membership. This view is that
-- subtraction: every county MOYD has members in, how many, and who if anyone
-- has taken it. A county with members and no owner is the finding.
--
-- security_invoker so the view reads with the caller's own RLS: an executive
-- sees the state, a member sees nothing.
create or replace view public.exec_region_coverage
with (security_invoker = true) as
with county_members as (
  select btrim(m.county) as county,
         count(*)::int as member_count
    from public.members m
   where m.county is not null
     and btrim(m.county) <> ''
   group by btrim(m.county)
),
owned as (
  select btrim(county) as county,
         array_agg(distinct owner_label order by owner_label)
           filter (where owner_label is not null) as owner_labels,
         array_agg(distinct owner_member_id)
           filter (where owner_member_id is not null) as owner_member_ids,
         bool_or(needs_confirmation) as any_unconfirmed,
         min(meeting_id::text)::uuid as first_meeting_id
    from public.meeting_commitments c
   cross join lateral unnest(c.counties) as county
   where c.kind = 'region'
     and c.status not in ('dropped', 'deferred')
   group by btrim(county)
)
select coalesce(cm.county, o.county) as county,
       coalesce(cm.member_count, 0) as member_count,
       coalesce(o.owner_labels, '{}') as owner_labels,
       coalesce(o.owner_member_ids, '{}') as owner_member_ids,
       coalesce(o.any_unconfirmed, false) as any_unconfirmed,
       (o.county is not null) as has_owner,
       o.first_meeting_id
  from county_members cm
  full outer join owned o on o.county = cm.county;

revoke all on public.exec_region_coverage from anon;
grant select on public.exec_region_coverage to authenticated;

comment on view public.exec_region_coverage is
  'Every county MOYD has members in, against the executive who took responsibility for it. Rows with has_owner = false and a member_count above zero are the gaps. Reads with the caller RLS, so non-executives see nothing.';
