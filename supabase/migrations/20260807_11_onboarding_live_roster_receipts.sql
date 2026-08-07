-- Close the live-mode duplicate-send hole before ONBOARDING_MODE is ever flipped.
--
-- member-onboard's "have we already welcomed this person" probe is
-- (member_id, mode) scoped -- see functions/member-onboard/index.ts, the
-- priorTasks query. The mode scoping is correct: a test row means the mail went
-- to ONBOARDING_TEST_EMAIL, so it must not suppress a real welcome once live.
--
-- The consequence nobody had acted on: public.onboarding_tasks holds ZERO rows
-- at mode='live', so the instant the mode is flipped every existing member
-- reads as never-onboarded. The website route
-- (site-forms/api/membership/process/route.ts) calls member-onboard
-- UNCONDITIONALLY -- there is no new-vs-existing branch around the fetch, and
-- it upserts on email -- so one resubmission by a long-standing member would
-- send them a live first-contact "Welcome Aboard!" (or, worse, a too_young /
-- aged_out rejection, since the probe runs BEFORE the age branch), CC the
-- caucus chairs, fire a real Slack invite, post their name and email into
-- #membership-outreach-committee, and subscribe them to members@ for real.
--
-- So: give every member who predates the live cascade a live-mode receipt.
--
-- task_type is 'pre_existing_roster', not a recycled 'age_branch_notified'.
-- The row must not claim these people were welcomed in live -- they were not.
-- It claims the true thing: they predate live onboarding and must never be
-- first-contacted by it. That also makes the backfill trivially reversible
-- (delete by task_type) if the unwelcomed backlog is ever deliberately mailed.
--
-- These rows CANNOT cause a send. The drainer's due query is
-- .eq("mode", mode).eq("done", false).lte("run_after", now) -- done=true
-- excludes them, and run_after IS NULL never satisfies lte anyway. They are
-- doubly inert, and while the system is in test the mode filter hides them too.

SET search_path = public, pg_temp;

-- Residue from an undocumented hand-invoked cascade test at 00:41:10Z against
-- the "Andy Test" fixture member. Both rows are mode='test'; one is still
-- done=false and cron would keep polling it to no purpose. It was reported as
-- pre-existing state, which it was not.
DELETE FROM public.onboarding_tasks
WHERE mode = 'test'
  AND member_id = '2f1b4df5-5eba-4b17-bfef-8a96b0bdd370';

INSERT INTO public.onboarding_tasks (member_id, task_type, mode, done, run_after, attempts, meta)
SELECT
  m.id,
  'pre_existing_roster',
  'live',
  true,
  NULL,
  0,
  jsonb_build_object(
    'email', m.email,
    'reason', 'Member predates live onboarding. Receipt exists so the (member_id, mode) duplicate-send probe in member-onboard suppresses a live first-contact welcome if this member ever resubmits the membership form.',
    'backfilled_at', now()
  )
FROM public.members m
WHERE NOT EXISTS (
  SELECT 1 FROM public.onboarding_tasks t
  WHERE t.member_id = m.id AND t.mode = 'live'
);
