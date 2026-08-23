-- public.audit_log is RLS-protected and policy-gated. Its six monthly PARTITIONS
-- are not: relrowsecurity is false on every one of them and none carries a
-- policy, while anon and authenticated hold SELECT, INSERT and UPDATE on each.
--
-- Postgres checks privileges and RLS against the RELATION NAMED IN THE QUERY, so
-- the parent's protection does not cover a query aimed straight at a partition.
-- The only thing standing between the public anon key and the audit trail today
-- is that PostgREST keeps partitions out of its schema cache: probed live on
-- 2026-08-23, GET /rest/v1/audit_log_2026_09 with the publishable key answers
-- 404 PGRST205 rather than rows. That is a property of the API layer, not of the
-- database, and it is not something to rely on.
--
-- Revoking is the right shape here rather than enabling RLS on the partitions.
-- The audit trigger writes through the PARENT, so its privileges are checked
-- against the parent and are untouched by this; enabling RLS on leaf partitions
-- would be reasoning about the partition-routing path with a live audit trail as
-- the thing that breaks if the reasoning is wrong. service_role is deliberately
-- left alone, since it bypasses RLS anyway and the export job uses it.
--
-- Nothing legitimate reads a partition by name. The CRM and every edge function
-- query public.audit_log.
--
-- Verified against the running system, not by reading definitions. After this
-- ran: all six partitions carry no anon or authenticated grant at all; an
-- authenticated exec still SELECTs 500 rows from public.audit_log; and an UPDATE
-- on public.meetings performed AS authenticated still writes its audit row, so
-- the trigger path is intact.
do $$
declare p record;
begin
  for p in
    select c.relname
    from pg_class c
    join pg_inherits i on i.inhrelid = c.oid
    where i.inhparent = 'public.audit_log'::regclass
      and c.relnamespace = 'public'::regnamespace
  loop
    execute format('revoke all on public.%I from anon, authenticated', p.relname);
  end loop;
end $$;

-- Future partitions inherit the same problem the moment they are created, so
-- close the default as well as the six that exist. This binds only objects
-- created LATER by the role that owns the partition-creating path.
alter default privileges in schema public revoke all on tables from anon;
