-- Convert MEC research RPCs to SECURITY DEFINER so they bypass RLS on
-- mec_donors / mec_contributions / donor_enrichment when called by the
-- authenticated role. Without this, the function executes as the caller,
-- RLS filters block the join (returning 0 rows), AND the planner still
-- scans the indexes — producing both empty results AND statement-timeout
-- errors at the 8s authenticated-role limit.

ALTER FUNCTION public.search_donors_v3(
  text, text, text, text, integer, integer, numeric, numeric, text,
  text, text, text, integer, integer, boolean, boolean, boolean,
  boolean, text, integer, integer
) SECURITY DEFINER SET search_path = public, pg_temp;

ALTER FUNCTION public.get_donor_unified_profile(integer)
  SECURITY DEFINER SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.search_donors_v3(
  text, text, text, text, integer, integer, numeric, numeric, text,
  text, text, text, integer, integer, boolean, boolean, boolean,
  boolean, text, integer, integer
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_donor_unified_profile(integer) TO authenticated;
