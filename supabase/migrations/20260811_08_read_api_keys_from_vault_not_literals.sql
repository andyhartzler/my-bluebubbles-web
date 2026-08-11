-- Applied to production as version 20260811230133,
-- recorded name: 20260811_02_read_api_keys_from_vault_not_literals
--
-- ===========================================================================
-- HOW TO ROTATE THE SERVICE_ROLE KEY AFTER THIS MIGRATION
-- ===========================================================================
-- 1. Rotate the key in the Supabase dashboard (Project Settings -> API keys).
-- 2. Run exactly one statement, as postgres:
--
--      SELECT vault.update_secret(
--        (SELECT id FROM vault.secrets WHERE name = 'service_role_key'),
--        '<the new service_role key>'
--      );
--
-- 3. Nothing else. No function is redefined, no deploy, no restart. The next
--    call reads the new value. The same applies to 'anon_key'.
--
-- To confirm the swap took, without sending anything anywhere:
--      SELECT name, left(decrypted_secret, 12) || '...' || right(decrypted_secret, 6)
--      FROM vault.decrypted_secrets WHERE name IN ('service_role_key','anon_key');
-- ===========================================================================
--
-- WHY THIS MIGRATION EXISTS
-- Seven live functions embedded a project API key as a string literal in their
-- body. pg_get_functiondef exposes those bodies, and copies of them are in the
-- git history of a PUBLIC repo. Rotating the key would have left every one of
-- them posting a dead credential, and because pg_net is fire-and-forget and all
-- of these swallow or ignore the response, the failure would have been silent.
--
-- WHAT IS DELIBERATELY *NOT* CHANGED
--   - Which key each function sends. Four sent service_role, three sent anon.
--     They still do. Standardising them onto service_role would have widened
--     the credential sent to endpoints that never needed it.
--   - Any guard clause, payload, URL, timeout, log line, or exception handler.
--
-- WHAT IS CHANGED BEYOND THE KEY, AND WHY
--   - public.auto_fetch_member_profile_pictures becomes SECURITY DEFINER.
--     It was the only SECURITY INVOKER of the seven, and an invoker running as
--     'authenticated' cannot read vault.decrypted_secrets. Its owner is already
--     postgres and net.http_post is EXECUTE-to-PUBLIC, so the success path is
--     unchanged; it simply now runs as the owner it was already owned by.
--   - Every function gets a pinned search_path of 'public, extensions'. That is
--     the resolution these already got from the standard Supabase role default,
--     so nothing resolves differently; it just stops being mutable, which
--     matters more now that these functions read a secret.
--   - public.call_populate_subscriber_geography was carrying an anon key from
--     2024-11-16 that is NOT the project's current anon key (the JWT secret was
--     reissued 2025-10-11). It now sends the current one. This is inert either
--     way: populate-subscriber-geography runs with verify_jwt = false.
--   - Each function RAISEs a WARNING naming the missing vault secret if the
--     lookup comes back empty, so a bad rotation is loud instead of silent.

-- ---------------------------------------------------------------------------
-- 1/7  extensions.trigger_sync_member_to_mautic  (anon)  -> sync-to-mautic
--      Fired by public.members trigger_sync_member_to_mautic_insert / _update.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION extensions.trigger_sync_member_to_mautic()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  payload JSONB;
  request_id BIGINT;
  v_key TEXT;
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

  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'anon_key';
  IF v_key IS NULL OR v_key = '' THEN
    RAISE WARNING 'vault secret anon_key is missing or empty; sync-to-mautic will be called unauthenticated';
  END IF;

  payload := jsonb_build_object(
    'type', 'member',
    'record', row_to_json(NEW)::jsonb
  );

  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/sync-to-mautic',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_key, '')
    ),
    body := payload
  ) INTO request_id;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Mautic member sync failed: %', SQLERRM;
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2/7  extensions.trigger_sync_subscriber_to_mautic  (anon)  -> sync-to-mautic
--      Fired by public.subscribers trigger_sync_subscriber_to_mautic.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION extensions.trigger_sync_subscriber_to_mautic()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  payload JSONB;
  request_id BIGINT;
  should_sync BOOLEAN := FALSE;
  v_key TEXT;
BEGIN
  -- For INSERT: Only sync if email is present
  IF TG_OP = 'INSERT' THEN
    -- Skip if no email (can't sync without email)
    IF NEW.email IS NULL OR NEW.email = '' THEN
      RAISE LOG 'Mautic sync skipped - no email for new subscriber %', NEW.id;
      RETURN NEW;
    END IF;

    -- Skip if mautic_id is already set (means it came FROM Mautic)
    IF NEW.mautic_id IS NOT NULL THEN
      RAISE LOG 'Mautic sync skipped - subscriber % already has mautic_id % (likely from Mautic)', NEW.id, NEW.mautic_id;
      RETURN NEW;
    END IF;

    should_sync := TRUE;
  END IF;

  -- For UPDATE: Only sync if substantive fields changed
  IF TG_OP = 'UPDATE' THEN
    -- Skip if mautic_id was just set (prevents loop after sync)
    IF (OLD.mautic_id IS NULL AND NEW.mautic_id IS NOT NULL) THEN
      RAISE LOG 'Mautic sync skipped - mautic_id just set for subscriber %', NEW.id;
      RETURN NEW;
    END IF;

    -- Check if any USER-FACING fields changed (not system/enrichment fields)
    -- These are fields the user explicitly sets, not auto-populated
    IF (OLD.email IS DISTINCT FROM NEW.email) OR
       (OLD.name IS DISTINCT FROM NEW.name) OR
       (OLD.phone IS DISTINCT FROM NEW.phone) OR
       (OLD.address IS DISTINCT FROM NEW.address) OR
       (OLD.city IS DISTINCT FROM NEW.city) OR
       (OLD.state IS DISTINCT FROM NEW.state) OR
       (OLD.zip_code IS DISTINCT FROM NEW.zip_code) OR
       (OLD.date_of_birth IS DISTINCT FROM NEW.date_of_birth) OR
       (OLD.subscription_status IS DISTINCT FROM NEW.subscription_status)
    THEN
      should_sync := TRUE;
      RAISE LOG 'Mautic sync triggered - substantive field changed for subscriber %', NEW.id;
    ELSE
      -- These fields are auto-populated by other triggers, don't re-sync:
      -- county, congressional_district, senate_district, house_district (geography)
      -- phone_e164 (phone formatting)
      -- member_id (enrichment/linking)
      -- mautic_id (from Mautic sync)
      -- updated_at (automatic)
      RAISE LOG 'Mautic sync skipped - only system fields changed for subscriber %', NEW.id;
      RETURN NEW;
    END IF;
  END IF;

  -- Perform sync if needed
  IF should_sync THEN
    SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets WHERE name = 'anon_key';
    IF v_key IS NULL OR v_key = '' THEN
      RAISE WARNING 'vault secret anon_key is missing or empty; sync-to-mautic will be called unauthenticated';
    END IF;

    payload := jsonb_build_object(
      'type', 'subscriber',
      'record', row_to_json(NEW)::jsonb
    );

    SELECT net.http_post(
      url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/sync-to-mautic',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || coalesce(v_key, '')
      ),
      body := payload
    ) INTO request_id;

    RAISE LOG 'Mautic sync initiated for subscriber % (request_id: %)', NEW.id, request_id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Mautic subscriber sync failed: %', SQLERRM;
  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3/7  public.auto_fetch_member_profile_pictures  (service_role)
--      -> fetch-all-member-profile-pictures
--      This is the ONE endpoint of the five that runs with verify_jwt = true,
--      so this is the one call that genuinely breaks on rotation.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_fetch_member_profile_pictures()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_key TEXT;
BEGIN
  IF (NEW.instagram IS NOT NULL OR NEW.x IS NOT NULL)
     AND NEW.profile_pictures IS NULL THEN
    BEGIN
      SELECT decrypted_secret INTO v_key
      FROM vault.decrypted_secrets WHERE name = 'service_role_key';
      IF v_key IS NULL OR v_key = '' THEN
        RAISE WARNING 'vault secret service_role_key is missing or empty; fetch-all-member-profile-pictures will reject the call (verify_jwt is on)';
      END IF;

      PERFORM net.http_post(
        url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/fetch-all-member-profile-pictures',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || coalesce(v_key, '')
        ),
        body := jsonb_build_object('memberId', NEW.id::text)
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'profile picture fetch could not be queued for member %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4/7  public.call_populate_subscriber_geography  (anon)
--      -> populate-subscriber-geography
--      Was carrying a superseded 2024 anon key; now carries the current one.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.call_populate_subscriber_geography()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  request_id bigint;
  v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'anon_key';
  IF v_key IS NULL OR v_key = '' THEN
    RAISE WARNING 'vault secret anon_key is missing or empty; populate-subscriber-geography will be called unauthenticated';
  END IF;

  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/populate-subscriber-geography',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_key, '')
    ),
    body := jsonb_build_object('subscriberId', NEW.id::text)
  ) INTO request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Don't fail the insert if the HTTP call fails
    RAISE WARNING 'Failed to call populate-subscriber-geography: %', SQLERRM;
    RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5/7  public.request_bill_text_extraction(uuid)  (service_role)
--      -> extract-bill-text-openstates.  RPC, not a trigger.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_bill_text_extraction(p_bill_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_request_id bigint;
  v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key';
  IF v_key IS NULL OR v_key = '' THEN
    RAISE WARNING 'vault secret service_role_key is missing or empty; extract-bill-text-openstates will be called unauthenticated';
  END IF;

  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/extract-bill-text-openstates',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || coalesce(v_key, ''),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'bill_id', p_bill_id,
      'force', true
    )
  ) INTO v_request_id;

  RETURN v_request_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6/7  public.trigger_extract_bill_text_on_insert  (service_role)
--      -> extract-bill-text-openstates
--      Fired by public.legislation_tracked_bills trg_extract_bill_text_on_insert.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trigger_extract_bill_text_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_request_id bigint;
  v_key text;
BEGIN
  -- Only trigger if the bill doesn't already have text and has an openstates_bill_id
  IF NEW.current_bill_text IS NULL
     AND NEW.openstates_bill_id IS NOT NULL
     AND NEW.sync_error IS NULL
     AND (NEW.text_extraction_deferred IS NULL OR NEW.text_extraction_deferred = false)
  THEN
    SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets WHERE name = 'service_role_key';
    IF v_key IS NULL OR v_key = '' THEN
      RAISE WARNING 'vault secret service_role_key is missing or empty; extract-bill-text-openstates will be called unauthenticated';
    END IF;

    -- Queue HTTP request to extract text (async, non-blocking)
    SELECT net.http_post(
      url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/extract-bill-text-openstates',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || coalesce(v_key, ''),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'bill_id', NEW.id,
        'skip_large_files', true
      ),
      timeout_milliseconds := 30000  -- 30 second timeout
    ) INTO v_request_id;

    -- Log that we queued the request (optional - for debugging)
    RAISE LOG 'Queued text extraction for bill % (request_id: %)', NEW.bill_identifier, v_request_id;
  END IF;

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7/7  public.trigger_notify_exec_job_submitted  (service_role)
--      -> notify-executive-job-submission.  THIS ONE SENDS REAL EMAIL
--      (Gmail API, to info@moyoungdemocrats.org). Never let it fire in a test.
--      Fired by public.jobs notify_exec_job_submitted_trigger.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trigger_notify_exec_job_submitted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  request_id bigint;
  v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key';
  IF v_key IS NULL OR v_key = '' THEN
    RAISE WARNING 'vault secret service_role_key is missing or empty; notify-executive-job-submission will be called unauthenticated';
  END IF;

  -- Call the executive notification Edge Function
  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/notify-executive-job-submission',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_key, '')
    ),
    body := jsonb_build_object('job_id', NEW.id::text)
  ) INTO request_id;

  RAISE LOG 'Executive notification request sent for job %, request_id: %', NEW.id, request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the insert
    RAISE WARNING 'Executive job notification failed: %', SQLERRM;
    RETURN NEW;
END;
$function$;
