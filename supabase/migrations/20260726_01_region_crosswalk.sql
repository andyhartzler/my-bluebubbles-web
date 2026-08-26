-- COUNTY -> DISTRICT CROSSWALK, SO A COUNTY CAN NAME ITS OVERLAPPING RACES.
--
-- Counties are not a ballot unit. A voter in a county belongs to one
-- congressional, one house and one senate district, and a county overlaps
-- whichever of those its voters fall into. County-mode candidate resolution
-- needs that overlap set, and computing it at runtime would mean either a GIS
-- point-in-polygon pass or a scan of 4.34M voter rows on every county tap.
-- This table is that overlap precomputed once: for each county the office
-- districts its voters actually live in, with a voter count so a sliver of
-- misassigned rows can be told from a real overlap.
--
-- KEYED TO THE MAP, NOT TO THE VOTER FILE. The client selects a county by the
-- `county` property in assets/geojson/mo_counties.geojson, so the key here is
-- the geojson label, not the voter-file spelling. Two reconciliations are
-- baked in and both are load-bearing:
--
--   * De Kalb (voter file) -> DeKalb (geojson). A spelling difference only.
--
--   * St. Louis City (voter file) -> St. Louis (geojson). The geojson carries
--     TWO polygons labelled "St. Louis", geoid 29189 (the county) and geoid
--     29510 (the independent city). Both share the map key "St. Louis", so a
--     tap on either selects the same key, and the crosswalk for "St. Louis"
--     is deliberately the union of county and city voters. Keeping them apart
--     would leave the city's districts unreachable from the map.
--
-- Kansas City is the honest gap. The voter file carries a "Kansas City"
-- pseudo-county, the Kansas City Election Board's jurisdiction, which has NO
-- county polygon of its own and physically spans Jackson, Clay, Platte and
-- Cass. It is inserted under its own key "Kansas City" and nothing else. It
-- is NOT split back across those four counties: the voter file does not say
-- which KC voter sits in which surrounding county, so any split would be
-- invented. Consequence: a tap on the Jackson/Clay/Platte/Cass polygons will
-- not surface the KC-jurisdiction races, and there is no polygon a "Kansas
-- City" key can ever be reached from. This is recorded rather than papered
-- over.
--
-- DERIVED REFERENCE DATA. Every row is computed from public.mo_voter_file
-- below. There is nothing member-specific or private in it, but it is still
-- gated to the executive committee like the rest of the CRM.

create table if not exists public.region_crosswalk (
  county      text    not null,
  -- 'congressional' | 'house' | 'senate'. 'house' comes from the voter file's
  -- legislative_district column, which is the Missouri House.
  office_type text    not null check (office_type in ('congressional', 'house', 'senate')),
  -- Bare district digits, leading zeros stripped: '2', '63', not '20 LE 063'.
  -- Matches ElectionResult.district and the officeType:bareDigits key shape
  -- the candidate index uses.
  district    text    not null,
  voter_count integer not null,
  primary key (county, office_type, district)
);

comment on table public.region_crosswalk is
  'Precomputed county-to-district overlap from public.mo_voter_file, keyed to the assets/geojson/mo_counties.geojson county label so county-mode on the volunteers map can name its overlapping congressional/house/senate races with zero runtime GIS. St. Louis City folds into St. Louis (shared map key); De Kalb folds into DeKalb (spelling); Kansas City is its own key with no polygon.';

-- Idempotent rebuild. This is derived, so it is safe to wipe and recompute:
-- there is no human-entered state to lose.
truncate table public.region_crosswalk;

insert into public.region_crosswalk (county, office_type, district, voter_count)
with base as (
  select
    case
      -- The city polygon shares the map key "St. Louis"; fold its voters in.
      when vf.county = 'St. Louis City' then 'St. Louis'
      -- Voter-file spelling differs from the geojson label.
      when vf.county = 'De Kalb'        then 'DeKalb'
      else vf.county
    end as county,
    -- District values are '<year> <TYPE> <number>', number zero-padded, e.g.
    -- '20 CN 2', '20 LE 063', '20 SE 02'. Correct parse is the TRAILING
    -- number with leading zeros stripped. A digits-only replace would splice
    -- the year onto the number and corrupt every House district, so it is not
    -- used here.
    nullif(ltrim((regexp_match(vf.congressional_district, '([0-9]+)\s*$'))[1], '0'), '') as cd,
    nullif(ltrim((regexp_match(vf.legislative_district,   '([0-9]+)\s*$'))[1], '0'), '') as hd,
    nullif(ltrim((regexp_match(vf.senate_district,        '([0-9]+)\s*$'))[1], '0'), '') as sd
  from public.mo_voter_file vf
  where vf.county is not null
    and btrim(vf.county) <> ''
),
unpivoted as (
  select county, 'congressional'::text as office_type, cd as district from base where cd is not null
  union all
  select county, 'house'::text,               hd            from base where hd is not null
  union all
  select county, 'senate'::text,              sd            from base where sd is not null
)
select county, office_type, district, count(*)::int as voter_count
from unpivoted
group by county, office_type, district
-- Floor. A county overlaps a district for real when a meaningful number of its
-- voters live there; a handful is a data-entry stray, not an overlap. 25 drops
-- the strays without touching any genuine split.
having count(*) >= 25;

-- RLS. The CRM is executive-committee-only. This is reference data rather than
-- personal data, but it is gated the same way as everything else the client
-- reads, on public.is_staff(). The service_role policy is for the migration
-- and any future backfill; clients only ever read.
alter table public.region_crosswalk enable row level security;

drop policy if exists region_crosswalk_service_role on public.region_crosswalk;
create policy region_crosswalk_service_role on public.region_crosswalk
  as permissive for all to service_role
  using (true) with check (true);

drop policy if exists region_crosswalk_staff_read on public.region_crosswalk;
create policy region_crosswalk_staff_read on public.region_crosswalk
  as permissive for select to authenticated
  using ((select public.is_staff()));

revoke all on public.region_crosswalk from anon;
grant select on public.region_crosswalk to authenticated;
