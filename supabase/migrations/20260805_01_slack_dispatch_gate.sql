-- ============================================================================
-- 20260805_01_slack_dispatch_gate
--
-- Turns public.slack_channel_membership_log from an append-only journal into
-- something with an approval state, so that scheduling slack-sync-to-slack
-- cannot drain a nine month backlog of committee changes at real humans.
--
-- Three changes, no behaviour change on their own except the trigger stamp:
--
--   1. A `dispatch` column: NULL / 'approved' / 'superseded' / 'executed'.
--      NULL is the default and means inert. The 385 rows already sitting in the
--      table (349 'invited', 36 'removed', queued between 2025-11-19 and
--      2026-07-15) all get NULL and therefore cannot be sent by anything.
--
--   2. The source CHECK widened to allow 'onboarding', so the member-onboard
--      cascade can record the channel invites it actually performs. Today it
--      invites and writes nothing, which is why the CRM's Slack page would stay
--      silent through an entire live onboarding run.
--
--   3. sync_committees_to_slack stamps NEW rows dispatch='approved'. This is
--      the design point that matters: the gate is the DEFAULT, not a one-time
--      cleanup. A committee change made today is true today and is queued ready
--      to send; a committee change from November 2025 is not, and no date
--      cutoff has to be maintained by anyone.
--
-- The three foreign-key hint embeds the CRM Slack page depends on are NOT
-- altered. This extends the table; it does not restructure it.
-- ============================================================================

ALTER TABLE public.slack_channel_membership_log
  ADD COLUMN IF NOT EXISTS dispatch text;

ALTER TABLE public.slack_channel_membership_log
  DROP CONSTRAINT IF EXISTS slack_channel_membership_log_dispatch_check;

ALTER TABLE public.slack_channel_membership_log
  ADD CONSTRAINT slack_channel_membership_log_dispatch_check
  CHECK (dispatch IS NULL OR dispatch IN ('approved', 'superseded', 'executed'));

COMMENT ON COLUMN public.slack_channel_membership_log.dispatch IS
  'Send gate. NULL = inert (never sent, never will be without a human). '
  'approved = queued and sendable by slack-sync-to-slack. '
  'superseded = no longer true, resolved without executing. '
  'executed = a Slack call has been attempted for this row.';

ALTER TABLE public.slack_channel_membership_log
  DROP CONSTRAINT IF EXISTS slack_channel_membership_log_source_check;

ALTER TABLE public.slack_channel_membership_log
  ADD CONSTRAINT slack_channel_membership_log_source_check
  CHECK (source IN ('slack_event', 'supabase_trigger', 'manual_sync', 'onboarding'));

-- The drain query is (success = false AND source = 'supabase_trigger' AND
-- dispatch = 'approved'), ordered by created_at. Index the sendable set only:
-- it is expected to hold single digits, against 2073 rows in the table.
CREATE INDEX IF NOT EXISTS idx_slack_membership_log_sendable
  ON public.slack_channel_membership_log (created_at)
  WHERE success = false AND dispatch = 'approved';

-- ---------------------------------------------------------------------------
-- The trigger. Identical to the deployed function except that both INSERTs now
-- carry dispatch = 'approved'.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_committees_to_slack()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    added_committees TEXT[];
    removed_committees TEXT[];
    committee TEXT;
    channel_record RECORD;
    slack_user_id TEXT;
BEGIN
    -- Only proceed if committees array changed
    IF OLD.committee IS DISTINCT FROM NEW.committee THEN

        -- Get the Slack user ID for this member (check both places)
        slack_user_id := NEW.slack_user_id;

        IF slack_user_id IS NULL THEN
            SELECT sum.slack_user_id INTO slack_user_id
            FROM public.slack_user_mapping sum
            WHERE sum.member_id = NEW.id
            LIMIT 1;
        END IF;

        -- If no Slack user ID found, we can't sync
        IF slack_user_id IS NULL THEN
            RAISE NOTICE 'No Slack user ID found for member %', NEW.id;
            RETURN NEW;
        END IF;

        -- Find added committees (in NEW but not in OLD)
        IF NEW.committee IS NOT NULL THEN
            added_committees := ARRAY(
                SELECT unnest(NEW.committee)
                EXCEPT
                SELECT unnest(COALESCE(OLD.committee, ARRAY[]::TEXT[]))
            );
        END IF;

        -- Find removed committees (in OLD but not in NEW)
        IF OLD.committee IS NOT NULL THEN
            removed_committees := ARRAY(
                SELECT unnest(OLD.committee)
                EXCEPT
                SELECT unnest(COALESCE(NEW.committee, ARRAY[]::TEXT[]))
            );
        END IF;

        -- Process added committees - invite to channels
        IF array_length(added_committees, 1) > 0 THEN
            FOREACH committee IN ARRAY added_committees LOOP
                FOR channel_record IN
                    SELECT slack_channel_id, slack_channel_name
                    FROM public.slack_channel_committee_mapping
                    WHERE committee_name = committee AND is_active = true
                LOOP
                    INSERT INTO public.slack_channel_membership_log (
                        member_id,
                        slack_user_id,
                        slack_channel_id,
                        action,
                        source,
                        success,
                        dispatch,
                        metadata
                    ) VALUES (
                        NEW.id,
                        slack_user_id,
                        channel_record.slack_channel_id,
                        'invited',
                        'supabase_trigger',
                        false,
                        -- A committee change made NOW is true NOW. This is what
                        -- makes the drain safe to schedule: forward drift is
                        -- sendable, the historic backlog is not.
                        'approved',
                        jsonb_build_object(
                            'committee', committee,
                            'channel_name', channel_record.slack_channel_name
                        )
                    );
                END LOOP;
            END LOOP;
        END IF;

        -- Process removed committees
        IF array_length(removed_committees, 1) > 0 THEN
            FOREACH committee IN ARRAY removed_committees LOOP
                FOR channel_record IN
                    SELECT slack_channel_id, slack_channel_name
                    FROM public.slack_channel_committee_mapping
                    WHERE committee_name = committee AND is_active = true
                LOOP
                    INSERT INTO public.slack_channel_membership_log (
                        member_id,
                        slack_user_id,
                        slack_channel_id,
                        action,
                        source,
                        success,
                        dispatch,
                        metadata
                    ) VALUES (
                        NEW.id,
                        slack_user_id,
                        channel_record.slack_channel_id,
                        'removed',
                        'supabase_trigger',
                        false,
                        'approved',
                        jsonb_build_object(
                            'committee', committee,
                            'channel_name', channel_record.slack_channel_name
                        )
                    );
                END LOOP;
            END LOOP;
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;
