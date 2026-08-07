-- LIVE UNAUTHENTICATED DATA BREACH. 37 views in the API schema carried a SELECT
-- grant to `anon`, and 34 of them had no security_invoker, so they executed as
-- their postgres owner and RLS on the base tables never applied.
--
-- Verified over the open internet with the publishable anon key that ships inside
-- the public browser bundle, not inferred from catalog state:
--   GET /rest/v1/members                     -> 401  42501 permission denied
--   GET /rest/v1/members_with_slack          -> 206  content-range 0-0/419
--   GET /rest/v1/subscribers_summary         -> 206  content-range 0-0/73267
--   GET /rest/v1/donor_profile_contributions -> 206  content-range 0-0/4348
-- The control on the base table is the point: the anon role was blocked there by a
-- missing GRANT. The views walked around it.
--
-- Exposed: all 419 rows of public.members including special-category data (race,
-- religion, sexual orientation, disability, gender identity) and dates of birth
-- belonging to minors; all 73,267 rows of public.subscribers; 4,348 donor
-- contribution rows with amounts attached to named individuals.
--
-- REVOKING RATHER THAN ONLY SETTING security_invoker, because the two failures are
-- independent and either alone would have been enough to prevent this. A missing
-- grant cannot leak even if a future view is created without security_invoker, and
-- security_invoker cannot leak even if a future grant is made. Both are applied
-- (see 20260807_12).
--
-- NOTHING ANON-FACING BREAKS. Every one of these 37 view names was grepped across
-- the public website's src/ tree and appears zero times. Only four appear anywhere
-- in either repo (dashboard_metrics, donor_profile_contributions,
-- event_analytics_summary, voting_forms) and all four are read by the Flutter CRM,
-- which authenticates and is executive-committee-only.
do $$
declare v record; n int := 0;
begin
  for v in
    select c.oid::regclass as rel
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relkind in ('v','m')
       and has_table_privilege('anon', c.oid, 'SELECT')
  loop
    execute format('revoke all on %s from anon', v.rel);
    n := n + 1;
  end loop;
  raise notice 'revoked anon from % views', n;
end $$;

-- Stop this recurring silently. Without it the next view postgres creates in this
-- schema is granted to anon by default, with no signal. That default is how 34
-- views ended up here without anyone making a decision.
alter default privileges for role postgres in schema public revoke select on tables from anon;
