-- 20260421_17_extend_donor_profile_rpc.sql
-- Extend get_donor_profile_by_natural_key to return mec_donor_id, mo_voter_file_id,
-- birth_year, and an `enrichment` object so MECDonorScreen can render the new
-- voter-file and enrichment cards.

CREATE OR REPLACE FUNCTION public.get_donor_profile_by_natural_key(
  p_first_name text, p_last_name text,
  p_city text DEFAULT NULL::text, p_state text DEFAULT NULL::text
) RETURNS json
LANGUAGE sql STABLE
AS $function$
  WITH donor_contribs AS (
    SELECT mc.id, mc.mec_id, mc.committee_name, mc.contribution_amount,
           mc.contribution_date, mc.monetary_or_inkind, mc.employer, mc.occupation
    FROM public.mec_contributions mc
    WHERE lower(trim(mc.contributor_first_name)) = lower(trim(p_first_name))
      AND lower(trim(mc.contributor_last_name))  = lower(trim(p_last_name))
      AND (p_city IS NULL OR p_city = '' OR lower(trim(coalesce(mc.city,''))) = lower(trim(p_city)))
      AND (p_state IS NULL OR p_state = '' OR lower(trim(coalesce(mc.state,''))) = lower(trim(p_state)))
  ),
  -- NEW: the aggregated mec_donors row for this person (voter_file linkage lives here)
  donor_identity AS (
    SELECT md.id AS mec_donor_id,
           md.mo_voter_file_id,
           md.birth_year,
           md.date_of_birth
    FROM public.mec_donors md
    WHERE lower(trim(md.first_name)) = lower(trim(p_first_name))
      AND lower(trim(md.last_name))  = lower(trim(p_last_name))
      AND (p_city IS NULL OR p_city = '' OR lower(trim(coalesce(md.city,''))) = lower(trim(p_city)))
      AND (p_state IS NULL OR p_state = '' OR lower(trim(coalesce(md.state,''))) = lower(trim(p_state)))
    LIMIT 1
  ),
  -- NEW: donor_enrichment row joined on mec_donors.id
  enrichment AS (
    SELECT e.id AS enrichment_id,
           e.gender, e.party_lean, e.party_lean_confidence,
           e.current_city, e.current_zip, e.current_county, e.congressional_district,
           e.total_political_donations, e.donation_count, e.avg_donation, e.donation_frequency,
           e.is_homeowner, e.wealth_score, e.age_estimate,
           e.mo_voter_file_id AS enrichment_mo_voter_file_id,
           e.current_employer, e.current_job_title,
           e.estimated_income_range, e.estimated_net_worth_range,
           e.ethnicity, e.generation
    FROM public.donor_enrichment e
    JOIN donor_identity di ON di.mec_donor_id = e.donor_id
    LIMIT 1
  ),
  committee_to_candidate AS (
    SELECT DISTINCT ON (dc.mec_id)
      dc.mec_id, c.id AS candidate_id, c.name AS candidate_name, c.party AS candidate_party
    FROM donor_contribs dc
    LEFT JOIN public.candidates c ON dc.mec_id = ANY(c.mec_committee_ids)
    ORDER BY dc.mec_id, c.updated_at DESC NULLS LAST
  ),
  enriched_contribs AS (
    SELECT dc.*, ctc.candidate_id, ctc.candidate_name, ctc.candidate_party
    FROM donor_contribs dc
    LEFT JOIN committee_to_candidate ctc ON ctc.mec_id = dc.mec_id
  ),
  by_committee AS (
    SELECT mec_id, MAX(committee_name) as committee_name,
           SUM(contribution_amount) as total, COUNT(*) as count,
           MIN(contribution_date) as first_given, MAX(contribution_date) as last_given
    FROM donor_contribs GROUP BY mec_id
  ),
  by_candidate AS (
    SELECT candidate_id, candidate_name, candidate_party,
           SUM(contribution_amount) as total, COUNT(*) as count
    FROM enriched_contribs
    WHERE candidate_id IS NOT NULL
    GROUP BY candidate_id, candidate_name, candidate_party
  )
  SELECT json_build_object(
    'first_name', p_first_name,
    'last_name', p_last_name,
    'city', p_city,
    'state', p_state,
    -- NEW: identity fields (from mec_donors)
    'id',                 (SELECT mec_donor_id::text     FROM donor_identity),
    'profile_id',         (SELECT mec_donor_id::text     FROM donor_identity),
    'mec_donor_id',       (SELECT mec_donor_id           FROM donor_identity),
    'mo_voter_file_id',   (SELECT mo_voter_file_id       FROM donor_identity),
    'birth_year',         (SELECT birth_year             FROM donor_identity),
    'date_of_birth',      (SELECT date_of_birth          FROM donor_identity),
    -- NEW: enrichment object
    'enrichment',         (SELECT row_to_json(e.*)       FROM enrichment e),
    -- existing aggregates
    'total_given',        COALESCE((SELECT SUM(contribution_amount) FROM donor_contribs), 0),
    'contribution_count', (SELECT COUNT(*) FROM donor_contribs),
    'first_contribution', (SELECT MIN(contribution_date) FROM donor_contribs),
    'last_contribution',  (SELECT MAX(contribution_date) FROM donor_contribs),
    'unique_committees',  (SELECT COUNT(*) FROM by_committee),
    'unique_candidates',  (SELECT COUNT(*) FROM by_candidate),
    'employer',   (SELECT MAX(employer)   FROM donor_contribs WHERE employer   IS NOT NULL AND employer   <> ''),
    'occupation', (SELECT MAX(occupation) FROM donor_contribs WHERE occupation IS NOT NULL AND occupation <> ''),
    'by_committee', (SELECT COALESCE(json_agg(row_to_json(b) ORDER BY b.total DESC), '[]'::json) FROM by_committee b),
    'by_candidate', (SELECT COALESCE(json_agg(row_to_json(b) ORDER BY b.total DESC), '[]'::json) FROM by_candidate b),
    'recent_contributions', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.contribution_date DESC NULLS LAST), '[]'::json)
      FROM (
        SELECT contribution_date, contribution_amount, monetary_or_inkind,
               mec_id, committee_name, candidate_name
        FROM enriched_contribs
        ORDER BY contribution_date DESC NULLS LAST
        LIMIT 50
      ) t
    )
  );
$function$;

NOTIFY pgrst, 'reload schema';
