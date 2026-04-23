# Candidate Questionnaire Tab — Implementation Blueprint
**Date:** 2026-04-23
**Status:** PLANNING — no code written
**Target file replaced:** `lib/screens/crm/widgets/candidate_questionnaire_panel.dart` (rewritten in place) + new files

---

## Architecture Overview

### Data Flow

```
CandidateDetailScreen (tab index 4)
  └── CandidateQuestionnairePanel(candidateId)          [thin shell, no change]
        └── QuestionnaireTabController (StatefulWidget)
              │
              ├── CandidateRepository.fetchAllSubmissions(candidateId)
              │     └── Supabase: SELECT * FROM candidate_endorsement_responses
              │           WHERE candidate_id = $1 ORDER BY submitted_at DESC
              │
              ├── CandidateRepository.fetchEndorsementScore(candidateId)
              │     └── Supabase RPC: get_candidate_endorsement_score($1)
              │           ├── reads form_schemas.schema_json for moyd_aligned_answer + weight
              │           └── joins against form_submissions.data JSONB
              │
              │   [on edit]
              └── CandidateRepository.updateAnswer(submissionId, questionId, newValue)
                    └── Supabase RPC: update_endorsement_response($1, $2, $3)
                          ├── SECURITY DEFINER — checks is_staff()
                          ├── UPDATE form_submissions SET data = jsonb_set(data, …)
                          └── INSERT form_submission_edits (audit row)
```

### Scoring: Server-Side via SQL Function

**Decision: server-side scoring in `public.get_candidate_endorsement_score()`.**

Rationale: (a) schema metadata and answers both live in Postgres; computing there avoids shipping the full schema JSON on every tab open. (b) Score becomes queryable for future candidate-list sorting (`ORDER BY endorsement_score DESC`). (c) Schema changes auto-propagate without a Flutter app release. (d) Trade-off is one RPC round-trip (~50ms), mitigated by issuing in parallel with the submissions list via `Future.wait`.

Client-side fallback: when `scoring_available == false` (v1 schema detected — no question has a `weight` field), the ring is replaced with a notice and answers render flat without grouping. The tab is usable the moment any submission exists, before v2 launches.

### Edit Write-Back Path

Staff edits go through a dedicated RPC rather than direct UPDATE on `form_submissions.data`, to enforce:
1. Audit trail (who changed what and when).
2. Atomic JSONB patch (`jsonb_set`) instead of overwriting the whole `data` blob.
3. `SECURITY DEFINER` to enforce `is_staff()` without granting direct write access on `form_submissions`.

---

## Data Layer

### Migration 1: form_submission_edits audit table

File: `supabase/migrations/20260423_00_form_submission_edits.sql` (mirror copy — canonical source in moydforms repo).

```sql
BEGIN;

CREATE TABLE IF NOT EXISTS public.form_submission_edits (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id   uuid NOT NULL REFERENCES public.form_submissions(id) ON DELETE CASCADE,
  question_id     text NOT NULL,
  old_value       jsonb,
  new_value       jsonb NOT NULL,
  edited_by       uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  edited_at       timestamptz NOT NULL DEFAULT now(),
  edit_note       text
);

CREATE INDEX IF NOT EXISTS idx_fse_submission_id ON public.form_submission_edits (submission_id);

ALTER TABLE public.form_submission_edits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Staff can read edits"
  ON public.form_submission_edits
  FOR SELECT TO authenticated
  USING (public.is_staff());

-- No INSERT/UPDATE/DELETE policy — writes go through the SECURITY DEFINER RPC.

COMMIT;
```

### Migration 2: update_endorsement_response RPC

File: `supabase/migrations/20260423_01_update_endorsement_response_rpc.sql`

```sql
BEGIN;

CREATE OR REPLACE FUNCTION public.update_endorsement_response(
  p_submission_id  uuid,
  p_question_id    text,
  p_new_value      jsonb,
  p_edit_note      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_value jsonb;
  v_edit_id   uuid;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'Unauthorized: staff role required';
  END IF;

  SELECT data -> p_question_id
    INTO v_old_value
    FROM public.form_submissions
   WHERE id = p_submission_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Submission % not found', p_submission_id;
  END IF;

  UPDATE public.form_submissions
     SET data = jsonb_set(data, ARRAY[p_question_id], p_new_value, true),
         updated_at = now()
   WHERE id = p_submission_id;

  INSERT INTO public.form_submission_edits
         (submission_id, question_id, old_value, new_value, edited_by, edit_note)
  VALUES (p_submission_id, p_question_id, v_old_value, p_new_value, auth.uid(), p_edit_note)
  RETURNING id INTO v_edit_id;

  RETURN jsonb_build_object(
    'edit_id',     v_edit_id,
    'question_id', p_question_id,
    'old_value',   v_old_value,
    'new_value',   p_new_value,
    'edited_at',   now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_endorsement_response TO authenticated;

COMMIT;
```

### Migration 3: get_candidate_endorsement_score RPC

File: `supabase/migrations/20260423_02_get_candidate_endorsement_score_rpc.sql`

Reads `form_schemas.schema_json` for v2 metadata (`moyd_aligned_answer`, `weight`, `policy_area`). When those are absent (v1 schema), returns `scoring_available: false` with raw answers.

```sql
BEGIN;

CREATE OR REPLACE FUNCTION public.get_candidate_endorsement_score(p_candidate_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission_id   uuid;
  v_data            jsonb;
  v_schema          jsonb;
  v_slug            text;
  v_submitted_at    timestamptz;
  v_questions       jsonb;
  v_question        jsonb;
  v_q_id            text;
  v_q_type          text;
  v_q_text          text;
  v_answer          jsonb;
  v_aligned_ans     text;
  v_weight          numeric;
  v_policy_area     text;
  v_aligned         boolean;
  v_total_weight    numeric := 0;
  v_aligned_weight  numeric := 0;
  v_total_qs        int := 0;
  v_answered_qs     int := 0;
  v_area_total_w    jsonb := '{}'::jsonb;
  v_area_aligned_w  jsonb := '{}'::jsonb;
  v_answer_rows     jsonb := '[]'::jsonb;
  v_area_scores     jsonb := '{}'::jsonb;
  v_area_key        text;
  v_has_v2          boolean := false;
BEGIN
  IF NOT public.is_staff() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT fs.id, fs.data, fs.created_at, fsch.schema_json, fsch.slug
    INTO v_submission_id, v_data, v_submitted_at, v_schema, v_slug
    FROM public.form_submissions fs
    JOIN public.form_schemas fsch ON fsch.id = fs.form_id
   WHERE fs.candidate_id = p_candidate_id
     AND fsch.slug LIKE 'endorsement-questionnaire%'
     AND fs.status IN ('submitted','reviewed','processed')
   ORDER BY fs.created_at DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'candidate_id', p_candidate_id,
      'submission_id', NULL,
      'scoring_available', false,
      'has_submission', false,
      'answers', '[]'::jsonb,
      'overall_percent', NULL,
      'area_scores', '{}'::jsonb
    );
  END IF;

  v_questions := v_schema -> 'questions';

  SELECT bool_or((q->>'weight') IS NOT NULL)
    INTO v_has_v2
    FROM jsonb_array_elements(v_questions) q;

  FOR v_question IN SELECT * FROM jsonb_array_elements(v_questions)
  LOOP
    v_q_id       := v_question->>'id';
    v_q_type     := v_question->>'question_type';
    v_q_text     := v_question->>'text';
    v_aligned_ans := v_question->>'moyd_aligned_answer';
    v_weight     := COALESCE((v_question->>'weight')::numeric, 1.0);
    v_policy_area := COALESCE(v_question->>'policy_area', 'general');

    IF v_q_type IN ('section_header','file_upload') THEN CONTINUE; END IF;

    v_total_qs := v_total_qs + 1;
    v_answer := v_data -> v_q_id;
    IF v_answer IS NOT NULL AND v_answer != 'null'::jsonb THEN
      v_answered_qs := v_answered_qs + 1;
    END IF;

    v_aligned := false;
    IF v_aligned_ans IS NOT NULL AND v_answer IS NOT NULL THEN
      v_aligned := (v_answer #>> '{}') = v_aligned_ans;
    END IF;

    IF v_aligned_ans IS NOT NULL THEN
      v_total_weight := v_total_weight + v_weight;
      v_area_total_w := jsonb_set(v_area_total_w, ARRAY[v_policy_area],
        to_jsonb(COALESCE((v_area_total_w->>v_policy_area)::numeric,0) + v_weight));
      IF v_aligned THEN
        v_aligned_weight := v_aligned_weight + v_weight;
        v_area_aligned_w := jsonb_set(v_area_aligned_w, ARRAY[v_policy_area],
          to_jsonb(COALESCE((v_area_aligned_w->>v_policy_area)::numeric,0) + v_weight));
      END IF;
    END IF;

    v_answer_rows := v_answer_rows || jsonb_build_object(
      'question_id', v_q_id,
      'question_text', v_q_text,
      'question_type', v_q_type,
      'policy_area', v_policy_area,
      'weight', v_weight,
      'answer', v_answer,
      'aligned', v_aligned,
      'moyd_aligned_answer', v_aligned_ans,
      'options', v_question->'options'
    );
  END LOOP;

  FOR v_area_key IN SELECT key FROM jsonb_object_keys(v_area_total_w) k(key)
  LOOP
    DECLARE
      v_aw numeric := COALESCE((v_area_aligned_w->>v_area_key)::numeric, 0);
      v_tw numeric := COALESCE((v_area_total_w->>v_area_key)::numeric, 0);
    BEGIN
      v_area_scores := jsonb_set(v_area_scores, ARRAY[v_area_key],
        jsonb_build_object(
          'aligned_weight', v_aw,
          'total_weight', v_tw,
          'percent', CASE WHEN v_tw > 0 THEN round((v_aw/v_tw)*100) ELSE NULL END
        ));
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'candidate_id', p_candidate_id,
    'submission_id', v_submission_id,
    'submitted_at', v_submitted_at,
    'form_slug', v_slug,
    'scoring_available', v_has_v2,
    'has_submission', true,
    'overall_percent', CASE WHEN v_total_weight > 0 THEN round((v_aligned_weight/v_total_weight)*100) ELSE NULL END,
    'total_questions', v_total_qs,
    'answered_count', v_answered_qs,
    'area_scores', v_area_scores,
    'answers', v_answer_rows
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_candidate_endorsement_score TO authenticated;

COMMIT;
```

---

## Repository + Models (Dart)

### New models

`lib/models/crm/endorsement_score.dart`:
```dart
class EndorsementScore {
  final String candidateId;
  final String? submissionId;
  final bool hasSubmission;
  final bool scoringAvailable;
  final double? overallPercent;
  final int totalQuestions;
  final int answeredCount;
  final DateTime? submittedAt;
  final Map<String, PolicyAreaScore> areaScores;
  final List<EndorsementAnswer> answers;
  factory EndorsementScore.fromJson(Map<String, dynamic>);
  factory EndorsementScore.empty(String candidateId);
}

class PolicyAreaScore {
  final double alignedWeight;
  final double totalWeight;
  final double? percent;
  factory PolicyAreaScore.fromJson(Map<String, dynamic>);
}
```

`lib/models/crm/endorsement_answer.dart`:
```dart
enum QuestionType { radio, checkbox, shortAnswer, longAnswer, number, email, phone, dropdown, datePicker, unknown }

class EndorsementAnswer {
  final String questionId;
  final String questionText;
  final QuestionType questionType;
  final String policyArea;
  final double weight;
  final dynamic answer;
  final bool? aligned;
  final String? moydAlignedAnswer;
  final List<Map<String, String>> options;
  bool get isAnswered => answer != null;
  bool get isLongText => questionType == QuestionType.longAnswer;
  bool get isScorable => moydAlignedAnswer != null;
}
```

`lib/models/crm/endorsement_submission_summary.dart`:
```dart
class EndorsementSubmissionSummary {
  final String submissionId;
  final DateTime submittedAt;
  final String formSlug;
  final String? submitterName;
}
```

### CandidateRepository additions

```dart
Future<EndorsementScore> fetchEndorsementScore(String candidateId);
Future<List<EndorsementSubmissionSummary>> fetchAllSubmissions(String candidateId);
Future<Map<String, dynamic>> updateAnswer(String submissionId, String questionId, dynamic newValue, {String? editNote});
String generateCandidateQuestionnaireLink(String candidateId, {String slug = 'endorsement-questionnaire-2026-v2'});
```

---

## UI Components (Dart Widgets)

File layout:
```
lib/screens/crm/widgets/
  candidate_questionnaire_panel.dart          [1-line child swap]
  questionnaire/
    questionnaire_tab_controller.dart         [replaces EndorsementQuestionnaireSection]
    alignment_summary_card.dart
    alignment_ring_painter.dart
    policy_area_section.dart
    answer_tile.dart
    expandable_answer.dart                    [moved from old section]
    edit_answer_dialog.dart
    send_link_action.dart
    submission_history_drawer.dart
```

### `questionnaire_tab_controller.dart`
StatefulWidget. Fetches score + submissions in parallel via `Future.wait`. Three render states: loading / error / loaded. Loaded branch: empty → SendLinkAction; populated → AlignmentSummaryCard + "Why running" callout + list of PolicyAreaSection + "View history" button when submissions > 1.

### `alignment_summary_card.dart`
Layout: ring left/top (120–160px), metadata right/bottom (date, answered count, form slug). If `scoringAvailable == false`, ring shows "?" + "Scoring requires v2 schema" notice.

### `alignment_ring_painter.dart`
CustomPainter. Two arcs: background track (opacity 0.12), foreground filled `-π/2` start, sweepAngle `2π * (percent/100)`. Color interpolation: republicanRed → slateBlue → democratBlue → sunriseGold.

### `policy_area_section.dart`
StatefulWidget. Header: area name humanized + progress bar + "X/Y aligned" chip + expand chevron. Body: Wrap of AnswerTile (ListView below 480px). Poor-scoring areas default-expanded (<60%).

### `answer_tile.dart`
Question label + answer value + aligned dot. Long-text uses ExpandableAnswer. Staff-only trailing edit pencil → EditAnswerDialog.

### `edit_answer_dialog.dart`
Editor per type: RadioListTile for radio/dropdown, CheckboxListTile for checkbox, TextField for long/short, numeric keyboard for number. Cancel + Save footer. Save → updateAnswer RPC → optimistic setState via onSaved callback.

### `send_link_action.dart`
Empty state card. Builds deep link `https://forms.moyoungdemocrats.org/endorsement-questionnaire-2026-v2?candidate_id=X`, copies to clipboard, SnackBar confirm.

### `submission_history_drawer.dart`
Bottom sheet (mobile) / dialog (desktop). ListView of BrandedActivityFeedItem with date + form slug + CURRENT chip.

---

## Build Sequence

| Step | Description | Complexity | Est. Hours |
|------|-------------|-----------|------------|
| 1 | SQL migrations (3 files) | M | 3–4h |
| 2 | Flutter models (3 files) | S | 1h |
| 3 | Repository methods (4 methods) | S | 1–2h |
| 4 | Read-only UI (7 new files) | L | 6–8h |
| 5 | Edit dialog + write path | M | 3–4h |
| 6 | Share-link action | S | 0.5h |
| 7 | Submission history | M | 2–3h |
| **Total** | | | **17–23h** |

Steps 2 and 3 parallelize with Step 1 once the RPC JSON shape is locked from this blueprint.

---

## Dependencies on v2 Questionnaire Schema

v1 (current): no `policy_area`/`moyd_aligned_answer`/`weight` → fallback mode (raw answers, no ring, no grouping, edit still works).

v2 (concurrent): required per-question fields `policy_area`, `moyd_aligned_answer`, `weight`. Schema-driven UI; adding/renaming areas needs no code change.

Blocking: none. Migration 1 can ship with v1 live. Full scoring activates the moment a v2 submission exists.

---

## Risks + Open Questions

**Risk A — Supabase project boundary (HIGH):** Confirm CRM `_supabase.privilegedClient` points to the moydforms Supabase project. `form_submissions`/`form_schemas`/`candidates` must share one Postgres instance for the RPCs to work. If separate, needs Edge Function proxy or FDW — blueprint addendum required.

**Risk B — `is_staff()` existence (MEDIUM):** Confirm `public.is_staff()` exists in the moydforms project and returns correctly for CRM users. If absent or using a different signal (JWT claim, different table), the RPC migrations need adjustment before apply.

**Risk C — `edited_by` identity (MEDIUM):** CRM uses service-role client. `auth.uid()` under service-role returns null, breaking the audit column. Decision: (a) move CRM staff to Supabase Auth (preferred), or (b) add explicit `p_editor_id uuid` parameter sourced from CRM session.

**Risk D — Concurrent edits (LOW):** Two staff editing same answer → last-write-wins. `jsonb_set` is atomic per row; two UPDATEs don't serialize. Audit preserves both. Acceptable for MVP; optimistic lock later if contention arises.

**Risk E — Re-submission after staff edit (MEDIUM):** New public submission = new row; staff edits live on the old row; history drawer exposes both. Staff must be aware. Consider CRM notification on new submission as future enhancement.

**Risk F — v2 schema drift (MEDIUM):** Scoring function reads schema for the submission's own form_slug, so v2.0 submissions score against v2.0 schema. Bump slug to v3 for breaking changes; minor-version changes stay in same slug.

---

## File Tree (after execution)

```
lib/
  models/crm/
    endorsement_score.dart                          [NEW]
    endorsement_answer.dart                         [NEW]
    endorsement_submission_summary.dart             [NEW]
  services/crm/
    candidate_repository.dart                       [MODIFIED — 4 new methods]
  screens/crm/widgets/
    candidate_questionnaire_panel.dart              [MODIFIED — 1 line]
    endorsement_questionnaire_section.dart          [DELETED after Step 4]
    questionnaire/
      questionnaire_tab_controller.dart             [NEW]
      alignment_summary_card.dart                   [NEW]
      alignment_ring_painter.dart                   [NEW]
      policy_area_section.dart                      [NEW]
      answer_tile.dart                              [NEW]
      expandable_answer.dart                        [NEW — moved from old section]
      edit_answer_dialog.dart                       [NEW]
      send_link_action.dart                         [NEW]
      submission_history_drawer.dart                [NEW]

supabase/migrations/
  20260423_00_form_submission_edits.sql             [NEW — mirror]
  20260423_01_update_endorsement_response_rpc.sql   [NEW — mirror]
  20260423_02_get_candidate_endorsement_score_rpc.sql [NEW — mirror]
```

---

*Blueprint authored 2026-04-23. No production code or SQL has been executed.*
