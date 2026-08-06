-- ============================================================================
-- 20260806_04_member_insert_enrichment_fails_soft
--
-- An INSERT into public.members fires 21 triggers. Seven of them are AFTER
-- INSERT, and an AFTER INSERT trigger that raises aborts the whole statement:
-- the member row never lands, the website route returns 500, and the applicant
-- is told to try again with nothing saved anywhere. On a form that has
-- converted a single person in its life, losing a real signup because a
-- downstream side effect had a bad afternoon is the worst available outcome.
--
-- The seven, and where they stood before this file:
--   knowledge_sync_members_insert           sync_table_to_knowledge      UNGUARDED
--   on_member_created_lookup_districts      trigger_district_lookup      UNGUARDED
--   trigger_auto_generate_membership_card   auto_generate_membership_card UNGUARDED
--   refresh_metrics_on_members              trigger_refresh_dashboard_metrics  guarded
--   trigger_auto_fetch_profile_pictures_on_insert
--                                           auto_fetch_member_profile_pictures guarded
--   trigger_sync_member_to_mautic_insert    extensions.trigger_sync_member_to_mautic guarded
--   trg_audit_members_ins_del               fn_audit_log_trigger         UNGUARDED, deliberately
--
-- This file guards the three that were unguarded ENRICHMENT. Everything it
-- touches is something we compute ABOUT a member after the fact: a search
-- document, a district, a wallet card. None of it establishes who the member is
-- or whether they are eligible, so none of it has any business deciding whether
-- they exist. The BEFORE INSERT triggers, which do establish identity and
-- eligibility (auth user, chapter, county normalization, exec flag, age
-- eligibility), are untouched and must stay hard: a member we cannot identify
-- should not be written.
--
-- fn_audit_log_trigger stays hard too, and that is a decision. The audit log is
-- the accountability record for a table that carries the CRM access gate. A
-- write we cannot account for is worse than a write that did not happen, and
-- unlike the three below it depends on nothing outside this database, so a
-- failure there means something is wrong with the audit table itself.
--
-- Mechanism: a plpgsql BEGIN/EXCEPTION block is a subtransaction, so a failure
-- rolls back only the block's own work and the member row survives. Every
-- handler RAISE WARNING with the member id, so a failure is in the Postgres log
-- rather than nowhere.
-- ============================================================================


-- ── 1. The knowledge document ───────────────────────────────────────────────
-- Enrichment for the RAG index. This is the one with real database work behind
-- it: upsert_knowledge_document writes public.knowledge_documents and
-- public.knowledge_embedding_queue, so a constraint, a column change or a
-- missing ON CONFLICT target on either of those tables aborts the signup that
-- happened to be in flight. It is attached to 14 tables, not only members
-- (calendar_events, campaigns, chapters, donations, donors, events,
-- form_schemas, jobs, legislation_tracked_bills, meetings, slack_messages,
-- subscribers). It is enrichment on every one of them, so the guard belongs in
-- the function rather than in a members-only copy.
CREATE OR REPLACE FUNCTION public.sync_table_to_knowledge()
 RETURNS trigger
 LANGUAGE plpgsql
AS $fn$
DECLARE
  v_config RECORD;
  v_title TEXT;
  v_content TEXT;
  v_metadata JSONB;
  v_record JSONB;
  v_col TEXT;
BEGIN
  BEGIN
    -- Get configuration for this table
    SELECT * INTO v_config
    FROM public.knowledge_table_config
    WHERE table_name = TG_TABLE_NAME
      AND schema_name = TG_TABLE_SCHEMA
      AND is_enabled = true;

    -- If not configured or not enabled, skip
    IF v_config IS NULL THEN
      RETURN NEW;
    END IF;

    -- Convert record to JSONB
    v_record := to_jsonb(NEW);

    -- Build title from template
    v_title := v_config.title_template;
    IF v_title IS NOT NULL THEN
      FOR v_col IN SELECT jsonb_object_keys(v_record) LOOP
        v_title := REPLACE(v_title, '{{' || v_col || '}}', COALESCE(v_record->>v_col, ''));
      END LOOP;
    ELSE
      v_title := TG_TABLE_NAME || ': ' || COALESCE(v_record->>'name', v_record->>'title', v_record->>'id', 'Unknown');
    END IF;

    -- Build content from template or auto-generate
    IF v_config.content_template IS NOT NULL THEN
      v_content := v_config.content_template;
      FOR v_col IN SELECT jsonb_object_keys(v_record) LOOP
        v_content := REPLACE(v_content, '{{' || v_col || '}}', COALESCE(v_record->>v_col, ''));
      END LOOP;
    ELSE
      v_content := '';
      FOR v_col IN SELECT jsonb_object_keys(v_record) LOOP
        IF v_record->>v_col IS NOT NULL AND LENGTH(v_record->>v_col) > 0 THEN
          IF v_col NOT IN ('id', 'created_at', 'updated_at', 'search_vector', 'embedding') THEN
            v_content := v_content || v_col || ': ' || v_record->>v_col || E'\n';
          END IF;
        END IF;
      END LOOP;
    END IF;

    -- Build metadata from configured columns
    v_metadata := '{}'::jsonb;
    IF v_config.metadata_columns IS NOT NULL AND array_length(v_config.metadata_columns, 1) > 0 THEN
      FOREACH v_col IN ARRAY v_config.metadata_columns LOOP
        IF v_record ? v_col THEN
          v_metadata := v_metadata || jsonb_build_object(v_col, v_record->v_col);
        END IF;
      END LOOP;
    END IF;

    v_metadata := v_metadata || jsonb_build_object(
      '_table', TG_TABLE_NAME,
      '_operation', TG_OP
    );

    PERFORM public.upsert_knowledge_document(
      'database',
      TG_TABLE_NAME,
      (v_record->>v_config.primary_key_column)::UUID,
      v_title,
      v_content,
      v_metadata,
      NULL,
      NULL
    );
  EXCEPTION WHEN OTHERS THEN
    -- The row itself is the point; the search document is a derivative of it
    -- and can be rebuilt from the row at any time. Never the other way round.
    RAISE WARNING 'knowledge sync failed for %.% row %: %',
      TG_TABLE_SCHEMA, TG_TABLE_NAME, (to_jsonb(NEW)->>'id'), SQLERRM;
  END;

  RETURN NEW;
END;
$fn$;


-- ── 2. The district lookup ──────────────────────────────────────────────────
-- Fire-and-forget queue write via pg_net, so the trigger never sees the edge
-- function's answer either way. What it CAN see is a failure to enqueue, and
-- today that failure takes the member with it.
--
-- The Authorization header is gone, and it is not an omission. It carried a
-- hardcoded service-role JWT in the function body, readable by anyone who can
-- read pg_proc, and it authenticated nothing: lookup-districts is deployed
-- verify_jwt=false (checked against the Management API on 2026-08-06) and its
-- handler has no auth check of its own, so the header was decorative. A
-- credential that protects nothing is a liability rather than a safeguard, and
-- the correct place to fix the endpoint being open is the endpoint.
CREATE OR REPLACE FUNCTION public.trigger_district_lookup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $fn$
BEGIN
  -- Only trigger if address or county was provided
  IF NEW.address IS NOT NULL OR NEW.county IS NOT NULL THEN
    BEGIN
      PERFORM net.http_post(
        url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/lookup-districts',
        headers := jsonb_build_object('Content-Type', 'application/json'),
        body := jsonb_build_object('memberId', NEW.id::text)
      );
    EXCEPTION WHEN OTHERS THEN
      -- A member with no districts is a member we can still reach. A member
      -- who was refused at signup is not.
      RAISE WARNING 'district lookup could not be queued for member %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$fn$;


-- ── 3. The membership card ──────────────────────────────────────────────────
-- public.membership_cards has UNIQUE (member_id), so this INSERT has a real way
-- to raise, and every other constraint or column change on that table lands on
-- the signup path too. The card is created 'pending' and deliberately notifies
-- nobody; it is issued properly when the member first opens the portal, which
-- is also where a missing one can be created. So a member without a card row is
-- a recoverable state and a refused applicant is not.
CREATE OR REPLACE FUNCTION public.auto_generate_membership_card()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $fn$
BEGIN
  -- Only create card if member has email
  IF NEW.email IS NOT NULL AND NEW.email != '' THEN
    BEGIN
      -- Create membership_cards record silently
      -- NO emails, NO notifications, NO automatic alerts
      INSERT INTO public.membership_cards (
        member_id,
        card_status,
        activation_date
      ) VALUES (
        NEW.id,
        'pending',
        COALESCE(NEW.date_joined, CURRENT_DATE)
      );

      -- Wallet passes will be generated when member first accesses portal
      -- This allows for internal vetting before member notification
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'membership card could not be created for member %: %', NEW.id, SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$fn$;
