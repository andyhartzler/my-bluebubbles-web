# Candidate Review + Decisions redesign & AI-score depth — 2026-07-23

Approved by Andrew 2026-07-23. Three workstreams, one shared data contract.

## Workstream 1 — Candidate Review page (full redesign + sticky nav)

Files: `lib/features/forms/widgets/submission_detail/*` (body, section_card,
verdict_block, hero), `lib/features/forms/models/submission_review_model.dart`.
Hosts (`SubmissionDetailScreen`, CandidateDetailScreen questionnaire tab) keep
their scroll contexts; the body stays a plain Column.

- **Sticky section navigator** directly under the hero: pill tabs generated
  from the form's real sections (Alignment, Run with us, Where you live and
  run, The race, Policy positions, Documents, References — whatever the schema
  yields). Tap = animated scroll to section; active pill tracks scroll
  position. Implemented inside the body via a `SliverPersistentHeader`-style
  approach OR an overlay pinned row driven by scroll notifications — must work
  embedded in both hosts.
- The old far-left floating "AI ALIGNMENT / rule-based" stat strip is
  retired. Office / District / Raised / Track / flags become a stat band
  inside or directly beneath the hero (navy surface, white/gold text, AA
  contrast).
- **Verdict block**: large score ring (green ≥85, amber 50–84, red <50),
  Gemini narrative beside it, model + old rule-based score as small chips.
  Disqualifier callouts render as red bordered cards with the quote. Per-issue
  breakdown is open by default on wide screens: one row per issue with stance
  icon, label, mini score bar, 1-line rationale. NEW: renders `deductions`
  (see contract) as a "Where the points went" list when score < 100.
- **Section cards**: navy-tinted header row with gold rule + section title;
  answers rendered as content, not a 220px gray label column. Short answers:
  small muted label above, value in titleMedium weight 600. Booleans/choices:
  check/x chips. Long text: quote block with gold left rule + show-more
  (keep). Currency/emails/phones formatted, copy-on-tap where useful.
- Two-column flow on ≥980px stays, but the sticky nav must scroll to the
  correct card wherever the dealer put it.

## Workstream 2 — Decisions tab (rich rows + expand)

Files: `lib/features/forms/screens/endorsement_hub/widgets/decisions/`.
`decision_board.dart` (64KB) must be split into focused files (board scaffold,
toolbar, ballot row, expansion, roster, final-call panel, baseline row) with
ZERO behavior change to voting logic: chair identity/Confirm/final call, live
sync, quorum, withdraw-on-retap, reason sheet all preserved exactly
(`endorsement_vote_repository.dart` and `decision_repository.dart` untouched
unless a bug is found).

- **Sticky toolbar** while the list scrolls: search (name/district), the
  existing All / Needs my vote / (chair) Splits filter, sort menu, and ballot
  progress ("You voted on N of 70").
- **One compact row per ballot candidate**: headshot (existing
  `headshot_avatar.dart`), name, district chip, alignment badge, compact
  Yes / No segmented control + tiny tally ("2Y · 0N · 1 waiting"), consensus
  state accent. Rows are 1-line on desktop, 2-line on mobile. Voting from the
  row works without expanding.
- **District chip tap → district map**: bottom sheet / dialog with
  `MissouriMapWidget` highlighting the candidate's district polygon (reuse
  the office+districtNum resolution used by
  `lib/screens/crm/candidates/candidate_district_sheet.dart`; endorsement
  entries carry office + district strings like "MO House 119" / "MO HD 3" —
  parse chamber + number robustly).
- **Tap row → expands in place**: full AI rationale, deductions list when
  score < 100, disqualifier warnings, tally bar, voter roster, vote reasons,
  Full review link, chair-only Confirm / Final call. Already-decided
  candidates stay locked baseline rows.
- Decided/locked candidates keep their section; expanded state is per-row,
  multiple rows may be expanded.

## Workstream 3 — AI scorer explanation depth

File: `/Users/moyd/moyd-endorsement-campaign/score_endorsements.py`.

- Add `deductions` to the response schema + prompt rules: for any
  overall_score < 100, Gemini must itemize every deduction —
  `{issue_id, label, points_lost (integer, best estimate), quote,
  explanation}` — such that explanation depth scales with distance from 100.
  A 100 may have a brief rationale and empty deductions; sub-100 rationales
  must name every dinged issue; disqualified candidates keep the existing
  disqualifiers treatment plus deductions.
- DDL: `alter table public.endorsement_ai_scores add column if not exists
  deductions jsonb not null default '[]'::jsonb;` (public. prefix — search_path
  gotcha). Upsert writes it.
- Re-run scorer for every submission whose current overall_score < 100
  (`--only` with ids queried from public.endorsement_ai_scores).

## Shared data contract

`public.endorsement_ai_scores.deductions`:
```json
[{"issue_id": "pos_trans_healthcare", "label": "Trans healthcare",
  "points_lost": 2, "quote": "...", "explanation": "..."}]
```
Both UIs must degrade gracefully when `deductions` is empty/absent (older
rows, 100-scorers).

## House rules (hard)

- Contrast verified in BOTH themes; never `Theme.cardColor` on branded navy
  surfaces; white/gold on navy only where ≥4.5:1.
- No em-dashes in any user-visible copy.
- No local `flutter build`; a single `flutter analyze` at the end is the only
  local verification. Deploy verification happens on Netlify after push.
- No "for now" stubs; no behavior regressions in voting logic.
