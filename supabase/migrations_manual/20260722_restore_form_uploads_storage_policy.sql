-- Restore anonymous uploads to the form-uploads storage bucket.
-- Applied to prod 2026-07-22 via psql.
--
-- Incident: candidate Rene Vance (and everyone else) could not attach a
-- headshot on the endorsement questionnaire. moydforms' upload route
-- (/api/forms/[slug]/upload) uses the ANON key, and storage.objects had NO
-- INSERT policy for bucket form-uploads: every upload 403'd inside Supabase
-- ("new row violates row-level security policy") and surfaced as a generic
-- 500. Last successful upload was 2026-07-20 23:22 UTC; the permissive
-- policy was evidently dropped during the 2026-07-21/22 RLS perf/audit
-- policy consolidation. public.form_files still had its "Anyone can insert
-- files" policy, so only the storage side was broken.
--
-- The bucket itself enforces the guardrails (25MB file_size_limit and an
-- image/document mime allowlist), and the route validates form existence,
-- so a bucket-scoped INSERT policy restores the original design.

create policy form_uploads_public_insert on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'form-uploads');

-- Verified post-apply: POST to the production endpoint with a probe PNG
-- returned 200 + public URL (probe object deleted after via Storage API).
