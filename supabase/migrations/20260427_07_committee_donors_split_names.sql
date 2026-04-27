-- Add first_name / last_name / company to get_committee_donors_paginated
-- return shape so committees_tab.dart can navigate to MECDonorScreen.

DROP FUNCTION IF EXISTS public.get_committee_donors_paginated(text, integer, integer, text, boolean);

CREATE OR REPLACE FUNCTION public.get_committee_donors_paginated(
  p_mec_id text,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0,
  p_sort_by text DEFAULT 'total'::text,
  p_ascending boolean DEFAULT false
)
RETURNS TABLE(
  donor_id integer,
  donor_name text,
  first_name text,
  last_name text,
  company text,
  city text,
  state text,
  employer text,
  occupation text,
  total numeric,
  cnt integer,
  first_date date,
  last_date date,
  has_fec boolean
)
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    d.id::int,
    CASE
      WHEN c.contributor_company IS NOT NULL AND c.contributor_company != '' THEN c.contributor_company
      WHEN c.contributor_committee IS NOT NULL AND c.contributor_committee != '' THEN c.contributor_committee
      ELSE trim(coalesce(c.contributor_first_name, '') || ' ' || coalesce(c.contributor_last_name, ''))
    END,
    max(c.contributor_first_name),
    max(c.contributor_last_name),
    max(c.contributor_company),
    max(c.city),
    max(c.state),
    max(c.employer),
    max(c.occupation),
    sum(c.contribution_amount),
    count(*)::int,
    min(c.contribution_date)::date,
    max(c.contribution_date)::date,
    coalesce(max(d.fec_contribution_count), 0) > 0
  FROM public.mec_contributions c
  LEFT JOIN public.mec_donors d ON d.id = c.donor_id
  WHERE c.mec_id = p_mec_id
  GROUP BY d.id, 2
  ORDER BY
    CASE WHEN p_sort_by = 'total' AND NOT p_ascending THEN sum(c.contribution_amount) END DESC NULLS LAST,
    CASE WHEN p_sort_by = 'total' AND p_ascending THEN sum(c.contribution_amount) END ASC NULLS LAST,
    CASE WHEN p_sort_by = 'count' AND NOT p_ascending THEN count(*) END DESC,
    CASE WHEN p_sort_by = 'count' AND p_ascending THEN count(*) END ASC,
    CASE WHEN p_sort_by = 'name' THEN 1 END ASC,
    CASE WHEN p_sort_by = 'last_date' AND NOT p_ascending THEN max(c.contribution_date) END DESC NULLS LAST,
    CASE WHEN p_sort_by = 'last_date' AND p_ascending THEN max(c.contribution_date) END ASC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_committee_donors_paginated TO authenticated;
