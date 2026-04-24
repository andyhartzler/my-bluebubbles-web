-- 2026-04-24 RLS Phase 3 — close authenticated-role write gaps for the CRM.
--
-- Context (Phase 1a of the per-user-access upgrade per /tmp/moyd-access-audit/05-plan.md):
-- today ~40 Dart files run their writes through `privilegedClient` (a browser-
-- resident service-role JWT). Phase 1d will switch those writers to the anon
-- client, meaning every write will run as role=authenticated and must pass
-- RLS. Before we flip the switch, every CRM-writable table must have an
-- authenticated-role write policy — either staff-wide via `public.is_staff()`
-- or owner-scoped via `= auth.uid()`.
--
-- SCOPE: authoring-only. This file ADDS new policies — it never modifies or
-- drops existing ones. Rollback = DROP POLICY on the ~2 policies created here.
--
-- =========================================================================
--   AUDIT SUMMARY (inline, reproducible via the query at the bottom of this
--   header comment). Date of audit run: 2026-04-24.
--
--   Tables audited: 59 candidate tables from §2.2 of 02-crm-findings.md.
--   2 of those — `voting_forms`, `fec_finance_cache` — do not exist in the
--   public schema and are skipped.
--
--   ─────────────────────────────────────────────────────────────────────────
--   (A) ALREADY ADEQUATE — no new policies needed. These tables already have
--       a policy on TO authenticated with USING (public.is_staff()) (the
--       canonical `rls_phase2_staff_all` created by 20260422_05_rls_phase2.sql)
--       or a pre-existing staff_write. Phase 1d writes will work as-is.
--
--       members, donors, donor_profiles, donor_tags, donor_activity_log,
--       donor_enrichment, candidates, historical_candidates, chapters,
--       committees, events, meetings, scheduled_meetings, meeting_attendance,
--       non_member_attendees, bank_transactions, receipts, mec_reports,
--       plaid_connections, member_profile_changes, member_submitted_events,
--       member_portal_meetings, member_portal_resources, chapter_documents,
--       call_time_lists, call_time_list_items, subscribers, form_submissions,
--       email_campaigns, email_campaign_recipients, email_campaign_links,
--       email_campaign_link_clicks, email_templates, surveys, survey_questions,
--       survey_responses, survey_sessions, slack_user_mapping,
--       slack_channel_committee_mapping, slack_message_archive_status,
--       slack_messages, slack_users_unmatched, event_attendees
--
--   ─────────────────────────────────────────────────────────────────────────
--   (B) OWNER-SCOPED AUTHENTICATED POLICIES — authenticated role has
--       INSERT/UPDATE/DELETE keyed off `created_by = auth.uid()` /
--       `author_id = auth.uid()` / `user_id = auth.uid()` / `member_id = ...`.
--       Matches how the Dart side will populate the column post Phase 1d,
--       so these work without new staff policies. These are also the
--       committee-scoped tables and MUST NOT be converted to staff-all.
--
--       form_schemas          (INSERT/UPDATE/DELETE keyed to created_by)
--       form_templates        (INSERT/UPDATE/DELETE keyed to created_by)
--       knowledge_chat_sessions (INSERT/UPDATE/DELETE keyed to user_id)
--       canvas_boards         (INSERT open; UPDATE open; DELETE owner-scoped)
--       canvas_nodes          (INSERT/UPDATE/DELETE open to authenticated)
--       canvas_connections    (INSERT/UPDATE/DELETE open to authenticated)
--       calendar_events       (INSERT/UPDATE/DELETE open to authenticated)
--       legislation_tracked_bills (INSERT/UPDATE/DELETE open to authenticated)
--       legislation_bill_notes (INSERT/UPDATE/DELETE keyed to author_id)
--       votes                 (INSERT keyed to member_id; SELECT own)
--
--       Committee-flow verification: canvas_*, legislation_*, and votes all
--       apply TO authenticated (not service_role), so committee members with
--       their user JWT will continue to write successfully post-Phase 1d.
--       No changes required.
--
--   ─────────────────────────────────────────────────────────────────────────
--   (C) PARTIAL AUTHENTICATED POLICIES — authenticated has some CRUD ops but
--       not the ones the CRM uses. New policies added below.
--
--       jobs
--         Existing authenticated UPDATE policies:
--           * "Users can update their submissions" — qual =
--             (status='pending' AND submitter_email=auth.jwt()->>'email')
--           * "Job posters can update own jobs" — qual =
--             (submitter_email = auth.email())
--         Gap: `jobs_service.dart:approveJob` / `rejectJob` flip status to
--         'approved' / 'rejected' from staff side — staff are NOT the
--         submitter, so the existing policies block them. Staff-all policy
--         added.
--
--       job_applications
--         Existing authenticated UPDATE policy:
--           * "Job posters can update application status" — only the job
--             poster (by email match) can update.
--         Gap: `jobs_service.dart:updateApplicationStatus` is called from
--         the CRM admin side by staff who typically aren't the job poster.
--         Staff-all policy added.
--
--   ─────────────────────────────────────────────────────────────────────────
--   (D) INTENTIONALLY LEFT SERVICE-ROLE-ONLY — no CRM client writes today
--       (verified via grep for .insert / .update / .upsert / .delete on
--       these table names in lib/). Edge functions or cron jobs populate
--       them. No Phase 1d pressure on these.
--
--       knowledge_documents
--           CRM reads only (ai_assistant_service.dart:240..). Embedding
--           pipeline writes come from `ai-assistant` edge fn with service
--           role. If/when a staff-side `knowledge_documents` management UI
--           lands, add a policy then — don't pre-emptively widen access.
--       legislation_bill_actions
--           Populated by the `openstates-*` edge fns (service role). CRM
--           legislation_service.dart reads only. Keep service-role-only.
--       mec_historical_filings
--           Populated by the MEC scraper edge fn. finances_page.dart reads
--           only (line 274). Public SELECT policy already exists.
--
--   ─────────────────────────────────────────────────────────────────────────
--   (E) EXISTING OVERLY-PERMISSIVE POLICIES — out of scope for this phase
--       but flagged for Andrew's eventual tightening pass. Not changed here
--       because Phase 1a's charter is additive-only.
--
--       quick_links
--           Has 4 policies FOR ALL CRUD ops on role `{public}` (anon AND
--           authenticated). Any unauthenticated caller with the anon key
--           can INSERT/UPDATE/DELETE today. Authenticated staff writes will
--           work post Phase 1d (they fall under the {public} role), but
--           the anon write loophole should be closed in a separate
--           tightening migration. Flagging only.
--
--   ─────────────────────────────────────────────────────────────────────────
--   (F) TABLES NOT PRESENT IN THE DATABASE — skipped.
--
--       voting_forms           (no matching relation in public.*)
--       fec_finance_cache      (fec_api_service.dart upserts this but the
--                               relation does not exist in production;
--                               logged as dead code — caught by 04 audit)
--
-- Reproducibility:
--   SELECT tablename, policyname, cmd, roles::text,
--          left(coalesce(qual,''),60) AS qual,
--          left(coalesce(with_check,''),40) AS with_check
--   FROM pg_policies
--   WHERE schemaname='public'
--     AND tablename IN (<target list>)
--   ORDER BY tablename, cmd;
--
-- Rollback:
--   DROP POLICY IF EXISTS "rls_phase3_jobs_staff_all" ON public.jobs;
--   DROP POLICY IF EXISTS "rls_phase3_job_applications_staff_all"
--     ON public.job_applications;

BEGIN;

-- =========================================================================
-- (C.1) public.jobs — staff can approve/reject/update any submission.
-- =========================================================================
-- Guard: drop-if-exists before CREATE so the migration is idempotent and
-- re-runnable without error.

DROP POLICY IF EXISTS "rls_phase3_jobs_staff_all" ON public.jobs;

CREATE POLICY "rls_phase3_jobs_staff_all"
  ON public.jobs
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

COMMENT ON POLICY "rls_phase3_jobs_staff_all" ON public.jobs IS
  'Phase 1a (20260424_02): staff can INSERT/UPDATE/DELETE any job row — supports the jobs_service.dart approveJob/rejectJob/updateJob flow from the CRM admin side. Does not replace the "anyone can create pending jobs" public INSERT path or the job-poster self-service UPDATE policy.';

-- =========================================================================
-- (C.2) public.job_applications — staff can update application status on
--       behalf of any job, not just jobs they posted.
-- =========================================================================

DROP POLICY IF EXISTS "rls_phase3_job_applications_staff_all" ON public.job_applications;

CREATE POLICY "rls_phase3_job_applications_staff_all"
  ON public.job_applications
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

COMMENT ON POLICY "rls_phase3_job_applications_staff_all" ON public.job_applications IS
  'Phase 1a (20260424_02): staff can INSERT/UPDATE/DELETE any job application — supports jobs_service.dart updateApplicationStatus. Does not replace the anon/public INSERT path used by the public application form.';

-- =========================================================================
-- PostgREST schema reload so the new policies take effect immediately.
-- =========================================================================
NOTIFY pgrst, 'reload schema';

COMMIT;
