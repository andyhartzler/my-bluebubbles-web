-- 20260427_06_donor_payee_rpc_security_definer.sql
--
-- Money-tab donor/payee detail screens were failing with
-- `42501: permission denied for table mec_contributions` because the
-- natural-key RPCs run LANGUAGE sql STABLE (SECURITY INVOKER), and the
-- `authenticated` role has no SELECT on mec_contributions, mec_donors,
-- mec_expenditures, donor_enrichment.
--
-- Fix: flip both RPCs to SECURITY DEFINER + lock down search_path so
-- the authenticated user can call them but the function body executes
-- with the function owner's privileges (which DO have SELECT on these
-- tables). This is the standard PostgREST pattern for "expose a
-- read-only view of restricted tables via an RPC".
--
-- Idempotent: ALTER FUNCTION ... SECURITY DEFINER and GRANT EXECUTE
-- both succeed regardless of prior state.

ALTER FUNCTION public.get_donor_profile_by_natural_key(text, text, text, text)
  SECURITY DEFINER
  SET search_path = public, pg_temp;

ALTER FUNCTION public.get_payee_profile_by_natural_key(text, text, text, text, text)
  SECURITY DEFINER
  SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.get_donor_profile_by_natural_key(text, text, text, text)
  TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_payee_profile_by_natural_key(text, text, text, text, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
