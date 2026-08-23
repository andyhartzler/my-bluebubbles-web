-- SLACK MAY NOT REVOKE A COMMITTEE THAT GATES CRM ACCESS, AND ITS COMMITTEE
-- WRITES ARE NO LONGER READ-MODIFY-WRITE.
--
-- WHAT HAPPENED. public.audit_log, 2026-08-12 01:39:39, actor_role
-- service_role, member e6d85cb1-c1eb-44cc-be07-2411fc21785a:
--
--   committee: ["High School Democrats","Executive Committee","Speak Your Mind"]
--           -> ["High School Democrats","Speak Your Mind"]
--
-- That is slack-events handling member_left_channel. public
-- .slack_channel_committee_mapping maps the #executive-committee channel to
-- the 'Executive Committee' committee and the row is active, so leaving that
-- Slack channel removes the committee. members.committee is the source of
-- truth for CRM access and the executive_committee boolean is derived from it
-- by trigger, so that write revoked a person's CRM access. Nobody chose it and
-- no record of the removal exists outside the audit log.
--
-- Slack channel membership is a CONSEQUENCE of a committee assignment, not a
-- cause of one: sync_committees_to_slack already pushes the other direction.
-- An inbound removal is a person tidying a sidebar, and the outbound sync will
-- put them back in the channel anyway.
--
-- THE SECOND DEFECT IS THE SHAPE OF THE WRITE. Both slack-events paths read
-- members.committee, edit the array in JS, and write the whole array back.
-- That is check-then-write on a column: an exec assignment made in the CRM
-- between the read and the write is silently discarded, and the write reports
-- success. Doing the edit inside the UPDATE removes the window entirely.
--
-- WHY THE EXEC COMMITTEE IS NAMED AS A LITERAL. Because that is the whole
-- requirement. members.committee gates CRM access on exactly one value, and a
-- provenance column or a per-committee flag table would be machinery built for
-- a rule that has one case. If a second access-gating committee ever exists,
-- widen the array here.
create or replace function public.slack_add_committee(
  p_member_id uuid,
  p_committee text
)
returns text[]
language sql
set search_path to 'public', 'pg_temp'
as $function$
  update public.members
     set committee = coalesce(committee, '{}'::text[]) || array[p_committee]
   where id = p_member_id
     and not (coalesce(committee, '{}'::text[]) @> array[p_committee])
  returning committee;
$function$;

comment on function public.slack_add_committee(uuid, text) is
  'Appends one committee to members.committee in a single statement, so a concurrent CRM edit cannot be lost. Returns null when the member already had it or does not exist.';

create or replace function public.slack_remove_committee(
  p_member_id uuid,
  p_committee text
)
returns text[]
language sql
set search_path to 'public', 'pg_temp'
as $function$
  update public.members
     set committee = array_remove(committee, p_committee)
   where id = p_member_id
     and committee @> array[p_committee]
     -- Leaving a Slack channel does not revoke CRM access. The guard is here
     -- rather than in the caller so that no future caller can route around it.
     and p_committee <> 'Executive Committee'
  returning committee;
$function$;

comment on function public.slack_remove_committee(uuid, text) is
  'Removes one committee from members.committee in a single statement, and REFUSES to remove Executive Committee, which gates CRM access. Returns null when it refused or when the member did not have it; the caller must report that rather than treat it as a write.';

revoke all on function public.slack_add_committee(uuid, text) from public;
revoke all on function public.slack_add_committee(uuid, text) from anon;
revoke all on function public.slack_add_committee(uuid, text) from authenticated;
grant execute on function public.slack_add_committee(uuid, text) to service_role;

revoke all on function public.slack_remove_committee(uuid, text) from public;
revoke all on function public.slack_remove_committee(uuid, text) from anon;
revoke all on function public.slack_remove_committee(uuid, text) from authenticated;
grant execute on function public.slack_remove_committee(uuid, text) to service_role;
