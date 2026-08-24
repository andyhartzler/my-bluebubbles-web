-- THE TILE WOULD HAVE DISAGREED WITH THE LIST IT OPENS.
--
-- exec_region_coverage counted every member with a county. The members list the
-- tile taps through to does not: MemberRepository._applyMemberFilters applies
-- `.eq('membership_eligible', true)` unconditionally, at
-- lib/services/crm/member_repository.dart:217, on both the fetch and the count.
-- 27 of 425 members are not eligible.
--
-- So "Jackson, 65 members" opened a list of 62, and "Randolph, 1" opened an
-- empty one. Measured before this ran: SEVENTEEN counties disagreed, including
-- Cape Girardeau 22 against 18, which is the county with the worst phone
-- coverage in the state and therefore the one most likely to be looked at
-- twice.
--
-- A number that does not survive being tapped is worse than no number. Fixed
-- here rather than in Dart so every future reader of this view inherits the
-- same universe as the list.
--
-- phone_count is added at the same time because it is the number that changes a
-- decision rather than reporting one. "Call Clay" is 23 of 25 reachable. "Call
-- Cape Girardeau" is 5 of 18, which is not a calling job at all, and the chair
-- said in the meeting that thin regions should phone bank instead. It counts
-- phone_e164 rather than phone, because that is the column the messaging path
-- dials, so this stays consistent with what the CRM can actually reach rather
-- than inventing a second definition of reachable.
--
-- phone_count is APPENDED, not placed next to member_count where it belongs.
-- CREATE OR REPLACE VIEW cannot rename or reorder existing columns, it can only
-- add to the end, and it raised 42P16 when this was first written the tidy way.
-- Column order is not worth a DROP: pg_class.reloptions is {security_invoker=true}
-- and there is no grant to anon, both verified before writing this, and a DROP
-- loses the reloption. A view over members that loses security_invoker runs as
-- its owner and hands the whole member file past RLS.
--
-- Applied and verified 2026-08-24 by impersonation, not by reading the policy:
-- as the chair, all 62 counties agree with the list exactly, phone_count is
-- populated, reloptions still {security_invoker=true}, anon still cannot select.
create or replace view public.exec_region_coverage
with (security_invoker = true) as
with county_members as (
  select btrim(m.county) as county,
         count(*)::integer as member_count,
         count(*) filter (
           where m.phone_e164 is not null and btrim(m.phone_e164) <> ''
         )::integer as phone_count
    from members m
   where m.county is not null
     and btrim(m.county) <> ''
     -- The list the tile opens applies exactly this. Keep them identical.
     and m.membership_eligible is true
   group by btrim(m.county)
), owned as (
  select btrim(county.county) as county,
         array_agg(distinct c.owner_label order by c.owner_label)
           filter (where c.owner_label is not null) as owner_labels,
         array_agg(distinct c.owner_member_id)
           filter (where c.owner_member_id is not null) as owner_member_ids,
         bool_or(c.needs_confirmation) as any_unconfirmed,
         min(c.meeting_id::text)::uuid as first_meeting_id
    from meeting_commitments c
         cross join lateral unnest(c.counties) county(county)
   where c.kind = 'region'
     and c.status <> all (array['dropped'::text, 'deferred'::text])
   group by btrim(county.county)
)
select coalesce(cm.county, o.county) as county,
       coalesce(cm.member_count, 0) as member_count,
       coalesce(o.owner_labels, '{}'::text[]) as owner_labels,
       coalesce(o.owner_member_ids, '{}'::uuid[]) as owner_member_ids,
       coalesce(o.any_unconfirmed, false) as any_unconfirmed,
       o.county is not null as has_owner,
       o.first_meeting_id,
       coalesce(cm.phone_count, 0) as phone_count
  from county_members cm
       full join owned o on o.county = cm.county
 where (select is_staff());

comment on view public.exec_region_coverage is
  'Executive planning surface: members per county against the region owners '
  'assigned at an executive meeting. Counts ONLY membership_eligible members, '
  'because that is what the members list shows, and a count that changes when '
  'you tap it destroys trust in the surface. phone_count is phone_e164, the '
  'column the messaging path dials. security_invoker: replace, never drop.';
