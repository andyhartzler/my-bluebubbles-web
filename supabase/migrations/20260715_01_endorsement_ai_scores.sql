-- Gemini-judged endorsement alignment scores.
--
-- Replaces the rigid client-side rule-based alignment score for the endorsement
-- hub. Each row is one submission scored by Gemini reading the candidate's FULL
-- responses (selected option + written detail) against MOYD's policy platform.
-- Re-runnable and idempotent per submission (PK = submission_id, upsert).
--
-- Public schema only. Additive / non-destructive.

create table if not exists public.endorsement_ai_scores (
  submission_id uuid primary key
    references public.form_submissions (id) on delete cascade,
  candidate_id  uuid,
  overall_score int  not null check (overall_score between 0 and 100),
  per_issue     jsonb not null default '[]'::jsonb,
  rationale     text,
  model         text,
  scored_at     timestamptz not null default now()
);

comment on table public.endorsement_ai_scores is
  'Gemini-judged alignment of an endorsement submission against the MOYD platform. overall_score 0-100; per_issue = [{id,label,score,stance,rationale}]. Idempotent per submission_id (upsert to re-score).';

alter table public.endorsement_ai_scores enable row level security;

-- Staff (execs) read; service_role does the writing from the scoring pipeline.
drop policy if exists endorsement_ai_scores_staff_read on public.endorsement_ai_scores;
create policy endorsement_ai_scores_staff_read
  on public.endorsement_ai_scores
  for select
  to authenticated
  using (is_staff());

drop policy if exists endorsement_ai_scores_service on public.endorsement_ai_scores;
create policy endorsement_ai_scores_service
  on public.endorsement_ai_scores
  for all
  to service_role
  using (true)
  with check (true);
