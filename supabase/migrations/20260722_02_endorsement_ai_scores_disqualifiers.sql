-- Disqualifier mechanic for the Gemini endorsement judge.
--
-- The rescoring rubric (2026-07-22) judges through MOYD's progressive lens and
-- treats positions that break core platform values (trans healthcare,
-- reproductive rights, labor, restorative justice, voting rights) as
-- disqualifying: disqualified=true and the overall score is capped at 25.
-- disqualifiers = [{issue_id, position, quote, why_disqualifying}].
--
-- Public schema only. Additive / non-destructive.

alter table public.endorsement_ai_scores
  add column if not exists disqualified boolean not null default false,
  add column if not exists disqualifiers jsonb not null default '[]'::jsonb;

comment on column public.endorsement_ai_scores.disqualified is
  'True when any answer breaks a core MOYD value (see disqualifiers). Overall score is capped at 25.';
comment on column public.endorsement_ai_scores.disqualifiers is
  'Array of {issue_id, position, quote, why_disqualifying} for each disqualifying answer.';
