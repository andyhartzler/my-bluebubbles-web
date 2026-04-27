-- =====================================================================
-- 20260507_01_prefill_endorsement_for_candidate.sql
--
-- "Smart endorsement form" — convert list-it-out questions into
-- confirm-this-is-correct prefilled answers using data we already have.
--
-- Adds a STABLE SECURITY DEFINER RPC that, given a candidate UUID,
-- returns a JSON object whose keys correspond to `prefill_source`
-- strings on form questions in `form_schemas.schema.questions[]`. The
-- moydforms renderer calls this once on form load when the URL has
-- `?candidate_id=<uuid>`, and surfaces a "Confirm correct / Edit"
-- toggle for each prefilled question.
--
-- =============================================
-- Single-source-of-truth contract for the new question shape
-- =============================================
-- A `prefilledConfirm` question in form_schemas.schema.questions[] looks like:
--
--   {
--     "id": "raised_to_date",
--     "page": 6,
--     "text": "Total raised to date (USD)",
--     "question_type": "prefilled_confirm",
--     "prefill_source": "mec_total_raised",
--     "prefill_format": "currency",   -- optional: currency | text | csv | date
--     "fallback_question_type": "number",  -- what the editable widget renders as
--     "required": true
--   }
--
-- The RPC return shape is:
--   {
--     "raised_to_date": {
--       "value": 12345.67,
--       "display": "$12,345.67",
--       "source": "mec_financial_summaries (committee C123456)",
--       "confidence": "high"   -- high | medium | low | missing
--     },
--     ...
--   }
--
-- Confidence levels:
--   high    — direct lookup, single canonical source (e.g. MEC summary)
--   medium  — derived/rolled-up (e.g. summed from contributions table)
--   low     — heuristic (e.g. voter-history primary count)
--   missing — no data found; renderer should NOT prefill, just show the
--             editable fallback widget.
--
-- All keys in the response are OPTIONAL. If a question's prefill_source
-- has no matching key, the renderer falls back to a plain editable widget.
--
-- =============================================
-- Supported prefill_source values (v1)
-- =============================================
--   mec_committee_name     -- comma-separated committee names from candidate_mec_committee
--   mec_committee_id       -- comma-separated MEC IDs (C-prefixed)
--   mec_total_raised       -- USD numeric, summed over all committees this cycle
--   mec_contribution_count -- integer
--   incumbent_yn           -- "yes"/"no" string from candidates.incumbent
--   prior_office           -- text describing prior elected office (legislator hit)
--   voter_primary_participation
--                          -- list of Democratic primaries voted in (last 6yr)
--   filing_status          -- "filed YYYY-MM-DD" / "needs to be filed"
--   campaign_committee_name -- candidates.campaign_committee or fallback to MEC
-- =============================================

SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.prefill_endorsement_for_candidate(
  p_candidate_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cand            public.candidates%ROWTYPE;
  v_result          jsonb := '{}'::jsonb;
  v_mec_ids         text[];
  v_mec_names       text[];
  v_total_raised    numeric;
  v_contrib_count   integer;
  v_voter_history   jsonb;
  v_primary_list    text[];
  v_legislator_role text;
BEGIN
  -- 1. Load candidate row.
  SELECT * INTO v_cand FROM public.candidates WHERE id = p_candidate_id;
  IF NOT FOUND THEN
    RETURN '{}'::jsonb;
  END IF;

  -- 2. MEC committee names + ids (preferring the normalized lookup table,
  --    fall back to the inline mec_committee_ids array if empty).
  SELECT
    array_agg(DISTINCT cmc.mec_id ORDER BY cmc.mec_id),
    array_agg(DISTINCT mc.committee_name ORDER BY mc.committee_name)
    FILTER (WHERE mc.committee_name IS NOT NULL)
  INTO v_mec_ids, v_mec_names
  FROM public.candidate_mec_committee cmc
  LEFT JOIN public.mec_committees mc ON mc.mec_id = cmc.mec_id
  WHERE cmc.candidate_id = p_candidate_id;

  IF v_mec_ids IS NULL OR array_length(v_mec_ids, 1) IS NULL THEN
    -- legacy path: inline column on candidates
    SELECT array_remove(v_cand.mec_committee_ids, NULL) INTO v_mec_ids;
    IF v_mec_ids IS NOT NULL AND array_length(v_mec_ids, 1) > 0 THEN
      SELECT array_agg(DISTINCT mc.committee_name ORDER BY mc.committee_name)
        FILTER (WHERE mc.committee_name IS NOT NULL)
      INTO v_mec_names
      FROM public.mec_committees mc
      WHERE mc.mec_id = ANY (v_mec_ids);
    END IF;
  END IF;

  IF v_mec_ids IS NOT NULL AND array_length(v_mec_ids, 1) > 0 THEN
    v_result := v_result || jsonb_build_object(
      'mec_committee_id',
      jsonb_build_object(
        'value',   array_to_string(v_mec_ids, ', '),
        'display', array_to_string(v_mec_ids, ', '),
        'source',  'candidate_mec_committee',
        'confidence', 'high'
      )
    );

    IF v_mec_names IS NOT NULL AND array_length(v_mec_names, 1) > 0 THEN
      v_result := v_result || jsonb_build_object(
        'mec_committee_name',
        jsonb_build_object(
          'value',   array_to_string(v_mec_names, ', '),
          'display', array_to_string(v_mec_names, ', '),
          'source',  'mec_committees.committee_name',
          'confidence', 'high'
        )
      );
      -- Also surface the first name as the canonical campaign_committee_name
      -- if the candidates table itself doesn't have one set.
      v_result := v_result || jsonb_build_object(
        'campaign_committee_name',
        jsonb_build_object(
          'value',   coalesce(nullif(v_cand.campaign_committee, ''), v_mec_names[1]),
          'display', coalesce(nullif(v_cand.campaign_committee, ''), v_mec_names[1]),
          'source',  CASE
            WHEN nullif(v_cand.campaign_committee, '') IS NULL THEN 'mec_committees.committee_name'
            ELSE 'candidates.campaign_committee'
          END,
          'confidence', 'high'
        )
      );
    END IF;

    -- 3. Total raised — preferred source is mec_financial_summaries (a single
    --    row per committee+election period), fall back to summing contributions.
    SELECT coalesce(sum(total_contributions), 0)
    INTO v_total_raised
    FROM public.mec_financial_summaries
    WHERE mec_id = ANY (v_mec_ids);

    IF v_total_raised IS NULL OR v_total_raised = 0 THEN
      -- Fallback: roll up from mec_contributions
      SELECT coalesce(sum(contribution_amount), 0), count(*)
      INTO v_total_raised, v_contrib_count
      FROM public.mec_contributions
      WHERE mec_id = ANY (v_mec_ids);

      IF v_total_raised > 0 THEN
        v_result := v_result || jsonb_build_object(
          'mec_total_raised',
          jsonb_build_object(
            'value',   v_total_raised,
            'display', '$' || to_char(v_total_raised, 'FM999,999,999.00'),
            'source',  'mec_contributions (summed)',
            'confidence', 'medium'
          )
        );
      END IF;
    ELSE
      v_result := v_result || jsonb_build_object(
        'mec_total_raised',
        jsonb_build_object(
          'value',   v_total_raised,
          'display', '$' || to_char(v_total_raised, 'FM999,999,999.00'),
          'source',  'mec_financial_summaries',
          'confidence', 'high'
        )
      );
    END IF;

    -- Contribution count (always from the contributions table — the summary
    -- doesn't store a count). Cheap because (mec_id) is indexed.
    IF v_contrib_count IS NULL THEN
      SELECT count(*) INTO v_contrib_count
      FROM public.mec_contributions
      WHERE mec_id = ANY (v_mec_ids);
    END IF;

    IF v_contrib_count IS NOT NULL AND v_contrib_count > 0 THEN
      v_result := v_result || jsonb_build_object(
        'mec_contribution_count',
        jsonb_build_object(
          'value',   v_contrib_count,
          'display', to_char(v_contrib_count, 'FM999,999'),
          'source',  'mec_contributions (count)',
          'confidence', 'high'
        )
      );
    END IF;
  END IF;  -- end MEC block

  -- 4. Incumbent y/n
  v_result := v_result || jsonb_build_object(
    'incumbent_yn',
    jsonb_build_object(
      'value',   CASE WHEN v_cand.incumbent THEN 'yes' ELSE 'no' END,
      'display', CASE WHEN v_cand.incumbent THEN 'Yes — currently holds this seat' ELSE 'No — not the incumbent' END,
      'source',  'candidates.incumbent',
      'confidence', 'high'
    )
  );

  -- 5. Prior elected office — if there's a legislator_id, the candidate has
  --    a hit in legislation_legislators which means current/prior office.
  IF v_cand.legislator_id IS NOT NULL THEN
    SELECT
      coalesce(
        nullif(concat_ws(' ',
          ll.chamber,
          'District ' || nullif(ll.district, '')
        ), ''),
        'Missouri General Assembly'
      )
    INTO v_legislator_role
    FROM public.legislation_legislators ll
    WHERE ll.id = v_cand.legislator_id;

    IF v_legislator_role IS NOT NULL THEN
      v_result := v_result || jsonb_build_object(
        'prior_office',
        jsonb_build_object(
          'value',   v_legislator_role,
          'display', v_legislator_role || ' — confirmed via OpenStates legislator match',
          'source',  'legislation_legislators',
          'confidence', 'high'
        )
      );
    END IF;
  END IF;

  -- 6. Past voting record / Democratic primary participation — pulled from
  --    mo_voter_file.voter_history (JSONB array of "MM/DD/YYYY <Election>"
  --    strings). We filter to "Primary" entries from the last 6 years.
  IF v_cand.mo_voter_file_id IS NOT NULL THEN
    SELECT vf.voter_history
    INTO v_voter_history
    FROM public.mo_voter_file vf
    WHERE vf.voter_id = v_cand.mo_voter_file_id;

    IF v_voter_history IS NOT NULL THEN
      WITH parsed AS (
        SELECT jsonb_array_elements_text(v_voter_history) AS raw
      ),
      filtered AS (
        SELECT raw
        FROM parsed
        WHERE raw ILIKE '%Primary%'
          -- keep last 6 years
          AND substring(raw FROM '\d{4}')::int >= extract(year FROM now())::int - 6
      )
      SELECT array_agg(raw ORDER BY raw DESC)
      INTO v_primary_list
      FROM filtered;

      IF v_primary_list IS NOT NULL AND array_length(v_primary_list, 1) > 0 THEN
        v_result := v_result || jsonb_build_object(
          'voter_primary_participation',
          jsonb_build_object(
            'value',   array_to_string(v_primary_list, '; '),
            'display', array_to_string(v_primary_list, E'\n'),
            'source',  'mo_voter_file.voter_history',
            'confidence', 'low'  -- low because we can't tell D vs R primary
          )
        );
      END IF;
    END IF;
  END IF;

  -- 7. Filing status
  IF coalesce(v_cand.filing_status, '') = 'filed' OR v_cand.filing_date IS NOT NULL THEN
    v_result := v_result || jsonb_build_object(
      'filing_status',
      jsonb_build_object(
        'value',   coalesce('filed ' || v_cand.filing_date, 'filed'),
        'display', 'Filed' || coalesce(' on ' || v_cand.filing_date, ''),
        'source',  'candidates.filing_status',
        'confidence', 'high'
      )
    );
  ELSE
    v_result := v_result || jsonb_build_object(
      'filing_status',
      jsonb_build_object(
        'value',   'needs_to_file',
        'display', 'Filing not yet recorded — confirm or update',
        'source',  'candidates.filing_status',
        'confidence', 'medium'
      )
    );
  END IF;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.prefill_endorsement_for_candidate(uuid) IS
'Smart-form prefill RPC for endorsement-questionnaire-2026. Returns a jsonb
object keyed by prefill_source strings. Each value has shape
{value, display, source, confidence}. Used by moydforms renderer to
convert list-it-out questions into confirm-this-is-correct prefilled
answers. STABLE SECURITY DEFINER so anonymous form visitors can hit it
through the moydforms anon key without exposing the underlying tables.';

-- Anon needs EXECUTE so the public form page can read prefill data when
-- the URL contains a candidate_id. The function only returns derived
-- aggregates + names that are already public knowledge (filings, MEC
-- committee names) so this does not leak anything new.
GRANT EXECUTE ON FUNCTION public.prefill_endorsement_for_candidate(uuid) TO anon, authenticated;

-- =============================================
-- Schema-version bump on the endorsement-questionnaire-2026 row.
-- Adds the new `prefilledConfirm`-style questions for the data points we
-- already know. The renderer (moydforms) interprets `question_type =
-- 'prefilled_confirm'` and falls back to `fallback_question_type` if the
-- RPC returns no value for the question's `prefill_source`.
-- =============================================
-- The CRM form-builder serializes to either `schema.questions[]` (legacy
-- raw JSON) or `schema.fields[]` (FormFieldConfig output). We patch
-- whichever array is present, using the same per-field metadata in both
-- shapes — that way an in-flight builder save can round-trip without
-- silently stripping our prefill_source.
DO $migrate$
DECLARE
  v_id              uuid;
  v_schema          jsonb;
  v_use_questions   boolean;
  v_arr_path        text;
  v_inner_type_key  text;
  v_arr             jsonb;
BEGIN
  SELECT id, schema INTO v_id, v_schema
  FROM public.form_schemas
  WHERE slug = 'endorsement-questionnaire-2026';

  IF v_id IS NULL THEN
    RETURN;
  END IF;

  v_use_questions := v_schema ? 'questions';
  v_arr_path      := CASE WHEN v_use_questions THEN 'questions' ELSE 'fields' END;
  -- moydforms reads `question_type` on the questions[] shape and `type`
  -- on the fields[] shape — same value, different key.
  v_inner_type_key := CASE WHEN v_use_questions THEN 'question_type' ELSE 'type' END;

  v_arr := v_schema -> v_arr_path;
  IF v_arr IS NULL THEN
    RETURN;
  END IF;

  v_arr := (
    SELECT jsonb_agg(
      CASE
        WHEN q->>'id' = 'campaign_committee_name' THEN q ||
          jsonb_build_object(
            v_inner_type_key,         'prefilled_confirm',
            'prefill_source',         'campaign_committee_name',
            'fallback_question_type', 'short_answer'
          )
        WHEN q->>'id' = 'mec_id' THEN q ||
          jsonb_build_object(
            v_inner_type_key,         'prefilled_confirm',
            'prefill_source',         'mec_committee_id',
            'fallback_question_type', 'short_answer'
          )
        WHEN q->>'id' = 'raised_to_date' THEN q ||
          jsonb_build_object(
            v_inner_type_key,         'prefilled_confirm',
            'prefill_source',         'mec_total_raised',
            'prefill_format',         'currency',
            'fallback_question_type', 'number'
          )
        WHEN q->>'id' = 'prior_office' THEN q ||
          jsonb_build_object(
            v_inner_type_key,         'prefilled_confirm',
            'prefill_source',         'incumbent_yn',
            'fallback_question_type', 'radio'
          )
        WHEN q->>'id' = 'prior_office_detail' THEN q ||
          jsonb_build_object(
            'prefill_source',         'prior_office'
          )
        WHEN q->>'id' = 'democratic_primary_history' THEN q ||
          jsonb_build_object(
            v_inner_type_key,         'prefilled_confirm',
            'prefill_source',         'voter_primary_participation',
            'fallback_question_type', 'long_answer'
          )
        ELSE q
      END
    )
    FROM jsonb_array_elements(v_arr) q
  );

  v_schema := jsonb_set(v_schema, ARRAY['version'], '"1.1.0"'::jsonb, true);
  v_schema := jsonb_set(v_schema, ARRAY[v_arr_path], v_arr, true);

  UPDATE public.form_schemas SET schema = v_schema WHERE id = v_id;
END;
$migrate$;
