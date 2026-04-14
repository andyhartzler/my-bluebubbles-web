-- =====================================================
-- Add UNIQUE constraint on mec_reports.quarter
--
-- Without this, the Plaid Edge Function's upsert(..., { onConflict: "quarter" })
-- fails silently (PostgREST can't find a conflict target) and the generated
-- report row is never persisted — even though the CSVs upload and the function
-- returns success:true. This caused 2026-Q1 to appear "filed-ready" in the
-- response but leave the mec_reports table empty.
-- =====================================================

ALTER TABLE public.mec_reports
  ADD CONSTRAINT mec_reports_quarter_unique UNIQUE (quarter);

NOTIFY pgrst, 'reload schema';
