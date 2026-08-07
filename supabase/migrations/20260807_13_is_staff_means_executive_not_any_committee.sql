-- ROOT CAUSE of the bulk-read exposure, and the reason narrowing the views alone
-- did not fix it.
--
-- is_staff() was defined as `executive_committee = true OR committee IS NOT NULL`.
-- `committee` is populated from the ordinary membership signup form, where an
-- applicant ticks which committees interest them. So expressing interest in a
-- committee granted staff authority. It matched 273 of the 419 members who hold a
-- login: 16 executives and 257 ordinary members.
--
-- is_staff() gates 137 RLS policies across 101 tables. Measured before this change
-- by impersonating a real ordinary member holding a committee value:
--   public.members      419 rows  (name, email, phone, home address, and the
--                                  special-category fields race, religion, sexual
--                                  orientation, disability, gender identity, plus
--                                  dates of birth belonging to minors)
--   public.subscribers  73,267 rows
--   public.donors       49 rows
--   public.donations    118 rows
-- Those are the base tables, read directly, by someone with no executive role.
--
-- THE GIVEAWAY IS THAT THE CORRECT FUNCTION ALREADY EXISTS.
-- public.is_committee_member() carries a byte-identical body to the old is_staff()
-- and is referenced by exactly zero policies. is_staff() was written as a copy of
-- the committee predicate and then wired everywhere authority was meant. Two names,
-- one meaning, and the wrong one load-bearing.
--
-- So this separates two models that were always intended rather than inventing one.
-- is_staff() now means executive authority. is_committee_member() keeps the broad
-- committee-interest meaning, unchanged, for anything that genuinely wants it.
--
-- NO UI LOSES ANYTHING. CRM access is already executive-committee-only, so the 257
-- ordinary members this removes could never reach these tables through any
-- interface; only by presenting their token straight to PostgREST. The member portal
-- is unaffected twice over: members_self_read is a separate self-scoped policy that
-- does not consult is_staff(), and the portal's edge functions
-- (get-member-dashboard, generate-wallet-passes, request-physical-card) read with
-- the service role, which bypasses RLS entirely.
--
-- VERIFIED AFTER APPLYING, by impersonation rather than by reading the definition.
-- Executive chair: members 419, subscribers 73267, donors 49, donations 118,
-- knowledge_documents 78830. Ordinary member: members 1 (their OWN row, via
-- members_self_read, which is correct), everything else 0.
--
-- REVERTING IS ONE STATEMENT if this proves too tight: restore the OR clause.
-- Prefer widening a specific policy to is_committee_member() over widening this.
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  SELECT COALESCE(
    (SELECT m.executive_committee FROM public.members m WHERE m.user_id = auth.uid() LIMIT 1),
    false
  );
$function$;
