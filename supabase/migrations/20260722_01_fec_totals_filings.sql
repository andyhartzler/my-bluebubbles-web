-- FEC bucket: per-cycle committee financial totals + filings metadata
-- Mirrors existing fec_* conventions: bigint identity PK, created_at/updated_at
-- timestamptz DEFAULT now(), RLS enabled with a single permissive <table>_read
-- FOR ALL policy (siblings use plain USING(true) WITH CHECK(true)), and grants
-- mirrored across anon / authenticated / service_role / postgres.

-- ---------------------------------------------------------------------------
-- public.fec_committee_totals
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fec_committee_totals (
    id                        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cmte_id                   text NOT NULL,
    cycle                     integer NOT NULL,
    receipts                  numeric,
    disbursements             numeric,
    cash_on_hand_end          numeric,
    debts_owed                numeric,
    individual_contributions  numeric,
    last_report_date          date,
    coverage_end_date         date,
    raw                       jsonb,
    created_at                timestamptz DEFAULT now(),
    updated_at                timestamptz DEFAULT now(),
    CONSTRAINT fec_committee_totals_cmte_cycle_key UNIQUE (cmte_id, cycle)
);

CREATE INDEX IF NOT EXISTS idx_fec_committee_totals_cmte
    ON public.fec_committee_totals USING btree (cmte_id);
CREATE INDEX IF NOT EXISTS idx_fec_committee_totals_cycle
    ON public.fec_committee_totals USING btree (cycle);

ALTER TABLE public.fec_committee_totals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fec_committee_totals_read ON public.fec_committee_totals;
CREATE POLICY fec_committee_totals_read ON public.fec_committee_totals
    FOR ALL TO public USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, REFERENCES, TRIGGER ON public.fec_committee_totals TO anon;
GRANT ALL ON public.fec_committee_totals TO authenticated;
GRANT ALL ON public.fec_committee_totals TO service_role;
GRANT ALL ON public.fec_committee_totals TO postgres;

-- ---------------------------------------------------------------------------
-- public.fec_filings
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fec_filings (
    id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fec_file_id           bigint NOT NULL,
    cand_id               text,
    cmte_id               text,
    form_type             text,
    report_type           text,
    coverage_start        date,
    coverage_end          date,
    receipt_date          date,
    total_receipts        numeric,
    total_disbursements   numeric,
    pdf_url               text,
    raw                   jsonb,
    created_at            timestamptz DEFAULT now(),
    updated_at            timestamptz DEFAULT now(),
    CONSTRAINT fec_filings_fec_file_id_key UNIQUE (fec_file_id)
);

CREATE INDEX IF NOT EXISTS idx_fec_filings_cmte
    ON public.fec_filings USING btree (cmte_id);
CREATE INDEX IF NOT EXISTS idx_fec_filings_cand
    ON public.fec_filings USING btree (cand_id);
CREATE INDEX IF NOT EXISTS idx_fec_filings_coverage_end
    ON public.fec_filings USING btree (coverage_end);

ALTER TABLE public.fec_filings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fec_filings_read ON public.fec_filings;
CREATE POLICY fec_filings_read ON public.fec_filings
    FOR ALL TO public USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, REFERENCES, TRIGGER ON public.fec_filings TO anon;
GRANT ALL ON public.fec_filings TO authenticated;
GRANT ALL ON public.fec_filings TO service_role;
GRANT ALL ON public.fec_filings TO postgres;
