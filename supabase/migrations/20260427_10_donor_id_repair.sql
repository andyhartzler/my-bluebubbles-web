-- Repair mec_contributions.donor_id linkage via natural-key match,
-- recompute mec_donors aggregates, install real-time triggers so totals
-- stay live as new contributions arrive.
--
-- See docs/superpowers/plans/2026-04-27-mec-contributions-donor-id-repair.md
-- for full plan, evidence, and rollback procedure.
--
-- This file is a RECORD OF WHAT WAS APPLIED on 2026-04-27 in production.
-- The actual repair was executed via direct psql in batched UPDATEs (the
-- proposal-table + batch-loop approach can't fit in a single SQL file
-- because of timeout boundaries — see the plan doc for the full procedure).
-- This migration captures the load-bearing trigger + function defintions
-- and the persistent schema changes (generated column, backup columns).

-- ---------------------------------------------------------------------------
-- Real-time aggregate triggers (the durable change)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_recompute_mec_donor_aggregate(p_donor_id bigint)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_donor_id IS NULL THEN RETURN; END IF;
  UPDATE public.mec_donors d
  SET total_contributed = coalesce(s.total, 0),
      contribution_count = coalesce(s.cnt, 0),
      first_contribution_date = s.first_d,
      last_contribution_date = s.last_d
  FROM (
    SELECT
      sum(contribution_amount) AS total,
      count(*)::int AS cnt,
      min(contribution_date)::date AS first_d,
      max(contribution_date)::date AS last_d
    FROM public.mec_contributions
    WHERE donor_id = p_donor_id
  ) s
  WHERE d.id = p_donor_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_mec_contributions_aggregate_trigger()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.fn_recompute_mec_donor_aggregate(OLD.donor_id);
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    PERFORM public.fn_recompute_mec_donor_aggregate(NEW.donor_id);
    RETURN NEW;
  ELSE
    IF OLD.donor_id IS DISTINCT FROM NEW.donor_id THEN
      PERFORM public.fn_recompute_mec_donor_aggregate(OLD.donor_id);
      PERFORM public.fn_recompute_mec_donor_aggregate(NEW.donor_id);
    ELSIF OLD.contribution_amount IS DISTINCT FROM NEW.contribution_amount
       OR OLD.contribution_date IS DISTINCT FROM NEW.contribution_date THEN
      PERFORM public.fn_recompute_mec_donor_aggregate(NEW.donor_id);
    END IF;
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_mec_contributions_aggregate ON public.mec_contributions;
CREATE TRIGGER trg_mec_contributions_aggregate
AFTER INSERT OR UPDATE OR DELETE ON public.mec_contributions
FOR EACH ROW
EXECUTE FUNCTION public.fn_mec_contributions_aggregate_trigger();

CREATE OR REPLACE FUNCTION public.fn_recompute_mec_donor_fec_aggregate(p_donor_id bigint)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_donor_id IS NULL THEN RETURN; END IF;
  UPDATE public.mec_donors d
  SET fec_total_contributed = coalesce(s.total, 0),
      fec_contribution_count = coalesce(s.cnt, 0)
  FROM (
    SELECT
      sum(transaction_amount) AS total,
      count(*)::int AS cnt
    FROM public.fec_contributions
    WHERE donor_id = p_donor_id
  ) s
  WHERE d.id = p_donor_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_fec_contributions_aggregate_trigger()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.fn_recompute_mec_donor_fec_aggregate(OLD.donor_id);
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    PERFORM public.fn_recompute_mec_donor_fec_aggregate(NEW.donor_id);
    RETURN NEW;
  ELSE
    IF OLD.donor_id IS DISTINCT FROM NEW.donor_id THEN
      PERFORM public.fn_recompute_mec_donor_fec_aggregate(OLD.donor_id);
      PERFORM public.fn_recompute_mec_donor_fec_aggregate(NEW.donor_id);
    ELSIF OLD.transaction_amount IS DISTINCT FROM NEW.transaction_amount THEN
      PERFORM public.fn_recompute_mec_donor_fec_aggregate(NEW.donor_id);
    END IF;
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_fec_contributions_aggregate ON public.fec_contributions;
CREATE TRIGGER trg_fec_contributions_aggregate
AFTER INSERT OR UPDATE OR DELETE ON public.fec_contributions
FOR EACH ROW
EXECUTE FUNCTION public.fn_fec_contributions_aggregate_trigger();
