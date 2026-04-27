-- Search-timeout fix: 3 indexes that resolve PostgREST 57014 on
-- search_donors_v3 with party-filter.

CREATE INDEX IF NOT EXISTS idx_donor_enrichment_party_lean_trgm
  ON public.donor_enrichment USING gin (party_lean gin_trgm_ops);

ALTER TABLE public.mec_donors
  ADD COLUMN IF NOT EXISTS combined_total numeric
  GENERATED ALWAYS AS (
    coalesce(total_contributed, 0) + coalesce(fec_total_contributed, 0)
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_mec_donors_combined_total_individual
  ON public.mec_donors (combined_total DESC NULLS LAST)
  WHERE donor_type = 'individual';

CREATE INDEX IF NOT EXISTS idx_donor_enrichment_donor_id_covering
  ON public.donor_enrichment (donor_id)
  INCLUDE (party_lean, gender, age_estimate, is_homeowner,
           phone_mobile, phone_home, email_personal, current_employer);
