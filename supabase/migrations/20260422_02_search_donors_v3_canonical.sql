-- 2026-04-22 Drop the stale `p_state`-first overload of `search_donors_v3`
-- created by migration 002 and re-assert the canonical `p_name_query`-first
-- signature. Having both overloads with arity 21 made PostgREST raise
-- PGRST203 "Could not choose the best candidate function" on the Donor
-- Research tab. The canonical body uses the newer mec_donors schema
-- (donor_type, company_name, committee_name, total_contributed,
-- fec_total_contributed, *_contribution_date) and returns the richer row
-- shape Flutter consumes (donor_name, party_lean, data_sources,
-- committees_donated_to, age_estimate, …). See migration 002 for the
-- original signature that is being superseded here.

DROP FUNCTION IF EXISTS public.search_donors_v3(
  p_state TEXT,
  p_year_from INTEGER,
  p_year_to INTEGER,
  p_min_total NUMERIC,
  p_max_total NUMERIC,
  p_party TEXT,
  p_name_query TEXT,
  p_city TEXT,
  p_zip TEXT,
  p_employer TEXT,
  p_occupation TEXT,
  p_gender TEXT,
  p_age_min INTEGER,
  p_age_max INTEGER,
  p_has_phone BOOLEAN,
  p_has_email BOOLEAN,
  p_is_homeowner BOOLEAN,
  p_individuals_only BOOLEAN,
  p_source TEXT,
  p_limit INTEGER,
  p_offset INTEGER
);

CREATE OR REPLACE FUNCTION public.search_donors_v3(
  p_name_query        TEXT    DEFAULT NULL,
  p_state             TEXT    DEFAULT NULL,
  p_city              TEXT    DEFAULT NULL,
  p_zip               TEXT    DEFAULT NULL,
  p_year_from         INTEGER DEFAULT NULL,
  p_year_to           INTEGER DEFAULT NULL,
  p_min_total         NUMERIC DEFAULT NULL,
  p_max_total         NUMERIC DEFAULT NULL,
  p_party             TEXT    DEFAULT NULL,
  p_employer          TEXT    DEFAULT NULL,
  p_occupation        TEXT    DEFAULT NULL,
  p_gender            TEXT    DEFAULT NULL,
  p_age_min           INTEGER DEFAULT NULL,
  p_age_max           INTEGER DEFAULT NULL,
  p_has_phone         BOOLEAN DEFAULT NULL,
  p_has_email         BOOLEAN DEFAULT NULL,
  p_is_homeowner      BOOLEAN DEFAULT NULL,
  p_individuals_only  BOOLEAN DEFAULT TRUE,
  p_source            TEXT    DEFAULT 'both',
  p_limit             INTEGER DEFAULT 100,
  p_offset            INTEGER DEFAULT 0
)
RETURNS TABLE (
  donor_id                 INTEGER,
  donor_name               TEXT,
  last_name                TEXT,
  first_name               TEXT,
  company_name             TEXT,
  committee_name           TEXT,
  city                     TEXT,
  state                    TEXT,
  zip                      TEXT,
  employer                 TEXT,
  occupation               TEXT,
  mec_total                NUMERIC,
  mec_count                INTEGER,
  fec_total                NUMERIC,
  fec_count                INTEGER,
  total_amount             NUMERIC,
  contribution_count       INTEGER,
  first_year               INTEGER,
  last_year                INTEGER,
  committees_donated_to    JSONB,
  data_sources             TEXT,
  gender                   TEXT,
  age_estimate             INTEGER,
  generation               TEXT,
  party_lean               TEXT,
  party_lean_confidence    NUMERIC,
  phone_mobile             TEXT,
  phone_home               TEXT,
  email_personal           TEXT,
  social_profile_count     INTEGER,
  giving_capacity_estimate NUMERIC,
  wealth_score             NUMERIC,
  engagement_score         NUMERIC,
  is_homeowner             BOOLEAN,
  current_employer         TEXT,
  current_job_title        TEXT,
  estimated_income_range   TEXT,
  ethnicity                TEXT
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  _date_from DATE;
  _date_to DATE;
  _has_enrichment_filter BOOLEAN;
BEGIN
  IF p_year_from IS NOT NULL THEN
    _date_from := make_date(p_year_from, 1, 1);
  END IF;
  IF p_year_to IS NOT NULL THEN
    _date_to := make_date(p_year_to, 12, 31);
  END IF;

  _has_enrichment_filter := (
    p_gender IS NOT NULL OR p_age_min IS NOT NULL OR p_age_max IS NOT NULL
    OR p_has_phone IS NOT NULL OR p_has_email IS NOT NULL
    OR p_is_homeowner IS NOT NULL OR p_party IS NOT NULL
  );

  IF _has_enrichment_filter THEN
    RETURN QUERY
    WITH filtered_donors AS (
      SELECT d2.id
      FROM public.mec_donors d2
      INNER JOIN public.donor_enrichment e2 ON e2.donor_id = d2.id
      WHERE
        (p_name_query IS NULL OR (
          d2.last_name ILIKE '%' || p_name_query || '%'
          OR d2.first_name ILIKE '%' || p_name_query || '%'
          OR d2.company_name ILIKE '%' || p_name_query || '%'
          OR d2.committee_name ILIKE '%' || p_name_query || '%'
        ))
        AND (p_state IS NULL OR d2.state = p_state)
        AND (p_city IS NULL OR d2.city ILIKE '%' || p_city || '%')
        AND (p_zip IS NULL OR d2.zip LIKE p_zip || '%')
        AND (_date_from IS NULL OR d2.last_contribution_date >= _date_from)
        AND (_date_to IS NULL OR d2.first_contribution_date <= _date_to)
        AND (p_employer IS NULL OR d2.employer ILIKE '%' || p_employer || '%')
        AND (p_occupation IS NULL OR d2.occupation ILIKE '%' || p_occupation || '%')
        AND (NOT p_individuals_only OR d2.donor_type = 'individual')
        AND (p_source = 'both'
             OR (p_source = 'mec' AND d2.contribution_count > 0)
             OR (p_source = 'fec' AND coalesce(d2.fec_contribution_count, 0) > 0))
        AND (p_min_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) >= p_min_total)
        AND (p_max_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) <= p_max_total)
        AND (p_gender IS NULL OR e2.gender ILIKE p_gender)
        AND (p_age_min IS NULL OR e2.age_estimate >= p_age_min)
        AND (p_age_max IS NULL OR e2.age_estimate <= p_age_max)
        AND (p_has_phone IS NULL OR (p_has_phone = (coalesce(e2.phone_mobile, '') != '' OR coalesce(e2.phone_home, '') != '')))
        AND (p_has_email IS NULL OR (p_has_email = (coalesce(e2.email_personal, '') != '')))
        AND (p_is_homeowner IS NULL OR e2.is_homeowner = p_is_homeowner)
        AND (p_party IS NULL OR e2.party_lean ILIKE '%' || p_party || '%')
      ORDER BY (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) DESC NULLS LAST
      LIMIT p_limit OFFSET p_offset
    )
    SELECT
      d.id::int,
      CASE
        WHEN d.donor_type = 'individual' THEN coalesce(d.first_name || ' ' || d.last_name, d.last_name)
        WHEN d.company_name IS NOT NULL THEN d.company_name
        ELSE d.committee_name
      END,
      d.last_name, d.first_name, d.company_name, d.committee_name,
      d.city, d.state, d.zip, d.employer, d.occupation,
      coalesce(d.total_contributed, 0)::numeric,
      coalesce(d.contribution_count, 0)::int,
      coalesce(d.fec_total_contributed, 0)::numeric,
      coalesce(d.fec_contribution_count, 0)::int,
      (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0))::numeric,
      (coalesce(d.contribution_count, 0) + coalesce(d.fec_contribution_count, 0))::int,
      EXTRACT(YEAR FROM d.first_contribution_date)::int,
      EXTRACT(YEAR FROM d.last_contribution_date)::int,
      d.committees_donated_to,
      CASE
        WHEN coalesce(d.contribution_count, 0) > 0 AND coalesce(d.fec_contribution_count, 0) > 0 THEN 'MEC+FEC'
        WHEN coalesce(d.fec_contribution_count, 0) > 0 THEN 'FEC'
        ELSE 'MEC'
      END,
      e.gender, e.age_estimate, e.generation, e.party_lean, e.party_lean_confidence,
      e.phone_mobile, e.phone_home, e.email_personal, e.social_profile_count,
      e.giving_capacity_estimate, e.wealth_score, e.engagement_score,
      e.is_homeowner, e.current_employer, e.current_job_title,
      e.estimated_income_range, e.ethnicity
    FROM filtered_donors fd
    JOIN public.mec_donors d ON d.id = fd.id
    LEFT JOIN public.donor_enrichment e ON e.donor_id = d.id
    ORDER BY (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0)) DESC NULLS LAST;

  ELSE
    RETURN QUERY
    WITH top_donors AS (
      SELECT d2.id
      FROM public.mec_donors d2
      WHERE
        (p_name_query IS NULL OR (
          d2.last_name ILIKE '%' || p_name_query || '%'
          OR d2.first_name ILIKE '%' || p_name_query || '%'
          OR d2.company_name ILIKE '%' || p_name_query || '%'
          OR d2.committee_name ILIKE '%' || p_name_query || '%'
        ))
        AND (p_state IS NULL OR d2.state = p_state)
        AND (p_city IS NULL OR d2.city ILIKE '%' || p_city || '%')
        AND (p_zip IS NULL OR d2.zip LIKE p_zip || '%')
        AND (_date_from IS NULL OR d2.last_contribution_date >= _date_from)
        AND (_date_to IS NULL OR d2.first_contribution_date <= _date_to)
        AND (p_employer IS NULL OR d2.employer ILIKE '%' || p_employer || '%')
        AND (p_occupation IS NULL OR d2.occupation ILIKE '%' || p_occupation || '%')
        AND (NOT p_individuals_only OR d2.donor_type = 'individual')
        AND (p_source = 'both'
             OR (p_source = 'mec' AND d2.contribution_count > 0)
             OR (p_source = 'fec' AND coalesce(d2.fec_contribution_count, 0) > 0))
        AND (p_min_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) >= p_min_total)
        AND (p_max_total IS NULL OR (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) <= p_max_total)
      ORDER BY (coalesce(d2.total_contributed, 0) + coalesce(d2.fec_total_contributed, 0)) DESC NULLS LAST
      LIMIT p_limit OFFSET p_offset
    )
    SELECT
      d.id::int,
      CASE
        WHEN d.donor_type = 'individual' THEN coalesce(d.first_name || ' ' || d.last_name, d.last_name)
        WHEN d.company_name IS NOT NULL THEN d.company_name
        ELSE d.committee_name
      END,
      d.last_name, d.first_name, d.company_name, d.committee_name,
      d.city, d.state, d.zip, d.employer, d.occupation,
      coalesce(d.total_contributed, 0)::numeric,
      coalesce(d.contribution_count, 0)::int,
      coalesce(d.fec_total_contributed, 0)::numeric,
      coalesce(d.fec_contribution_count, 0)::int,
      (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0))::numeric,
      (coalesce(d.contribution_count, 0) + coalesce(d.fec_contribution_count, 0))::int,
      EXTRACT(YEAR FROM d.first_contribution_date)::int,
      EXTRACT(YEAR FROM d.last_contribution_date)::int,
      d.committees_donated_to,
      CASE
        WHEN coalesce(d.contribution_count, 0) > 0 AND coalesce(d.fec_contribution_count, 0) > 0 THEN 'MEC+FEC'
        WHEN coalesce(d.fec_contribution_count, 0) > 0 THEN 'FEC'
        ELSE 'MEC'
      END,
      e.gender, e.age_estimate, e.generation, e.party_lean, e.party_lean_confidence,
      e.phone_mobile, e.phone_home, e.email_personal, e.social_profile_count,
      e.giving_capacity_estimate, e.wealth_score, e.engagement_score,
      e.is_homeowner, e.current_employer, e.current_job_title,
      e.estimated_income_range, e.ethnicity
    FROM top_donors td
    JOIN public.mec_donors d ON d.id = td.id
    LEFT JOIN public.donor_enrichment e ON e.donor_id = d.id
    ORDER BY (coalesce(d.total_contributed, 0) + coalesce(d.fec_total_contributed, 0)) DESC NULLS LAST;
  END IF;
END;
$function$;

NOTIFY pgrst, 'reload schema';
