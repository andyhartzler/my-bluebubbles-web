-- MOYD membership age gate, hard-coded into public.members.
-- Rule (Andrew, 2026-07-14): CALENDAR-YEAR, not exact birthday. Eligibility is
-- the age you TURN this calendar year: age_this_year = current year - birth year.
--   turn 13 this year .. turn 35 this year  => eligible (13 through under 36)
--   turn 12 or younger this year            => too_young
--   turn 36 or older this year              => aged_out
-- Missing birth date/year => eligible (never hard-block on absent data).
-- Everything lives in the public schema. Never touch the listmonk schema.

-- Authoritative 3-way branch function (single source of truth for the DB flag
-- AND the onboarding edge function, which calls it via RPC).
CREATE OR REPLACE FUNCTION public.moyd_age_branch(p_dob date, p_birth_year integer DEFAULT NULL)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
    WHEN COALESCE(EXTRACT(YEAR FROM p_dob)::int, p_birth_year) IS NULL THEN 'eligible'
    WHEN (EXTRACT(YEAR FROM CURRENT_DATE)::int - COALESCE(EXTRACT(YEAR FROM p_dob)::int, p_birth_year)) < 13 THEN 'too_young'
    WHEN (EXTRACT(YEAR FROM CURRENT_DATE)::int - COALESCE(EXTRACT(YEAR FROM p_dob)::int, p_birth_year)) > 35 THEN 'aged_out'
    ELSE 'eligible'
  END;
$$;

-- There is already a trigger (trigger_update_membership_eligible ->
-- update_membership_eligible) that owns members.membership_eligible. Its old body
-- used exact-birthday "under 36" with NO minimum age and ignored birth_year, and
-- it fires after any duplicate we add (alphabetical order), so it would overwrite
-- us. Replace THAT function with the calendar-year rule (via moyd_age_branch) so
-- there is one owner, and extend its trigger to also fire on birth_year.
CREATE OR REPLACE FUNCTION public.update_membership_eligible()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  NEW.membership_eligible := (public.moyd_age_branch(NEW.date_of_birth, NEW.birth_year) = 'eligible');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_update_membership_eligible ON public.members;
CREATE TRIGGER trigger_update_membership_eligible
  BEFORE INSERT OR UPDATE OF date_of_birth, birth_year ON public.members
  FOR EACH ROW EXECUTE FUNCTION public.update_membership_eligible();

-- One-time backfill so existing rows reflect the rule (corrects prior drift).
UPDATE public.members
SET membership_eligible = (public.moyd_age_branch(date_of_birth, birth_year) = 'eligible');
