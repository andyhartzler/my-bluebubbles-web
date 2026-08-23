-- Revoking an executive's access did not stick, and the reversal was silent.
--
-- members.executive_committee is DERIVED. update_executive_committee_flag() sets it
-- from ('Executive Committee' = ANY(NEW.committee)). But the trigger was declared
-- BEFORE INSERT OR UPDATE **OF committee**, so it fires only when that one column
-- appears in the UPDATE's SET list.
--
-- revoke-executive-session wrote `.update({ executive_committee: false })` and never
-- named committee. So the trigger stayed quiet, the boolean went false, and the array
-- still said 'Executive Committee'. The next write touching committee for ANY reason
-- recomputed the boolean from the array and handed the access straight back.
--
-- Demonstrated on this database before the change, in a rolled-back transaction:
--   start = true, after revoke = false, after any committee write = TRUE
--
-- CRM access is executive-committee-only and the CRM reads the whole member and donor
-- file. Revocation is the control you reach for when someone leaves or a session is
-- compromised, and it was reversing itself with no error and nothing in a log.
--
-- The same shape runs the other way: invite_executive_dialog promotes with
-- `.update({'executive_committee': true})` and no committee entry, so the promotion
-- evaporates on the next committee write.
--
-- FIX: drop the column scope. The boolean is recomputed from the array on every
-- update, so the two can never diverge, and a direct write to the boolean becomes a
-- no-op. That is correct for a derived value; the array is the source of truth, which
-- is what the access model already assumes.
--
-- CONSEQUENCE, deliberate: a caller setting only the boolean now achieves nothing
-- instead of appearing to work and later reversing. It fails visibly. Revocation must
-- remove the array entry, which is what 20260824_05 provides.
--
-- Verified after applying, in a rolled-back transaction:
--   boolean-only revoke -> still true (inert)
--   array_remove revoke -> false (works)
drop trigger if exists trigger_update_executive_committee on public.members;

create trigger trigger_update_executive_committee
  before insert or update on public.members
  for each row execute function public.update_executive_committee_flag();
