-- =====================================================================
-- 20260424_04_personalized_home.sql
-- Personalized home screen + multi-page dashboard support.
--
-- Adds three tables (assignments, dashboard_pages, user_home_preferences),
-- adds members.avatar_url, fixes candidates.moyd_assigned_to to uuid+FK,
-- attaches the audit trigger, adds additive RLS for meeting self-reads,
-- and refines storage policies on member-photos to enforce per-user folders.
--
-- Spec: docs/superpowers/specs/2026-04-24-personalized-home-design.md
-- =====================================================================

SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------
-- 1. user_home_preferences
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_home_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  layout jsonb NOT NULL DEFAULT '{"widgets":[],"columns":4}'::jsonb,
  layout_mobile jsonb NOT NULL DEFAULT '{"widgets":[],"columns":2}'::jsonb,
  show_profile_header boolean NOT NULL DEFAULT true,
  show_assignments boolean NOT NULL DEFAULT true,
  show_meeting_history boolean NOT NULL DEFAULT true,
  show_optional_tiles boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_uhp_updated_at ON public.user_home_preferences;
CREATE TRIGGER trg_uhp_updated_at
  BEFORE UPDATE ON public.user_home_preferences
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

ALTER TABLE public.user_home_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS uhp_self_all ON public.user_home_preferences;
CREATE POLICY uhp_self_all ON public.user_home_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin())
  WITH CHECK (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS uhp_service_role ON public.user_home_preferences;
CREATE POLICY uhp_service_role ON public.user_home_preferences
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_audit_user_home_preferences ON public.user_home_preferences;
CREATE TRIGGER trg_audit_user_home_preferences
  AFTER INSERT OR UPDATE OR DELETE ON public.user_home_preferences
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 2. dashboard_pages (per-user dashboards, one row per page)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.dashboard_pages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL DEFAULT 'My Dashboard',
  position integer NOT NULL DEFAULT 0,
  layout jsonb NOT NULL DEFAULT '{"widgets":[],"columns":4}'::jsonb,
  layout_mobile jsonb NOT NULL DEFAULT '{"widgets":[],"columns":2}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dashboard_pages_user_id
  ON public.dashboard_pages(user_id, position);

DROP TRIGGER IF EXISTS trg_dp_updated_at ON public.dashboard_pages;
CREATE TRIGGER trg_dp_updated_at
  BEFORE UPDATE ON public.dashboard_pages
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

ALTER TABLE public.dashboard_pages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dp_select ON public.dashboard_pages;
CREATE POLICY dp_select ON public.dashboard_pages
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS dp_insert ON public.dashboard_pages;
CREATE POLICY dp_insert ON public.dashboard_pages
  FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND (user_id = auth.uid() OR public.current_user_is_superadmin())
  );

DROP POLICY IF EXISTS dp_update ON public.dashboard_pages;
CREATE POLICY dp_update ON public.dashboard_pages
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin())
  WITH CHECK (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS dp_delete ON public.dashboard_pages;
CREATE POLICY dp_delete ON public.dashboard_pages
  FOR DELETE TO authenticated
  USING (user_id = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS dp_service_role ON public.dashboard_pages;
CREATE POLICY dp_service_role ON public.dashboard_pages
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_audit_dashboard_pages ON public.dashboard_pages;
CREATE TRIGGER trg_audit_dashboard_pages
  AFTER INSERT OR UPDATE OR DELETE ON public.dashboard_pages
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 3. assignments
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assigned_to uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  note text,
  entity_type text,
  entity_id text,
  entity_url text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','done','cancelled')),
  priority text CHECK (priority IN ('low','medium','high')),
  due_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assignments_assigned_to
  ON public.assignments(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_assignments_assigned_by
  ON public.assignments(assigned_by);

DROP TRIGGER IF EXISTS trg_assn_updated_at ON public.assignments;
CREATE TRIGGER trg_assn_updated_at
  BEFORE UPDATE ON public.assignments
  FOR EACH ROW EXECUTE FUNCTION public.tg_set_updated_at();

ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS assn_select ON public.assignments;
CREATE POLICY assn_select ON public.assignments
  FOR SELECT TO authenticated
  USING (
    assigned_to = auth.uid()
    OR assigned_by = auth.uid()
    OR public.current_user_is_superadmin()
  );

DROP POLICY IF EXISTS assn_insert ON public.assignments;
CREATE POLICY assn_insert ON public.assignments
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_staff()
    AND assigned_by IS NOT NULL
    AND assigned_by = auth.uid()
  );

DROP POLICY IF EXISTS assn_update ON public.assignments;
CREATE POLICY assn_update ON public.assignments
  FOR UPDATE TO authenticated
  USING (
    assigned_to = auth.uid()
    OR assigned_by = auth.uid()
    OR public.current_user_is_superadmin()
  )
  WITH CHECK (
    assigned_to = auth.uid()
    OR assigned_by = auth.uid()
    OR public.current_user_is_superadmin()
  );

DROP POLICY IF EXISTS assn_delete ON public.assignments;
CREATE POLICY assn_delete ON public.assignments
  FOR DELETE TO authenticated
  USING (assigned_by = auth.uid() OR public.current_user_is_superadmin());

DROP POLICY IF EXISTS assn_service_role ON public.assignments;
CREATE POLICY assn_service_role ON public.assignments
  FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP TRIGGER IF EXISTS trg_audit_assignments ON public.assignments;
CREATE TRIGGER trg_audit_assignments
  AFTER INSERT OR UPDATE OR DELETE ON public.assignments
  FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_trigger();

-- ---------------------------------------------------------------------
-- 4. members.avatar_url (user-uploaded headshot, separate from
--    auto-fetched profile_pictures jsonb)
-- ---------------------------------------------------------------------
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS avatar_url text;

-- ---------------------------------------------------------------------
-- 5. candidates.moyd_assigned_to: text -> uuid + FK to members.id
--    Supabase audit confirmed 0 populated rows; safe to convert.
-- ---------------------------------------------------------------------
DO $$
DECLARE
  current_type text;
BEGIN
  SELECT data_type INTO current_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'candidates'
      AND column_name = 'moyd_assigned_to';

  IF current_type = 'text' THEN
    -- Empty out any blank strings before cast
    UPDATE public.candidates
       SET moyd_assigned_to = NULL
     WHERE moyd_assigned_to = '';

    EXECUTE 'ALTER TABLE public.candidates
             ALTER COLUMN moyd_assigned_to TYPE uuid
             USING moyd_assigned_to::uuid';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'candidates_moyd_assigned_to_fkey'
  ) THEN
    ALTER TABLE public.candidates
      ADD CONSTRAINT candidates_moyd_assigned_to_fkey
      FOREIGN KEY (moyd_assigned_to)
      REFERENCES public.members(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- 6. Additive RLS for meeting tables so members can see their own
--    attendance / invitations / hosted meetings on the home screen.
--    Existing staff-all policies stay; these are additive SELECTs.
-- ---------------------------------------------------------------------

-- meetings: see if I attended or hosted
DROP POLICY IF EXISTS meetings_self_attended ON public.meetings;
CREATE POLICY meetings_self_attended ON public.meetings
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.meeting_attendance ma
      JOIN public.members m ON m.id = ma.member_id
      WHERE ma.meeting_id = meetings.id
        AND m.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = meetings.meeting_host
        AND m.user_id = auth.uid()
    )
  );

-- scheduled_meetings: see if I created or was invited
DROP POLICY IF EXISTS scheduled_meetings_self_invited ON public.scheduled_meetings;
CREATE POLICY scheduled_meetings_self_invited ON public.scheduled_meetings
  FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.meeting_invitees mi
      JOIN public.members m ON m.id = mi.member_id
      WHERE mi.meeting_id = scheduled_meetings.id
        AND m.user_id = auth.uid()
    )
  );

-- meeting_attendance: my own rows
DROP POLICY IF EXISTS meeting_attendance_self_select ON public.meeting_attendance;
CREATE POLICY meeting_attendance_self_select ON public.meeting_attendance
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = meeting_attendance.member_id
        AND m.user_id = auth.uid()
    )
  );

-- meeting_invitees: my own rows
DROP POLICY IF EXISTS meeting_invitees_self_select ON public.meeting_invitees;
CREATE POLICY meeting_invitees_self_select ON public.meeting_invitees
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.members m
      WHERE m.id = meeting_invitees.member_id
        AND m.user_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- 7. storage.objects: tighten member-photos write policies to
--    enforce per-user folders (storage.foldername(name)[1] = auth.uid()).
--    Keep the existing service_role + public-read policies.
-- ---------------------------------------------------------------------
DO $$
BEGIN
  -- Drop any prior bucket-wide authenticated write policies for member-photos.
  -- (Names vary; drop by policy_name when they exist.)
  IF EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'storage' AND tablename = 'objects'
       AND policyname = 'Authenticated users can upload member photos'
  ) THEN
    DROP POLICY "Authenticated users can upload member photos" ON storage.objects;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'storage' AND tablename = 'objects'
       AND policyname = 'Authenticated users can update member photos'
  ) THEN
    DROP POLICY "Authenticated users can update member photos" ON storage.objects;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_policies
     WHERE schemaname = 'storage' AND tablename = 'objects'
       AND policyname = 'Authenticated users can delete member photos'
  ) THEN
    DROP POLICY "Authenticated users can delete member photos" ON storage.objects;
  END IF;
END $$;

DROP POLICY IF EXISTS "Authenticated users upload own folder member photos" ON storage.objects;
CREATE POLICY "Authenticated users upload own folder member photos" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Authenticated users update own folder member photos" ON storage.objects;
CREATE POLICY "Authenticated users update own folder member photos" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Authenticated users delete own folder member photos" ON storage.objects;
CREATE POLICY "Authenticated users delete own folder member photos" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'member-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- =====================================================================
-- End migration.
-- =====================================================================
