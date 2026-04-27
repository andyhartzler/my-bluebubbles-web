CREATE OR REPLACE FUNCTION public.fn_candidates_recompute_estimated_age()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.date_of_birth IS NOT NULL THEN
    NEW.estimated_age := EXTRACT(YEAR FROM age(CURRENT_DATE, NEW.date_of_birth))::int;
  ELSIF NEW.birth_year IS NOT NULL THEN
    NEW.estimated_age := EXTRACT(YEAR FROM CURRENT_DATE)::int - NEW.birth_year;
  ELSE
    NEW.estimated_age := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_candidates_recompute_estimated_age ON public.candidates;
CREATE TRIGGER trg_candidates_recompute_estimated_age
BEFORE INSERT OR UPDATE OF date_of_birth, birth_year ON public.candidates
FOR EACH ROW
EXECUTE FUNCTION public.fn_candidates_recompute_estimated_age();

-- One-time backfill
UPDATE public.candidates
SET date_of_birth = date_of_birth
WHERE date_of_birth IS NOT NULL OR birth_year IS NOT NULL;
