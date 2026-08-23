-- meetings-zap must be able to record a Zoom-named host WITHOUT being able to
-- destroy one that is already there.
--
-- The gap this closes is written down in meetings-zap's own source:
--   "NOT fixed here, and it is a real gap: when this path DOES resolve a host
--    it still overwrites whatever is in the column, including a
--    meeting_host_source='human' confirmation."
-- It is not hypothetical. audit_log for meeting be6fbb14 shows service_role
-- writing meeting_host = null on 2026-08-20 over a value andrew@hartzler.us
-- had entered on 2026-08-12, then writing a different member on 2026-08-21.
--
-- WHY THIS IS AN RPC AND NOT A CHECK IN THE FUNCTION. meetings-zap reaches the
-- meeting row through an upsert on zoom_meeting_uuid, so there is no read of
-- the existing row to check against, and adding one would only move the race
-- rather than close it. The rule belongs in the statement that writes.
--
-- ZOOM MAY ONLY FILL AN EMPTY SLOT. The guard here is stricter than
-- claim_meeting_host's, deliberately. A transcript inference is allowed to
-- replace an earlier transcript inference because it is the same kind of
-- evidence, freshly computed. Zoom's host_name is a weaker signal than either
-- a human or a transcript: the executive committee shares one Zoom account, so
-- the field names whoever's credentials started the call, which is often not
-- who chaired it. It has nothing to add to a slot that is already filled.
create or replace function public.claim_meeting_host_from_zoom(
  p_meeting_id uuid,
  p_host uuid
)
returns uuid
language sql
set search_path to 'public', 'pg_temp'
as $function$
  update public.meetings
     set meeting_host        = p_host,
         meeting_host_source = 'zoom'
   where id = p_meeting_id
     and meeting_host is null
  returning id;
$function$;

comment on function public.claim_meeting_host_from_zoom(uuid, uuid) is
  'Fills meetings.meeting_host from the Zoom host field only when the slot is empty. Returns null when it refused, which the caller must report rather than treat as a write.';

revoke all on function public.claim_meeting_host_from_zoom(uuid, uuid) from public;
revoke all on function public.claim_meeting_host_from_zoom(uuid, uuid) from anon;
revoke all on function public.claim_meeting_host_from_zoom(uuid, uuid) from authenticated;
grant execute on function public.claim_meeting_host_from_zoom(uuid, uuid) to service_role;
