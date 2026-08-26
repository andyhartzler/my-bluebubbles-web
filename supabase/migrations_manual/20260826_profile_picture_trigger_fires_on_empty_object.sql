-- Applied to production 2026-08-26 (via MCP apply_migration, name
-- profile_picture_trigger_fires_on_empty_object).
--
-- The auto-fetch trigger had never fired once: it gated on
-- profile_pictures IS NULL, but the column defaults to '{}'::jsonb, so the
-- condition was false on every row ever inserted. That is why the newest
-- object in the member-photos bucket predated this change by two months.
--
-- Changes:
--   * fire on the empty object as well as NULL
--   * include tiktok (fetch-all-member-profile-pictures now fetches TikTok
--     avatars via unavatar.io; Instagram's endpoints are dead and unavatar
--     puts Instagram behind its paid tier, so IG stays best-effort)
--   * on UPDATE, only re-fire when a social handle actually changed, so
--     routine member edits do not queue doomed fetch attempts
CREATE OR REPLACE FUNCTION public.auto_fetch_member_profile_pictures()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_key TEXT;
BEGIN
  IF (NEW.instagram IS NOT NULL OR NEW.x IS NOT NULL OR NEW.tiktok IS NOT NULL)
     AND (NEW.profile_pictures IS NULL OR NEW.profile_pictures = '{}'::jsonb)
     AND (TG_OP = 'INSERT'
          OR OLD.instagram IS DISTINCT FROM NEW.instagram
          OR OLD.x IS DISTINCT FROM NEW.x
          OR OLD.tiktok IS DISTINCT FROM NEW.tiktok) THEN
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
