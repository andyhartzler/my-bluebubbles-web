-- THE COVERAGE VIEW LEAKED ONE ROW TO EVERY SIGNED-IN MEMBER.
--
-- Found by impersonating a real non-executive member rather than by reading
-- the policy. public.meeting_commitments correctly returned zero rows to
-- them, so the table gate was right. public.exec_region_coverage returned
-- one: their own county, member_count 1, no owners.
--
-- The cause is that security_invoker was doing exactly what it should. The
-- view aggregates public.members, and members carries members_self_read, so
-- a member reading the view aggregates the one row they are allowed to see.
-- Nobody else's data crossed the boundary, so this is not a disclosure. It is
-- still wrong: the view is an executive planning surface, its own comment
-- says a member sees nothing, and a member who reached it would be shown a
-- one-county picture of the state that reads as fact.
--
-- Reading the policy would never have found this. The policy is correct. The
-- aggregate over it is what was not.
create or replace view public.exec_region_coverage
with (security_invoker = true) as
with county_members as (
  select btrim(m.county) as county,
         count(*)::int as member_count
    from public.members m
   where m.county is not null
     and btrim(m.county) <> ''
   group by btrim(m.county)
),
owned as (
  select btrim(county) as county,
         array_agg(distinct owner_label order by owner_label)
           filter (where owner_label is not null) as owner_labels,
         array_agg(distinct owner_member_id)
           filter (where owner_member_id is not null) as owner_member_ids,
         bool_or(needs_confirmation) as any_unconfirmed,
         min(meeting_id::text)::uuid as first_meeting_id
    from public.meeting_commitments c
   cross join lateral unnest(c.counties) as county
   where c.kind = 'region'
     and c.status not in ('dropped', 'deferred')
   group by btrim(county)
)
select coalesce(cm.county, o.county) as county,
       coalesce(cm.member_count, 0) as member_count,
       coalesce(o.owner_labels, '{}') as owner_labels,
       coalesce(o.owner_member_ids, '{}') as owner_member_ids,
       coalesce(o.any_unconfirmed, false) as any_unconfirmed,
       (o.county is not null) as has_owner,
       o.first_meeting_id
  from county_members cm
  full outer join owned o on o.county = cm.county
 -- The gate the table already had, applied to the aggregate as well. Kept as
 -- a scalar subquery so it is evaluated once per statement rather than per
 -- row, matching the (select is_staff()) form used in the policies.
 where (select public.is_staff());

revoke all on public.exec_region_coverage from anon;
grant select on public.exec_region_coverage to authenticated;

comment on view public.exec_region_coverage is
  'Every county MOYD has members in, against the executive who took responsibility for it. Rows with has_owner = false and a member_count above zero are the gaps. Executive-committee-only: gated on is_staff() in the view body, because security_invoker alone still let a member aggregate their own members row into a one-county answer.';
