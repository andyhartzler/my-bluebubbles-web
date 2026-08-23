-- AN IMPORT MAY ADD A COMMITTEE AND MAY REMOVE ONE IT MANAGES. IT MAY NOT
-- REPLACE THE LIST.
--
-- WHAT WAS WRONG. chapter-members-supabase and hs-chapters-supabase- both built
-- one dbMemberData object containing `committee: ['College Democrats']` or
-- `committee: ['High School Democrats']` and applied it with
-- `.update(dbMemberData).eq('id', matchedMember.id)`. A chapter roster import
-- therefore wrote the one committee it knows about and DISCARDED every other
-- committee on the row.
--
-- members.committee is not decoration, it is ACCESS.
-- trigger_update_executive_committee derives members.executive_committee from
-- that array on every insert or update of it, and CRM access is
-- executive-committee-only. So an import landing on an exec's row by the
-- name+phone or name+DOB match path silently revoked their CRM access, and
-- sync_committees_to_slack_trigger then pushed the removal on to Slack.
-- 20260823_05 fixed the same defect in slack-events; this is the other half.
--
-- THE DISTINCTION. Automation SHOULD keep derived membership current: if the
-- roster says someone is in the chapter, that lands. What it must not do is
-- remove a committee it does not know about. So the caller declares TWO sets:
--   p_managed  the committees this import is authoritative for
--   p_assigned the committees the roster says this person is in right now
-- Everything outside p_managed is untouched, whatever it is. A committee in
-- p_managed and not in p_assigned is removed, which is how a genuine departure
-- still works. Anything in p_assigned is added if missing.
--
-- WHY THIS IS ONE FUNCTION AND NOT ARRAY ARITHMETIC IN EACH CALLER. Five
-- callers each doing their own merge is five places to get it wrong later, and
-- a sixth caller inherits nothing. It also removes the read-modify-write
-- window: the row is locked and edited inside one statement, so a CRM edit made
-- between a caller's read and its write can no longer be lost.
--
-- WHY EXECUTIVE COMMITTEE IS NAMED AS A LITERAL. Same reason 20260823_05 names
-- it: members.committee gates CRM access on exactly one value, and a provenance
-- column or a per-committee flag table would be machinery built for a rule with
-- one case. The guard sits here rather than in the callers so that no future
-- caller can route around it, in BOTH directions. An import may not revoke CRM
-- access, and an import driven by a Google Sheet may not GRANT it either. If a
-- second access-gating committee ever exists, widen the checks here.
create or replace function public.import_merge_committees(
  p_member_id uuid,
  p_managed text[],
  p_assigned text[]
)
returns text[]
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_current  text[];
  v_next     text[] := '{}'::text[];
  v_managed  text[] := coalesce(p_managed, '{}'::text[]);
  v_assigned text[] := coalesce(p_assigned, '{}'::text[]);
  v_item     text;
begin
  select coalesce(committee, '{}'::text[])
    into v_current
    from public.members
   where id = p_member_id
     for update;

  if not found then
    return null;
  end if;

  -- Keep every existing committee except one this import both manages and no
  -- longer asserts. Executive Committee is never dropped here.
  foreach v_item in array v_current loop
    if v_item = any(v_managed)
       and not (v_item = any(v_assigned))
       and v_item <> 'Executive Committee' then
      continue;
    end if;
    if not (v_item = any(v_next)) then
      v_next := v_next || v_item;
    end if;
  end loop;

  -- Add what the roster asserts, except CRM access, which an import may not
  -- grant. Order is preserved: existing entries keep their positions and new
  -- ones append.
  foreach v_item in array v_assigned loop
    if v_item <> 'Executive Committee' and not (v_item = any(v_next)) then
      v_next := v_next || v_item;
    end if;
  end loop;

  if v_next is distinct from v_current then
    update public.members
       set committee = v_next
     where id = p_member_id;
  end if;

  return v_next;
end;
$function$;

comment on function public.import_merge_committees(uuid, text[], text[]) is
  'Merges an import''s committee assignment into members.committee inside one locked statement. Committees outside p_managed are never touched; a managed committee absent from p_assigned is removed; Executive Committee is neither removed nor added, because it gates CRM access. Returns the resulting array, or null when the member does not exist.';

revoke all on function public.import_merge_committees(uuid, text[], text[]) from public;
revoke all on function public.import_merge_committees(uuid, text[], text[]) from anon;
revoke all on function public.import_merge_committees(uuid, text[], text[]) from authenticated;
grant execute on function public.import_merge_committees(uuid, text[], text[]) to service_role;
