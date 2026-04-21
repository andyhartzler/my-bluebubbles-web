-- 20260421_03_candidates_parse_address.sql
-- Parse candidates.address (free-form text) into zip/city/county columns so the
-- voter-file match can use them. All 520 candidates have `address`; none have
-- `zip`, `city`, or `county` populated.

BEGIN;

-- zip5: last 5-digit block in the address (ignores any ZIP+4 suffix)
UPDATE public.candidates
SET zip = substring(address FROM '(\d{5})(?:-\d{4})?\s*$')
WHERE zip IS NULL AND address IS NOT NULL;

-- Fallback: if not at end of string, grab any 5-digit block
UPDATE public.candidates
SET zip = substring(address FROM '(\d{5})(?:-\d{4})?')
WHERE zip IS NULL AND address IS NOT NULL;

-- state default
UPDATE public.candidates
SET state = 'MO'
WHERE state IS NULL;

-- city: the chunk between the last comma and " MO"
UPDATE public.candidates
SET city = upper(trim(substring(address FROM ',\s*([A-Za-z][A-Za-z\s\.]+?)\s+MO\b')))
WHERE city IS NULL AND address IS NOT NULL;

-- county: derive from voter-file majority-vote per zip5
WITH zip_counties AS (
  SELECT residential_zip5 AS zip5, county,
         ROW_NUMBER() OVER (PARTITION BY residential_zip5 ORDER BY COUNT(*) DESC) AS rnk
  FROM public.mo_voter_file
  WHERE residential_zip5 IS NOT NULL AND residential_zip5 <> ''
  GROUP BY residential_zip5, county
)
UPDATE public.candidates c
SET county = zc.county
FROM zip_counties zc
WHERE zc.rnk = 1
  AND c.zip = zc.zip5
  AND c.county IS NULL;

COMMIT;

-- Verify coverage
SELECT COUNT(*)                       AS total,
       COUNT(zip) FILTER (WHERE zip <> '')       AS with_zip,
       COUNT(city) FILTER (WHERE city <> '')     AS with_city,
       COUNT(county) FILTER (WHERE county <> '') AS with_county
FROM public.candidates;
