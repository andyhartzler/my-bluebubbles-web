-- =====================================================
-- MOYD Donor Platform: Unified Identity Layer
-- Run this in the Supabase SQL Editor (Dashboard > SQL)
-- =====================================================

-- 1. Bridge table connecting all donor universes
CREATE TABLE IF NOT EXISTS public.donor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Links to all three universes
  donor_id UUID,                                   -- Universe 1: donors table (UUID)
  mec_donor_id INTEGER,                            -- Universe 2: mec_donors table (int)
  van_id INTEGER,                                  -- Universe 3: van_voters table (int)
  member_id UUID,                                  -- MOYD member link
  
  -- Canonical identity (best available data merged)
  display_name TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  phone_e164 TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  county TEXT,
  congressional_district TEXT,
  
  -- Computed scores (refreshed by cron/trigger)
  total_donated_moyd NUMERIC DEFAULT 0,
  total_donated_political NUMERIC DEFAULT 0,
  donation_count_moyd INTEGER DEFAULT 0,
  donation_count_political INTEGER DEFAULT 0,
  first_donation_date TIMESTAMPTZ,
  last_donation_date TIMESTAMPTZ,
  largest_gift NUMERIC DEFAULT 0,
  average_gift NUMERIC DEFAULT 0,
  is_recurring_donor BOOLEAN DEFAULT FALSE,
  
  -- Enrichment scores (from donor_enrichment)
  giving_capacity NUMERIC,
  wealth_score NUMERIC,
  engagement_score NUMERIC,
  party_lean TEXT,
  party_lean_confidence NUMERIC,
  age_estimate INTEGER,
  gender TEXT,
  is_homeowner BOOLEAN,
  estimated_income_range TEXT,
  estimated_net_worth_range TEXT,
  
  -- Tier classification
  donor_tier TEXT DEFAULT 'prospect',  -- 'major', 'mid', 'small', 'prospect', 'lapsed'
  
  -- Match metadata
  match_confidence NUMERIC,
  match_method TEXT,
  
  -- Flags
  has_casenet_records BOOLEAN DEFAULT FALSE,
  has_property_records BOOLEAN DEFAULT FALSE,
  has_sec_filings BOOLEAN DEFAULT FALSE,
  has_business_entities BOOLEAN DEFAULT FALSE,
  has_enrichment BOOLEAN DEFAULT FALSE,
  has_van_data BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Indexes for fast lookup from any universe
CREATE INDEX IF NOT EXISTS idx_dp_donor_id ON public.donor_profiles(donor_id);
CREATE INDEX IF NOT EXISTS idx_dp_mec_donor_id ON public.donor_profiles(mec_donor_id);
CREATE INDEX IF NOT EXISTS idx_dp_van_id ON public.donor_profiles(van_id);
CREATE INDEX IF NOT EXISTS idx_dp_member_id ON public.donor_profiles(member_id);
CREATE INDEX IF NOT EXISTS idx_dp_display_name ON public.donor_profiles(display_name);
CREATE INDEX IF NOT EXISTS idx_dp_email ON public.donor_profiles(email);
CREATE INDEX IF NOT EXISTS idx_dp_phone ON public.donor_profiles(phone_e164);
CREATE INDEX IF NOT EXISTS idx_dp_tier ON public.donor_profiles(donor_tier);
CREATE INDEX IF NOT EXISTS idx_dp_zip ON public.donor_profiles(zip);
CREATE INDEX IF NOT EXISTS idx_dp_county ON public.donor_profiles(county);
CREATE INDEX IF NOT EXISTS idx_dp_cd ON public.donor_profiles(congressional_district);
CREATE INDEX IF NOT EXISTS idx_dp_party ON public.donor_profiles(party_lean);
CREATE INDEX IF NOT EXISTS idx_dp_wealth ON public.donor_profiles(wealth_score);
CREATE INDEX IF NOT EXISTS idx_dp_total_moyd ON public.donor_profiles(total_donated_moyd);
CREATE INDEX IF NOT EXISTS idx_dp_total_political ON public.donor_profiles(total_donated_political);
CREATE INDEX IF NOT EXISTS idx_dp_last_name ON public.donor_profiles(last_name);

-- 3. Tags system
CREATE TABLE IF NOT EXISTS public.donor_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.donor_profiles(id) ON DELETE CASCADE,
  tag_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  created_by TEXT,
  UNIQUE(profile_id, tag_name)
);

CREATE INDEX IF NOT EXISTS idx_dtags_profile ON public.donor_tags(profile_id);
CREATE INDEX IF NOT EXISTS idx_dtags_name ON public.donor_tags(tag_name);

-- 4. Activity log
CREATE TABLE IF NOT EXISTS public.donor_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.donor_profiles(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL,  -- 'call', 'email', 'note', 'tag_added', 'donation', 'pledge', 'meeting'
  title TEXT,
  description TEXT,
  metadata JSONB DEFAULT '{}',
  created_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dal_profile ON public.donor_activity_log(profile_id);
CREATE INDEX IF NOT EXISTS idx_dal_type ON public.donor_activity_log(activity_type);
CREATE INDEX IF NOT EXISTS idx_dal_created ON public.donor_activity_log(created_at DESC);

-- 5. Call outcomes (extends call_time_list_items)
CREATE TABLE IF NOT EXISTS public.donor_call_outcomes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID REFERENCES public.donor_profiles(id),
  list_item_id INTEGER REFERENCES public.call_time_list_items(id),
  outcome TEXT NOT NULL,  -- 'connected', 'voicemail', 'no_answer', 'wrong_number', 'pledged', 'declined', 'follow_up'
  pledge_amount NUMERIC,
  pledge_fulfilled BOOLEAN DEFAULT FALSE,
  pledge_fulfilled_at TIMESTAMPTZ,
  notes TEXT,
  called_by TEXT,
  called_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dco_profile ON public.donor_call_outcomes(profile_id);

-- 6. Indexes on existing tables for name-based matching
CREATE INDEX IF NOT EXISTS idx_casenet_donor_name ON public.casenet_records(donor_name);
CREATE INDEX IF NOT EXISTS idx_nonprofit_name ON public.nonprofit_officers(officer_name);
CREATE INDEX IF NOT EXISTS idx_mec_donors_name ON public.mec_donors(last_name, first_name);
CREATE INDEX IF NOT EXISTS idx_mec_donors_email ON public.mec_donors(email);

-- 7. Unified contribution view
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
  d.id as source_id
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
WHERE dp.mec_donor_id IS NOT NULL;

-- 8. RPC: Search donor profiles with filters
CREATE OR REPLACE FUNCTION public.search_donor_profiles(
  search_query TEXT DEFAULT NULL,
  filter_tier TEXT DEFAULT NULL,
  filter_party TEXT DEFAULT NULL,
  filter_county TEXT DEFAULT NULL,
  filter_cd TEXT DEFAULT NULL,
  filter_min_donated NUMERIC DEFAULT NULL,
  filter_max_donated NUMERIC DEFAULT NULL,
  filter_min_wealth NUMERIC DEFAULT NULL,
  filter_has_enrichment BOOLEAN DEFAULT NULL,
  filter_has_van BOOLEAN DEFAULT NULL,
  sort_by TEXT DEFAULT 'total_donated_political',
  sort_dir TEXT DEFAULT 'desc',
  page_num INTEGER DEFAULT 1,
  page_size INTEGER DEFAULT 50
)
RETURNS TABLE(
  id UUID,
  display_name TEXT,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone_e164 TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  county TEXT,
  congressional_district TEXT,
  donor_tier TEXT,
  party_lean TEXT,
  wealth_score NUMERIC,
  engagement_score NUMERIC,
  giving_capacity NUMERIC,
  total_donated_moyd NUMERIC,
  total_donated_political NUMERIC,
  donation_count_moyd INTEGER,
  donation_count_political INTEGER,
  last_donation_date TIMESTAMPTZ,
  has_enrichment BOOLEAN,
  has_van_data BOOLEAN,
  has_casenet_records BOOLEAN,
  has_property_records BOOLEAN,
  donor_id UUID,
  mec_donor_id INTEGER,
  member_id UUID,
  total_count BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
  offset_val INTEGER;
  total BIGINT;
BEGIN
  offset_val := (page_num - 1) * page_size;
  
  -- Get total count first
  SELECT count(*) INTO total
  FROM public.donor_profiles dp
  WHERE
    (search_query IS NULL OR 
     dp.display_name ILIKE '%' || search_query || '%' OR
     dp.email ILIKE '%' || search_query || '%' OR
     dp.phone_e164 LIKE '%' || search_query || '%' OR
     dp.city ILIKE '%' || search_query || '%')
    AND (filter_tier IS NULL OR dp.donor_tier = filter_tier)
    AND (filter_party IS NULL OR dp.party_lean = filter_party)
    AND (filter_county IS NULL OR dp.county ILIKE filter_county)
    AND (filter_cd IS NULL OR dp.congressional_district = filter_cd)
    AND (filter_min_donated IS NULL OR dp.total_donated_political >= filter_min_donated)
    AND (filter_max_donated IS NULL OR dp.total_donated_political <= filter_max_donated)
    AND (filter_min_wealth IS NULL OR dp.wealth_score >= filter_min_wealth)
    AND (filter_has_enrichment IS NULL OR dp.has_enrichment = filter_has_enrichment)
    AND (filter_has_van IS NULL OR dp.has_van_data = filter_has_van);

  RETURN QUERY
  SELECT 
    dp.id, dp.display_name, dp.first_name, dp.last_name,
    dp.email, dp.phone_e164, dp.city, dp.state, dp.zip,
    dp.county, dp.congressional_district, dp.donor_tier,
    dp.party_lean, dp.wealth_score, dp.engagement_score,
    dp.giving_capacity, dp.total_donated_moyd, dp.total_donated_political,
    dp.donation_count_moyd, dp.donation_count_political,
    dp.last_donation_date, dp.has_enrichment, dp.has_van_data,
    dp.has_casenet_records, dp.has_property_records,
    dp.donor_id, dp.mec_donor_id, dp.member_id,
    total as total_count
  FROM public.donor_profiles dp
  WHERE
    (search_query IS NULL OR 
     dp.display_name ILIKE '%' || search_query || '%' OR
     dp.email ILIKE '%' || search_query || '%' OR
     dp.phone_e164 LIKE '%' || search_query || '%' OR
     dp.city ILIKE '%' || search_query || '%')
    AND (filter_tier IS NULL OR dp.donor_tier = filter_tier)
    AND (filter_party IS NULL OR dp.party_lean = filter_party)
    AND (filter_county IS NULL OR dp.county ILIKE filter_county)
    AND (filter_cd IS NULL OR dp.congressional_district = filter_cd)
    AND (filter_min_donated IS NULL OR dp.total_donated_political >= filter_min_donated)
    AND (filter_max_donated IS NULL OR dp.total_donated_political <= filter_max_donated)
    AND (filter_min_wealth IS NULL OR dp.wealth_score >= filter_min_wealth)
    AND (filter_has_enrichment IS NULL OR dp.has_enrichment = filter_has_enrichment)
    AND (filter_has_van IS NULL OR dp.has_van_data = filter_has_van)
  ORDER BY
    CASE WHEN sort_dir = 'desc' THEN
      CASE sort_by
        WHEN 'total_donated_political' THEN dp.total_donated_political
        WHEN 'total_donated_moyd' THEN dp.total_donated_moyd
        WHEN 'wealth_score' THEN dp.wealth_score
        WHEN 'engagement_score' THEN dp.engagement_score
        WHEN 'giving_capacity' THEN dp.giving_capacity
        ELSE dp.total_donated_political
      END
    END DESC NULLS LAST,
    CASE WHEN sort_dir = 'asc' THEN
      CASE sort_by
        WHEN 'total_donated_political' THEN dp.total_donated_political
        WHEN 'total_donated_moyd' THEN dp.total_donated_moyd
        WHEN 'wealth_score' THEN dp.wealth_score
        WHEN 'engagement_score' THEN dp.engagement_score
        WHEN 'giving_capacity' THEN dp.giving_capacity
        ELSE dp.total_donated_political
      END
    END ASC NULLS LAST,
    CASE WHEN sort_by = 'name' AND sort_dir = 'asc' THEN dp.display_name END ASC,
    CASE WHEN sort_by = 'name' AND sort_dir = 'desc' THEN dp.display_name END DESC
  LIMIT page_size
  OFFSET offset_val;
END;
$$;

-- 9. RPC: Get full donor profile with all linked data
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

-- 10. Notify PostgREST to pick up new schema
NOTIFY pgrst, 'reload schema';
