-- Chartering form advertised a 250 MB per-file cap that nothing downstream honoured.
--
-- The chain was: form_schemas file_config.max_size_mb = 250 -> the client
-- validator (FileUpload.tsx reads field.maxFileSizeMB) = 250 -> the upload route
-- (site-forms/api/forms/[slug]/upload/route.ts, MAX_FILE_SIZE = 25 * 1024 * 1024)
-- = 25 -> storage.buckets 'form-uploads'.file_size_limit = 26214400 = 25 MiB.
-- An applicant picking a 60 MB roster passed the client check and was rejected
-- by the server, on a REQUIRED field.
--
-- Route and bucket already agree at 25 MiB, so the schema is the wrong number.
-- All nine file_config blocks on this form carry 250 and no other form is
-- touched.
update public.form_schemas
set schema = replace(schema::text, '"max_size_mb": 250', '"max_size_mb": 25')::jsonb,
    updated_at = now()
where slug = 'chapter-chartering'
  and schema::text like '%"max_size_mb": 250%';
