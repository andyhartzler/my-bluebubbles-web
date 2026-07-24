-- Member onboarding cascade ("Member Poloooza" rebuild).
-- Follow-up task queue processed by the onboarding-followups Edge Function
-- (invoked every 10 min by pg_cron). Each row is one deferred action for a
-- newly onboarded member (e.g. a Slack-join reminder, or a poll to auto-add
-- them to committee/caucus channels once they appear in Slack).
SET search_path = public, pg_temp;

CREATE TABLE IF NOT EXISTS public.onboarding_tasks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id   uuid,
  task_type   text NOT NULL,               -- 'slack_join_reminder' | 'slack_channel_sync'
  run_after   timestamptz,                 -- do not process before this time
  done        boolean NOT NULL DEFAULT false,
  attempts    int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  meta        jsonb                         -- variant, target channels, cc, threadId, etc.
);

-- Fast "what is due now" scan for the cron processor.
CREATE INDEX IF NOT EXISTS onboarding_tasks_due_idx
  ON public.onboarding_tasks (done, run_after);

-- Locked down: only service_role (the Edge Functions) touches this table.
ALTER TABLE public.onboarding_tasks ENABLE ROW LEVEL SECURITY;
