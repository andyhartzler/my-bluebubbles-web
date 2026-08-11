-- Applied to production 2026-08-11 as 20260811164308.
--
-- Stops the Mautic member sync feedback loop that had been running since
-- 2026-08-05 19:46 UTC, writing ~46,000 rows/day into public.mautic_sync_log
-- for a single member (d3b78425-e543-4cc5-ad3f-5ed8834dce1c).
--
-- WHERE THE LIVE CODE ACTUALLY LIVES: the triggers on public.members and
-- public.mautic_sync_log execute the function copies in the `extensions`
-- schema, not public (pg_trigger.tgfoid = extensions.trigger_sync_member_to_mautic
-- / extensions.process_mautic_sync_log). 20260811_01 patched the public copies
-- and changed nothing. This migration patches the live ones and drops the dead
-- public duplicates.
--
-- THE CYCLE:
--   1. Any UPDATE on public.members fires trigger_sync_member_to_mautic_update,
--      which net.http_post's the row to the sync-to-mautic edge function.
--   2. sync-to-mautic upserts the Mautic contact, then unconditionally runs
--      UPDATE members SET mautic_id = <same value> (its updateMauticId helper),
--      and separately INSERTs into mautic_sync_log, whose AFTER INSERT trigger
--      process_mautic_sync_log ran a second unconditional
--      UPDATE members SET mautic_id = <same value>.
--   3. Both write-backs are no-op UPDATEs: mautic_id does not change. The old
--      guard only skipped when mautic_id HAD changed, so a no-op write-back
--      sailed through it and re-posted to the edge function. Two write-backs
--      per pass, every pass succeeding, forever.
--
-- THE FIX: replace the negative guard with a positive one. Sync only when a
-- field that sync-to-mautic actually maps into the Mautic contact has changed.
-- A no-op UPDATE now changes none of them, so it syncs nothing and the cycle
-- cannot close. This is the shape trigger_sync_subscriber_to_mautic has always
-- had, which is why the subscriber path never looped.
--
-- Field list is taken from mapMemberToMautic() in
-- supabase/functions/sync-to-mautic/index.ts. If a new field is added to that
-- mapping, add it here too or edits to it will not reach Mautic.

CREATE OR REPLACE FUNCTION extensions.trigger_sync_member_to_mautic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
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

-- Second write-back in the cycle. A log row that reports the mautic_id the
-- member already has has nothing to write, so do not write it.
CREATE OR REPLACE FUNCTION extensions.process_mautic_sync_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
  IF NEW.success = TRUE
     AND NEW.mautic_id IS NOT NULL
     AND NEW.action IN ('create', 'update')
     AND NEW.entity_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN

    IF NEW.entity_type = 'member' THEN
      UPDATE public.members
         SET mautic_id = NEW.mautic_id
       WHERE id = NEW.entity_id::UUID
         AND mautic_id IS DISTINCT FROM NEW.mautic_id;
    ELSIF NEW.entity_type = 'subscriber' THEN
      UPDATE public.subscribers
         SET mautic_id = NEW.mautic_id
       WHERE id = NEW.entity_id::UUID
         AND mautic_id IS DISTINCT FROM NEW.mautic_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP FUNCTION IF EXISTS public.trigger_sync_member_to_mautic();
DROP FUNCTION IF EXISTS public.process_mautic_sync_log();
