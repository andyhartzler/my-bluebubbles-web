-- Closes a bypass left open by 20260811_06, found by that migration's own
-- adversarial verification pass and confirmed live afterwards.
--
-- 20260811_06 revoked public.format_dashboard_metrics_for_knowledge() from anon on
-- the reasoning that its only caller runs as postgres, so no client role needs
-- EXECUTE. That reasoning is correct about the inner function and stops exactly one
-- level too early.
--
-- public.sync_dashboard_metrics_to_knowledge() is SECURITY DEFINER owned by
-- postgres, was still granted to anon and authenticated, and calls the revoked
-- function from inside its own body, where it succeeds because it runs as the
-- owner. Verified live with the publishable anon key AFTER _06 was applied:
--   POST /rest/v1/rpc/sync_dashboard_metrics_to_knowledge -> HTTP 204
-- The revoke was real and it was reachable around.
--
-- SCOPE THIS HONESTLY. The wrapper RETURNS void, so an anonymous caller reads
-- nothing back. What it gets is an unauthenticated WRITE trigger: each call
-- rebuilds a knowledge_documents row. The cost is resource abuse and unbounded
-- writes driven by a stranger, not disclosure. It is a lower severity than the
-- seven PII functions closed in _06 and it is still not something a stranger
-- should be able to drive.
--
-- REVOKED FROM PUBLIC, not only from anon. anon and authenticated both inherit
-- PUBLIC, so revoking the two named roles alone leaves the grant intact and reads
-- as effective. That precise mistake has now been caught twice today.
--
-- NOTHING LOSES A CALLER. Enumerated before revoking: zero references in the
-- Flutter CRM, zero in the website, zero in any deployed edge function, zero in
-- cron.job. Its single in-database caller is public.trigger_sync_dashboard_metrics,
-- and pg_trigger shows NO trigger bound to that function on any table, so the whole
-- chain is unreachable dead code today.
--
-- Verified after applying: the same anonymous POST now returns
-- HTTP 401 42501 permission denied for function sync_dashboard_metrics_to_knowledge.
revoke execute on function public.sync_dashboard_metrics_to_knowledge() from public;
revoke execute on function public.sync_dashboard_metrics_to_knowledge() from anon;
revoke execute on function public.sync_dashboard_metrics_to_knowledge() from authenticated;

-- Pin search_path. An unpinned SECURITY DEFINER function resolves unqualified names
-- against the caller's path, which is a privilege-escalation path in its own right.
alter function public.sync_dashboard_metrics_to_knowledge() set search_path to 'public';
