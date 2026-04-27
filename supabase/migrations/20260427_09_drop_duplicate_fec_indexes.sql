-- Drop 5 pairs of exactly-equivalent btree indexes on fec_contributions.
-- The donor_id pair is INTENTIONALLY left as a pair (one is partial, one full).

DROP INDEX IF EXISTS public.idx_fec_cmte_id;
DROP INDEX IF EXISTS public.idx_fec_cycle;
DROP INDEX IF EXISTS public.idx_fec_transaction_date;
DROP INDEX IF EXISTS public.idx_fec_contributor_name;
DROP INDEX IF EXISTS public.idx_fec_state;
