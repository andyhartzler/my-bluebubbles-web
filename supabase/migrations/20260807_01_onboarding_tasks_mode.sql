-- Onboarding follow-up tasks carry the mode they were minted under.
--
-- WHY. onboarding-followups reads ONBOARDING_MODE at DRAIN time, up to 24h
-- after the task was created. That meant a task minted while the system was
-- deliberately quiet would start sending the moment the mode was flipped, so
-- member-onboard defended itself by refusing to write tasks at all outside
-- live. The side effect was that the cascade could never complete a single
-- pass in test: the queue was unreachable, and public.onboarding_tasks has
-- held zero rows since it was created on 2026-07-14.
--
-- Stamping the mode on the row moves the guard to where the hazard actually
-- is. A task is a promise made under one operating mode and is honoured only
-- under that same mode: onboarding-followups now filters on mode, so a test
-- task can never be drained as a live send, and a live task can never be
-- silently closed out by a drain that happens to run in test.
--
-- Only 'test' and 'live' exist here. dry_run sends nothing, so it owes no
-- follow-up and mints no row; there is deliberately no default, because a
-- task whose mode is unknown must fail loudly rather than pick one.
SET search_path = public, pg_temp;

ALTER TABLE public.onboarding_tasks
  ADD COLUMN mode text NOT NULL
  CONSTRAINT onboarding_tasks_mode_check CHECK (mode IN ('test', 'live'));

COMMENT ON COLUMN public.onboarding_tasks.mode IS
  'ONBOARDING_MODE in force when this task was created. onboarding-followups '
  'only drains tasks whose mode equals the mode it is running in.';

-- The drainer scans (mode, done, run_after); mode is now the leading predicate.
DROP INDEX IF EXISTS public.onboarding_tasks_due_idx;
CREATE INDEX onboarding_tasks_due_idx
  ON public.onboarding_tasks (mode, done, run_after);
