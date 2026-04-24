-- =============================================================================
-- Migration: 20260428_01_audit_triggers.sql
-- Phase:    Access Audit — Phase 2 (attach audit triggers)
-- Author:   Wave 1 Agent D
-- Date:     2026-04-28
-- Depends:  20260424_01_audit_foundations.sql (creates public.fn_audit_log_trigger)
--
-- Purpose
--   Attach the generic audit trigger public.fn_audit_log_trigger() as
--   AFTER INSERT OR UPDATE OR DELETE FOR EACH ROW on high-value mutable tables
--   so that every write lands in public.audit_log with (table, op, row_id,
--   auth.uid, before, after, timestamp). See 05-plan.md Phase 2 + §2.4.
--
-- Tables audited (24 attached — member_roles added in-file below):
--   Core people:     members
--   Donors:          donors, donor_profiles, donor_tags, donor_activity_log
--   Candidates:      candidates, historical_candidates
--   Organization:    chapters, committees
--   Events/Meetings: events, meetings, scheduled_meetings
--   Finance:         bank_transactions, receipts, mec_reports
--   Jobs:            jobs, job_applications
--   Member Portal:   member_profile_changes, member_submitted_events
--   Forms:           form_schemas, form_submissions
--   Knowledge:       knowledge_documents
--   Subscribers:     subscribers
--
-- Explicitly EXCLUDED (and why)
--   • form_analytics, form_field_analytics, form_events, job_analytics_events
--       — too high volume (anon inserts) would flood audit_log.
--   • audit_log itself, auth.audit_log_entries
--       — self-reference / external.
--   • mautic_sync_log, knowledge_usage_log, legislation_sync_log,
--     email_logs, email_log_members
--       — already sync/activity logs; don't audit log-table writes.
--   • mo_voter_file, mec_contributions, mec_expenditures, fec_contributions,
--     donor_contacts, donor_enrichment
--       — read-mostly, multi-million-row; would balloon audit_log.
--   • crm_dashboard_metrics
--       — trigger-maintained rollup; machine-driven writes.
--   • canvas_boards, canvas_nodes, canvas_connections
--       — committee whiteboard; high-frequency realtime; not audit-worthy.
--   • legislation_tracked_bills, legislation_bill_actions,
--     legislation_legislators, legislation_* (sync)
--   • slack_* (synced), mautic_sync_* (synced), bill_notes (committee scope,
--     defer), fec_finance_cache (cache).
--
-- Meta (audit the audit)
--   • member_roles — created by the prior migration 20260424_01_audit_foundations
--     (Phase 0). By migration-apply order it exists when this migration runs.
--     Trigger for it is wired at the bottom of this file. (Originally flagged as
--     missing because Agent D's live audit predated Phase 0 apply.)
--
-- id column verification
--   All 24 attached tables have an `id uuid` primary-key column, confirmed
--   against information_schema.columns on 2026-04-28. The generic trigger
--   public.fn_audit_log_trigger() relies on NEW.id / OLD.id; no special
--   ctid-based fallback is needed.
--
-- Rollback
--   DROP TRIGGER IF EXISTS trg_audit_<tablename> ON public.<tablename>;
--   (repeat per trigger below)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Core people
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_members ON public.members;
CREATE TRIGGER trg_audit_members
  AFTER INSERT OR UPDATE OR DELETE ON public.members
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Donors
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_donors ON public.donors;
CREATE TRIGGER trg_audit_donors
  AFTER INSERT OR UPDATE OR DELETE ON public.donors
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_donor_profiles ON public.donor_profiles;
CREATE TRIGGER trg_audit_donor_profiles
  AFTER INSERT OR UPDATE OR DELETE ON public.donor_profiles
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_donor_tags ON public.donor_tags;
CREATE TRIGGER trg_audit_donor_tags
  AFTER INSERT OR UPDATE OR DELETE ON public.donor_tags
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_donor_activity_log ON public.donor_activity_log;
CREATE TRIGGER trg_audit_donor_activity_log
  AFTER INSERT OR UPDATE OR DELETE ON public.donor_activity_log
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Candidates
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_candidates ON public.candidates;
CREATE TRIGGER trg_audit_candidates
  AFTER INSERT OR UPDATE OR DELETE ON public.candidates
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_historical_candidates ON public.historical_candidates;
CREATE TRIGGER trg_audit_historical_candidates
  AFTER INSERT OR UPDATE OR DELETE ON public.historical_candidates
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Organization
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_chapters ON public.chapters;
CREATE TRIGGER trg_audit_chapters
  AFTER INSERT OR UPDATE OR DELETE ON public.chapters
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_committees ON public.committees;
CREATE TRIGGER trg_audit_committees
  AFTER INSERT OR UPDATE OR DELETE ON public.committees
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Events + Meetings
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_events ON public.events;
CREATE TRIGGER trg_audit_events
  AFTER INSERT OR UPDATE OR DELETE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_meetings ON public.meetings;
CREATE TRIGGER trg_audit_meetings
  AFTER INSERT OR UPDATE OR DELETE ON public.meetings
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_scheduled_meetings ON public.scheduled_meetings;
CREATE TRIGGER trg_audit_scheduled_meetings
  AFTER INSERT OR UPDATE OR DELETE ON public.scheduled_meetings
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Finance
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_bank_transactions ON public.bank_transactions;
CREATE TRIGGER trg_audit_bank_transactions
  AFTER INSERT OR UPDATE OR DELETE ON public.bank_transactions
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_receipts ON public.receipts;
CREATE TRIGGER trg_audit_receipts
  AFTER INSERT OR UPDATE OR DELETE ON public.receipts
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_mec_reports ON public.mec_reports;
CREATE TRIGGER trg_audit_mec_reports
  AFTER INSERT OR UPDATE OR DELETE ON public.mec_reports
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Jobs
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_jobs ON public.jobs;
CREATE TRIGGER trg_audit_jobs
  AFTER INSERT OR UPDATE OR DELETE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_job_applications ON public.job_applications;
CREATE TRIGGER trg_audit_job_applications
  AFTER INSERT OR UPDATE OR DELETE ON public.job_applications
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Member Portal
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_member_profile_changes ON public.member_profile_changes;
CREATE TRIGGER trg_audit_member_profile_changes
  AFTER INSERT OR UPDATE OR DELETE ON public.member_profile_changes
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_member_submitted_events ON public.member_submitted_events;
CREATE TRIGGER trg_audit_member_submitted_events
  AFTER INSERT OR UPDATE OR DELETE ON public.member_submitted_events
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Forms
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_form_schemas ON public.form_schemas;
CREATE TRIGGER trg_audit_form_schemas
  AFTER INSERT OR UPDATE OR DELETE ON public.form_schemas
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

DROP TRIGGER IF EXISTS trg_audit_form_submissions ON public.form_submissions;
CREATE TRIGGER trg_audit_form_submissions
  AFTER INSERT OR UPDATE OR DELETE ON public.form_submissions
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Knowledge
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_knowledge_documents ON public.knowledge_documents;
CREATE TRIGGER trg_audit_knowledge_documents
  AFTER INSERT OR UPDATE OR DELETE ON public.knowledge_documents
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Subscribers
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_subscribers ON public.subscribers;
CREATE TRIGGER trg_audit_subscribers
  AFTER INSERT OR UPDATE OR DELETE ON public.subscribers
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- -----------------------------------------------------------------------------
-- Meta (audit the audit) — member_roles
-- -----------------------------------------------------------------------------
-- Table is created by the prior migration 20260424_01_audit_foundations.sql
-- (Phase 0). By migration application order, member_roles exists when this
-- migration runs. Agent D's live audit predated Phase 0 apply, so the table
-- appeared missing at audit time — the trigger is added here and will bind
-- at migration-apply time.
DROP TRIGGER IF EXISTS trg_audit_member_roles ON public.member_roles;
CREATE TRIGGER trg_audit_member_roles
  AFTER INSERT OR UPDATE OR DELETE ON public.member_roles
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- =============================================================================
-- Verification (run after migration applies):
--   SELECT tgname, tgrelid::regclass
--   FROM pg_trigger
--   WHERE tgname LIKE 'trg_audit_%'
--   ORDER BY tgname;
-- Expected row count: 24
-- =============================================================================
