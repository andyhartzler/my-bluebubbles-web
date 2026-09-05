-- APPLIED TO PRODUCTION 2026-09-05.
--
-- PRIVILEGE ESCALATION. public.members carries a members_self_update RLS policy,
-- USING and WITH CHECK both (user_id = auth.uid()). RLS is ROW level, not column
-- level, so that policy let a signed-in member rewrite ANY column on their own
-- row, and the BEFORE trigger update_executive_committee_flag derives
-- executive_committee := ('Executive Committee' = ANY(committee)).
--
-- So any of the 438 members holding a login could PATCH their own row with
-- committee = '{Executive Committee}' and thereby satisfy public.is_staff(),
-- which gates every exec-only policy in this database: the member roster and its
-- PII, the subscriber list, donors, outreach touchpoints and activities. Member
-- to full CRM admin, self-service.
--
-- RLS cannot express "these columns are frozen" in WITH CHECK, because a policy
-- sees only the candidate row and never OLD. Column level GRANTs cannot either,
-- because execs write these same columns through the same `authenticated` role.
-- A BEFORE trigger is the one place that sees OLD, NEW and the caller together.
--
-- Verified by impersonating a real non-exec member and running the attack: it is
-- refused with 42501 and the exec count is unchanged.
create or replace function public.guard_member_privilege_columns()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- No JWT means service_role, an edge function or another trigger. Those are
  -- backend paths that legitimately set these columns.
  if auth.uid() is null then return new; end if;
  -- Executives may administer anyone, including themselves. This is what keeps
  -- the CRM's own member editor working.
  if public.is_staff() then return new; end if;

  if new.committee is distinct from old.committee
     or new.executive_committee is distinct from old.executive_committee
     or new.executive_title is distinct from old.executive_title
     or new.executive_role is distinct from old.executive_role
     or new.user_id is distinct from old.user_id
     or new.membership_eligible is distinct from old.membership_eligible
  then
    raise exception
      'Committee membership and access fields can only be changed by the executive committee'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end; $$;

-- Name matters. Same-timing triggers fire alphabetically, and "guard_" sorts
-- before "trigger_update_executive_committee", so this sees the committee array
-- exactly as the client sent it rather than after the flag trigger derived from it.
drop trigger if exists guard_member_privilege_columns on public.members;
create trigger guard_member_privilege_columns
  before update on public.members
  for each row execute function public.guard_member_privilege_columns();
