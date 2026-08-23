-- An explicit, deliberate way to remove someone from the Executive Committee.
--
-- public.slack_remove_committee() refuses this on purpose: it carries
-- `and p_committee <> 'Executive Committee'` so a Slack channel-leave event can never
-- revoke somebody's CRM access. That guard is correct and stays. A member wandering
-- out of a Slack channel must not cost them the member database.
--
-- But revocation is a real operation. When someone leaves, or a session is
-- compromised, an admin has to actually remove them, and after 20260824_04 writing
-- executive_committee = false is a no-op because the flag is recomputed from the array.
--
-- The two paths are separated by intent rather than by accident:
--   slack_remove_committee        automated, refuses Executive Committee
--   slack_remove_committee_force  deliberate admin action, allows it
--
-- Restricted to service_role. The only caller is revoke-executive-session, which
-- authenticates the requester as a superadmin first. NOT granted to authenticated, so
-- no member and no browser session can reach it even with a valid token.
--
-- One statement, so there is no read-modify-write window on the security path, and the
-- derived flag falls out of the same UPDATE via the trigger.
--
-- Verified after applying: before=true, after force revoke=false, still in array=false.
create or replace function public.slack_remove_committee_force(
  p_member_id uuid,
  p_committee text
)
returns boolean
language sql
security definer
set search_path to 'public'
as $function$
  update public.members
     set committee = array_remove(coalesce(committee, '{}'), p_committee)
   where id = p_member_id
     and coalesce(committee, '{}') @> array[p_committee]
  returning true;
$function$;

revoke execute on function public.slack_remove_committee_force(uuid, text) from public;
revoke execute on function public.slack_remove_committee_force(uuid, text) from anon;
revoke execute on function public.slack_remove_committee_force(uuid, text) from authenticated;
grant  execute on function public.slack_remove_committee_force(uuid, text) to service_role;
