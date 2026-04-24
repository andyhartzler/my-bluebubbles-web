-- ============================================================================
-- 20260424_03_storage_rls.sql
--
-- Phase 1b of the access-control / audit-trail plan.
-- See: /tmp/moyd-access-audit/05-plan.md §3 Phase 1b
--      /tmp/moyd-access-audit/03-crm-audit.md §B.1 (11 storage-write sites)
--      /tmp/moyd-access-audit/04-supabase-audit.md §B#8 (20/23 buckets public)
--
-- SCOPE
-- -----
-- Today the Flutter web bundle embeds the service-role JWT. Every Dart storage
-- upload routes through `CRMSupabaseService.privilegedClient.storage.*` which
-- bypasses storage.objects RLS entirely. After Phase 1d the Dart client is
-- switched back to anon, so every bucket that the CRM writes to needs
-- authenticated RLS policies gated on `public.is_staff()`.
--
-- This migration:
--   1. Adds staff-gated INSERT/UPDATE/DELETE policies to the 10+ buckets the
--      CRM writes to from Dart (today via privilegedClient, soon via anon).
--   2. Removes permissive `{public}` write policies on buckets that should
--      require staff membership (member-documents, quick-access-files, events,
--      governing-documents). These predate the access-control plan and would
--      leave writes wide open to anon after Phase 1d.
--   3. Flips `job-applications` bucket to `public = false` (PII fix per
--      04-supabase-audit §B#8 — resume PII URL-guessable today).
--   4. Adds a SELECT policy on `job-applications` for staff + owner, so the
--      in-app application reviewer and the original applicant can still read.
--   5. Preserves existing committee-scope policies on `canvas-files` and
--      `member-photos` (committee flow already works; don't expand access).
--
-- PII RISK FIX
-- ------------
-- `job-applications` is `public=true` today — resumes (PDF/DOCX) at
-- https://<project>.supabase.co/storage/v1/object/public/job-applications/<uid>/<file>
-- are reachable by anyone who guesses the path. Flipping `public=false` forces
-- all reads through the Storage REST endpoint which enforces RLS. The new
-- SELECT policy permits (a) staff (exec or committee member) for reviewer UI
-- and (b) the uploader (`auth.uid()::text = foldername(name)[1]`) — matching
-- the existing `Users can delete own job application files` pattern.
--
-- The public INSERT policy (`Public upload access for job applications`) is
-- kept so unauthenticated applicants can still submit resumes. The user-scope
-- UPDATE/DELETE policies are kept.
--
-- ROLLBACK
-- --------
-- Every CREATE POLICY is preceded by DROP POLICY IF EXISTS to make the
-- migration idempotent. To fully roll back:
--   UPDATE storage.buckets SET public = true WHERE id = 'job-applications';
--   DROP POLICY <each staff_* policy> ON storage.objects;
--   -- Re-create the dropped `{public}` permissive policies from the pre-audit
--   -- snapshot below.
-- Pre-migration policy snapshot is captured as comments in §0 below and
-- preserved in git history.
--
-- NOT APPLIED — DRAFT ONLY.
-- ============================================================================


-- ============================================================================
-- §0. Pre-migration audit snapshot (captured 2026-04-24, read-only queries)
-- ============================================================================
-- Source: SELECT id, name, public FROM storage.buckets ORDER BY id;
--
-- id                   | public
-- ---------------------+--------
-- avatars              | t
-- campaign-images      | t
-- campaigns            | t
-- candidate-photos     | t
-- canvas-files         | t
-- events               | t
-- form-documents       | t
-- form-uploads         | f
-- governing-documents  | t
-- job-applications     | t    <-- FLIPPED TO FALSE BY THIS MIGRATION
-- legislation-pdfs     | t
-- legislator-photos    | t
-- listmonk-media       | t
-- mautic               | t
-- mec-filings          | f
-- meetings             | t
-- member-documents     | t
-- member-photos        | t
-- membership-cards     | t
-- moyd-assets          | t
-- quick-access-files   | t
-- receipts             | t
-- slack-files          | t
--
-- Source: SELECT policyname, cmd, roles, qual, with_check FROM pg_policies
--         WHERE schemaname='storage' AND tablename='objects';
--
-- 70 policies total. Relevant to Phase 1b write-path buckets:
--
-- member-documents:
--   "All Access Pass xe2kp1_0" SELECT {public}  -- KEEP (public reads expected)
--   "All Access Pass xe2kp1_1" INSERT {public}  -- DROP (this migration)
--   "All Access Pass xe2kp1_2" UPDATE {public}  -- DROP (this migration)
--   "Public read access for member-documents" SELECT {public} -- KEEP
--   "Service role uploads/updates/deletes from member-documents"  -- KEEP
--
-- quick-access-files:
--   "Anyone can view quick access files" SELECT {public}  -- KEEP
--   "Anyone can upload quick access files" INSERT {public} -- DROP
--   "Anyone can update quick access files" UPDATE {public} -- DROP
--   "Anyone can delete quick access files" DELETE {public} -- DROP
--
-- events:
--   "Public can view event files" SELECT {public}                -- KEEP
--   "Authenticated users can upload event files" INSERT {public} -- DROP (mislabelled: role is public)
--   "Authenticated users can update event files" UPDATE {public} -- DROP (same)
--   "Authenticated users can delete event files" DELETE {public} -- DROP (same)
--
-- governing-documents:
--   "Public Access txrot6_0" SELECT {public}  -- KEEP
--   "Public Access txrot6_1" INSERT {public}  -- DROP
--   "Public Access txrot6_2" UPDATE {public}  -- DROP
--
-- chapter-documents: NO POLICIES EXIST TODAY -- ADD staff INSERT/UPDATE/DELETE.
--
-- candidate-photos: authenticated INSERT/UPDATE/DELETE + public SELECT.
--   Authenticated-only is currently sufficient (no `is_staff()` check) but we
--   tighten to `is_staff()` for defense-in-depth.
--
-- canvas-files: authenticated INSERT/UPDATE/DELETE/SELECT. Used by committee
--   flow. Do NOT add `is_staff()` staff-all — committee members aren't exec.
--   `is_staff()` DOES cover committee members (is_staff() = exec OR committee),
--   so we can tighten to `is_staff()` without regressing committee access.
--
-- member-photos: public SELECT + public INSERT/UPDATE/DELETE + authenticated
--   INSERT/DELETE variants + service_role DELETE. Used by committee member
--   self-edit flow (anon upload). Keep existing policies — don't expand. This
--   bucket is explicitly owner-scoped by the Dart uploader (path is
--   `${member.id}/...` or `profile-photos/${member.id}_*`) so RLS narrowing is
--   a follow-up.
--
-- legislator-photos: public SELECT + public INSERT/UPDATE + authenticated
--   SELECT. Similar to member-photos — anon/committee flow. Leave.
--
-- form-documents: no existing policies (bucket is public, reads work). Add
--   staff INSERT/UPDATE/DELETE for Dart uploads.
--
-- receipts: no policies (service_role bypasses via receipts edge fn). Add
--   staff INSERT/UPDATE/DELETE as defense-in-depth for the day we stop using
--   service_role in the edge fn.
--
-- membership-cards: only a public SELECT exists. Add staff INSERT/UPDATE/DELETE
--   for the generator flow (server-side today; defense-in-depth for the future).
--
-- meetings: authenticated SELECT + service_role INSERT/UPDATE only. Already
--   tight. Leave untouched.
--
-- job-applications: public SELECT + public INSERT + authenticated UPDATE/DELETE
--   gated on `foldername(name)[1] = auth.uid()::text` + service_role ALL.
--   This migration flips public=false, drops the blanket public SELECT, and
--   replaces it with a staff-or-owner SELECT.
-- ============================================================================


-- ============================================================================
-- §1. Flip job-applications to private + swap SELECT policy
-- ============================================================================

UPDATE storage.buckets SET public = false WHERE id = 'job-applications';

-- Drop the blanket public SELECT (resume PII URL-guessable today).
DROP POLICY IF EXISTS "Public read access for job applications" ON storage.objects;

-- New SELECT: staff (exec or committee) OR the uploader themselves.
-- Uploader-folder pattern mirrors existing delete/update policies on this bucket.
DROP POLICY IF EXISTS "job_applications_select_staff_or_owner" ON storage.objects;
CREATE POLICY "job_applications_select_staff_or_owner"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'job-applications'
        AND (
            public.is_staff()
            OR (storage.foldername(name))[1] = (auth.uid())::text
        )
    );

-- Kept (unchanged):
--   "Public upload access for job applications" INSERT {public}
--   "Users can update own job application files" UPDATE {authenticated, self-folder}
--   "Users can delete own job application files" DELETE {authenticated, self-folder}
--   "Service role full access to job applications" ALL {service_role}


-- ============================================================================
-- §2. member-documents — drop permissive public writes, add staff-only writes
-- ============================================================================

DROP POLICY IF EXISTS "All Access Pass xe2kp1_1" ON storage.objects;
DROP POLICY IF EXISTS "All Access Pass xe2kp1_2" ON storage.objects;

DROP POLICY IF EXISTS "member_documents_insert_staff" ON storage.objects;
CREATE POLICY "member_documents_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'member-documents' AND public.is_staff());

DROP POLICY IF EXISTS "member_documents_update_staff" ON storage.objects;
CREATE POLICY "member_documents_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'member-documents' AND public.is_staff())
    WITH CHECK (bucket_id = 'member-documents' AND public.is_staff());

DROP POLICY IF EXISTS "member_documents_delete_staff" ON storage.objects;
CREATE POLICY "member_documents_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'member-documents' AND public.is_staff());

-- Existing "Public read access for member-documents" SELECT {public} kept.
-- Existing "Service role ..." policies kept.


-- ============================================================================
-- §3. quick-access-files — drop permissive public writes, add staff-only writes
-- ============================================================================

DROP POLICY IF EXISTS "Anyone can upload quick access files" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can update quick access files" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can delete quick access files" ON storage.objects;

DROP POLICY IF EXISTS "quick_access_files_insert_staff" ON storage.objects;
CREATE POLICY "quick_access_files_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'quick-access-files' AND public.is_staff());

DROP POLICY IF EXISTS "quick_access_files_update_staff" ON storage.objects;
CREATE POLICY "quick_access_files_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'quick-access-files' AND public.is_staff())
    WITH CHECK (bucket_id = 'quick-access-files' AND public.is_staff());

DROP POLICY IF EXISTS "quick_access_files_delete_staff" ON storage.objects;
CREATE POLICY "quick_access_files_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'quick-access-files' AND public.is_staff());

-- Existing "Anyone can view quick access files" SELECT {public} kept.


-- ============================================================================
-- §4. events — swap mislabelled public writes for staff-only writes
-- ============================================================================

DROP POLICY IF EXISTS "Authenticated users can upload event files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update event files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete event files" ON storage.objects;

DROP POLICY IF EXISTS "events_insert_staff" ON storage.objects;
CREATE POLICY "events_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'events' AND public.is_staff());

DROP POLICY IF EXISTS "events_update_staff" ON storage.objects;
CREATE POLICY "events_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'events' AND public.is_staff())
    WITH CHECK (bucket_id = 'events' AND public.is_staff());

DROP POLICY IF EXISTS "events_delete_staff" ON storage.objects;
CREATE POLICY "events_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'events' AND public.is_staff());

-- Existing "Public can view event files" SELECT {public} kept.


-- ============================================================================
-- §5. governing-documents — drop permissive public writes, add staff-only writes
-- ============================================================================

DROP POLICY IF EXISTS "Public Access txrot6_1" ON storage.objects;
DROP POLICY IF EXISTS "Public Access txrot6_2" ON storage.objects;

DROP POLICY IF EXISTS "governing_documents_insert_staff" ON storage.objects;
CREATE POLICY "governing_documents_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'governing-documents' AND public.is_staff());

DROP POLICY IF EXISTS "governing_documents_update_staff" ON storage.objects;
CREATE POLICY "governing_documents_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'governing-documents' AND public.is_staff())
    WITH CHECK (bucket_id = 'governing-documents' AND public.is_staff());

DROP POLICY IF EXISTS "governing_documents_delete_staff" ON storage.objects;
CREATE POLICY "governing_documents_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'governing-documents' AND public.is_staff());

-- Existing "Public Access txrot6_0" SELECT {public} kept.


-- ============================================================================
-- §6. chapter-documents — no existing policies, add staff-only writes + read
-- ============================================================================
-- Bucket is referenced by chapter_repository.dart:82 as 'chapter-documents'.
-- It exists in storage.buckets (public=t) but has no RLS policies defined,
-- which means authenticated users get nothing when RLS takes effect. Add the
-- full CRUD suite gated on is_staff(), plus a public SELECT to match the
-- bucket's public=t flag and Dart's getPublicUrl() expectation.

DROP POLICY IF EXISTS "chapter_documents_select_public" ON storage.objects;
CREATE POLICY "chapter_documents_select_public"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'chapter-documents');

DROP POLICY IF EXISTS "chapter_documents_insert_staff" ON storage.objects;
CREATE POLICY "chapter_documents_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'chapter-documents' AND public.is_staff());

DROP POLICY IF EXISTS "chapter_documents_update_staff" ON storage.objects;
CREATE POLICY "chapter_documents_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'chapter-documents' AND public.is_staff())
    WITH CHECK (bucket_id = 'chapter-documents' AND public.is_staff());

DROP POLICY IF EXISTS "chapter_documents_delete_staff" ON storage.objects;
CREATE POLICY "chapter_documents_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'chapter-documents' AND public.is_staff());


-- ============================================================================
-- §7. candidate-photos — tighten existing authenticated writes to staff only
-- ============================================================================
-- Existing policies grant ANY authenticated user write. Replace with is_staff().
-- Public SELECT stays (public=t bucket, Dart uses getPublicUrl).

DROP POLICY IF EXISTS "candidate-photos authenticated write" ON storage.objects;
DROP POLICY IF EXISTS "candidate-photos authenticated update" ON storage.objects;
DROP POLICY IF EXISTS "candidate-photos authenticated delete" ON storage.objects;

DROP POLICY IF EXISTS "candidate_photos_insert_staff" ON storage.objects;
CREATE POLICY "candidate_photos_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'candidate-photos' AND public.is_staff());

DROP POLICY IF EXISTS "candidate_photos_update_staff" ON storage.objects;
CREATE POLICY "candidate_photos_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'candidate-photos' AND public.is_staff())
    WITH CHECK (bucket_id = 'candidate-photos' AND public.is_staff());

DROP POLICY IF EXISTS "candidate_photos_delete_staff" ON storage.objects;
CREATE POLICY "candidate_photos_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'candidate-photos' AND public.is_staff());

-- Existing "candidate-photos public read" SELECT {public} kept.


-- ============================================================================
-- §8. canvas-files — tighten authenticated to is_staff() (committee-scope safe)
-- ============================================================================
-- canvas-files is used by the committee canvas-board feature. Existing
-- policies grant ANY authenticated user CRUD. `is_staff()` returns TRUE for
-- both executive committee members AND committee members (see
-- public.is_staff definition: executive_committee = true OR committee IS NOT
-- NULL), so narrowing to is_staff() does NOT regress committee access — it
-- only excludes the pathological case of a non-staff authenticated user.

DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated update" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated delete" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated view" ON storage.objects;

DROP POLICY IF EXISTS "canvas_files_select_staff" ON storage.objects;
CREATE POLICY "canvas_files_select_staff"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'canvas-files' AND public.is_staff());

DROP POLICY IF EXISTS "canvas_files_insert_staff" ON storage.objects;
CREATE POLICY "canvas_files_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'canvas-files' AND public.is_staff());

DROP POLICY IF EXISTS "canvas_files_update_staff" ON storage.objects;
CREATE POLICY "canvas_files_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'canvas-files' AND public.is_staff())
    WITH CHECK (bucket_id = 'canvas-files' AND public.is_staff());

DROP POLICY IF EXISTS "canvas_files_delete_staff" ON storage.objects;
CREATE POLICY "canvas_files_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'canvas-files' AND public.is_staff());


-- ============================================================================
-- §9. form-documents — no existing policies, add staff-only writes + public read
-- ============================================================================
-- form-documents bucket is public=t and Dart (vote_builder_screen.dart:970)
-- calls getPublicUrl. No storage.objects policies exist today — this works
-- while Dart uses privilegedClient. Post-Phase-1d writes would fail without
-- these policies.

DROP POLICY IF EXISTS "form_documents_select_public" ON storage.objects;
CREATE POLICY "form_documents_select_public"
    ON storage.objects FOR SELECT TO public
    USING (bucket_id = 'form-documents');

DROP POLICY IF EXISTS "form_documents_insert_staff" ON storage.objects;
CREATE POLICY "form_documents_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'form-documents' AND public.is_staff());

DROP POLICY IF EXISTS "form_documents_update_staff" ON storage.objects;
CREATE POLICY "form_documents_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'form-documents' AND public.is_staff())
    WITH CHECK (bucket_id = 'form-documents' AND public.is_staff());

DROP POLICY IF EXISTS "form_documents_delete_staff" ON storage.objects;
CREATE POLICY "form_documents_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'form-documents' AND public.is_staff());


-- ============================================================================
-- §10. receipts — no existing policies, add staff-only writes (defense-in-depth)
-- ============================================================================
-- Today all writes go through the `receipts` edge fn using service_role
-- (bypasses RLS). Dart does not upload to this bucket directly. Adding staff
-- policies costs nothing and keeps the door open for a future refactor that
-- swaps the edge fn to user-JWT + RLS (Phase 1c).

DROP POLICY IF EXISTS "receipts_insert_staff" ON storage.objects;
CREATE POLICY "receipts_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'receipts' AND public.is_staff());

DROP POLICY IF EXISTS "receipts_update_staff" ON storage.objects;
CREATE POLICY "receipts_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'receipts' AND public.is_staff())
    WITH CHECK (bucket_id = 'receipts' AND public.is_staff());

DROP POLICY IF EXISTS "receipts_delete_staff" ON storage.objects;
CREATE POLICY "receipts_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'receipts' AND public.is_staff());

DROP POLICY IF EXISTS "receipts_select_staff" ON storage.objects;
CREATE POLICY "receipts_select_staff"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'receipts' AND public.is_staff());

-- NOTE: receipts bucket is currently public=t. If the receipts edge fn uses
-- getPublicUrl() for emailed links, flipping to private must be coordinated
-- with that code path (signed URLs instead). Out of scope for this migration.


-- ============================================================================
-- §11. membership-cards — staff writes for defense-in-depth
-- ============================================================================
-- Generator is server-side today. Existing public SELECT ("Public read access
-- for pkpass files") kept for card downloads. Add staff writes for the future.

DROP POLICY IF EXISTS "membership_cards_insert_staff" ON storage.objects;
CREATE POLICY "membership_cards_insert_staff"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'membership-cards' AND public.is_staff());

DROP POLICY IF EXISTS "membership_cards_update_staff" ON storage.objects;
CREATE POLICY "membership_cards_update_staff"
    ON storage.objects FOR UPDATE TO authenticated
    USING (bucket_id = 'membership-cards' AND public.is_staff())
    WITH CHECK (bucket_id = 'membership-cards' AND public.is_staff());

DROP POLICY IF EXISTS "membership_cards_delete_staff" ON storage.objects;
CREATE POLICY "membership_cards_delete_staff"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'membership-cards' AND public.is_staff());


-- ============================================================================
-- §12. Buckets NOT touched by this migration (rationale documented)
-- ============================================================================
-- - member-photos: committee members legitimately upload from the anon client
--   (committee_member_settings_screen.dart:260, uses _supabase.client). The
--   existing `{public}` INSERT/UPDATE/DELETE policies permit this flow.
--   Adding `is_staff()` policies on top would work for exec/committee users
--   but would also require dropping the existing public policies, which would
--   break the anon-client path. Defer to a follow-up migration that adds a
--   proper `(storage.foldername(name))[1] = auth.uid()::text`-scoped user
--   policy and removes the blanket public ones. Not a Phase 1b blocker because
--   the anon client already writes successfully today.
--
-- - legislator-photos: similar anon/admin-scripted upload pattern
--   (legislation_service.dart:732 uses `_supabase.storage.from(...)` — anon
--   client). Existing `{public}` policies keep that working. Tightening to
--   staff-only is also a follow-up.
--
-- - meetings: already has authenticated SELECT + service_role-only
--   INSERT/UPDATE. Tight. Leave.
--
-- - avatars, campaign-images, campaigns, listmonk-media, legislation-pdfs,
--   mautic, moyd-assets, slack-files, form-uploads, mec-filings: either
--   already private, already staff-scoped, or not touched by the CRM's
--   privilegedClient write paths enumerated in 03-crm-audit §B.1. Leaving
--   their existing policies untouched.
-- ============================================================================


-- ============================================================================
-- §13. Post-migration verification queries (comment-only, NOT executed)
-- ============================================================================
--
-- 1. Confirm job-applications is private:
--      SELECT public FROM storage.buckets WHERE id = 'job-applications';
--      -- Expected: f
--
-- 2. Confirm staff-gated insert policies exist on each targeted bucket:
--      SELECT policyname, cmd, roles
--      FROM pg_policies
--      WHERE schemaname = 'storage'
--        AND tablename = 'objects'
--        AND policyname LIKE '%_insert_staff'
--      ORDER BY policyname;
--      -- Expected: candidate_photos_insert_staff, canvas_files_insert_staff,
--      --           chapter_documents_insert_staff, events_insert_staff,
--      --           form_documents_insert_staff, governing_documents_insert_staff,
--      --           member_documents_insert_staff, membership_cards_insert_staff,
--      --           quick_access_files_insert_staff, receipts_insert_staff
--      -- (10 rows)
--
-- 3. Confirm permissive public writes on gated buckets are gone:
--      SELECT policyname, cmd, bucket, qual, with_check
--      FROM pg_policies p
--      CROSS JOIN LATERAL (
--        SELECT COALESCE(
--          substring(p.qual FROM 'bucket_id\s*=\s*''([^'']+)'''),
--          substring(p.with_check FROM 'bucket_id\s*=\s*''([^'']+)''')
--        ) AS bucket
--      ) b
--      WHERE schemaname = 'storage' AND tablename = 'objects'
--        AND cmd IN ('INSERT','UPDATE','DELETE')
--        AND 'public' = ANY(roles)
--        AND bucket IN ('member-documents','quick-access-files','events',
--                       'governing-documents','job-applications');
--      -- Expected: only "Public upload access for job applications" (kept on
--      -- purpose for anon applicants). All others gone.
--
-- 4. Spot-check a staff user can still read their own job-applications:
--      SET LOCAL ROLE authenticated;
--      SET LOCAL request.jwt.claim.sub TO '<a staff user uuid>';
--      SELECT name FROM storage.objects WHERE bucket_id = 'job-applications' LIMIT 1;
--      -- Expected: row returned.
--      RESET ROLE;
-- ============================================================================

-- End of migration.
