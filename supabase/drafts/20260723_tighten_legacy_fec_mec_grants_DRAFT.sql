-- DRAFT - DO NOT APPLY WITHOUT ANDREW SIGN-OFF (per standing rule: RLS changes to
-- existing tables are draft-then-approve).
-- Same tightening as 20260723_tighten_new_table_grants.sql, applied to the
-- PRE-EXISTING research tables that carry anon INSERT/UPDATE + FOR ALL USING(true)
-- policies: fec_contributions, fec_candidates, fec_committees, and the MEC bucket
-- equivalents (mec_donors, mec_contributions, mec_expenditures, mec_committees, ...).
-- Risk if left as-is: anyone holding the public anon key can write/corrupt research
-- money data. App impact of applying: none expected (app reads as authenticated;
-- pipelines write as postgres/service_role) - but verify no edge function writes
-- these tables under anon before applying.

REVOKE INSERT, UPDATE, TRIGGER, REFERENCES ON public.fec_contributions,
  public.fec_candidates, public.fec_committees FROM anon;
-- (enumerate MEC tables + policy rewrites after inventory; generate mechanically
--  from pg_policies WHERE qual='true' AND cmd='ALL' AND roles='{public}')
