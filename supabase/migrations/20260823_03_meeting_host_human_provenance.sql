-- A HAND-ENTERED MEETING HOST IS NOW LABELLED AS ONE, IN THE DATABASE.
--
-- WHAT WENT WRONG, from public.audit_log, meeting
-- be6fbb14-cefa-4413-95cd-8455aedeb805 (Executive Committee Meeting,
-- 2026-07-29):
--
--   2026-08-12 00:41  actor_role=authenticated, andrew@hartzler.us
--                     meeting_host: null -> f1ac8208
--   2026-08-20 22:43  actor_role=service_role
--                     meeting_host: f1ac8208 -> null
--   2026-08-21 00:14  actor_role=service_role
--                     meeting_host: null -> 163cd118
--
-- A person typed the host. Automation erased it eight days later and then
-- wrote a different person into the field. The value only still exists
-- because the audit trigger kept a copy.
--
-- WHY THE EXISTING GUARD DID NOT STOP IT. claim_meeting_host (20260823_02)
-- refuses to write unless `meeting_host is null or meeting_host_source =
-- 'transcript'`, which is correct and enforced in the statement. But NOTHING
-- EVER SET meeting_host_source = 'human'. The CRM meeting editor
-- (lib/screens/crm/editors/meeting_edit_sheet.dart) writes meeting_host on
-- its own; 20260822_03 then retro-stamped every unlabelled host 'legacy'. So
-- a human confirmation was indistinguishable from an unscored 2025 LLM guess,
-- and every guard keyed on provenance was reading a provenance nobody set.
--
-- Zero rows carry source='human' at the time of this migration. That is the
-- finding, not a coincidence.
--
-- THE FIX IS A TRIGGER, NOT A CHANGE TO THE APP. Two reasons.
--   1. The rule has to hold for every writer, including psql, the dashboard,
--      and any future client. A Dart change protects one screen.
--   2. The CRM has been UNABLE to record a host since 20260822_03 added the
--      validated CHECK meetings_host_needs_source (meeting_host is null or
--      meeting_host_source is not null). The editor sends meeting_host with
--      no source, so on any meeting with no host today that save fails with
--      23514. Stamping the source in a BEFORE trigger fixes the write and the
--      provenance in one place.
--
-- HOW AUTOMATION IS KEPT OUT OF THE 'human' LABEL. Every edge function calls
-- with the service role, where auth.uid() is null; pg_cron and pg_net calls
-- have no JWT at all. Only a signed-in end user has auth.uid(). The audit log
-- shows exactly this split: actor_role 'authenticated' with an actor_email
-- for the two human writes, 'service_role' or 'none' for everything else. So
-- an unprovenanced write can never be mislabelled gold: it is labelled human
-- only when a logged-in person made it.
create or replace function public.fn_meetings_stamp_human_host()
returns trigger
language plpgsql
set search_path to 'public', 'pg_temp'
as $function$
begin
  -- Not an end user. Automation states its own provenance or writes nothing.
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.meeting_host is not null and new.meeting_host_source is null then
      new.meeting_host_source      := 'human';
      new.meeting_host_confidence  := null;
      new.meeting_host_evidence    := null;
      new.meeting_host_inferred_at := null;
    end if;
    return new;
  end if;

  -- A person changed who hosted and did not state a provenance themselves.
  -- That is a hand-entered fact. The machine confidence and evidence beside
  -- it described the guess this replaces, so they are cleared rather than
  -- left to describe a value they were never about.
  if new.meeting_host is not null
     and new.meeting_host is distinct from old.meeting_host
     and new.meeting_host_source is not distinct from old.meeting_host_source then
    new.meeting_host_source      := 'human';
    new.meeting_host_confidence  := null;
    new.meeting_host_evidence    := null;
    new.meeting_host_inferred_at := null;
  end if;

  -- A person clearing the host is not a confirmation of anything, so the row
  -- must not keep claiming a provenance for a host that is gone. Cleared this
  -- way the slot is empty and every inferrer may fill it again.
  if new.meeting_host is null
     and old.meeting_host is not null
     and new.meeting_host_source is not distinct from old.meeting_host_source then
    new.meeting_host_source      := null;
    new.meeting_host_confidence  := null;
    new.meeting_host_evidence    := null;
    new.meeting_host_inferred_at := null;
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_meetings_stamp_human_host on public.meetings;
create trigger trg_meetings_stamp_human_host
  before insert or update of meeting_host on public.meetings
  for each row execute function public.fn_meetings_stamp_human_host();

comment on function public.fn_meetings_stamp_human_host() is
  'Labels meetings.meeting_host as source=human when a signed-in person sets it, so guards keyed on provenance can refuse to overwrite it. Service-role and cron writes are untouched: they have no auth.uid().';

-- RESTORE THE ONE VALUE AUTOMATION DESTROYED.
--
-- be6fbb14 currently reads 163cd118, written by service_role on 2026-08-21
-- over the 2026-08-12 entry of f1ac8208. Two independent reasons to restore
-- rather than leave it:
--   - a person entered f1ac8208 and no person has ever changed it since;
--   - the face-matching pass on 2026-08-23 wrote, into this row's own
--     evidence, that the recorded host and the shared-account tile match
--     DISAGREE, and the tile match is the value the person had entered. The
--     machine evidence in the row already contradicted the machine value in
--     the row.
-- Names are deliberately not written here. This repo is public and a
-- face-match result attached to a named person does not belong in it; the
-- member ids above are enough to act on and audit_log holds the rest.
-- That evidence text described the guess being replaced, so it does not
-- survive on the row; audit_log keeps it.
update public.meetings
   set meeting_host             = 'f1ac8208-ad64-405f-8b55-8284ddef51cf',
       meeting_host_source      = 'human',
       meeting_host_confidence  = null,
       meeting_host_evidence    = null,
       meeting_host_inferred_at = null
 where id = 'be6fbb14-cefa-4413-95cd-8455aedeb805';

-- 23149467 already holds the value Andrew typed on 2026-07-14; only its label
-- is wrong. 20260822_03 stamped it 'legacy' along with the machine guesses.
-- The host itself is not touched here.
update public.meetings
   set meeting_host_source      = 'human',
       meeting_host_confidence  = null,
       meeting_host_evidence    = null,
       meeting_host_inferred_at = null
 where id = '23149467-16cd-4799-9025-96c0aa0010de'
   and meeting_host = 'f1ac8208-ad64-405f-8b55-8284ddef51cf';
