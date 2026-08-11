-- Applied to production 2026-08-11 as 20260811163924.
--
-- FIRST ATTEMPT AT THE MAUTIC MEMBER SYNC LOOP FIX. It did not work, and is
-- kept here only so the repo matches the migration history in production.
-- It patched public.trigger_sync_member_to_mautic() and
-- public.process_mautic_sync_log(), but the triggers on public.members and
-- public.mautic_sync_log execute the copies in the `extensions` schema
-- (pg_trigger.tgfoid resolved to extensions.*), so this migration created two
-- unused duplicate functions in public and changed no live behaviour. The log
-- kept accumulating at the same rate, which is how the mistake was caught.
--
-- 20260811_02 patches the live functions in `extensions` and drops the two
-- dead public duplicates this migration created. Read that file for the
-- explanation of the loop.

CREATE OR REPLACE FUNCTION public.trigger_sync_member_to_mautic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payload JSONB;
  request_id BIGINT;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NOT (
         (OLD.email                  IS DISTINCT FROM NEW.email)
      OR (OLD.name                   IS DISTINCT FROM NEW.name)
      OR (OLD.phone                  IS DISTINCT FROM NEW.phone)
      OR (OLD.phone_e164             IS DISTINCT FROM NEW.phone_e164)
      OR (OLD.address                IS DISTINCT FROM NEW.address)
      OR (OLD.city                   IS DISTINCT FROM NEW.city)
      OR (OLD.state                  IS DISTINCT FROM NEW.state)
      OR (OLD.zip_code               IS DISTINCT FROM NEW.zip_code)
      OR (OLD.county                 IS DISTINCT FROM NEW.county)
      OR (OLD.congressional_district IS DISTINCT FROM NEW.congressional_district)
      OR (OLD.senate_district        IS DISTINCT FROM NEW.senate_district)
      OR (OLD.house_district         IS DISTINCT FROM NEW.house_district)
      OR (OLD.date_of_birth          IS DISTINCT FROM NEW.date_of_birth)
      OR (OLD.school_name            IS DISTINCT FROM NEW.school_name)
      OR (OLD.college                IS DISTINCT FROM NEW.college)
      OR (OLD.high_school            IS DISTINCT FROM NEW.high_school)
      OR (OLD.chapter_position       IS DISTINCT FROM NEW.chapter_position)
      OR (OLD.membership_eligible    IS DISTINCT FROM NEW.membership_eligible)
    ) THEN
      RETURN NEW;
    END IF;
  END IF;

  IF NEW.email IS NULL OR NEW.email = '' THEN
    RETURN NEW;
  END IF;

  payload := jsonb_build_object(
    'type', 'member',
    'record', row_to_json(NEW)::jsonb
  );

  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/sync-to-mautic',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyMTcxOTksImV4cCI6MjA3NTc5MzE5OX0.KsOsdwE8Bl4CcHIdYzNmOrDOs_ajle9s7DY4lfXzWFA'
    ),
    body := payload
  ) INTO request_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Mautic member sync failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.process_mautic_sync_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.success = TRUE
     AND NEW.mautic_id IS NOT NULL
     AND NEW.action IN ('create', 'update')
     AND NEW.entity_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN

    IF NEW.entity_type = 'member' THEN
      UPDATE members
         SET mautic_id = NEW.mautic_id
       WHERE id = NEW.entity_id::UUID
         AND mautic_id IS DISTINCT FROM NEW.mautic_id;
    ELSIF NEW.entity_type = 'subscriber' THEN
      UPDATE subscribers
         SET mautic_id = NEW.mautic_id
       WHERE id = NEW.entity_id::UUID
         AND mautic_id IS DISTINCT FROM NEW.mautic_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
