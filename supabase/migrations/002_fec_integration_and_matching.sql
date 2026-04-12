-- =====================================================
-- MOYD Donor Platform: FEC Integration & MEC↔FEC Matching
-- Adds FEC contributions to unified views, improves
-- donor matching, and creates missing RPC functions.
-- Run this in the Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- 1. Ensure indexes exist on fec_contributions for fast joins
CREATE INDEX IF NOT EXISTS idx_fec_donor_id ON public.fec_contributions(donor_id);
CREATE INDEX IF NOT EXISTS idx_fec_cmte_id ON public.fec_contributions(cmte_id);
CREATE INDEX IF NOT EXISTS idx_fec_contributor_name ON public.fec_contributions(contributor_name);
CREATE INDEX IF NOT EXISTS idx_fec_transaction_date ON public.fec_contributions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_fec_state ON public.fec_contributions(state);
CREATE INDEX IF NOT EXISTS idx_fec_cycle ON public.fec_contributions(cycle);

-- 2. Ensure indexes on mec_contributions for fast joins
CREATE INDEX IF NOT EXISTS idx_mec_contrib_donor_id ON public.mec_contributions(donor_id);
CREATE INDEX IF NOT EXISTS idx_mec_contrib_committee ON public.mec_contributions(mec_id);
CREATE INDEX IF NOT EXISTS idx_mec_contrib_date ON public.mec_contributions(contribution_date);

-- 3. Ensure indexes on donor_enrichment
CREATE INDEX IF NOT EXISTS idx_de_donor_id ON public.donor_enrichment(donor_id);

-- 4. Update unified contribution view to include FEC
CREATE OR REPLACE VIEW public.donor_profile_contributions AS
SELECT
  dp.id as profile_id,
  'moyd' as source,
  d.amount,
  d.donation_date as contribution_date,
  d.payment_method,
  d.campaign as recipient_name,
  d.recurring,
  d.status,
  d.id::text as source_id
FROM public.donor_profiles dp
JOIN public.donations d ON d.donor_id = dp.donor_id
WHERE dp.donor_id IS NOT NULL

UNION ALL

SELECT
  dp.id as profile_id,
  'mec' as source,
  mc.contribution_amount as amount,
  mc.contribution_date::timestamptz as contribution_date,
  mc.monetary_or_inkind as payment_method,
  mc.committee_name as recipient_name,
  FALSE as recurring,
  'completed' as status,
  mc.id::text as source_id
FROM public.donor_profiles dp
JOIN public.mec_contributions mc ON mc.donor_id = dp.mec_donor_id
WHERE dp.mec_donor_id IS NOT NULL

UNION ALL

SELECT
  dp.id as profile_id,
  'fec' as source,
  fc.transaction_amount as amount,
  fc.transaction_date::timestamptz as contribution_date,
  'monetary' as payment_method,
  fc.committee_name as recipient_name,
  FALSE as recurring,
  'completed' as status,
  fc.id::text as source_id
FROM public.donor_profiles dp
JOIN public.fec_contributions fc ON fc.donor_id = dp.mec_donor_id
WHERE dp.mec_donor_id IS NOT NULL;

-- 5. Update get_donor_profile_full to include FEC contributions
CREATE OR REPLACE FUNCTION public.get_donor_profile_full(p_profile_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  result JSONB;
  profile_row public.donor_profiles;
BEGIN
  SELECT * INTO profile_row FROM public.donor_profiles WHERE id = p_profile_id;

  IF profile_row IS NULL THEN
    RETURN NULL;
  END IF;

  result := to_jsonb(profile_row);

  -- Add MOYD donations
  IF profile_row.donor_id IS NOT NULL THEN
    result := result || jsonb_build_object('moyd_donations',
      (SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.donation_date DESC), '[]'::jsonb)
       FROM public.donations d WHERE d.donor_id = profile_row.donor_id));

    result := result || jsonb_build_object('thank_yous',
      (SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
       FROM public.donation_thank_yous t
       JOIN public.donations d ON d.id = t.donation_id
       WHERE d.donor_id = profile_row.donor_id));
  END IF;

  -- Add MEC contributions (top 100 by amount)
  IF profile_row.mec_donor_id IS NOT NULL THEN
    result := result || jsonb_build_object('mec_contributions',
      (SELECT COALESCE(jsonb_agg(to_jsonb(mc) ORDER BY mc.contribution_amount DESC), '[]'::jsonb)
       FROM (SELECT * FROM public.mec_contributions
             WHERE donor_id = profile_row.mec_donor_id
             ORDER BY contribution_amount DESC LIMIT 100) mc));

    -- Add FEC contributions (top 100 by amount)
    result := result || jsonb_build_object('fec_contributions',
      (SELECT COALESCE(jsonb_agg(to_jsonb(fc) ORDER BY fc.transaction_amount DESC), '[]'::jsonb)
       FROM (SELECT * FROM public.fec_contributions
             WHERE donor_id = profile_row.mec_donor_id
             ORDER BY transaction_amount DESC LIMIT 100) fc));

    -- Add enrichment
    result := result || jsonb_build_object('enrichment',
      (SELECT to_jsonb(de) FROM public.donor_enrichment de
       WHERE de.donor_id = profile_row.mec_donor_id LIMIT 1));

    -- Add SEC filings
    result := result || jsonb_build_object('sec_filings',
      (SELECT COALESCE(jsonb_agg(to_jsonb(sf) ORDER BY sf.file_date DESC), '[]'::jsonb)
       FROM public.sec_insider_filings sf WHERE sf.donor_id = profile_row.mec_donor_id));
  END IF;

  -- Add property records (linked via donors.id UUID)
  IF profile_row.donor_id IS NOT NULL THEN
    result := result || jsonb_build_object('property_records',
      (SELECT COALESCE(jsonb_agg(to_jsonb(pr)), '[]'::jsonb)
       FROM public.property_records pr WHERE pr.donor_id = profile_row.donor_id::text));
  END IF;

  -- Add casenet records (name-based match)
  result := result || jsonb_build_object('casenet_records',
    (SELECT COALESCE(jsonb_agg(to_jsonb(cr)), '[]'::jsonb)
     FROM public.casenet_records cr
     WHERE cr.donor_name ILIKE '%' || profile_row.last_name || '%'
     AND (profile_row.first_name IS NULL OR cr.donor_name ILIKE '%' || profile_row.first_name || '%')));

  -- Add business entities
  IF profile_row.mec_donor_id IS NOT NULL THEN
    result := result || jsonb_build_object('business_entities',
      (SELECT COALESCE(jsonb_agg(to_jsonb(be)), '[]'::jsonb)
       FROM public.mo_business_entities be WHERE be.donor_id = profile_row.mec_donor_id));
  END IF;

  -- Add VAN data
  IF profile_row.van_id IS NOT NULL THEN
    result := result || jsonb_build_object('van_voter',
      (SELECT to_jsonb(v) FROM public.van_voters v WHERE v.van_id = profile_row.van_id));
    result := result || jsonb_build_object('van_voting_history',
      (SELECT COALESCE(jsonb_agg(to_jsonb(vh) ORDER BY vh.election_year DESC), '[]'::jsonb)
       FROM public.van_voting_history vh WHERE vh.van_id = profile_row.van_id));
    result := result || jsonb_build_object('van_scores',
      (SELECT COALESCE(jsonb_agg(to_jsonb(vs)), '[]'::jsonb)
       FROM public.van_scores vs WHERE vs.van_id = profile_row.van_id));
  END IF;

  -- Add tags
  result := result || jsonb_build_object('tags',
    (SELECT COALESCE(jsonb_agg(dt.tag_name), '[]'::jsonb)
     FROM public.donor_tags dt WHERE dt.profile_id = p_profile_id));

  -- Add recent activity
  result := result || jsonb_build_object('recent_activity',
    (SELECT COALESCE(jsonb_agg(to_jsonb(al) ORDER BY al.created_at DESC), '[]'::jsonb)
     FROM (SELECT * FROM public.donor_activity_log WHERE profile_id = p_profile_id
           ORDER BY created_at DESC LIMIT 50) al));

  -- Add call outcomes
  result := result || jsonb_build_object('call_outcomes',
    (SELECT COALESCE(jsonb_agg(to_jsonb(co) ORDER BY co.called_at DESC), '[]'::jsonb)
     FROM public.donor_call_outcomes co WHERE co.profile_id = p_profile_id));

  -- Add census context for their zip
  IF profile_row.zip IS NOT NULL THEN
    result := result || jsonb_build_object('census_data',
      (SELECT to_jsonb(cz) FROM public.census_zip_data cz
       WHERE cz.zip5 = LEFT(profile_row.zip, 5) LIMIT 1));
    result := result || jsonb_build_object('zillow_data',
      (SELECT to_jsonb(zz) FROM public.zillow_zip_data zz
       WHERE zz.zip5 = LEFT(profile_row.zip, 5) LIMIT 1));
  END IF;

  RETURN result;
END;
$$;

-- 6. Create search_donors_v3 — unified MEC+FEC search
--    The app calls this via mec_repository.dart#searchDonorsUnified
CREATE OR REPLACE FUNCTION public.search_donors_v3(
  p_state TEXT DEFAULT NULL,
  p_year_from INTEGER DEFAULT NULL,
  p_year_to INTEGER DEFAULT NULL,
  p_min_total NUMERIC DEFAULT NULL,
  p_max_total NUMERIC DEFAULT NULL,
  p_party TEXT DEFAULT NULL,
  p_name_query TEXT DEFAULT NULL,
  p_city TEXT DEFAULT NULL,
  p_zip TEXT DEFAULT NULL,
  p_employer TEXT DEFAULT NULL,
  p_occupation TEXT DEFAULT NULL,
  p_gender TEXT DEFAULT NULL,
  p_age_min INTEGER DEFAULT NULL,
  p_age_max INTEGER DEFAULT NULL,
  p_has_phone BOOLEAN DEFAULT NULL,
  p_has_email BOOLEAN DEFAULT NULL,
  p_is_homeowner BOOLEAN DEFAULT NULL,
  p_individuals_only BOOLEAN DEFAULT TRUE,
  p_source TEXT DEFAULT 'both',
  p_limit INTEGER DEFAULT 100,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
  donor_id INTEGER,
  first_name TEXT,
  last_name TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  employer TEXT,
  occupation TEXT,
  total_amount NUMERIC,
  contribution_count BIGINT,
  party TEXT,
  committees JSONB,
  first_date DATE,
  last_date DATE,
  -- Enrichment fields
  gender TEXT,
  age INTEGER,
  phone TEXT,
  email TEXT,
  income_range TEXT,
  net_worth_range TEXT,
  is_homeowner BOOLEAN,
  wealth_score NUMERIC,
  giving_capacity NUMERIC,
  source TEXT,
  total_count BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
  total BIGINT;
BEGIN
  -- Count total matching rows
  SELECT count(DISTINCT md.id) INTO total
  FROM public.mec_donors md
  LEFT JOIN public.donor_enrichment de ON de.donor_id = md.id
  WHERE
    (p_name_query IS NULL OR
     (md.first_name || ' ' || md.last_name) ILIKE '%' || p_name_query || '%' OR
     md.last_name ILIKE '%' || p_name_query || '%')
    AND (p_state IS NULL OR md.state = p_state)
    AND (p_city IS NULL OR md.city ILIKE p_city || '%')
    AND (p_zip IS NULL OR md.zip LIKE p_zip || '%')
    AND (p_employer IS NULL OR md.employer ILIKE '%' || p_employer || '%')
    AND (p_occupation IS NULL OR md.occupation ILIKE '%' || p_occupation || '%')
    AND (p_gender IS NULL OR de.gender = p_gender)
    AND (p_age_min IS NULL OR de.age >= p_age_min)
    AND (p_age_max IS NULL OR de.age <= p_age_max)
    AND (p_has_phone IS NULL OR (p_has_phone AND de.phone IS NOT NULL))
    AND (p_has_email IS NULL OR (p_has_email AND md.email IS NOT NULL))
    AND (p_is_homeowner IS NULL OR de.is_homeowner = p_is_homeowner);

  RETURN QUERY
  WITH combined AS (
    -- MEC contributions
    SELECT
      md.id as d_id,
      md.first_name as d_first,
      md.last_name as d_last,
      md.city as d_city,
      md.state as d_state,
      md.zip as d_zip,
      md.employer as d_employer,
      md.occupation as d_occupation,
      COALESCE(SUM(mc.contribution_amount), 0) as d_total,
      COUNT(mc.id) as d_count,
      md.party as d_party,
      MIN(mc.contribution_date) as d_first_date,
      MAX(mc.contribution_date) as d_last_date,
      'mec' as d_source
    FROM public.mec_donors md
    LEFT JOIN public.mec_contributions mc ON mc.donor_id = md.id
    LEFT JOIN public.donor_enrichment de ON de.donor_id = md.id
    WHERE
      (p_source IN ('both', 'mec'))
      AND (p_name_query IS NULL OR
           (md.first_name || ' ' || md.last_name) ILIKE '%' || p_name_query || '%' OR
           md.last_name ILIKE '%' || p_name_query || '%')
      AND (p_state IS NULL OR md.state = p_state)
      AND (p_city IS NULL OR md.city ILIKE p_city || '%')
      AND (p_zip IS NULL OR md.zip LIKE p_zip || '%')
      AND (p_employer IS NULL OR md.employer ILIKE '%' || p_employer || '%')
      AND (p_occupation IS NULL OR md.occupation ILIKE '%' || p_occupation || '%')
      AND (p_gender IS NULL OR de.gender = p_gender)
      AND (p_age_min IS NULL OR de.age >= p_age_min)
      AND (p_age_max IS NULL OR de.age <= p_age_max)
      AND (p_has_phone IS NULL OR (p_has_phone AND de.phone IS NOT NULL))
      AND (p_has_email IS NULL OR (p_has_email AND md.email IS NOT NULL))
      AND (p_is_homeowner IS NULL OR de.is_homeowner = p_is_homeowner)
    GROUP BY md.id

    UNION ALL

    -- FEC contributions (only for donors NOT already in MEC, to avoid double-counting)
    SELECT
      md.id as d_id,
      md.first_name as d_first,
      md.last_name as d_last,
      md.city as d_city,
      md.state as d_state,
      md.zip as d_zip,
      md.employer as d_employer,
      md.occupation as d_occupation,
      COALESCE(SUM(fc.transaction_amount), 0) as d_total,
      COUNT(fc.id) as d_count,
      md.party as d_party,
      MIN(fc.transaction_date) as d_first_date,
      MAX(fc.transaction_date) as d_last_date,
      'fec' as d_source
    FROM public.mec_donors md
    JOIN public.fec_contributions fc ON fc.donor_id = md.id
    LEFT JOIN public.donor_enrichment de ON de.donor_id = md.id
    WHERE
      (p_source IN ('both', 'fec'))
      AND (p_name_query IS NULL OR
           (md.first_name || ' ' || md.last_name) ILIKE '%' || p_name_query || '%' OR
           md.last_name ILIKE '%' || p_name_query || '%')
      AND (p_state IS NULL OR md.state = p_state)
      AND (p_city IS NULL OR md.city ILIKE p_city || '%')
      AND (p_zip IS NULL OR md.zip LIKE p_zip || '%')
      AND (p_employer IS NULL OR md.employer ILIKE '%' || p_employer || '%')
      AND (p_occupation IS NULL OR md.occupation ILIKE '%' || p_occupation || '%')
      AND (p_gender IS NULL OR de.gender = p_gender)
      AND (p_age_min IS NULL OR de.age >= p_age_min)
      AND (p_age_max IS NULL OR de.age <= p_age_max)
      AND (p_has_phone IS NULL OR (p_has_phone AND de.phone IS NOT NULL))
      AND (p_has_email IS NULL OR (p_has_email AND md.email IS NOT NULL))
      AND (p_is_homeowner IS NULL OR de.is_homeowner = p_is_homeowner)
    GROUP BY md.id
  ),
  -- Aggregate across MEC+FEC per donor (same person appears as one row)
  unified AS (
    SELECT
      c.d_id,
      c.d_first,
      c.d_last,
      c.d_city,
      c.d_state,
      c.d_zip,
      c.d_employer,
      c.d_occupation,
      SUM(c.d_total) as d_total,
      SUM(c.d_count) as d_count,
      c.d_party,
      MIN(c.d_first_date) as d_first_date,
      MAX(c.d_last_date) as d_last_date,
      CASE
        WHEN COUNT(DISTINCT c.d_source) > 1 THEN 'both'
        ELSE MAX(c.d_source)
      END as d_source
    FROM combined c
    GROUP BY c.d_id, c.d_first, c.d_last, c.d_city, c.d_state,
             c.d_zip, c.d_employer, c.d_occupation, c.d_party
  )
  SELECT
    u.d_id,
    u.d_first,
    u.d_last,
    u.d_city,
    u.d_state,
    u.d_zip,
    u.d_employer,
    u.d_occupation,
    u.d_total,
    u.d_count,
    u.d_party,
    '[]'::jsonb as committees,
    u.d_first_date,
    u.d_last_date,
    de.gender,
    de.age,
    de.phone,
    md2.email,
    de.income_range,
    de.net_worth_range,
    de.is_homeowner,
    de.wealth_score,
    de.giving_capacity,
    u.d_source,
    total as total_count
  FROM unified u
  LEFT JOIN public.donor_enrichment de ON de.donor_id = u.d_id
  LEFT JOIN public.mec_donors md2 ON md2.id = u.d_id
  WHERE
    (p_min_total IS NULL OR u.d_total >= p_min_total)
    AND (p_max_total IS NULL OR u.d_total <= p_max_total)
    AND (p_year_from IS NULL OR EXTRACT(YEAR FROM u.d_last_date) >= p_year_from)
    AND (p_year_to IS NULL OR EXTRACT(YEAR FROM u.d_first_date) <= p_year_to)
  ORDER BY u.d_total DESC NULLS LAST
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- 7. Create get_donor_unified_profile — full MEC+FEC profile by mec_donor_id
--    The app calls this via mec_repository.dart#getDonorUnifiedProfile
DROP FUNCTION IF EXISTS public.get_donor_unified_profile(integer);
CREATE OR REPLACE FUNCTION public.get_donor_unified_profile(p_donor_id INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  result JSONB;
  donor_row RECORD;
BEGIN
  -- Get base donor info from mec_donors
  SELECT * INTO donor_row FROM public.mec_donors WHERE id = p_donor_id;

  IF donor_row IS NULL THEN
    RETURN NULL;
  END IF;

  result := to_jsonb(donor_row);

  -- Add MEC contributions (top 200 by amount)
  result := result || jsonb_build_object('mec_contributions',
    (SELECT COALESCE(jsonb_agg(to_jsonb(mc) ORDER BY mc.contribution_amount DESC), '[]'::jsonb)
     FROM (SELECT * FROM public.mec_contributions
           WHERE donor_id = p_donor_id
           ORDER BY contribution_amount DESC LIMIT 200) mc));

  -- Add FEC contributions (top 200 by amount)
  result := result || jsonb_build_object('fec_contributions',
    (SELECT COALESCE(jsonb_agg(to_jsonb(fc) ORDER BY fc.transaction_amount DESC), '[]'::jsonb)
     FROM (SELECT * FROM public.fec_contributions
           WHERE donor_id = p_donor_id
           ORDER BY transaction_amount DESC LIMIT 200) fc));

  -- Totals
  result := result || jsonb_build_object(
    'mec_total', (SELECT COALESCE(SUM(contribution_amount), 0) FROM public.mec_contributions WHERE donor_id = p_donor_id),
    'fec_total', (SELECT COALESCE(SUM(transaction_amount), 0) FROM public.fec_contributions WHERE donor_id = p_donor_id),
    'mec_count', (SELECT COUNT(*) FROM public.mec_contributions WHERE donor_id = p_donor_id),
    'fec_count', (SELECT COUNT(*) FROM public.fec_contributions WHERE donor_id = p_donor_id)
  );

  -- Add enrichment
  result := result || jsonb_build_object('enrichment',
    (SELECT to_jsonb(de) FROM public.donor_enrichment de WHERE de.donor_id = p_donor_id LIMIT 1));

  -- Add committees donated to (MEC)
  result := result || jsonb_build_object('mec_committees',
    (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
      'mec_id', mc.mec_id,
      'committee_name', mc.committee_name,
      'total', SUM(mc.contribution_amount),
      'count', COUNT(*)
    )), '[]'::jsonb)
     FROM public.mec_contributions mc
     WHERE mc.donor_id = p_donor_id
     GROUP BY mc.mec_id, mc.committee_name));

  -- Add FEC committees donated to
  result := result || jsonb_build_object('fec_committees',
    (SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object(
      'cmte_id', fc.cmte_id,
      'committee_name', fc.committee_name,
      'total', SUM(fc.transaction_amount),
      'count', COUNT(*)
    )), '[]'::jsonb)
     FROM public.fec_contributions fc
     WHERE fc.donor_id = p_donor_id
     GROUP BY fc.cmte_id, fc.committee_name));

  -- Add linked donor_profile if exists
  result := result || jsonb_build_object('profile_id',
    (SELECT id FROM public.donor_profiles WHERE mec_donor_id = p_donor_id LIMIT 1));

  RETURN result;
END;
$$;

-- 8. Notify PostgREST to pick up new schema
NOTIFY pgrst, 'reload schema';
