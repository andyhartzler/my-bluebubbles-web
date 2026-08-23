-- claim_meeting_host: the never-overwrite guard, moved into SQL because
-- PostgREST cannot express it on an UPDATE.
--
-- WHY THIS EXISTS AT ALL
-- identify-meeting-host reads meetings.meeting_host near the top of its handler,
-- spends seconds in a model call, and then writes. A human confirming the host in
-- the CRM inside that gap must not be silently overwritten by a machine guess, so
-- the condition has to be part of the statement that writes. That reasoning is
-- unchanged and is the whole point of this function.
--
-- WHY IT IS NOT A .or() FILTER ANY MORE
-- It was written as
--   .update({...}).eq("id", id).or("meeting_host.is.null,meeting_host_source.eq.transcript")
-- and that shape NEVER WORKED. Probed live against this project on 2026-08-23:
-- a PATCH carrying an `or=` filter that names any column other than `id` answers
--
--   42703  column meetings.meeting_host does not exist
--
-- while the same filter on a GET returns the row, and the same column used as a
-- plain `meeting_host=is.null` filter on the same PATCH succeeds. So the column
-- plainly exists and it is the or-tree rendering on a mutation that breaks. The
-- edge function surfaced this as HTTP 500 "write failed: column
-- meetings.meeting_host does not exist" on every single write attempt, which is
-- why nothing has been backfilled since that filter was introduced.
--
-- An RPC puts the whole predicate in one statement, is enforced by the database
-- exactly as intended, and cannot be broken again by PostgREST filter rendering.
--
-- SECURITY INVOKER on purpose. The only caller is an edge function holding the
-- service role key, which bypasses RLS anyway, so there is nothing here that
-- needs SECURITY DEFINER and no reason to hand it a privilege escalation.

create or replace function public.claim_meeting_host(
  p_meeting_id uuid,
  p_host uuid,
  p_confidence numeric,
  p_evidence text
)
returns uuid
language sql
volatile
set search_path = public, pg_temp
as $$
  update public.meetings
     set meeting_host             = p_host,
         meeting_host_source      = 'transcript',
         meeting_host_confidence  = p_confidence,
         meeting_host_evidence    = left(p_evidence, 1000),
         meeting_host_inferred_at = now()
   where id = p_meeting_id
     -- The guard. NULL means nobody has claimed the slot; 'transcript' means this
     -- inferrer wrote it last and may refine its own answer. 'legacy', 'face' and
     -- anything a human sets are refused, and the caller sees a NULL return.
     and (meeting_host is null or meeting_host_source = 'transcript')
  returning id;
$$;

comment on function public.claim_meeting_host(uuid, uuid, numeric, text) is
  'Writes an inferred meeting host only if the slot is unclaimed or was last written by the same inferrer. Returns the meeting id on success and NULL when the guard refuses.';

revoke all on function public.claim_meeting_host(uuid, uuid, numeric, text) from public;
revoke all on function public.claim_meeting_host(uuid, uuid, numeric, text) from anon;
revoke all on function public.claim_meeting_host(uuid, uuid, numeric, text) from authenticated;
grant execute on function public.claim_meeting_host(uuid, uuid, numeric, text) to service_role;
