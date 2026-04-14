-- 005_mec_historical_filings.sql
-- Archive of MEC quarterly/annual filings pulled from the MEC web portal.
-- Separate from public.mec_reports (which holds MOYD's OWN generated reports
-- from the Plaid Edge Function) so the archive can track any committee's
-- historical filings without polluting the active-quarter workflow.

CREATE TABLE IF NOT EXISTS public.mec_historical_filings (
  id bigserial PRIMARY KEY,
  committee_mec_id text NOT NULL,
  committee_name text NOT NULL,

  filing_type text NOT NULL,
  period_start date,
  period_end date,
  filing_date date,
  filing_year smallint,
  quarter text,

  total_monetary_contributions numeric(14,2),
  total_inkind_contributions numeric(14,2),
  total_contributions numeric(14,2),
  total_expenditures numeric(14,2),
  cash_on_hand numeric(14,2),
  loans_outstanding numeric(14,2),
  itemized_contribution_count integer,
  itemized_expenditure_count integer,

  source_url text,
  storage_bucket text NOT NULL DEFAULT 'mec-filings',
  storage_path text,
  raw_text text,

  discovered_at timestamptz NOT NULL DEFAULT now(),
  last_fetched_at timestamptz,
  processed_at timestamptz,
  notes text,

  UNIQUE (committee_mec_id, filing_type, period_start, period_end, filing_date)
);

CREATE INDEX IF NOT EXISTS idx_mec_hist_committee ON public.mec_historical_filings (committee_mec_id);
CREATE INDEX IF NOT EXISTS idx_mec_hist_year_quarter ON public.mec_historical_filings (filing_year, quarter);
CREATE INDEX IF NOT EXISTS idx_mec_hist_filing_date ON public.mec_historical_filings (filing_date);

INSERT INTO storage.buckets (id, name, public)
VALUES ('mec-filings', 'mec-filings', false)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.mec_historical_filings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service role all" ON public.mec_historical_filings;
CREATE POLICY "service role all" ON public.mec_historical_filings FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "authenticated read" ON public.mec_historical_filings;
CREATE POLICY "authenticated read" ON public.mec_historical_filings FOR SELECT TO authenticated USING (true);
