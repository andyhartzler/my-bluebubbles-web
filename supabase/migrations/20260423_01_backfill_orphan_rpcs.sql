-- Backfill source-of-truth for RPCs that exist in prod without migration history.
-- Generated 2026-04-23 via pg_get_functiondef. Does not change behavior - these
-- functions were already running in prod. Wraps each with DROP FUNCTION IF EXISTS
-- (name, arg-types) followed by the CREATE OR REPLACE body.
--
-- Stats:
--   Total public RPCs (non-extension): 233
--   Already in migrations:             24
--   Drift (backfilled below):          187
--   Candidates for drop (commented):   22


-- =============================================================
-- BACKFILL: drift RPCs currently running in prod
-- =============================================================

-- --- add_member_field_to_visibility(p_field_name text, p_display_label text, p_field_category text, p_is_visible boolean, p_is_editable boolean) ---
CREATE OR REPLACE FUNCTION public.add_member_field_to_visibility(p_field_name text, p_display_label text, p_field_category text DEFAULT 'Other'::text, p_is_visible boolean DEFAULT false, p_is_editable boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO member_portal_field_visibility (
    field_name,
    display_label,
    field_category,
    is_visible,
    is_editable,
    is_required,
    sort_order
  ) VALUES (
    p_field_name,
    p_display_label,
    p_field_category,
    p_is_visible,
    p_is_editable,
    false,
    999 -- Put new fields at the end
  )
  ON CONFLICT (field_name) DO NOTHING; -- Don't override if already exists
END;
$function$;

-- --- add_subscriber_to_listmonk_lists(p_email text, p_list_uuids uuid[]) ---
CREATE OR REPLACE FUNCTION public.add_subscriber_to_listmonk_lists(p_email text, p_list_uuids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'listmonk'
AS $function$
DECLARE
  v_listmonk_sub_id INTEGER;
  v_listmonk_sub_uuid UUID;
  v_list RECORD;
  v_lists_added TEXT[] := '{}';
  v_status listmonk.subscription_status;
  v_normalized_email TEXT;
BEGIN
  -- Normalize email
  v_normalized_email := LOWER(TRIM(p_email));

  -- Get the listmonk subscriber (uses integer ID)
  SELECT id, uuid INTO v_listmonk_sub_id, v_listmonk_sub_uuid
  FROM listmonk.subscribers
  WHERE LOWER(email) = v_normalized_email
  LIMIT 1;

  IF v_listmonk_sub_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Subscriber not found in listmonk. Sync may still be in progress.'
    );
  END IF;

  -- Loop through each list UUID and add subscriber
  FOR v_list IN 
    SELECT id, uuid, name, optin 
    FROM listmonk.lists 
    WHERE uuid = ANY(p_list_uuids)
  LOOP
    -- Check if already subscribed to this list
    IF NOT EXISTS (
      SELECT 1 FROM listmonk.subscriber_lists 
      WHERE subscriber_id = v_listmonk_sub_id 
      AND list_id = v_list.id
    ) THEN
      -- Determine status based on optin type
      -- 'single' = confirmed immediately, 'double' = needs email confirmation
      v_status := CASE 
        WHEN v_list.optin = 'single' THEN 'confirmed'::listmonk.subscription_status
        ELSE 'unconfirmed'::listmonk.subscription_status
      END;
      
      -- Insert subscription
      INSERT INTO listmonk.subscriber_lists (
        subscriber_id, 
        list_id, 
        status, 
        meta,
        created_at, 
        updated_at
      )
      VALUES (
        v_listmonk_sub_id, 
        v_list.id, 
        v_status, 
        '{}'::jsonb,
        NOW(), 
        NOW()
      );
      
      v_lists_added := array_append(v_lists_added, v_list.name);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'listmonk_id', v_listmonk_sub_id,
    'listmonk_uuid', v_listmonk_sub_uuid,
    'lists_added', to_jsonb(v_lists_added)
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$;

-- --- append_member_document(member_id uuid, document_url text, document_name text, document_type text, notes text) ---
CREATE OR REPLACE FUNCTION public.append_member_document(member_id uuid, document_url text, document_name text, document_type text DEFAULT 'general'::text, notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  current_info jsonb;
  new_document jsonb;
  updated_info jsonb;
BEGIN
  -- Get current internal_member_info
  SELECT COALESCE(internal_member_info, '{}'::jsonb)
  INTO current_info
  FROM members
  WHERE id = member_id;
  
  -- Create new document entry
  new_document := jsonb_build_object(
    'url', document_url,
    'name', document_name,
    'type', document_type,
    'notes', notes,
    'uploaded_at', now()
  );
  
  -- Append to documents array
  IF current_info ? 'documents' THEN
    updated_info := jsonb_set(
      current_info,
      '{documents}',
      (current_info->'documents') || jsonb_build_array(new_document)
    );
  ELSE
    updated_info := current_info || jsonb_build_object(
      'documents', jsonb_build_array(new_document)
    );
  END IF;
  
  -- Update the member record
  UPDATE members
  SET internal_member_info = updated_info
  WHERE id = member_id;
  
  RETURN updated_info;
END;
$function$;

-- --- apply_approved_profile_change(p_change_id uuid) ---
CREATE OR REPLACE FUNCTION public.apply_approved_profile_change(p_change_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_change RECORD;
  v_sql TEXT;
BEGIN
  -- Get the approved change
  SELECT * INTO v_change
  FROM member_profile_changes
  WHERE id = p_change_id
    AND status = 'approved'
    AND applied_at IS NULL;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Build and execute dynamic SQL to update the member record
  IF v_change.change_type = 'delete' THEN
    v_sql := format(
      'UPDATE members SET %I = NULL WHERE id = $1',
      v_change.field_name
    );
  ELSE
    v_sql := format(
      'UPDATE members SET %I = $2 WHERE id = $1',
      v_change.field_name
    );
  END IF;
  
  IF v_change.change_type = 'delete' THEN
    EXECUTE v_sql USING v_change.member_id;
  ELSE
    EXECUTE v_sql USING v_change.member_id, v_change.new_value;
  END IF;
  
  -- Mark the change as applied
  UPDATE member_profile_changes
  SET applied_at = now()
  WHERE id = p_change_id;
  
  RETURN TRUE;
END;
$function$;

-- --- auto_create_auth_user_from_member() ---
CREATE OR REPLACE FUNCTION public.auto_create_auth_user_from_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  join_timestamp TIMESTAMPTZ;
  phone_to_use TEXT;
BEGIN
  IF NEW.email IS NOT NULL AND NEW.email != '' THEN
    join_timestamp := COALESCE(NEW.date_joined::timestamptz, NOW());
    phone_to_use := NEW.phone_e164;

    -- Prevent phone collisions
    IF phone_to_use IS NOT NULL 
       AND EXISTS (SELECT 1 FROM auth.users WHERE phone = phone_to_use)
    THEN
      phone_to_use := NULL;
    END IF;

    -- Only create if ID or Email doesn’t already exist
    IF NOT EXISTS (
      SELECT 1 FROM auth.users 
      WHERE id = NEW.id OR email = NEW.email
    ) THEN

      INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        phone,
        encrypted_password,
        email_confirmed_at,
        phone_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token,

        -- REQUIRED non-null fields to avoid scan errors
        email_change,
        email_change_sent_at,
        email_change_token_current,
        email_change_token_new,
        email_change_confirm_status,

        -- Other fields Supabase expects to exist but can be NULL
        reauthentication_token,
        last_sign_in_at,
        is_sso_user,
        deleted_at,
        is_super_admin
      )
      VALUES (
        '00000000-0000-0000-0000-000000000000',
        NEW.id,
        'authenticated',
        'authenticated',
        NEW.email,
        phone_to_use,
        '',
        join_timestamp,
        CASE WHEN phone_to_use IS NOT NULL THEN join_timestamp ELSE NULL END,
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('name', NEW.name, 'full_name', NEW.name),
        join_timestamp,
        join_timestamp,
        '',
        '',

        -- REQUIRED fields (SAFE DEFAULTS)
        '',          -- email_change (MUST be string)
        NULL,        -- email_change_sent_at
        '',          -- email_change_token_current
        '',          -- email_change_token_new
        0,           -- email_change_confirm_status

        -- Optional but supported
        '',          -- reauthentication_token
        NULL,        -- last_sign_in_at
        FALSE,       -- is_sso_user
        NULL,        -- deleted_at
        FALSE        -- is_super_admin
      );

      INSERT INTO auth.identities (
        provider_id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
      )
      VALUES (
        NEW.id::text,
        NEW.id,
        jsonb_build_object('sub', NEW.id::text, 'email', NEW.email),
        'email',
        join_timestamp,
        join_timestamp,
        join_timestamp
      );

    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

-- --- auto_create_chapter_from_member() ---
CREATE OR REPLACE FUNCTION public.auto_create_chapter_from_member()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Convert empty string to NULL
  IF NEW.chapter_name = '' THEN
    NEW.chapter_name := NULL;
  END IF;

  -- Only proceed if member has a valid chapter_name
  IF NEW.chapter_name IS NOT NULL THEN
    
    -- Insert chapter if it doesn't exist
    INSERT INTO public.chapters (
      chapter_name,
      standardized_name,
      school_name,
      chapter_type,
      status,
      is_chartered
    )
    VALUES (
      NEW.chapter_name,
      NEW.chapter_name || ' Governing Documents',
      COALESCE(NEW.school_name, NEW.college, NEW.high_school, NEW.chapter_name),
      -- Try to infer chapter type from school_name or in_school
      CASE 
        WHEN NEW.in_school = 'High School' THEN 'highschool'
        WHEN NEW.in_school = 'College/University' THEN 'college'
        WHEN NEW.school_name ILIKE '%high school%' THEN 'highschool'
        WHEN NEW.school_name ILIKE '%university%' OR NEW.school_name ILIKE '%college%' THEN 'college'
        WHEN NEW.college IS NOT NULL THEN 'college'
        WHEN NEW.high_school IS NOT NULL THEN 'highschool'
        ELSE 'college' -- Default to college
      END,
      'pending',
      FALSE
    )
    ON CONFLICT (chapter_name) DO NOTHING;
    
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- auto_create_member_portal_meeting() ---
CREATE OR REPLACE FUNCTION public.auto_create_member_portal_meeting()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Create a draft portal meeting record for the new meeting
  INSERT INTO member_portal_meetings (
    meeting_id,
    member_title,
    member_description,
    member_summary,
    member_key_points,
    member_action_items,
    visible_to_all,
    visible_to_attendees_only,
    is_published
  ) VALUES (
    NEW.id,
    NEW.meeting_title,
    COALESCE(NEW.discussion_highlights, 'Meeting discussion pending review.'),
    COALESCE(NEW.executive_recap, 'Meeting summary pending review.'),
    COALESCE(NEW.agenda_reviewed, ''),
    COALESCE(NEW.action_items, ''),
    false, -- Not visible to all
    true,  -- Only attendees
    false  -- Unpublished (admin must publish)
  );
  
  RETURN NEW;
END;
$function$;

-- --- auto_create_subscriber_from_attendee() ---
CREATE OR REPLACE FUNCTION public.auto_create_subscriber_from_attendee()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Only create if guest email exists and not already in subscribers
    IF NEW.guest_email IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.subscribers WHERE email = NEW.guest_email
    ) THEN
        INSERT INTO public.subscribers (
            email,
            name,
            phone,
            date_of_birth,
            address,
            city,
            state,
            zip_code,
            employer,
            source,
            subscription_status,
            optin_date,
            tags
        ) VALUES (
            NEW.guest_email,
            COALESCE(NEW.guest_name, 'Guest'),
            NEW.guest_phone,
            NEW.date_of_birth,
            NEW.address,
            NEW.city,
            NEW.state,
            NEW.zip,
            NEW.employer,
            'event_attendee',
            'subscribed',
            NOW(),
            'event_attendee'
        )
        ON CONFLICT (email) DO UPDATE SET
            -- Enrich with event attendee data if fields are empty
            phone = COALESCE(subscribers.phone, NEW.guest_phone),
            address = COALESCE(subscribers.address, NEW.address),
            city = COALESCE(subscribers.city, NEW.city),
            state = COALESCE(subscribers.state, NEW.state),
            zip_code = COALESCE(subscribers.zip_code, NEW.zip),
            employer = COALESCE(subscribers.employer, NEW.employer),
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$function$;

-- --- auto_create_subscriber_from_donor() ---
CREATE OR REPLACE FUNCTION public.auto_create_subscriber_from_donor()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Only create if email exists and not already in subscribers
    IF NEW.email IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.subscribers WHERE email = NEW.email
    ) THEN
        INSERT INTO public.subscribers (
            email,
            name,
            phone,
            phone_e164,
            date_of_birth,
            address,
            city,
            state,
            zip_code,
            county,
            congressional_district,
            employer,
            donor_id,
            source,
            subscription_status,
            optin_date
        ) VALUES (
            NEW.email,
            NEW.name,
            NEW.phone,
            NEW.phone_e164,
            NEW.date_of_birth,
            NEW.address,
            NEW.city,
            NEW.state,
            NEW.zip_code,
            NEW.county,
            NEW.congressional_district,
            NEW.employer,
            NEW.id,  -- Link to donor
            'donor',
            'subscribed',
            COALESCE(NEW.first_donation_date, NOW())
        )
        ON CONFLICT (email) DO UPDATE SET
            donor_id = NEW.id,
            -- Enrich with donor data if fields are empty
            phone = COALESCE(subscribers.phone, NEW.phone),
            phone_e164 = COALESCE(subscribers.phone_e164, NEW.phone_e164),
            address = COALESCE(subscribers.address, NEW.address),
            city = COALESCE(subscribers.city, NEW.city),
            state = COALESCE(subscribers.state, NEW.state),
            zip_code = COALESCE(subscribers.zip_code, NEW.zip_code),
            county = COALESCE(subscribers.county, NEW.county),
            congressional_district = COALESCE(subscribers.congressional_district, NEW.congressional_district),
            employer = COALESCE(subscribers.employer, NEW.employer),
            updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$function$;

-- --- auto_extract_endorsement_candidate_id() ---
CREATE OR REPLACE FUNCTION public.auto_extract_endorsement_candidate_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_slug text;
  v_cand_raw text;
  v_cand uuid;
BEGIN
  -- Only run when candidate_id column is NULL (don't clobber explicit sets)
  IF NEW.candidate_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Lookup the form slug
  SELECT slug INTO v_slug FROM public.form_schemas WHERE id = NEW.form_id;
  IF v_slug IS NULL OR v_slug NOT LIKE 'endorsement-questionnaire%' THEN
    RETURN NEW;
  END IF;

  -- Extract from data JSONB
  v_cand_raw := NEW.data->>'candidate_id';
  IF v_cand_raw IS NULL OR v_cand_raw = '' THEN
    RETURN NEW;
  END IF;

  -- Validate UUID format
  BEGIN
    v_cand := v_cand_raw::uuid;
  EXCEPTION WHEN OTHERS THEN
    RETURN NEW; -- invalid uuid, skip silently
  END;

  -- Verify candidate exists (FK would fail otherwise and kill the whole insert)
  IF NOT EXISTS (SELECT 1 FROM public.candidates WHERE id = v_cand) THEN
    RETURN NEW;
  END IF;

  NEW.candidate_id := v_cand;
  RETURN NEW;
END;
$function$;

-- --- auto_fetch_member_profile_pictures() ---
CREATE OR REPLACE FUNCTION public.auto_fetch_member_profile_pictures()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF (NEW.instagram IS NOT NULL OR NEW.x IS NOT NULL) 
     AND NEW.profile_pictures IS NULL THEN
    
    PERFORM extensions.http((
      'POST',
      'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/fetch-all-member-profile-pictures',
      ARRAY[
        extensions.http_header('Content-Type', 'application/json'),
        extensions.http_header('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDIxNzE5OSwiZXhwIjoyMDc1NzkzMTk5fQ.aNG79mrHw8P1TjJ6uYqP0ceSK65DOjaVUMt-MazXnWU')
      ],
      'application/json',
      jsonb_build_object('memberId', NEW.id::text)::text
    )::extensions.http_request);
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- auto_generate_membership_card() ---
CREATE OR REPLACE FUNCTION public.auto_generate_membership_card()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Only create card if member has email
  IF NEW.email IS NOT NULL AND NEW.email != '' THEN
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
  END IF;

  RETURN NEW;
END;
$function$;

-- --- auto_link_and_enrich_subscriber() ---
CREATE OR REPLACE FUNCTION public.auto_link_and_enrich_subscriber()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'listmonk'
AS $function$
DECLARE
  v_member_id uuid;
  v_donor_id uuid;
  v_member_record RECORD;
  v_donor_record RECORD;
BEGIN
  -- Link to member by email
  SELECT id INTO v_member_id
  FROM members
  WHERE email = NEW.email
  LIMIT 1;
  
  -- Link to donor by email
  SELECT id INTO v_donor_id
  FROM donors
  WHERE email = NEW.email
  LIMIT 1;
  
  -- Set the foreign keys
  NEW.member_id := v_member_id;
  NEW.donor_id := v_donor_id;
  
  -- Enrich data from member record if linked
  IF v_member_id IS NOT NULL THEN
    SELECT * INTO v_member_record FROM members WHERE id = v_member_id;
    
    -- Copy phone if subscriber doesn't have it
    IF NEW.phone IS NULL AND v_member_record.phone IS NOT NULL THEN
      NEW.phone := v_member_record.phone;
      NEW.phone_e164 := v_member_record.phone_e164;
    END IF;
    
    -- Copy date of birth if subscriber doesn't have it
    IF NEW.date_of_birth IS NULL AND v_member_record.date_of_birth IS NOT NULL THEN
      NEW.date_of_birth := v_member_record.date_of_birth;
    END IF;
    
    -- Copy address if subscriber doesn't have it
    IF NEW.address IS NULL AND v_member_record.address IS NOT NULL THEN
      NEW.address := v_member_record.address;
    END IF;
    
    -- Copy county if subscriber doesn't have it
    IF NEW.county IS NULL AND v_member_record.county IS NOT NULL THEN
      NEW.county := v_member_record.county;
    END IF;
    
    -- Copy congressional district
    IF NEW.congressional_district IS NULL AND v_member_record.congressional_district IS NOT NULL THEN
      NEW.congressional_district := v_member_record.congressional_district;
    END IF;
    
    -- Copy house/senate districts
    IF NEW.house_district IS NULL AND v_member_record.house_district IS NOT NULL THEN
      NEW.house_district := v_member_record.house_district;
    END IF;
    
    IF NEW.senate_district IS NULL AND v_member_record.senate_district IS NOT NULL THEN
      NEW.senate_district := v_member_record.senate_district;
    END IF;
  END IF;
  
  -- Enrich data from donor record if linked (only if not already filled by member)
  IF v_donor_id IS NOT NULL THEN
    SELECT * INTO v_donor_record FROM donors WHERE id = v_donor_id;
    
    -- Copy phone if still empty
    IF NEW.phone IS NULL AND v_donor_record.phone IS NOT NULL THEN
      NEW.phone := v_donor_record.phone;
      NEW.phone_e164 := v_donor_record.phone_e164;
    END IF;
    
    -- Copy date of birth if still empty
    IF NEW.date_of_birth IS NULL AND v_donor_record.date_of_birth IS NOT NULL THEN
      NEW.date_of_birth := v_donor_record.date_of_birth;
    END IF;
    
    -- Copy address components if still empty
    IF NEW.address IS NULL AND v_donor_record.address IS NOT NULL THEN
      NEW.address := v_donor_record.address;
    END IF;
    
    IF NEW.city IS NULL AND v_donor_record.city IS NOT NULL THEN
      NEW.city := v_donor_record.city;
    END IF;
    
    IF NEW.state IS NULL AND v_donor_record.state IS NOT NULL THEN
      NEW.state := v_donor_record.state;
    END IF;
    
    IF NEW.zip_code IS NULL AND v_donor_record.zip_code IS NOT NULL THEN
      NEW.zip_code := v_donor_record.zip_code;
    END IF;
    
    -- Copy county if still empty
    IF NEW.county IS NULL AND v_donor_record.county IS NOT NULL THEN
      NEW.county := v_donor_record.county;
    END IF;
    
    -- Copy congressional district if still empty
    IF NEW.congressional_district IS NULL AND v_donor_record.congressional_district IS NOT NULL THEN
      NEW.congressional_district := v_donor_record.congressional_district;
    END IF;
    
    -- Copy employer if still empty
    IF NEW.employer IS NULL AND v_donor_record.employer IS NOT NULL THEN
      NEW.employer := v_donor_record.employer;
    END IF;
  END IF;
  
  -- Set last_synced_at
  NEW.last_synced_at := now();
  
  RETURN NEW;
END;
$function$;

-- --- auto_link_donor_to_member() ---
CREATE OR REPLACE FUNCTION public.auto_link_donor_to_member()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  matched_member_id uuid;
BEGIN
  -- Only try to link if not already linked and email exists
  IF NEW.member_id IS NULL AND NEW.email IS NOT NULL THEN
    -- Try to find matching member by email
    SELECT id INTO matched_member_id
    FROM members
    WHERE email = NEW.email
       OR school_email = NEW.email
    LIMIT 1;
    
    -- If found, link them
    IF matched_member_id IS NOT NULL THEN
      NEW.member_id := matched_member_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- auto_match_slack_user(p_slack_user_id text, p_slack_email text, p_slack_real_name text, p_slack_display_name text, p_confidence_threshold numeric) ---
CREATE OR REPLACE FUNCTION public.auto_match_slack_user(p_slack_user_id text, p_slack_email text, p_slack_real_name text, p_slack_display_name text, p_confidence_threshold numeric DEFAULT 0.90)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_best_match RECORD;
    v_member_id UUID;
    v_all_matches JSONB;
BEGIN
    -- Check if already matched
    SELECT member_id INTO v_member_id
    FROM slack_user_mapping
    WHERE slack_user_id = p_slack_user_id;
    
    IF v_member_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'status', 'already_matched',
            'member_id', v_member_id
        );
    END IF;
    
    -- Find best match
    SELECT * INTO v_best_match
    FROM find_potential_member_matches(p_slack_email, p_slack_real_name, p_slack_display_name)
    ORDER BY confidence DESC
    LIMIT 1;
    
    -- If high confidence match, create mapping
    IF v_best_match.confidence >= p_confidence_threshold THEN
        INSERT INTO slack_user_mapping (
            member_id,
            slack_user_id,
            slack_email,
            slack_real_name,
            slack_display_name,
            matched_by,
            match_confidence
        ) VALUES (
            v_best_match.member_id,
            p_slack_user_id,
            p_slack_email,
            p_slack_real_name,
            p_slack_display_name,
            v_best_match.match_method,
            v_best_match.confidence
        );
        
        -- Also update members table
        UPDATE members
        SET slack_user_id = p_slack_user_id
        WHERE id = v_best_match.member_id;
        
        RETURN jsonb_build_object(
            'status', 'auto_matched',
            'member_id', v_best_match.member_id,
            'confidence', v_best_match.confidence,
            'method', v_best_match.match_method
        );
    END IF;
    
    -- Otherwise, queue for manual matching
    SELECT jsonb_agg(
        jsonb_build_object(
            'member_id', member_id,
            'member_email', member_email,
            'member_name', member_name,
            'confidence', confidence,
            'method', match_method
        )
    ) INTO v_all_matches
    FROM find_potential_member_matches(p_slack_email, p_slack_real_name, p_slack_display_name);
    
    INSERT INTO slack_users_unmatched (
        slack_user_id,
        slack_email,
        slack_real_name,
        slack_display_name,
        potential_matches
    ) VALUES (
        p_slack_user_id,
        p_slack_email,
        p_slack_real_name,
        p_slack_display_name,
        v_all_matches
    )
    ON CONFLICT (slack_user_id) DO UPDATE
    SET potential_matches = EXCLUDED.potential_matches,
        slack_email = EXCLUDED.slack_email,
        slack_real_name = EXCLUDED.slack_real_name,
        slack_display_name = EXCLUDED.slack_display_name;
    
    RETURN jsonb_build_object(
        'status', 'needs_manual_match',
        'potential_matches', v_all_matches
    );
END;
$function$;

-- --- auto_sync_quick_link_to_portal() ---
CREATE OR REPLACE FUNCTION public.auto_sync_quick_link_to_portal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Only sync if is_active is true
  IF NEW.is_active = true THEN
    -- Insert into member_portal_resources
    INSERT INTO member_portal_resources (
      title,
      description,
      resource_type,
      url,
      storage_url,
      is_visible,
      sort_order,
      category,
      icon_url
    ) VALUES (
      NEW.title,
      NEW.notes,
      -- Smart categorization
      CASE 
        WHEN LOWER(NEW.category) LIKE '%document%' OR LOWER(NEW.category) LIKE '%governing%' OR LOWER(NEW.category) LIKE '%bylaw%' OR LOWER(NEW.category) LIKE '%constitution%' 
          THEN 'governing_document'
        WHEN LOWER(NEW.category) LIKE '%toolkit%' OR LOWER(NEW.category) LIKE '%tool%' OR LOWER(NEW.category) LIKE '%resource%' 
          THEN 'digital_toolkit'
        ELSE 'digital_toolkit'
      END,
      NEW.url,
      NEW.storage_url,
      false, -- Default to not visible (admin must enable)
      NEW.sort_order,
      NEW.category,
      NEW.icon_url
    )
    ON CONFLICT (url) DO NOTHING; -- Prevent duplicates based on URL
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- auto_update_text_extraction_status() ---
CREATE OR REPLACE FUNCTION public.auto_update_text_extraction_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- If text was just populated (was NULL, now has value)
    IF OLD.current_bill_text IS NULL AND NEW.current_bill_text IS NOT NULL THEN
        NEW.text_extraction_status := 'completed';
    END IF;
    
    -- If text was removed (had value, now NULL), reset to pending
    IF OLD.current_bill_text IS NOT NULL AND NEW.current_bill_text IS NULL THEN
        NEW.text_extraction_status := 'pending';
    END IF;
    
    RETURN NEW;
END;
$function$;

-- --- auto_verify_email_confidence() ---
CREATE OR REPLACE FUNCTION public.auto_verify_email_confidence()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.contact_type = 'email' AND NEW.confidence = 'low' THEN
    IF split_part(NEW.contact_value, '@', 2) IN (
      'gmail.com', 'yahoo.com', 'aol.com', 'icloud.com', 'hotmail.com',
      'outlook.com', 'protonmail.com', 'comcast.net', 'att.net', 'me.com',
      'sbcglobal.net', 'verizon.net', 'mac.com', 'live.com', 'msn.com',
      'mail.com', 'ymail.com', 'rocketmail.com', 'pm.me', 'proton.me',
      'googlemail.com', 'hotmail.co.uk', 'yahoo.co.uk', 'cox.net'
    ) THEN
      NEW.confidence := 'verified_full_dns';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- --- batch_update_node_positions(p_updates jsonb) ---
CREATE OR REPLACE FUNCTION public.batch_update_node_positions(p_updates jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_update JSONB;
BEGIN
  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    UPDATE public.canvas_nodes
    SET 
      offset_x = (v_update->>'offset_x')::DOUBLE PRECISION,
      offset_y = (v_update->>'offset_y')::DOUBLE PRECISION,
      updated_at = NOW()
    WHERE id = (v_update->>'id')::UUID;
  END LOOP;
END;
$function$;

-- --- batch_update_subscriber_phone_and_address() ---
CREATE OR REPLACE FUNCTION public.batch_update_subscriber_phone_and_address()
 RETURNS TABLE(total_processed integer, phones_formatted integer, addresses_parsed integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total integer := 0;
  v_phones integer := 0;
  v_addresses integer := 0;
  v_subscriber RECORD;
BEGIN
  FOR v_subscriber IN 
    SELECT id, phone, phone_e164, address
    FROM subscribers
    WHERE phone IS NOT NULL OR address IS NOT NULL
  LOOP
    v_total := v_total + 1;
    
    -- Update to trigger phone and address parsing
    UPDATE subscribers
    SET updated_at = now()
    WHERE id = v_subscriber.id;
    
    -- Check if phone was formatted
    DECLARE
      v_new_phone_e164 text;
    BEGIN
      SELECT phone_e164 INTO v_new_phone_e164
      FROM subscribers WHERE id = v_subscriber.id;
      
      IF v_subscriber.phone_e164 IS NULL AND v_new_phone_e164 IS NOT NULL THEN
        v_phones := v_phones + 1;
      END IF;
    END;
    
    -- Check if address was parsed
    DECLARE
      v_new_city text;
    BEGIN
      SELECT city INTO v_new_city
      FROM subscribers WHERE id = v_subscriber.id;
      
      IF v_new_city IS NOT NULL THEN
        v_addresses := v_addresses + 1;
      END IF;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_total, v_phones, v_addresses;
END;
$function$;

-- --- bulk_sync_donors() ---
CREATE OR REPLACE FUNCTION public.bulk_sync_donors()
 RETURNS TABLE(synced_count integer, error_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_synced INT := 0;
  v_errors INT := 0;
  v_record RECORD;
BEGIN
  FOR v_record IN SELECT * FROM public.donors WHERE email IS NOT NULL AND email != '' LOOP
    BEGIN
      PERFORM public.sync_donor_to_subscribers() FROM public.donors WHERE id = v_record.id;
      v_synced := v_synced + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE NOTICE 'Error syncing donor %: %', v_record.email, SQLERRM;
    END;
  END LOOP;
  RETURN QUERY SELECT v_synced, v_errors;
END;
$function$;

-- --- bulk_sync_event_attendees() ---
CREATE OR REPLACE FUNCTION public.bulk_sync_event_attendees()
 RETURNS TABLE(synced_count integer, error_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_synced INT := 0;
  v_errors INT := 0;
  v_record RECORD;
BEGIN
  FOR v_record IN SELECT * FROM public.event_attendees LOOP
    BEGIN
      PERFORM public.sync_event_attendee_to_subscribers() FROM public.event_attendees WHERE id = v_record.id;
      v_synced := v_synced + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE NOTICE 'Error syncing attendee ID %: %', v_record.id, SQLERRM;
    END;
  END LOOP;
  RETURN QUERY SELECT v_synced, v_errors;
END;
$function$;

-- --- bulk_sync_members_to_listmonk() ---
CREATE OR REPLACE FUNCTION public.bulk_sync_members_to_listmonk()
 RETURNS TABLE(synced_count integer, error_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_synced INT := 0;
  v_errors INT := 0;
  v_record RECORD;
  v_subscriber_id INT;
BEGIN
  FOR v_record IN 
    SELECT * FROM public.members 
    WHERE email IS NOT NULL AND TRIM(email) != ''
  LOOP
    BEGIN
      INSERT INTO listmonk.subscribers (
        uuid,
        email,
        name,
        status,
        attribs
      ) VALUES (
        gen_random_uuid(),
        LOWER(TRIM(v_record.email)),
        TRIM(v_record.name),
        'enabled',
        jsonb_build_object(
          'crm_member_id', v_record.id::TEXT,
          'phone', v_record.phone,
          'phone_e164', v_record.phone_e164,
          'chapter_name', v_record.chapter_name,
          'chapter_position', v_record.chapter_position,
          'executive_role', v_record.executive_role,
          'source', 'member',
          'synced_at', NOW()
        )
      )
      ON CONFLICT (email) 
      DO UPDATE SET
        name = EXCLUDED.name,
        attribs = EXCLUDED.attribs,
        updated_at = NOW()
      RETURNING id INTO v_subscriber_id;

      -- Add to Members list (5)
      IF v_subscriber_id IS NOT NULL THEN
        INSERT INTO listmonk.subscriber_lists (subscriber_id, list_id, status)
        VALUES (v_subscriber_id, 5, 'confirmed')
        ON CONFLICT (subscriber_id, list_id) DO UPDATE SET status = 'confirmed';
      END IF;

      v_synced := v_synced + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE NOTICE 'Error syncing member %: %', v_record.email, SQLERRM;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_synced, v_errors;
END;
$function$;

-- --- bulk_sync_subscribers_to_listmonk() ---
CREATE OR REPLACE FUNCTION public.bulk_sync_subscribers_to_listmonk()
 RETURNS TABLE(synced_count integer, error_count integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_synced INT := 0;
  v_errors INT := 0;
  v_record RECORD;
  v_listmonk_id INT;
  v_lists INT[];
BEGIN
  FOR v_record IN 
    SELECT * FROM public.subscribers 
    WHERE email IS NOT NULL AND email != ''
  LOOP
    BEGIN
      -- Determine lists
      v_lists := ARRAY[3]; -- Newsletter
      IF v_record.donor_id IS NOT NULL THEN
        v_lists := v_lists || ARRAY[4];
      END IF;
      IF v_record.source = 'event_attendee' THEN
        v_lists := v_lists || ARRAY[6];
      END IF;
      
      -- Insert into listmonk
      INSERT INTO listmonk.subscribers (
        uuid,
        email,
        name,
        status,
        attribs
      ) VALUES (
        gen_random_uuid(),
        LOWER(TRIM(v_record.email)),
        TRIM(v_record.name),
        'enabled',
        jsonb_build_object(
          'crm_subscriber_id', v_record.id::TEXT,
          'donor_id', v_record.donor_id::TEXT,
          'member_id', v_record.member_id::TEXT,
          'source', v_record.source,
          'phone', v_record.phone,
          'synced_at', NOW()
        )
      )
      ON CONFLICT (email) DO UPDATE SET
        attribs = EXCLUDED.attribs,
        updated_at = NOW()
      RETURNING id INTO v_listmonk_id;
      
      -- Add to lists
      IF v_listmonk_id IS NOT NULL THEN
        DELETE FROM listmonk.subscriber_lists WHERE subscriber_id = v_listmonk_id;
        INSERT INTO listmonk.subscriber_lists (subscriber_id, list_id, status)
        SELECT v_listmonk_id, unnest(v_lists), 'confirmed';
      END IF;
      
      v_synced := v_synced + 1;
      
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      RAISE NOTICE 'Error: %', SQLERRM;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_synced, v_errors;
END;
$function$;

-- --- calculate_form_page_count(p_schema jsonb) ---
CREATE OR REPLACE FUNCTION public.calculate_form_page_count(p_schema jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE
  max_page INT := 1;
  item JSONB;
  page_val INT;
BEGIN
  IF p_schema IS NULL THEN
    RETURN 1;
  END IF;

  -- Canonical `fields` format — pageNumber (1-indexed)
  IF p_schema ? 'fields' AND jsonb_typeof(p_schema->'fields') = 'array' THEN
    FOR item IN SELECT jsonb_array_elements(p_schema->'fields')
    LOOP
      page_val := COALESCE(NULLIF(item->>'pageNumber','')::int, 1);
      IF page_val > max_page THEN max_page := page_val; END IF;
    END LOOP;
    RETURN GREATEST(max_page, 1);
  END IF;

  -- Legacy `questions` format — page (1-indexed)
  IF p_schema ? 'questions' AND jsonb_typeof(p_schema->'questions') = 'array' THEN
    FOR item IN SELECT jsonb_array_elements(p_schema->'questions')
    LOOP
      page_val := COALESCE(NULLIF(item->>'page','')::int, 1);
      IF page_val > max_page THEN max_page := page_val; END IF;
    END LOOP;
    RETURN GREATEST(max_page, 1);
  END IF;

  RETURN 1;
END;
$function$;

-- --- call_job_notification_edge_function(p_trigger_type text, p_job_id uuid, p_application_id uuid, p_old_status text) ---
CREATE OR REPLACE FUNCTION public.call_job_notification_edge_function(p_trigger_type text, p_job_id uuid, p_application_id uuid DEFAULT NULL::uuid, p_old_status text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_url TEXT;
  v_service_role_key TEXT;
  v_request_id BIGINT;
  v_payload JSONB;
BEGIN
  -- Get config from table
  SELECT value INTO v_url FROM public.job_notification_config WHERE key = 'edge_function_url';
  SELECT value INTO v_service_role_key FROM public.job_notification_config WHERE key = 'service_role_key';
  
  IF v_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'Job notification config not set. Please update job_notification_config table.';
    RETURN;
  END IF;
  
  -- Build payload
  v_payload := jsonb_build_object(
    'trigger_type', p_trigger_type,
    'job_id', p_job_id
  );
  
  IF p_application_id IS NOT NULL THEN
    v_payload := v_payload || jsonb_build_object('application_id', p_application_id);
  END IF;
  
  IF p_old_status IS NOT NULL THEN
    v_payload := v_payload || jsonb_build_object('old_status', p_old_status);
  END IF;
  
  -- FIXED: Use net.http_post (not extensions.http_post)
  SELECT net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key
    ),
    body := v_payload,
    timeout_milliseconds := 5000
  ) INTO v_request_id;
  
  RAISE LOG 'Job notification sent: type=%, job=%, app=%, request_id=%', 
    p_trigger_type, p_job_id, p_application_id, v_request_id;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to send job notification: % - %', SQLSTATE, SQLERRM;
END;
$function$;

-- --- call_populate_subscriber_geography() ---
CREATE OR REPLACE FUNCTION public.call_populate_subscriber_geography()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  request_id bigint;
BEGIN
  -- Use pg_net with the anon key (safe - it's already public)
  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/populate-subscriber-geography',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE3NzUwMzcsImV4cCI6MjA0NzM1MTAzN30.KsOsdwkivgwJDZVIOijsWCzqvjYgcZaNdOhcaJmJbNU"}'::jsonb,
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

-- --- can_member_vote(p_member_id uuid, p_voting_form_id uuid) ---
CREATE OR REPLACE FUNCTION public.can_member_vote(p_member_id uuid, p_voting_form_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$ DECLARE v_member RECORD; v_form RECORD; v_already_voted boolean; BEGIN SELECT * INTO v_member FROM public.members WHERE id = p_member_id; IF v_member IS NULL THEN RETURN false; END IF; IF v_member.membership_eligible IS NOT NULL AND v_member.membership_eligible = false THEN RETURN false; END IF; SELECT * INTO v_form FROM public.voting_forms WHERE id = p_voting_form_id; IF v_form IS NULL THEN RETURN false; END IF; IF v_form.status != 'active' THEN RETURN false; END IF; IF v_form.voting_starts_at IS NOT NULL AND now() < v_form.voting_starts_at THEN RETURN false; END IF; IF v_form.voting_ends_at IS NOT NULL AND now() > v_form.voting_ends_at THEN RETURN false; END IF; SELECT EXISTS(SELECT 1 FROM public.votes WHERE member_id = p_member_id AND voting_form_id = p_voting_form_id) INTO v_already_voted; IF v_already_voted THEN RETURN false; END IF; RETURN true; END; $function$;

-- --- check_executive_before_email(event jsonb) ---
CREATE OR REPLACE FUNCTION public.check_executive_before_email(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Do absolutely nothing, just return the event unchanged
  RETURN event;
END;
$function$;

-- --- claim_text_extraction_chunk(p_worker_id text, p_lock_duration_seconds integer) ---
CREATE OR REPLACE FUNCTION public.claim_text_extraction_chunk(p_worker_id text DEFAULT (gen_random_uuid())::text, p_lock_duration_seconds integer DEFAULT 60)
 RETURNS TABLE(queue_id uuid, bill_id uuid, bill_identifier text, pdf_storage_path text, pdf_total_pages integer, current_chunk integer, pages_per_chunk integer, start_page integer, end_page integer, extracted_chunks jsonb)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_record RECORD;
  v_start_page integer;
  v_end_page integer;
BEGIN
  -- Find and lock the next available queue item
  -- Prioritize: 1) Items already in progress (continue), 2) New items by priority
  SELECT q.* INTO v_record
  FROM public.legislation_text_extraction_queue q
  WHERE (
    -- Either queued and ready to start
    (q.status = 'queued')
    OR
    -- Or in progress but lock expired (abandoned)
    (q.status = 'processing' AND q.lock_expires_at < now())
  )
  AND q.attempts < q.max_attempts
  ORDER BY 
    CASE WHEN q.status = 'processing' THEN 0 ELSE 1 END, -- Prioritize continuing work
    q.priority,
    q.created_at
  LIMIT 1
  FOR UPDATE SKIP LOCKED;
  
  IF v_record IS NULL THEN
    RETURN; -- No work available
  END IF;
  
  -- Calculate page range for this chunk
  v_start_page := v_record.pages_processed;
  v_end_page := LEAST(
    v_start_page + v_record.pages_per_chunk,
    COALESCE(v_record.pdf_total_pages, v_start_page + v_record.pages_per_chunk)
  );
  
  -- Update the record with lock
  UPDATE public.legislation_text_extraction_queue
  SET 
    status = 'processing',
    locked_by = p_worker_id,
    locked_at = now(),
    lock_expires_at = now() + (p_lock_duration_seconds || ' seconds')::interval,
    started_at = COALESCE(started_at, now()),
    updated_at = now()
  WHERE id = v_record.id;
  
  -- Update bill status
  UPDATE public.legislation_tracked_bills
  SET 
    text_extraction_status = 'in_progress',
    text_extraction_started_at = COALESCE(text_extraction_started_at, now())
  WHERE id = v_record.bill_id;
  
  -- Return the work item
  RETURN QUERY SELECT
    v_record.id,
    v_record.bill_id,
    v_record.bill_identifier,
    v_record.pdf_storage_path,
    v_record.pdf_total_pages,
    v_record.current_chunk,
    v_record.pages_per_chunk,
    v_start_page,
    v_end_page,
    v_record.extracted_chunks;
END;
$function$;

-- --- cleanup_expired_tokens() ---
CREATE OR REPLACE FUNCTION public.cleanup_expired_tokens()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  DELETE FROM magic_links WHERE expires_at < NOW() - INTERVAL '24 hours';
  DELETE FROM claim_tokens WHERE expires_at < NOW() - INTERVAL '24 hours';
END;
$function$;

-- --- cleanup_stale_extraction_locks() ---
CREATE OR REPLACE FUNCTION public.cleanup_stale_extraction_locks()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.legislation_text_extraction_queue
  SET 
    status = 'queued',
    locked_by = NULL,
    locked_at = NULL,
    lock_expires_at = NULL,
    updated_at = now()
  WHERE status = 'processing'
    AND lock_expires_at < now()
    AND attempts < max_attempts;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$function$;

-- --- create_auth_users_from_members() ---
CREATE OR REPLACE FUNCTION public.create_auth_users_from_members()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  member_record RECORD;
  join_timestamp TIMESTAMPTZ;
  phone_to_use TEXT;
BEGIN
  -- Loop through members who have an email
  FOR member_record IN 
    SELECT id, email, name, phone_e164, date_joined
    FROM public.members
    WHERE email IS NOT NULL 
    AND email != ''
    -- Check if auth user doesn't already exist
    AND NOT EXISTS (SELECT 1 FROM auth.users WHERE id = members.id)
  LOOP
    -- Convert date_joined to timestamp, or use NOW() if NULL
    join_timestamp := COALESCE(member_record.date_joined::timestamptz, NOW());
    
    -- Use phone_e164
    phone_to_use := member_record.phone_e164;
    
    -- Check if phone already exists in auth.users, if so set to NULL
    IF phone_to_use IS NOT NULL AND EXISTS (SELECT 1 FROM auth.users WHERE phone = phone_to_use) THEN
      phone_to_use := NULL;
    END IF;
    
    -- Insert into auth.users using member's UUID
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      phone,
      encrypted_password,
      email_confirmed_at,
      phone_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      member_record.id,
      'authenticated',
      'authenticated',
      member_record.email,
      phone_to_use,
      '',
      join_timestamp,
      CASE WHEN phone_to_use IS NOT NULL THEN join_timestamp ELSE NULL END,
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('name', member_record.name),
      join_timestamp,
      join_timestamp,
      '',
      ''
    );

    -- Create identity record with provider_id
    INSERT INTO auth.identities (
      provider_id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      member_record.id::text,
      member_record.id,
      jsonb_build_object('sub', member_record.id::text, 'email', member_record.email),
      'email',
      join_timestamp,
      join_timestamp,
      join_timestamp
    );

  END LOOP;
END;
$function$;

-- --- create_bill_sync_status_on_insert() ---
CREATE OR REPLACE FUNCTION public.create_bill_sync_status_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.legislation_bill_sync_status (
    bill_id, last_import_at, needs_detail_sync, needs_text_extract, needs_sponsor_link
  ) VALUES (
    NEW.id, NOW(), TRUE, TRUE, TRUE
  )
  ON CONFLICT (bill_id) DO NOTHING;
  RETURN NEW;
END;
$function$;

-- --- custom_access_token_hook(event jsonb) ---
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  user_email text;
  is_executive boolean;
BEGIN
  -- Get the user's email from the event
  user_email := event->'claims'->>'email';
  
  -- Check if this email belongs to an executive member
  SELECT executive_committee INTO is_executive
  FROM public.members
  WHERE email = user_email
  LIMIT 1;
  
  -- If not found or not executive, block the token
  IF is_executive IS NULL THEN
    RAISE EXCEPTION 'Email not found in our system'
      USING HINT = 'not_found';
  END IF;
  
  IF is_executive = FALSE THEN
    RAISE EXCEPTION 'Access denied: Only executive committee members can access this app'
      USING HINT = 'not_executive';
  END IF;
  
  -- If executive, return the event unchanged (allow token to be issued)
  RETURN event;
END;
$function$;

-- --- delete_node_with_cleanup(p_node_id uuid) ---
CREATE OR REPLACE FUNCTION public.delete_node_with_cleanup(p_node_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_node RECORD;
  v_result JSONB;
BEGIN
  -- Get node details before deletion (for file cleanup)
  SELECT * INTO v_node
  FROM public.canvas_nodes
  WHERE id = p_node_id;
  
  IF v_node IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Node not found'
    );
  END IF;
  
  -- Delete the node (connections will cascade delete)
  DELETE FROM public.canvas_nodes WHERE id = p_node_id;
  
  -- Return file URLs that need cleanup (client handles actual storage deletion)
  v_result := jsonb_build_object(
    'success', true,
    'deleted_node_id', p_node_id,
    'files_to_delete', jsonb_build_array()
  );
  
  -- Add file URL if present
  IF v_node.file_url IS NOT NULL THEN
    v_result := jsonb_set(
      v_result, 
      '{files_to_delete}', 
      v_result->'files_to_delete' || to_jsonb(v_node.file_url)
    );
  END IF;
  
  -- Add image URLs if present
  IF v_node.image_url IS NOT NULL THEN
    v_result := jsonb_set(
      v_result, 
      '{files_to_delete}', 
      v_result->'files_to_delete' || to_jsonb(v_node.image_url)
    );
  END IF;
  
  IF v_node.image_thumbnail_url IS NOT NULL THEN
    v_result := jsonb_set(
      v_result, 
      '{files_to_delete}', 
      v_result->'files_to_delete' || to_jsonb(v_node.image_thumbnail_url)
    );
  END IF;
  
  RETURN v_result;
END;
$function$;

-- --- discover_new_tables() ---
CREATE OR REPLACE FUNCTION public.discover_new_tables()
 RETURNS TABLE(tbl_name text, row_count bigint, has_id_column boolean, suggested_title_column text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Insert newly discovered tables
  INSERT INTO public.knowledge_table_config (table_name, schema_name, is_discovered, is_enabled)
  SELECT 
    t.tablename,
    t.schemaname,
    true,
    false
  FROM pg_tables t
  WHERE t.schemaname = 'public'
    AND t.tablename NOT LIKE 'knowledge_%'
    AND t.tablename NOT LIKE 'pg_%'
    AND t.tablename NOT LIKE '_prisma%'
    AND t.tablename NOT IN (
      SELECT ktc.table_name FROM public.knowledge_table_config ktc WHERE ktc.schema_name = 'public'
    )
  ON CONFLICT (table_name) DO NOTHING;
  
  -- Return unconfigured tables
  RETURN QUERY
  SELECT 
    ktc.table_name::TEXT AS tbl_name,
    (SELECT reltuples::BIGINT FROM pg_class pc WHERE pc.relname = ktc.table_name) AS row_count,
    EXISTS(
      SELECT 1 FROM information_schema.columns isc
      WHERE isc.table_name = ktc.table_name 
        AND isc.table_schema = 'public'
        AND isc.column_name = 'id'
    ) AS has_id_column,
    COALESCE(
      (SELECT isc2.column_name FROM information_schema.columns isc2
       WHERE isc2.table_name = ktc.table_name 
         AND isc2.table_schema = 'public'
         AND isc2.column_name IN ('name', 'title', 'subject', 'email')
       LIMIT 1),
      'id'
    )::TEXT AS suggested_title_column
  FROM public.knowledge_table_config ktc
  WHERE ktc.is_discovered = true AND ktc.is_enabled = false
  ORDER BY row_count DESC NULLS LAST;
END;
$function$;

-- --- enrich_donors_from_census() ---
CREATE OR REPLACE FUNCTION public.enrich_donors_from_census()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET statement_timeout TO '300s'
AS $function$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE public.donor_enrichment d
    SET
        tract_median_household_income = c.median_household_income,
        tract_median_home_value = c.median_home_value,
        tract_pct_college_educated = c.pct_college_educated,
        tract_pct_white = c.pct_white,
        tract_pct_black = c.pct_black,
        tract_pct_hispanic = c.pct_hispanic,
        tract_pct_asian = c.pct_asian,
        tract_pct_poverty = c.pct_poverty,
        tract_pct_homeowner = c.pct_homeowner,
        tract_median_age = c.median_age,
        tract_population = c.total_population,
        neighborhood_type = c.urbanicity,
        urbanicity = c.urbanicity
    FROM public.census_zip_data c
    WHERE LEFT(d.current_zip, 5) = c.zip5
      AND d.current_zip IS NOT NULL
      AND LENGTH(d.current_zip) >= 5;
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$function$;

-- --- extract_sponsors_from_cached_data() ---
CREATE OR REPLACE FUNCTION public.extract_sponsors_from_cached_data()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  total_inserted INT := 0;
  batch_count INT;
  r RECORD;
BEGIN
  FOR r IN 
    SELECT 
      ltb.id as bill_id,
      ltb.bill_identifier,
      ltb.openstates_data->'sponsorships' as sponsorships
    FROM public.legislation_tracked_bills ltb
    WHERE ltb.session = '2026'
      AND ltb.openstates_data->'sponsorships' IS NOT NULL
      AND jsonb_array_length(ltb.openstates_data->'sponsorships') > 0
      AND NOT EXISTS (
        SELECT 1 FROM public.legislation_bill_sponsors lbs WHERE lbs.bill_id = ltb.id
      )
    LIMIT 100
  LOOP
    INSERT INTO public.legislation_bill_sponsors (
      bill_id, openstates_sponsorship_id, name, entity_type, is_primary,
      sponsorship_classification, openstates_person_id, party, role_title,
      role_org_classification, district, division_id, chamber
    )
    SELECT 
      r.bill_id,
      s->>'id',
      s->>'name',
      COALESCE(s->>'entity_type', 'person'),
      (s->>'primary')::boolean,
      s->>'classification',
      s->'person'->>'id',
      s->'person'->>'party',
      s->'person'->'current_role'->>'title',
      s->'person'->'current_role'->>'org_classification',
      s->'person'->'current_role'->>'district',
      s->'person'->'current_role'->>'division_id',
      s->'person'->'current_role'->>'org_classification'
    FROM jsonb_array_elements(r.sponsorships) as s
    ON CONFLICT (bill_id, name, sponsorship_classification) DO NOTHING;
    
    -- FIXED: GET DIAGNOSTICS can only assign, not do arithmetic
    GET DIAGNOSTICS batch_count = ROW_COUNT;
    total_inserted := total_inserted + batch_count;
  END LOOP;
  
  RETURN total_inserted;
END;
$function$;

-- --- finalize_text_extraction(p_queue_id uuid, p_worker_id text) ---
CREATE OR REPLACE FUNCTION public.finalize_text_extraction(p_queue_id uuid, p_worker_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_record RECORD;
  v_bill RECORD;
  v_full_text text;
  v_text_hash text;
  v_word_count integer;
BEGIN
  -- Get queue record
  SELECT * INTO v_record
  FROM public.legislation_text_extraction_queue
  WHERE id = p_queue_id;
  
  IF v_record IS NULL THEN
    RAISE EXCEPTION 'Queue item not found: %', p_queue_id;
  END IF;
  
  -- Get current bill text (accumulated from chunks)
  SELECT current_bill_text INTO v_full_text
  FROM public.legislation_tracked_bills
  WHERE id = v_record.bill_id;
  
  -- Calculate hash and word count
  v_text_hash := encode(sha256(v_full_text::bytea), 'hex');
  v_word_count := array_length(regexp_split_to_array(v_full_text, '\s+'), 1);
  
  -- Mark queue as completed
  UPDATE public.legislation_text_extraction_queue
  SET 
    status = 'completed',
    completed_at = now(),
    locked_by = NULL,
    locked_at = NULL,
    lock_expires_at = NULL,
    updated_at = now()
  WHERE id = p_queue_id;
  
  -- Update bill with final text
  UPDATE public.legislation_tracked_bills
  SET 
    current_bill_text_hash = v_text_hash,
    current_bill_text_word_count = v_word_count,
    current_bill_text_extracted_at = now(),
    text_extraction_status = 'completed',
    text_extraction_deferred = false,
    text_extraction_deferred_reason = NULL,
    sync_error = NULL
  WHERE id = v_record.bill_id;
  
  -- Update text versions table
  INSERT INTO public.legislation_bill_text_versions (
    bill_id,
    version_name,
    version_order,
    source_url,
    media_type,
    bill_text,
    text_hash,
    word_count,
    page_count,
    extracted_at,
    extraction_method,
    is_current
  )
  SELECT
    v_record.bill_id,
    COALESCE(ltb.current_bill_text_version, 'Introduced'),
    1,
    COALESCE(ltb.current_bill_text_url, ''),
    'application/pdf',
    v_full_text,
    v_text_hash,
    v_word_count,
    v_record.pdf_total_pages,
    now(),
    'chunked-large-file-processor',
    true
  FROM public.legislation_tracked_bills ltb
  WHERE ltb.id = v_record.bill_id
  ON CONFLICT (bill_id, source_url) DO UPDATE SET
    bill_text = EXCLUDED.bill_text,
    text_hash = EXCLUDED.text_hash,
    word_count = EXCLUDED.word_count,
    page_count = EXCLUDED.page_count,
    extracted_at = EXCLUDED.extracted_at,
    extraction_method = EXCLUDED.extraction_method;
  
  RETURN true;
END;
$function$;

-- --- find_donor_profile_by_mec_id(p_mec_donor_id integer) ---
CREATE OR REPLACE FUNCTION public.find_donor_profile_by_mec_id(p_mec_donor_id integer)
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT id::text FROM public.donor_profiles WHERE mec_donor_id = p_mec_donor_id LIMIT 1;
$function$;

-- --- find_or_create_subscriber_by_phone(p_phone text, p_phone_e164 text, p_source text) ---
CREATE OR REPLACE FUNCTION public.find_or_create_subscriber_by_phone(p_phone text, p_phone_e164 text, p_source text DEFAULT 'form'::text)
 RETURNS TABLE(subscriber_id uuid, member_id uuid, donor_id uuid, is_new boolean, name text, email text, zip_code text, address text, city text, state text, source_type text)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_subscriber RECORD;
  v_member RECORD;
  v_donor RECORD;
  v_attendee RECORD;
  v_found_subscriber_id UUID;
  v_found_member_id UUID;
  v_found_donor_id UUID;
  v_is_new BOOLEAN := FALSE;
  v_name TEXT;
  v_email TEXT;
  v_zip_code TEXT;
  v_address TEXT;
  v_city TEXT;
  v_state TEXT;
  v_source TEXT;
  v_phone_digits TEXT;
BEGIN
  -- Normalize phone to just digits for comparison
  v_phone_digits := REGEXP_REPLACE(p_phone_e164, '[^0-9]', '', 'g');
  IF LENGTH(v_phone_digits) = 11 AND v_phone_digits LIKE '1%' THEN
    v_phone_digits := SUBSTRING(v_phone_digits FROM 2);
  END IF;

  -- =========================================================================
  -- Search in MEMBERS table first (highest priority)
  -- Members has: phone, phone_e164, address, county (NO city, state, zip_code!)
  -- =========================================================================
  SELECT * INTO v_member
  FROM public.members
  WHERE phone_e164 = p_phone_e164
     OR phone = p_phone
     OR phone = p_phone_e164
     OR phone = v_phone_digits
     OR phone_e164 = p_phone
  LIMIT 1;
  
  IF v_member IS NOT NULL THEN
    v_found_member_id := v_member.id;
    v_name := v_member.name;
    v_email := v_member.email;
    v_address := v_member.address;
    -- Members doesn't have city, state, zip_code - leave as NULL
    v_source := 'member';
    
    -- Check if subscriber exists for this member
    SELECT * INTO v_subscriber
    FROM public.subscribers
    WHERE member_id = v_member.id
       OR (v_member.email IS NOT NULL AND email = v_member.email)
    LIMIT 1;
    
    IF v_subscriber IS NOT NULL THEN
      v_found_subscriber_id := v_subscriber.id;
      -- Get additional fields from subscriber that member doesn't have
      v_zip_code := v_subscriber.zip_code;
      v_city := v_subscriber.city;
      v_state := v_subscriber.state;
      v_address := COALESCE(v_address, v_subscriber.address);
    END IF;
  END IF;
  
  -- =========================================================================
  -- Search in SUBSCRIBERS table
  -- Subscribers has: phone, phone_e164, address, city, state, zip_code
  -- =========================================================================
  IF v_found_subscriber_id IS NULL THEN
    SELECT * INTO v_subscriber
    FROM public.subscribers
    WHERE phone_e164 = p_phone_e164
       OR phone = p_phone
       OR phone = p_phone_e164
       OR phone = v_phone_digits
       OR phone_e164 = p_phone
    LIMIT 1;
    
    IF v_subscriber IS NOT NULL THEN
      v_found_subscriber_id := v_subscriber.id;
      v_found_member_id := COALESCE(v_found_member_id, v_subscriber.member_id);
      v_found_donor_id := v_subscriber.donor_id;
      v_name := COALESCE(v_name, v_subscriber.name);
      v_email := COALESCE(v_email, v_subscriber.email);
      v_zip_code := COALESCE(v_zip_code, v_subscriber.zip_code);
      v_address := COALESCE(v_address, v_subscriber.address);
      v_city := COALESCE(v_city, v_subscriber.city);
      v_state := COALESCE(v_state, v_subscriber.state);
      v_source := COALESCE(v_source, 'subscriber');
    END IF;
  END IF;
  
  -- =========================================================================
  -- Search in DONORS table
  -- Donors has: phone, phone_e164, address, city, state, zip_code
  -- =========================================================================
  IF v_found_subscriber_id IS NULL AND v_found_member_id IS NULL THEN
    SELECT * INTO v_donor
    FROM public.donors
    WHERE phone_e164 = p_phone_e164
       OR phone = p_phone
       OR phone = p_phone_e164
       OR phone = v_phone_digits
       OR phone_e164 = p_phone
    LIMIT 1;
    
    IF v_donor IS NOT NULL THEN
      v_found_donor_id := v_donor.id;
      v_found_member_id := v_donor.member_id;
      v_name := COALESCE(v_name, v_donor.name);
      v_email := COALESCE(v_email, v_donor.email);
      v_zip_code := COALESCE(v_zip_code, v_donor.zip_code);
      v_address := COALESCE(v_address, v_donor.address);
      v_city := COALESCE(v_city, v_donor.city);
      v_state := COALESCE(v_state, v_donor.state);
      v_source := COALESCE(v_source, 'donor');
    END IF;
  END IF;
  
  -- =========================================================================
  -- Search in EVENT_ATTENDEES table
  -- Event attendees has: guest_phone, address, city, state, zip (NOT zip_code!)
  -- =========================================================================
  IF v_found_subscriber_id IS NULL AND v_found_member_id IS NULL AND v_found_donor_id IS NULL THEN
    SELECT * INTO v_attendee
    FROM public.event_attendees
    WHERE guest_phone = p_phone
       OR guest_phone = p_phone_e164
       OR guest_phone = v_phone_digits
    LIMIT 1;
    
    IF v_attendee IS NOT NULL THEN
      v_found_member_id := v_attendee.member_id;
      v_name := COALESCE(v_name, v_attendee.guest_name);
      v_email := COALESCE(v_email, v_attendee.guest_email);
      v_zip_code := COALESCE(v_zip_code, v_attendee.zip);  -- Note: column is "zip" not "zip_code"
      v_address := COALESCE(v_address, v_attendee.address);
      v_city := COALESCE(v_city, v_attendee.city);
      v_state := COALESCE(v_state, v_attendee.state);
      v_source := COALESCE(v_source, 'event_attendee');
    END IF;
  END IF;
  
  -- =========================================================================
  -- If no subscriber found, create one with placeholder values
  -- =========================================================================
  IF v_found_subscriber_id IS NULL THEN
    v_is_new := TRUE;
    
    -- Generate placeholder values if we don't have real ones
    IF v_name IS NULL THEN
      v_name := 'Pending ' || p_phone_e164;
    END IF;
    
    IF v_email IS NULL THEN
      v_email := public.generate_placeholder_email(p_phone_e164);
    END IF;
    
    INSERT INTO public.subscribers (
      name,
      email,
      phone,
      phone_e164,
      zip_code,
      address,
      city,
      state,
      member_id,
      donor_id,
      source,
      subscription_status,
      optin_date
    ) VALUES (
      v_name,
      v_email,
      p_phone,
      p_phone_e164,
      v_zip_code,
      v_address,
      v_city,
      v_state,
      v_found_member_id,
      v_found_donor_id,
      p_source,
      'pending',
      NOW()
    )
    RETURNING id INTO v_found_subscriber_id;
    
    v_source := 'new';
  END IF;
  
  RETURN QUERY SELECT 
    v_found_subscriber_id,
    v_found_member_id,
    v_found_donor_id,
    v_is_new,
    v_name,
    v_email,
    v_zip_code,
    v_address,
    v_city,
    v_state,
    v_source;
END;
$function$;

-- --- find_potential_member_matches(p_slack_email text, p_slack_real_name text, p_slack_display_name text) ---
CREATE OR REPLACE FUNCTION public.find_potential_member_matches(p_slack_email text, p_slack_real_name text, p_slack_display_name text)
 RETURNS TABLE(member_id uuid, match_method text, confidence numeric, member_email text, member_name text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Exact email match (highest confidence)
    IF p_slack_email IS NOT NULL THEN
        RETURN QUERY
        SELECT 
            m.id,
            'email_exact'::TEXT,
            1.00::NUMERIC,
            m.email,
            m.name
        FROM members m
        WHERE m.email = p_slack_email
        LIMIT 1;
        
        IF FOUND THEN RETURN; END IF;
        
        -- School email match
        RETURN QUERY
        SELECT 
            m.id,
            'school_email_exact'::TEXT,
            0.95::NUMERIC,
            m.email,
            m.name
        FROM members m
        WHERE m.school_email = p_slack_email
        LIMIT 1;
        
        IF FOUND THEN RETURN; END IF;
    END IF;
    
    -- Name-based fuzzy matching
    IF p_slack_real_name IS NOT NULL THEN
        RETURN QUERY
        SELECT 
            m.id,
            'name_fuzzy'::TEXT,
            CASE 
                WHEN similarity(LOWER(m.name), LOWER(p_slack_real_name)) > 0.7 THEN 0.80
                WHEN similarity(LOWER(m.name), LOWER(p_slack_real_name)) > 0.5 THEN 0.60
                ELSE 0.40
            END::NUMERIC,
            m.email,
            m.name
        FROM members m
        WHERE similarity(LOWER(m.name), LOWER(p_slack_real_name)) > 0.5
        ORDER BY similarity(LOWER(m.name), LOWER(p_slack_real_name)) DESC
        LIMIT 5;
    END IF;
    
    -- Display name matching as fallback
    IF p_slack_display_name IS NOT NULL THEN
        RETURN QUERY
        SELECT 
            m.id,
            'display_name_fuzzy'::TEXT,
            0.50::NUMERIC,
            m.email,
            m.name
        FROM members m
        WHERE similarity(LOWER(m.name), LOWER(p_slack_display_name)) > 0.5
        ORDER BY similarity(LOWER(m.name), LOWER(p_slack_display_name)) DESC
        LIMIT 3;
    END IF;
END;
$function$;

-- --- format_application_status(p_status text) ---
CREATE OR REPLACE FUNCTION public.format_application_status(p_status text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN CASE p_status
        WHEN 'submitted' THEN 'Submitted'
        WHEN 'reviewed' THEN 'Under Review'
        WHEN 'shortlisted' THEN 'Shortlisted'
        WHEN 'rejected' THEN 'Not Selected'
        WHEN 'accepted' THEN 'Accepted'
        ELSE p_status
    END;
END;
$function$;

-- --- format_dashboard_metrics_for_knowledge() ---
CREATE OR REPLACE FUNCTION public.format_dashboard_metrics_for_knowledge()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  metrics RECORD;
  result TEXT;
  top_donors TEXT;
  top_slack TEXT;
  members_by_county TEXT;
  members_by_cd TEXT;
  members_by_chapter TEXT;
  members_by_committee TEXT;
  members_by_college TEXT;
  members_by_gender TEXT;
  members_by_race TEXT;
  voter_registered INT;
  voter_not_registered INT;
  voter_unknown INT;
BEGIN
  -- Get the latest metrics
  SELECT * INTO metrics FROM public.crm_dashboard_metrics ORDER BY updated_at DESC LIMIT 1;
  
  IF metrics IS NULL THEN
    RETURN 'No dashboard metrics available.';
  END IF;

  -- Format top donors
  SELECT STRING_AGG(
    format('%s: $%s', elem->>'name', elem->>'total_donated'),
    E'\n'
  ) INTO top_donors
  FROM jsonb_array_elements(metrics.top_5_donors) AS elem;

  -- Format top Slack members (top 15)
  SELECT STRING_AGG(
    format('%s (%s): %s messages', elem->>'name', elem->>'email', elem->>'message_count'),
    E'\n'
  ) INTO top_slack
  FROM (
    SELECT jsonb_array_elements(metrics.top_50_slack_members) AS elem
    LIMIT 15
  ) sub;

  -- Format members by county (top 20)
  SELECT STRING_AGG(
    format('%s: %s members', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_county
  FROM (
    SELECT jsonb_array_elements(metrics.members_by_county) AS elem
    LIMIT 20
  ) sub;

  -- Format members by congressional district
  SELECT STRING_AGG(
    format('%s: %s members', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_cd
  FROM jsonb_array_elements(metrics.members_by_congressional_district) AS elem;

  -- Format members by chapter
  SELECT STRING_AGG(
    format('%s: %s members', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_chapter
  FROM jsonb_array_elements(metrics.members_by_chapter) AS elem;

  -- Format members by committee
  SELECT STRING_AGG(
    format('%s: %s members', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_committee
  FROM jsonb_array_elements(metrics.members_by_committee) AS elem;

  -- Format members by college (top 15)
  SELECT STRING_AGG(
    format('%s: %s members', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_college
  FROM (
    SELECT jsonb_array_elements(metrics.members_by_college) AS elem
    LIMIT 15
  ) sub;

  -- Format members by gender identity (top 10)
  SELECT STRING_AGG(
    format('%s: %s', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_gender
  FROM (
    SELECT jsonb_array_elements(metrics.members_by_gender_identity) AS elem
    LIMIT 10
  ) sub;

  -- Format members by race (top 10)
  SELECT STRING_AGG(
    format('%s: %s', elem->>'name', elem->>'count'),
    E'\n'
  ) INTO members_by_race
  FROM (
    SELECT jsonb_array_elements(metrics.members_by_race) AS elem
    LIMIT 10
  ) sub;

  -- Get voter registration counts
  SELECT COALESCE(SUM((elem->>'count')::int), 0) INTO voter_registered
  FROM jsonb_array_elements(metrics.members_by_voter_registration) elem 
  WHERE elem->>'name' = 'Registered';
  
  SELECT COALESCE(SUM((elem->>'count')::int), 0) INTO voter_not_registered
  FROM jsonb_array_elements(metrics.members_by_voter_registration) elem 
  WHERE elem->>'name' = 'Not Registered';
  
  SELECT COALESCE(SUM((elem->>'count')::int), 0) INTO voter_unknown
  FROM jsonb_array_elements(metrics.members_by_voter_registration) elem 
  WHERE elem->>'name' = 'Unknown';

  -- Build the full document
  result := format(
'# MOYD Organization Dashboard Metrics
Last Updated: %s

## Overview Statistics

### Membership
- **Total Members**: %s
- **Members with Phone Numbers**: %s
- **Total Subscribers**: %s
- **Total Donors**: %s
- **New Members This Week**: %s
- **New Members This Month**: %s
- **New Members This Year**: %s
- **New Subscribers This Month**: %s

### Age Demographics
- **Average Member Age**: %s years
- **Ages 14-17**: %s members
- **Ages 18-21**: %s members (largest group)
- **Ages 22-25**: %s members
- **Ages 26-30**: %s members
- **Ages 31-36**: %s members
- **Age Unknown**: %s members

### Chapters
- **Total Chapters**: %s
- **Chartered Chapters**: %s
- **College Chapters**: %s
- **High School Chapters**: %s
- **County Chapters**: %s

### Geographic Reach
- **Unique Counties Represented**: %s
- **Unique Congressional Districts**: %s
- **Unique State House Districts**: %s
- **Unique State Senate Districts**: %s
- **Unique Colleges**: %s
- **Unique High Schools**: %s

### Donations & Fundraising
- **Total Amount Raised**: $%s
- **Total Donation Count**: %s
- **Average Donation**: $%s
- **Recurring Donors**: %s
- **Donations This Month**: $%s
- **Donations This Year**: $%s

### Slack Activity
- **Total Slack Messages**: %s
- **Slack Messages This Month**: %s

### Social Media
- **Total Social Impressions**: %s

### Events
- **Total Events**: %s
- **Upcoming Events**: %s
- **Total Event Attendees**: %s

### Email Campaigns
- **Total Campaigns**: %s
- **Campaigns Sent**: %s
- **Total Emails Sent**: %s
- **Total Emails Opened**: %s
- **Total Emails Clicked**: %s
- **Average Open Rate**: %s%%
- **Average Click Rate**: %s%%

---

## Top 5 Donors
%s

---

## Top 15 Most Active Slack Members
%s

---

## Members by County (Top 20)
%s

---

## Members by Congressional District
%s

---

## Members by Chapter
%s

---

## Members by Committee/Interest Area
%s

---

## Members by College (Top 15)
%s

---

## Gender Identity Distribution
%s

---

## Racial Demographics
%s

---

## Voter Registration Status
- Registered: %s
- Not Registered: %s
- Unknown: %s

---

*This data is automatically updated from the CRM dashboard metrics.*',
    metrics.updated_at,
    metrics.total_members,
    metrics.total_members_with_phone,
    metrics.total_subscribers,
    metrics.total_donors,
    metrics.new_members_this_week,
    metrics.new_members_this_month,
    metrics.new_members_this_year,
    metrics.new_subscribers_this_month,
    metrics.average_member_age,
    metrics.age_14_17_count,
    metrics.age_18_21_count,
    metrics.age_22_25_count,
    metrics.age_26_30_count,
    metrics.age_31_36_count,
    metrics.age_unknown_count,
    metrics.total_chapters,
    metrics.total_chartered_chapters,
    metrics.total_college_chapters,
    metrics.total_highschool_chapters,
    metrics.total_county_chapters,
    metrics.total_unique_counties,
    metrics.total_unique_congressional_districts,
    metrics.total_unique_house_districts,
    metrics.total_unique_senate_districts,
    metrics.total_unique_colleges,
    metrics.total_unique_high_schools,
    metrics.total_donations_amount,
    metrics.total_donation_count,
    metrics.average_donation_amount,
    metrics.total_recurring_donors,
    metrics.donations_this_month,
    metrics.donations_this_year,
    metrics.total_slack_messages,
    metrics.slack_messages_this_month,
    metrics.total_social_impressions,
    metrics.total_events,
    metrics.upcoming_events,
    metrics.total_event_attendees,
    metrics.total_campaigns,
    metrics.campaigns_sent,
    metrics.total_emails_sent,
    metrics.total_emails_opened,
    metrics.total_emails_clicked,
    metrics.average_open_rate,
    metrics.average_click_rate,
    COALESCE(top_donors, 'No donor data available'),
    COALESCE(top_slack, 'No Slack data available'),
    COALESCE(members_by_county, 'No county data available'),
    COALESCE(members_by_cd, 'No congressional district data available'),
    COALESCE(members_by_chapter, 'No chapter data available'),
    COALESCE(members_by_committee, 'No committee data available'),
    COALESCE(members_by_college, 'No college data available'),
    COALESCE(members_by_gender, 'No gender data available'),
    COALESCE(members_by_race, 'No race data available'),
    voter_registered,
    voter_not_registered,
    voter_unknown
  );

  RETURN result;
END;
$function$;

-- --- format_job_type(p_job_type text) ---
CREATE OR REPLACE FUNCTION public.format_job_type(p_job_type text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    RETURN CASE p_job_type
        WHEN 'full-time' THEN 'Full-time'
        WHEN 'part-time' THEN 'Part-time'
        WHEN 'internship' THEN 'Internship'
        WHEN 'volunteer' THEN 'Volunteer'
        WHEN 'contract' THEN 'Contract'
        ELSE p_job_type
    END;
END;
$function$;

-- --- format_subscriber_phone_e164() ---
CREATE OR REPLACE FUNCTION public.format_subscriber_phone_e164()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cleaned_phone text;
  v_digits text;
BEGIN
  -- Only process if phone is not null and phone_e164 is null or phone has changed
  IF NEW.phone IS NOT NULL AND (
    NEW.phone_e164 IS NULL OR 
    (TG_OP = 'UPDATE' AND OLD.phone IS DISTINCT FROM NEW.phone)
  ) THEN
    -- Remove all non-digit characters
    v_digits := regexp_replace(NEW.phone, '[^0-9]', '', 'g');
    
    -- Handle different phone number formats
    IF length(v_digits) = 11 AND substring(v_digits, 1, 1) = '1' THEN
      -- Already has country code (1XXXXXXXXXX)
      NEW.phone_e164 := '+' || v_digits;
    ELSIF length(v_digits) = 10 THEN
      -- Standard 10-digit US number (XXXXXXXXXX)
      NEW.phone_e164 := '+1' || v_digits;
    ELSIF length(v_digits) = 7 THEN
      -- 7-digit local number - we can't determine area code, leave phone_e164 null
      NEW.phone_e164 := NULL;
    ELSE
      -- Invalid length, leave phone_e164 null
      NEW.phone_e164 := NULL;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- generate_form_slug() ---
CREATE OR REPLACE FUNCTION public.generate_form_slug()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  base_slug TEXT;
  final_slug TEXT;
  counter INT := 0;
BEGIN
  IF NEW.slug IS NULL THEN
    base_slug := lower(regexp_replace(NEW.title, '[^a-zA-Z0-9]+', '-', 'g'));
    base_slug := trim(both '-' from base_slug);
    final_slug := base_slug;
    
    WHILE EXISTS (
      SELECT 1 FROM public.form_schemas 
      WHERE slug = final_slug 
      AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) LOOP
      counter := counter + 1;
      final_slug := base_slug || '-' || counter;
    END LOOP;
    
    NEW.slug := final_slug;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- generate_job_slug() ---
CREATE OR REPLACE FUNCTION public.generate_job_slug()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  base_slug TEXT;
  final_slug TEXT;
  counter INT := 0;
BEGIN
  -- Generate slug from title and organization
  base_slug := lower(regexp_replace(NEW.title || '-' || NEW.organization, '[^a-zA-Z0-9]+', '-', 'g'));
  base_slug := trim(both '-' from base_slug);
  
  -- Truncate if too long
  IF length(base_slug) > 80 THEN
    base_slug := left(base_slug, 80);
    base_slug := trim(both '-' from base_slug);
  END IF;
  
  final_slug := base_slug;
  
  -- Check for uniqueness
  WHILE EXISTS (
    SELECT 1 FROM public.jobs 
    WHERE slug = final_slug 
    AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) LOOP
    counter := counter + 1;
    final_slug := base_slug || '-' || counter;
  END LOOP;
  
  NEW.slug := final_slug;
  RETURN NEW;
END;
$function$;

-- --- generate_placeholder_email(phone_e164 text) ---
CREATE OR REPLACE FUNCTION public.generate_placeholder_email(phone_e164 text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN 'form_' || REPLACE(phone_e164, '+', '') || '@pending.moyd.org';
END;
$function$;

-- --- get_all_chapters_summary() ---
CREATE OR REPLACE FUNCTION public.get_all_chapters_summary()
 RETURNS TABLE(chapter_name text, school_name text, chapter_type text, member_count bigint, document_count bigint, has_bylaws boolean, has_charter boolean, has_constitution boolean, officer_count bigint, newest_member_date date)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    d.chapter_name,
    d.school_name,
    d.chapter_type,
    COUNT(DISTINCT m.id) as member_count,
    COUNT(DISTINCT d.id) as document_count,
    MAX(CASE WHEN d.document_type = 'bylaws' THEN true ELSE false END) as has_bylaws,
    MAX(CASE WHEN d.document_type = 'charter' THEN true ELSE false END) as has_charter,
    MAX(CASE WHEN d.document_type = 'constitution' THEN true ELSE false END) as has_constitution,
    COUNT(DISTINCT CASE WHEN m.chapter_position IS NOT NULL THEN m.id END) as officer_count,
    MAX(m.date_joined) as newest_member_date
  FROM 
    public.chapter_documents d
  LEFT JOIN 
    public.members m ON m.chapter_name ILIKE '%' || d.school_name || '%'
  GROUP BY 
    d.chapter_name, d.school_name, d.chapter_type
  ORDER BY 
    d.chapter_type, d.school_name;
END;
$function$;

-- --- get_available_api_key() ---
CREATE OR REPLACE FUNCTION public.get_available_api_key()
 RETURNS TABLE(api_key text, key_id integer, key_name text, calls_remaining integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- First, clear expired rate limits
  UPDATE public.legislation_api_keys
  SET 
    is_rate_limited = FALSE,
    rate_limited_until = NULL,
    consecutive_429s = 0,
    updated_at = NOW()
  WHERE is_rate_limited = TRUE 
    AND rate_limited_until IS NOT NULL 
    AND rate_limited_until < NOW();
  
  -- Return key with most remaining capacity
  RETURN QUERY
  SELECT 
    lak.api_key,
    lak.id as key_id,
    lak.name as key_name,
    (lak.calls_limit - lak.calls_today) as calls_remaining
  FROM public.legislation_api_keys lak
  WHERE lak.is_active = TRUE
    AND lak.is_rate_limited = FALSE
    AND lak.calls_today < lak.calls_limit
  ORDER BY 
    lak.calls_today ASC,
    lak.consecutive_429s ASC
  LIMIT 1;
END;
$function$;

-- --- get_bills_for_detail_sync(p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_bills_for_detail_sync(p_limit integer DEFAULT 10)
 RETURNS TABLE(bill_id uuid, bill_identifier text, openstates_bill_id text, last_synced timestamp with time zone, priority integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    ltb.id,
    ltb.bill_identifier,
    ltb.openstates_bill_id,
    bss.last_detail_sync_at,
    CASE 
      WHEN bss.last_detail_sync_at IS NULL THEN 1
      WHEN bss.detail_sync_error IS NOT NULL AND bss.detail_sync_error NOT LIKE '%429%' THEN 3
      ELSE 2
    END as priority
  FROM public.legislation_tracked_bills ltb
  LEFT JOIN public.legislation_bill_sync_status bss ON bss.bill_id = ltb.id
  WHERE ltb.session = '2026'
    AND COALESCE(ltb.is_archived, FALSE) = FALSE
    AND (bss.needs_detail_sync = TRUE OR bss.bill_id IS NULL)
    AND (bss.detail_sync_error IS NULL OR bss.detail_sync_error NOT LIKE '%No PDF%')
  ORDER BY priority ASC, bss.last_detail_sync_at ASC NULLS FIRST
  LIMIT p_limit;
END;
$function$;

-- --- get_bills_for_text_extract(p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_bills_for_text_extract(p_limit integer DEFAULT 10)
 RETURNS TABLE(bill_id uuid, bill_identifier text, openstates_bill_id text, current_bill_text_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    ltb.id,
    ltb.bill_identifier,
    ltb.openstates_bill_id,
    ltb.current_bill_text_url
  FROM public.legislation_tracked_bills ltb
  LEFT JOIN public.legislation_bill_sync_status bss ON bss.bill_id = ltb.id
  WHERE ltb.session = '2026'
    AND COALESCE(ltb.is_archived, FALSE) = FALSE
    AND (bss.needs_text_extract = TRUE OR bss.bill_id IS NULL)
    AND ltb.current_bill_text IS NULL
    AND (ltb.sync_error IS NULL OR ltb.sync_error NOT LIKE '%No PDF%')
    AND (bss.text_extract_error IS NULL OR bss.text_extract_error NOT LIKE '%No PDF%')
  ORDER BY bss.last_text_extract_at ASC NULLS FIRST
  LIMIT p_limit;
END;
$function$;

-- --- get_bipartisan_bill_ids() ---
CREATE OR REPLACE FUNCTION public.get_bipartisan_bill_ids()
 RETURNS TABLE(bill_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT DISTINCT b.id as bill_id
  FROM legislation_tracked_bills b
  WHERE b.is_archived = false
  AND EXISTS (
    SELECT 1 FROM legislation_bill_sponsors s 
    WHERE s.bill_id = b.id 
    AND (s.party ILIKE '%democrat%' OR s.party = 'D')
  )
  AND EXISTS (
    SELECT 1 FROM legislation_bill_sponsors s 
    WHERE s.bill_id = b.id 
    AND (s.party ILIKE '%republican%' OR s.party = 'R')
  );
END;
$function$;

-- --- get_committee_donors_paginated(p_mec_id text, p_limit integer, p_offset integer, p_sort_by text, p_ascending boolean) ---
CREATE OR REPLACE FUNCTION public.get_committee_donors_paginated(p_mec_id text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0, p_sort_by text DEFAULT 'total'::text, p_ascending boolean DEFAULT false)
 RETURNS TABLE(donor_id integer, donor_name text, city text, state text, employer text, occupation text, total numeric, cnt integer, first_date date, last_date date, has_fec boolean)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    d.id::int,
    CASE
      WHEN c.contributor_company IS NOT NULL AND c.contributor_company != '' THEN c.contributor_company
      WHEN c.contributor_committee IS NOT NULL AND c.contributor_committee != '' THEN c.contributor_committee
      ELSE trim(coalesce(c.contributor_first_name, '') || ' ' || coalesce(c.contributor_last_name, ''))
    END,
    max(c.city),
    max(c.state),
    max(c.employer),
    max(c.occupation),
    sum(c.contribution_amount),
    count(*)::int,
    min(c.contribution_date)::date,
    max(c.contribution_date)::date,
    coalesce(max(d.fec_contribution_count), 0) > 0
  FROM public.mec_contributions c
  LEFT JOIN public.mec_donors d ON d.id = c.donor_id
  WHERE c.mec_id = p_mec_id
  GROUP BY d.id, 2
  ORDER BY
    CASE WHEN p_sort_by = 'total' AND NOT p_ascending THEN sum(c.contribution_amount) END DESC NULLS LAST,
    CASE WHEN p_sort_by = 'total' AND p_ascending THEN sum(c.contribution_amount) END ASC NULLS LAST,
    CASE WHEN p_sort_by = 'count' AND NOT p_ascending THEN count(*) END DESC,
    CASE WHEN p_sort_by = 'count' AND p_ascending THEN count(*) END ASC,
    CASE WHEN p_sort_by = 'name' THEN 1 END ASC,
    CASE WHEN p_sort_by = 'last_date' AND NOT p_ascending THEN max(c.contribution_date) END DESC NULLS LAST,
    CASE WHEN p_sort_by = 'last_date' AND p_ascending THEN max(c.contribution_date) END ASC NULLS LAST
  LIMIT p_limit OFFSET p_offset;
END;
$function$;

-- --- get_committee_full_profile(p_mec_id text) ---
CREATE OR REPLACE FUNCTION public.get_committee_full_profile(p_mec_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'committee', (SELECT row_to_json(c) FROM public.mec_committees c WHERE c.mec_id = p_mec_id),
    'candidate', (
      SELECT row_to_json(x) FROM (
        SELECT c.id, c.name, c.party, c.office, c.district, c.photo_url, c.incumbent
        FROM public.candidates c
        WHERE p_mec_id = ANY(c.mec_committee_ids) LIMIT 1
      ) x
    ),
    'totals',             (SELECT public.get_mec_finance_summary(p_mec_id)),
    'expenditure_totals', (SELECT public.get_mec_expenditure_summary(p_mec_id)),
    'top_donors',         (SELECT public.get_mec_top_donors(p_mec_id, 50)),
    'top_payees',         (SELECT public.get_mec_top_payees(p_mec_id, 50)),
    'timeline',           (SELECT public.get_mec_contribution_timeline(p_mec_id)),
    'recent_expenditures', (
      SELECT COALESCE(json_agg(row_to_json(e) ORDER BY e.expenditure_date DESC NULLS LAST), '[]'::json)
      FROM (
        SELECT id, expenditure_date, expenditure_amount, expenditure_purpose, expenditure_type,
               TRIM(COALESCE(payee_first_name, '')) AS payee_first_name,
               TRIM(COALESCE(payee_last_name,  '')) AS payee_last_name,
               TRIM(COALESCE(payee_company,    '')) AS payee_company,
               COALESCE(city,'') AS city, COALESCE(state,'') AS state,
               report
        FROM public.mec_expenditures
        WHERE mec_id = p_mec_id
        ORDER BY expenditure_date DESC NULLS LAST
        LIMIT 100
      ) e
    ),
    'recent_contributions', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.contribution_date DESC NULLS LAST), '[]'::json)
      FROM (
        SELECT id, contribution_date, contribution_amount, monetary_or_inkind,
               TRIM(COALESCE(contributor_first_name,'')) AS contributor_first_name,
               TRIM(COALESCE(contributor_last_name,''))  AS contributor_last_name,
               TRIM(COALESCE(contributor_committee,''))  AS contributor_committee,
               TRIM(COALESCE(contributor_company,''))    AS contributor_company,
               COALESCE(city,'') AS city, COALESCE(state,'') AS state,
               employer, occupation, report
        FROM public.mec_contributions
        WHERE mec_id = p_mec_id
        ORDER BY contribution_date DESC NULLS LAST
        LIMIT 100
      ) t
    )
  );
$function$;

-- --- get_committee_leaders(p_committee_slug text) ---
CREATE OR REPLACE FUNCTION public.get_committee_leaders(p_committee_slug text)
 RETURNS TABLE(member_id uuid, member_name text, email text, title text, profile_pictures jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_role_name text;
begin
  -- Get the executive_role_name for this committee
  select executive_role_name into v_role_name
  from public.committees
  where slug = p_committee_slug;
  
  if v_role_name is null then
    return;
  end if;
  
  return query
  select 
    m.id,
    m.name,
    m.email,
    m.executive_title,
    m.profile_pictures
  from public.members m
  where m.executive_role = v_role_name
    and m.executive_committee = true
    and m.executive_title in ('Chair', 'Co-Chair')
  order by 
    m.executive_title,  -- Groups Chair and Co-Chair together alphabetically
    m.name;
end;
$function$;

-- --- get_committee_with_leaders(p_committee_slug text) ---
CREATE OR REPLACE FUNCTION public.get_committee_with_leaders(p_committee_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_committee jsonb;
  v_leaders jsonb;
begin
  -- Get committee info
  select jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'slug', c.slug,
    'description', c.description,
    'tools', c.tools,
    'color', c.color,
    'icon', c.icon,
    'meeting_schedule', c.meeting_schedule,
    'slack_channel_id', c.slack_channel_id
  ) into v_committee
  from public.committees c
  where c.slug = p_committee_slug and c.is_active = true;
  
  if v_committee is null then
    return null;
  end if;
  
  -- Get leaders (supports multiple co-equal chairs)
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', l.member_id,
    'name', l.member_name,
    'email', l.email,
    'title', l.title,
    'profile_pictures', l.profile_pictures
  )), '[]'::jsonb) into v_leaders
  from public.get_committee_leaders(p_committee_slug) l;
  
  return v_committee || jsonb_build_object('leaders', v_leaders);
end;
$function$;

-- --- get_distinct_donor_zips(mo_only boolean) ---
CREATE OR REPLACE FUNCTION public.get_distinct_donor_zips(mo_only boolean DEFAULT false)
 RETURNS TABLE(zip5 text, state text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    SELECT DISTINCT sub.zip5, sub.state
    FROM (
        SELECT LEFT(f.zip, 5) AS zip5, f.state
        FROM public.fec_contributions f
        WHERE f.zip IS NOT NULL
          AND f.zip != ''
          AND LENGTH(f.zip) >= 5
          AND LEFT(f.zip, 5) ~ '^\d{5}$'
          AND (NOT mo_only OR f.state = 'MO')
        UNION
        SELECT LEFT(REPLACE(m.zip, '-', ''), 5) AS zip5, m.state
        FROM public.mec_contributions m
        WHERE m.zip IS NOT NULL
          AND m.zip != ''
          AND LENGTH(REPLACE(m.zip, '-', '')) >= 5
          AND LEFT(REPLACE(m.zip, '-', ''), 5) ~ '^\d{5}$'
          AND (NOT mo_only OR m.state = 'MO')
    ) sub
    ORDER BY sub.zip5;
END;
$function$;

-- --- get_district_historical_candidates(p_district text) ---
CREATE OR REPLACE FUNCTION public.get_district_historical_candidates(p_district text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.total_races DESC), '[]'::json)
  FROM (
    SELECT name, party, photo_url, years_ran, total_races
    FROM public.historical_candidates
    WHERE district = p_district
    ORDER BY total_races DESC
    LIMIT 50
  ) t;
$function$;

-- --- get_donor_candidates(p_donor_id integer) ---
CREATE OR REPLACE FUNCTION public.get_donor_candidates(p_donor_id integer)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.total_amount DESC), '[]'::json)
  FROM (
    SELECT
      c.id AS candidate_id,
      c.name,
      c.party,
      c.office,
      c.district,
      c.photo_url,
      mc.committee_name,
      SUM(mc.contribution_amount) AS total_amount,
      COUNT(*) AS contribution_count,
      MAX(mc.contribution_date) AS last_contribution
    FROM public.mec_contributions mc
    JOIN public.candidates c ON mc.mec_id = ANY(c.mec_committee_ids) AND c.election_year = 2026
    WHERE mc.donor_id = p_donor_id
    GROUP BY c.id, c.name, c.party, c.office, c.district, c.photo_url, mc.committee_name
    ORDER BY SUM(mc.contribution_amount) DESC
  ) t;
$function$;

-- --- get_donor_mec_contributions(p_donor_id integer, p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_donor_mec_contributions(p_donor_id integer, p_limit integer DEFAULT 1000)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.contribution_date DESC), '[]'::json)
  FROM (
    SELECT
      mc.mec_id,
      mc.committee_name,
      mc.contribution_amount,
      mc.contribution_date,
      mc.monetary_or_inkind,
      c.name AS candidate_name,
      c.office AS candidate_office,
      c.district AS candidate_district,
      c.party AS candidate_party,
      c.id AS candidate_id
    FROM public.mec_contributions mc
    LEFT JOIN public.candidates c ON mc.mec_id = ANY(c.mec_committee_ids) AND c.election_year = 2026
    WHERE mc.donor_id = p_donor_id
    ORDER BY mc.contribution_date DESC
    LIMIT p_limit
  ) t;
$function$;

-- --- get_donor_profile_stats() ---
CREATE OR REPLACE FUNCTION public.get_donor_profile_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$ DECLARE result JSONB; BEGIN SELECT jsonb_build_object( 'total_profiles', COUNT(*), 'total_raised_moyd', COALESCE(SUM(total_donated_moyd), 0), 'total_raised_political', COALESCE(SUM(total_donated_political), 0), 'average_gift', COALESCE(AVG(average_gift), 0), 'prospect_count', COUNT(*) FILTER (WHERE donor_tier IN ('prospect', 'high_value_prospect')) ) INTO result FROM public.donor_profiles; RETURN result; END; $function$;

-- --- get_election_history_pivoted(p_district text) ---
CREATE OR REPLACE FUNCTION public.get_election_history_pivoted(p_district text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.year DESC), '[]'::json)
  FROM (
    SELECT
      eh.election_year AS year,
      eh.district,
      MAX(CASE WHEN eh.party = 'Democratic' THEN eh.candidate_name END) AS dem_candidate,
      MAX(CASE WHEN eh.party = 'Republican' THEN eh.candidate_name END) AS rep_candidate,
      MAX(CASE WHEN eh.party = 'Democratic' THEN eh.votes END) AS dem_votes,
      MAX(CASE WHEN eh.party = 'Republican' THEN eh.votes END) AS rep_votes,
      SUM(eh.votes) FILTER (WHERE eh.votes IS NOT NULL) AS total_votes,
      CASE
        WHEN COALESCE(MAX(CASE WHEN eh.party = 'Democratic' THEN eh.votes END), 0) >
             COALESCE(MAX(CASE WHEN eh.party = 'Republican' THEN eh.votes END), 0) THEN 'Democratic'
        WHEN COALESCE(MAX(CASE WHEN eh.party = 'Republican' THEN eh.votes END), 0) >
             COALESCE(MAX(CASE WHEN eh.party = 'Democratic' THEN eh.votes END), 0) THEN 'Republican'
        ELSE 'Other'
      END AS winner,
      ROUND(100.0 * MAX(CASE WHEN eh.party = 'Democratic' THEN eh.votes END) / NULLIF(SUM(eh.votes) FILTER (WHERE eh.votes IS NOT NULL), 0), 2) AS dem_percent,
      ROUND(100.0 * MAX(CASE WHEN eh.party = 'Republican' THEN eh.votes END) / NULLIF(SUM(eh.votes) FILTER (WHERE eh.votes IS NOT NULL), 0), 2) AS rep_percent,
      gen_random_uuid()::text AS id
    FROM public.election_history eh
    WHERE eh.district = p_district
      AND eh.party IN ('Democratic', 'Republican')
      AND eh.election_type = 'general'
    GROUP BY eh.election_year, eh.district
    ORDER BY eh.election_year DESC
  ) r;
$function$;

-- --- get_fec_committees_for_candidate(p_fec_cand_id text) ---
CREATE OR REPLACE FUNCTION public.get_fec_committees_for_candidate(p_fec_cand_id text)
 RETURNS TABLE(cmte_id text, cmte_name text, cmte_type text, designation text, party text, cycle smallint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT DISTINCT cmte_id, cmte_name, cmte_type, designation, party, cycle
  FROM public.fec_committees WHERE cand_id = p_fec_cand_id
  ORDER BY cycle DESC, cmte_id;
$function$;

-- --- get_fec_contribution_timeline(p_fec_cand_id text) ---
CREATE OR REPLACE FUNCTION public.get_fec_contribution_timeline(p_fec_cand_id text)
 RETURNS TABLE(month_year text, total numeric, contribution_count integer)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    to_char(date_trunc('month', fc.transaction_date), 'YYYY-MM') AS month_year,
    SUM(fc.transaction_amount)::numeric AS total,
    COUNT(*)::int AS contribution_count
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
    AND fc.transaction_date IS NOT NULL
  GROUP BY date_trunc('month', fc.transaction_date)
  ORDER BY date_trunc('month', fc.transaction_date);
$function$;

-- --- get_fec_finance_summary(p_fec_cand_id text) ---
CREATE OR REPLACE FUNCTION public.get_fec_finance_summary(p_fec_cand_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_raised', COALESCE(SUM(fc.transaction_amount), 0),
    'contribution_count', COUNT(*),
    'avg_contribution', CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(fc.transaction_amount),0) / COUNT(*) ELSE 0 END,
    'unique_donors', COUNT(DISTINCT COALESCE(fc.donor_id::text, fc.contributor_name)),
    'individual_contribs', COUNT(*) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false)),
    'pac_contribs', COUNT(*) FILTER (WHERE COALESCE(fc.is_pac_contribution,false)),
    'individual_total', COALESCE(SUM(fc.transaction_amount) FILTER (WHERE NOT COALESCE(fc.is_pac_contribution,false)), 0),
    'pac_total', COALESCE(SUM(fc.transaction_amount) FILTER (WHERE COALESCE(fc.is_pac_contribution,false)), 0),
    'first_contribution', MIN(fc.transaction_date),
    'last_contribution', MAX(fc.transaction_date),
    'cycles_active', COUNT(DISTINCT fc.cycle),
    'committees_count', COUNT(DISTINCT fc.cmte_id)
  )
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id);
$function$;

-- --- get_fec_recent_contributions(p_fec_cand_id text, p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_fec_recent_contributions(p_fec_cand_id text, p_limit integer DEFAULT 50)
 RETURNS TABLE(contributor_name text, city text, state text, transaction_amount numeric, transaction_date date, employer text, occupation text, is_pac_contribution boolean, committee_name text, cycle smallint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT fc.contributor_name, fc.city, fc.state, fc.transaction_amount, fc.transaction_date,
    fc.employer, fc.occupation, COALESCE(fc.is_pac_contribution,false), fc.committee_name, fc.cycle
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
  ORDER BY fc.transaction_date DESC NULLS LAST
  LIMIT p_limit;
$function$;

-- --- get_fec_top_donors(p_fec_cand_id text, p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_fec_top_donors(p_fec_cand_id text, p_limit integer DEFAULT 10)
 RETURNS TABLE(donor_name text, city text, state text, employer text, occupation text, total_amount numeric, contribution_count integer, donor_id bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name) AS donor_name,
    MAX(fc.city) AS city, MAX(fc.state) AS state,
    MAX(fc.employer) AS employer, MAX(fc.occupation) AS occupation,
    SUM(fc.transaction_amount)::numeric AS total_amount,
    COUNT(*)::int AS contribution_count,
    MAX(fc.donor_id) AS donor_id
  FROM public.fec_contributions fc
  WHERE fc.cmte_id IN (SELECT cmte_id FROM public.fec_committees WHERE cand_id = p_fec_cand_id)
    AND NOT COALESCE(fc.is_pac_contribution, false)
  GROUP BY COALESCE(fc.contributor_name, fc.parsed_last_name || ', ' || fc.parsed_first_name)
  ORDER BY total_amount DESC
  LIMIT p_limit;
$function$;

-- --- get_historical_candidate_profile(p_name text) ---
CREATE OR REPLACE FUNCTION public.get_historical_candidate_profile(p_name text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'candidate', (
      SELECT row_to_json(hc)
      FROM public.historical_candidates hc
      WHERE hc.name = p_name
      LIMIT 1
    ),
    'races', (
      SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.election_year DESC), '[]'::json)
      FROM (
        SELECT election_year, election_type, office, district, votes, vote_percentage, winner, source
        FROM public.election_history
        WHERE candidate_name = p_name
        ORDER BY election_year DESC
      ) r
    ),
    'finance', (
      SELECT COALESCE(json_agg(row_to_json(f)), '[]'::json)
      FROM (
        SELECT mc.mec_id, mc.committee_name,
          (SELECT SUM(contribution_amount) FROM public.mec_contributions WHERE mec_id = mc.mec_id) AS total_raised,
          (SELECT COUNT(*) FROM public.mec_contributions WHERE mec_id = mc.mec_id) AS contribution_count
        FROM public.mec_committees mc
        WHERE mc.committee_name ILIKE '%' || split_part(p_name, ' ', array_length(string_to_array(p_name, ' '), 1)) || ' for%'
        LIMIT 5
      ) f
    )
  );
$function$;

-- --- get_job_notification_template(p_trigger_type job_notification_trigger, p_recipient_type job_notification_recipient) ---
CREATE OR REPLACE FUNCTION public.get_job_notification_template(p_trigger_type job_notification_trigger, p_recipient_type job_notification_recipient)
 RETURNS job_notification_templates
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_template public.job_notification_templates;
BEGIN
    SELECT * INTO v_template
    FROM public.job_notification_templates
    WHERE trigger_type = p_trigger_type
      AND recipient_type = p_recipient_type
      AND is_active = true
      AND is_default = true
    LIMIT 1;
    
    IF v_template IS NULL THEN
        SELECT * INTO v_template
        FROM public.job_notification_templates
        WHERE trigger_type = p_trigger_type
          AND recipient_type = p_recipient_type
          AND is_active = true
        ORDER BY updated_at DESC
        LIMIT 1;
    END IF;
    
    RETURN v_template;
END;
$function$;

-- --- get_legislation_statistics(session_filter text) ---
CREATE OR REPLACE FUNCTION public.get_legislation_statistics(session_filter text DEFAULT NULL::text)
 RETURNS TABLE(total_tracked bigint, support_count bigint, oppose_count bigint, watching_count bigint, critical_count bigint, high_count bigint, passed_lower_count bigint, passed_upper_count bigint, signed_count bigint, vetoed_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::bigint as total_tracked,
    COUNT(*) FILTER (WHERE position = 'support')::bigint as support_count,
    COUNT(*) FILTER (WHERE position = 'oppose')::bigint as oppose_count,
    COUNT(*) FILTER (WHERE position = 'watching')::bigint as watching_count,
    COUNT(*) FILTER (WHERE priority = 'critical')::bigint as critical_count,
    COUNT(*) FILTER (WHERE priority = 'high')::bigint as high_count,
    COUNT(*) FILTER (WHERE passed_lower = true)::bigint as passed_lower_count,
    COUNT(*) FILTER (WHERE passed_upper = true)::bigint as passed_upper_count,
    COUNT(*) FILTER (WHERE signed_by_governor = true)::bigint as signed_count,
    COUNT(*) FILTER (WHERE vetoed = true)::bigint as vetoed_count
  FROM public.legislation_tracked_bills
  WHERE is_archived = false
    AND (session_filter IS NULL OR session = session_filter);
END;
$function$;

-- --- get_listmonk_sync_stats() ---
CREATE OR REPLACE FUNCTION public.get_listmonk_sync_stats()
 RETURNS TABLE(members_count integer, donors_count integer, event_attendees_count integer, public_subscribers_count integer, listmonk_subscribers_count integer, newsletter_list_count integer, donors_list_count integer, members_list_count integer, event_attendees_list_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::INT FROM public.members WHERE email IS NOT NULL),
    (SELECT COUNT(*)::INT FROM public.donors WHERE email IS NOT NULL),
    (SELECT COUNT(*)::INT FROM public.event_attendees WHERE guest_email IS NOT NULL OR member_id IS NOT NULL),
    (SELECT COUNT(*)::INT FROM public.subscribers WHERE email IS NOT NULL),
    (SELECT COUNT(*)::INT FROM listmonk.subscribers),
    (SELECT COUNT(*)::INT FROM listmonk.subscriber_lists WHERE list_id = 3),
    (SELECT COUNT(*)::INT FROM listmonk.subscriber_lists WHERE list_id = 4),
    (SELECT COUNT(*)::INT FROM listmonk.subscriber_lists WHERE list_id = 5),
    (SELECT COUNT(*)::INT FROM listmonk.subscriber_lists WHERE list_id = 6);
END;
$function$;

-- --- get_mec_contribution_timeline(p_mec_id text) ---
CREATE OR REPLACE FUNCTION public.get_mec_contribution_timeline(p_mec_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.month), '[]'::json)
  FROM (
    SELECT
      TO_CHAR(contribution_date, 'YYYY-MM') as month,
      SUM(contribution_amount) as total,
      COUNT(*) as count
    FROM public.mec_contributions
    WHERE mec_id = p_mec_id AND contribution_date IS NOT NULL
    GROUP BY TO_CHAR(contribution_date, 'YYYY-MM')
    ORDER BY month
  ) t;
$function$;

-- --- get_mec_contribution_timeline_multi(p_mec_ids text[]) ---
CREATE OR REPLACE FUNCTION public.get_mec_contribution_timeline_multi(p_mec_ids text[])
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.month), '[]'::json)
  FROM (
    SELECT
      TO_CHAR(contribution_date, 'YYYY-MM') as month,
      SUM(contribution_amount) as total,
      COUNT(*) as count
    FROM public.mec_contributions
    WHERE mec_id = ANY(p_mec_ids) AND contribution_date IS NOT NULL
    GROUP BY TO_CHAR(contribution_date, 'YYYY-MM')
    ORDER BY month
  ) t;
$function$;

-- --- get_mec_expenditure_summary(p_mec_id text) ---
CREATE OR REPLACE FUNCTION public.get_mec_expenditure_summary(p_mec_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_spent', COALESCE(SUM(expenditure_amount), 0),
    'expenditure_count', COUNT(*),
    'avg_expenditure', CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(expenditure_amount), 0) / COUNT(*) ELSE 0 END,
    'first_expenditure', MIN(expenditure_date),
    'last_expenditure', MAX(expenditure_date),
    'unique_payees', COUNT(DISTINCT CONCAT(payee_last_name, '|', payee_first_name, '|', payee_company)),
    'by_purpose', (
      SELECT COALESCE(json_agg(row_to_json(bp) ORDER BY bp.total DESC), '[]'::json)
      FROM (
        SELECT
          COALESCE(NULLIF(TRIM(expenditure_purpose), ''), 'Unspecified') as purpose,
          SUM(expenditure_amount) as total,
          COUNT(*) as count
        FROM public.mec_expenditures
        WHERE mec_id = p_mec_id
        GROUP BY COALESCE(NULLIF(TRIM(expenditure_purpose), ''), 'Unspecified')
        ORDER BY SUM(expenditure_amount) DESC
      ) bp
    ),
    'by_type', (
      SELECT COALESCE(json_agg(row_to_json(bt) ORDER BY bt.total DESC), '[]'::json)
      FROM (
        SELECT
          COALESCE(NULLIF(TRIM(expenditure_type), ''), 'Other') as type,
          SUM(expenditure_amount) as total,
          COUNT(*) as count
        FROM public.mec_expenditures
        WHERE mec_id = p_mec_id
        GROUP BY COALESCE(NULLIF(TRIM(expenditure_type), ''), 'Other')
        ORDER BY SUM(expenditure_amount) DESC
      ) bt
    )
  )
  FROM public.mec_expenditures
  WHERE mec_id = p_mec_id;
$function$;

-- --- get_mec_expenditure_summary_multi(p_mec_ids text[]) ---
CREATE OR REPLACE FUNCTION public.get_mec_expenditure_summary_multi(p_mec_ids text[])
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_spent', COALESCE(SUM(expenditure_amount), 0),
    'expenditure_count', COUNT(*),
    'avg_expenditure', CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(expenditure_amount), 0) / COUNT(*) ELSE 0 END,
    'first_expenditure', MIN(expenditure_date),
    'last_expenditure', MAX(expenditure_date),
    'unique_payees', COUNT(DISTINCT CONCAT(payee_last_name, '|', payee_first_name, '|', payee_company)),
    'by_purpose', (
      SELECT COALESCE(json_agg(row_to_json(bp) ORDER BY bp.total DESC), '[]'::json)
      FROM (
        SELECT
          COALESCE(NULLIF(TRIM(expenditure_purpose), ''), 'Unspecified') as purpose,
          SUM(expenditure_amount) as total,
          COUNT(*) as count
        FROM public.mec_expenditures
        WHERE mec_id = ANY(p_mec_ids)
        GROUP BY COALESCE(NULLIF(TRIM(expenditure_purpose), ''), 'Unspecified')
        ORDER BY SUM(expenditure_amount) DESC
      ) bp
    ),
    'by_type', (
      SELECT COALESCE(json_agg(row_to_json(bt) ORDER BY bt.total DESC), '[]'::json)
      FROM (
        SELECT
          COALESCE(NULLIF(TRIM(expenditure_type), ''), 'Other') as type,
          SUM(expenditure_amount) as total,
          COUNT(*) as count
        FROM public.mec_expenditures
        WHERE mec_id = ANY(p_mec_ids)
        GROUP BY COALESCE(NULLIF(TRIM(expenditure_type), ''), 'Other')
        ORDER BY SUM(expenditure_amount) DESC
      ) bt
    )
  )
  FROM public.mec_expenditures
  WHERE mec_id = ANY(p_mec_ids);
$function$;

-- --- get_mec_finance_summary(p_mec_id text) ---
CREATE OR REPLACE FUNCTION public.get_mec_finance_summary(p_mec_id text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_raised', COALESCE(SUM(contribution_amount), 0),
    'contribution_count', COUNT(*),
    'monetary_total', COALESCE(SUM(CASE WHEN LOWER(COALESCE(monetary_or_inkind,'')) NOT LIKE '%in%kind%' AND LOWER(COALESCE(monetary_or_inkind,'')) NOT LIKE '%inkind%' THEN contribution_amount ELSE 0 END), 0),
    'in_kind_total', COALESCE(SUM(CASE WHEN LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%in%kind%' OR LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%inkind%' THEN contribution_amount ELSE 0 END), 0),
    'in_kind_count', COUNT(*) FILTER (WHERE LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%in%kind%' OR LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%inkind%'),
    'avg_contribution', CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(contribution_amount), 0) / COUNT(*) ELSE 0 END,
    'first_contribution', MIN(contribution_date),
    'last_contribution', MAX(contribution_date),
    'unique_donors', COUNT(DISTINCT CONCAT(contributor_last_name, '|', contributor_first_name))
  )
  FROM public.mec_contributions
  WHERE mec_id = p_mec_id;
$function$;

-- --- get_mec_finance_summary_multi(p_mec_ids text[]) ---
CREATE OR REPLACE FUNCTION public.get_mec_finance_summary_multi(p_mec_ids text[])
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT json_build_object(
    'total_raised', COALESCE(SUM(contribution_amount), 0),
    'contribution_count', COUNT(*),
    'monetary_total', COALESCE(SUM(CASE WHEN LOWER(COALESCE(monetary_or_inkind,'')) NOT LIKE '%in%kind%' AND LOWER(COALESCE(monetary_or_inkind,'')) NOT LIKE '%inkind%' THEN contribution_amount ELSE 0 END), 0),
    'in_kind_total', COALESCE(SUM(CASE WHEN LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%in%kind%' OR LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%inkind%' THEN contribution_amount ELSE 0 END), 0),
    'in_kind_count', COUNT(*) FILTER (WHERE LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%in%kind%' OR LOWER(COALESCE(monetary_or_inkind,'')) LIKE '%inkind%'),
    'avg_contribution', CASE WHEN COUNT(*) > 0 THEN COALESCE(SUM(contribution_amount), 0) / COUNT(*) ELSE 0 END,
    'first_contribution', MIN(contribution_date),
    'last_contribution', MAX(contribution_date),
    'unique_donors', COUNT(DISTINCT CONCAT(contributor_last_name, '|', contributor_first_name)),
    'committees_included', COALESCE(array_length(p_mec_ids, 1), 0)
  )
  FROM public.mec_contributions
  WHERE mec_id = ANY(p_mec_ids);
$function$;

-- --- get_mec_top_donors(p_mec_id text, p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_mec_top_donors(p_mec_id text, p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      TRIM(CONCAT(contributor_first_name, ' ', contributor_last_name)) as donor_name,
      contributor_first_name as first_name,
      contributor_last_name  as last_name,
      COALESCE(contributor_company, '') as company,
      COALESCE(city, '') as city,
      COALESCE(state, '') as state,
      SUM(contribution_amount) as total_amount,
      COUNT(*) as contribution_count,
      MAX(contribution_date) as last_contribution
    FROM public.mec_contributions
    WHERE mec_id = p_mec_id
    GROUP BY contributor_first_name, contributor_last_name, contributor_company, city, state
    ORDER BY SUM(contribution_amount) DESC
    LIMIT p_limit
  ) t;
$function$;

-- --- get_mec_top_donors_multi(p_mec_ids text[], p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_mec_top_donors_multi(p_mec_ids text[], p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      TRIM(CONCAT(contributor_first_name, ' ', contributor_last_name)) as donor_name,
      contributor_first_name as first_name,
      contributor_last_name  as last_name,
      COALESCE(contributor_company, '') as company,
      COALESCE(city, '') as city,
      COALESCE(state, '') as state,
      SUM(contribution_amount) as total_amount,
      COUNT(*) as contribution_count,
      MAX(contribution_date) as last_contribution
    FROM public.mec_contributions
    WHERE mec_id = ANY(p_mec_ids)
    GROUP BY contributor_first_name, contributor_last_name, contributor_company, city, state
    ORDER BY SUM(contribution_amount) DESC
    LIMIT p_limit
  ) t;
$function$;

-- --- get_mec_top_payees(p_mec_id text, p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_mec_top_payees(p_mec_id text, p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      CASE
        WHEN payee_company IS NOT NULL AND TRIM(payee_company) != '' THEN TRIM(payee_company)
        ELSE TRIM(CONCAT(payee_first_name, ' ', payee_last_name))
      END AS payee_name,
      TRIM(COALESCE(payee_first_name, '')) AS payee_first_name,
      TRIM(COALESCE(payee_last_name,  '')) AS payee_last_name,
      TRIM(COALESCE(payee_company,    '')) AS payee_company,
      COALESCE(city, '') AS city,
      COALESCE(state, '') AS state,
      SUM(expenditure_amount) AS total_amount,
      COUNT(*) AS payment_count,
      MAX(expenditure_date) AS last_payment
    FROM public.mec_expenditures
    WHERE mec_id = p_mec_id
    GROUP BY 1, 2, 3, 4, 5, 6
    ORDER BY SUM(expenditure_amount) DESC NULLS LAST
    LIMIT p_limit
  ) t;
$function$;

-- --- get_mec_top_payees_multi(p_mec_ids text[], p_limit integer) ---
CREATE OR REPLACE FUNCTION public.get_mec_top_payees_multi(p_mec_ids text[], p_limit integer DEFAULT 50)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
  FROM (
    SELECT
      CASE
        WHEN payee_company IS NOT NULL AND TRIM(payee_company) != '' THEN TRIM(payee_company)
        ELSE TRIM(CONCAT(payee_first_name, ' ', payee_last_name))
      END AS payee_name,
      TRIM(COALESCE(payee_first_name, '')) AS payee_first_name,
      TRIM(COALESCE(payee_last_name,  '')) AS payee_last_name,
      TRIM(COALESCE(payee_company,    '')) AS payee_company,
      COALESCE(city, '') AS city,
      COALESCE(state, '') AS state,
      SUM(expenditure_amount) AS total_amount,
      COUNT(*) AS payment_count,
      MAX(expenditure_date) AS last_payment
    FROM public.mec_expenditures
    WHERE mec_id = ANY(p_mec_ids)
    GROUP BY 1, 2, 3, 4, 5, 6
    ORDER BY SUM(expenditure_amount) DESC NULLS LAST
    LIMIT p_limit
  ) t;
$function$;

-- --- get_meeting_attendance_summary(meeting_uuid uuid) ---
CREATE OR REPLACE FUNCTION public.get_meeting_attendance_summary(meeting_uuid uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'meeting_id', m.id,
    'meeting_title', m.meeting_title,
    'meeting_date', m.meeting_date,
    'attendance_count', m.attendance_count,
    'attendees', (
      SELECT json_agg(
        json_build_object(
          'member_id', mem.id,
          'member_name', mem.name,
          'member_email', mem.email,
          'duration_minutes', ma.total_duration_minutes,
          'join_time', ma.first_join_time,
          'leave_time', ma.last_leave_time,
          'number_of_joins', ma.number_of_joins
        )
      )
      FROM meeting_attendance ma
      JOIN members mem ON mem.id = ma.member_id
      WHERE ma.meeting_id = m.id
    )
  ) INTO result
  FROM meetings m
  WHERE m.id = meeting_uuid;
  
  RETURN result;
END;
$function$;

-- --- get_or_create_committee_board(p_committee_id uuid) ---
CREATE OR REPLACE FUNCTION public.get_or_create_committee_board(p_committee_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_board_id UUID;
BEGIN
  -- Try to find existing board for this committee
  SELECT id INTO v_board_id
  FROM public.canvas_boards
  WHERE committee_id = p_committee_id
  LIMIT 1;
  
  -- If no board exists, create one
  IF v_board_id IS NULL THEN
    INSERT INTO public.canvas_boards (
      committee_id, 
      created_by,
      last_modified_by
    )
    VALUES (
      p_committee_id, 
      auth.uid(),
      auth.uid()
    )
    RETURNING id INTO v_board_id;
  END IF;
  
  RETURN v_board_id;
END;
$function$;

-- --- get_payee_profile_by_natural_key(p_first_name text, p_last_name text, p_company text, p_city text, p_state text) ---
CREATE OR REPLACE FUNCTION public.get_payee_profile_by_natural_key(p_first_name text DEFAULT NULL::text, p_last_name text DEFAULT NULL::text, p_company text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_state text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  WITH payee_exp AS (
    SELECT me.id, me.mec_id, me.committee_name, me.expenditure_amount,
           me.expenditure_date, me.expenditure_purpose, me.expenditure_type,
           me.payee_last_name, me.payee_first_name, me.payee_company,
           me.city AS payee_city, me.state AS payee_state
    FROM public.mec_expenditures me
    WHERE
      -- Individual path: last+first name match
      (
        p_last_name IS NOT NULL AND p_last_name <> ''
        AND lower(trim(coalesce(me.payee_last_name,'')))  = lower(trim(p_last_name))
        AND lower(trim(coalesce(me.payee_first_name,''))) = lower(trim(coalesce(p_first_name,'')))
      )
      OR
      -- Company path: company match
      (
        p_company IS NOT NULL AND p_company <> ''
        AND lower(trim(coalesce(me.payee_company,''))) = lower(trim(p_company))
      )
      -- Optional city/state scoping
      AND (p_city  IS NULL OR p_city  = '' OR lower(trim(coalesce(me.city,'')))  = lower(trim(p_city)))
      AND (p_state IS NULL OR p_state = '' OR lower(trim(coalesce(me.state,''))) = lower(trim(p_state)))
  ),
  committee_to_candidate AS (
    SELECT DISTINCT ON (pe.mec_id)
      pe.mec_id, c.id AS candidate_id, c.name AS candidate_name, c.party AS candidate_party
    FROM payee_exp pe
    LEFT JOIN public.candidates c ON pe.mec_id = ANY(c.mec_committee_ids)
    ORDER BY pe.mec_id, c.updated_at DESC NULLS LAST
  ),
  enriched AS (
    SELECT pe.*, ctc.candidate_id, ctc.candidate_name, ctc.candidate_party
    FROM payee_exp pe
    LEFT JOIN committee_to_candidate ctc ON ctc.mec_id = pe.mec_id
  ),
  by_committee AS (
    SELECT mec_id, MAX(committee_name) AS committee_name,
           SUM(expenditure_amount) AS total, COUNT(*) AS count,
           MIN(expenditure_date) AS first_paid, MAX(expenditure_date) AS last_paid
    FROM payee_exp GROUP BY mec_id
  ),
  by_candidate AS (
    SELECT candidate_id, candidate_name, candidate_party,
           SUM(expenditure_amount) AS total, COUNT(*) AS count
    FROM enriched
    WHERE candidate_id IS NOT NULL
    GROUP BY candidate_id, candidate_name, candidate_party
  ),
  by_purpose AS (
    SELECT COALESCE(NULLIF(expenditure_purpose,''), '(unspecified)') AS purpose,
           SUM(expenditure_amount) AS total, COUNT(*) AS count
    FROM payee_exp
    GROUP BY COALESCE(NULLIF(expenditure_purpose,''), '(unspecified)')
  )
  SELECT json_build_object(
    'first_name', p_first_name,
    'last_name',  p_last_name,
    'company',    p_company,
    'city',       p_city,
    'state',      p_state,
    'total_paid',         COALESCE((SELECT SUM(expenditure_amount) FROM payee_exp), 0),
    'expenditure_count',  (SELECT COUNT(*) FROM payee_exp),
    'first_payment',      (SELECT MIN(expenditure_date) FROM payee_exp),
    'last_payment',       (SELECT MAX(expenditure_date) FROM payee_exp),
    'unique_committees',  (SELECT COUNT(*) FROM by_committee),
    'unique_candidates',  (SELECT COUNT(*) FROM by_candidate),
    'display_city',       (SELECT MAX(payee_city)  FROM payee_exp WHERE payee_city  IS NOT NULL AND payee_city  <> ''),
    'display_state',      (SELECT MAX(payee_state) FROM payee_exp WHERE payee_state IS NOT NULL AND payee_state <> ''),
    'by_committee',   (SELECT COALESCE(json_agg(row_to_json(b) ORDER BY b.total DESC), '[]'::json) FROM by_committee b),
    'by_candidate',   (SELECT COALESCE(json_agg(row_to_json(b) ORDER BY b.total DESC), '[]'::json) FROM by_candidate b),
    'by_purpose',     (SELECT COALESCE(json_agg(row_to_json(b) ORDER BY b.total DESC), '[]'::json) FROM by_purpose b),
    'recent_expenditures', (SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.expenditure_date DESC NULLS LAST), '[]'::json)
                            FROM (
                              SELECT expenditure_date, expenditure_amount, expenditure_purpose, expenditure_type,
                                     mec_id, committee_name, candidate_name
                              FROM enriched
                              ORDER BY expenditure_date DESC NULLS LAST
                              LIMIT 100
                            ) t)
  );
$function$;

-- --- get_race_finance_comparison(p_office text, p_district text) ---
CREATE OR REPLACE FUNCTION public.get_race_finance_comparison(p_office text, p_district text)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
  WITH per_candidate AS (
    SELECT
      c.id as candidate_id,
      c.name, c.party, c.photo_url, c.estimated_age,
      c.mec_committee_ids, c.fec_candidate_id, c.incumbent,
      COALESCE((
        SELECT SUM(mc.contribution_amount) FROM public.mec_contributions mc
        WHERE c.mec_committee_ids IS NOT NULL AND array_length(c.mec_committee_ids, 1) > 0
          AND mc.mec_id = ANY(c.mec_committee_ids)
      ), 0) as mec_raised,
      COALESCE((
        SELECT COUNT(*) FROM public.mec_contributions mc
        WHERE c.mec_committee_ids IS NOT NULL AND array_length(c.mec_committee_ids, 1) > 0
          AND mc.mec_id = ANY(c.mec_committee_ids)
      ), 0) as mec_count,
      COALESCE((
        SELECT SUM(fc.transaction_amount) FROM public.fec_contributions fc
        JOIN public.fec_candidates fcand ON fcand.cand_id = c.fec_candidate_id
        WHERE c.fec_candidate_id IS NOT NULL AND c.fec_candidate_id <> ''
          AND fc.cmte_id = fcand.principal_committee_id
      ), 0) as fec_raised,
      COALESCE((
        SELECT COUNT(*) FROM public.fec_contributions fc
        JOIN public.fec_candidates fcand ON fcand.cand_id = c.fec_candidate_id
        WHERE c.fec_candidate_id IS NOT NULL AND c.fec_candidate_id <> ''
          AND fc.cmte_id = fcand.principal_committee_id
      ), 0) as fec_count,
      COALESCE((
        SELECT SUM(me.expenditure_amount) FROM public.mec_expenditures me
        WHERE me.mec_id = ANY(COALESCE(c.mec_committee_ids, ARRAY[]::text[]))
      ), 0) as total_spent,
      (SELECT count(*) FROM public.candidate_news cn WHERE cn.candidate_id = c.id) as news_count,
      c.endorsements IS NOT NULL AND c.endorsements <> '' as has_endorsements
    FROM public.candidates c
    WHERE c.office = p_office AND c.district = p_district
  )
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.total_raised DESC), '[]'::json)
  FROM (
    SELECT
      candidate_id, name, party, photo_url, estimated_age, incumbent,
      mec_committee_ids, fec_candidate_id,
      GREATEST(mec_raised, fec_raised) as total_raised,
      GREATEST(mec_count, fec_count) as contribution_count,
      CASE WHEN fec_raised > mec_raised THEN 'FEC' ELSE 'MEC' END as source,
      total_spent, news_count, has_endorsements,
      (mec_committee_ids IS NULL OR array_length(mec_committee_ids, 1) IS NULL)
        AND (fec_candidate_id IS NULL OR fec_candidate_id = '') as no_committee_linked
    FROM per_candidate
  ) t;
$function$;

-- --- get_total_api_calls_remaining() ---
CREATE OR REPLACE FUNCTION public.get_total_api_calls_remaining()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  remaining INT;
BEGIN
  SELECT COALESCE(SUM(calls_limit - calls_today), 0)
  INTO remaining
  FROM public.legislation_api_keys
  WHERE is_active = TRUE 
    AND is_rate_limited = FALSE;
  
  RETURN remaining;
END;
$function$;

-- --- get_user_valid_committees(user_email text) ---
CREATE OR REPLACE FUNCTION public.get_user_valid_committees(user_email text)
 RETURNS TABLE(committee_id uuid, committee_name text, committee_slug text, committee_tools jsonb, committee_color text, committee_icon text, committee_description text, workspace_enabled boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  member_committees text[];
BEGIN
  -- Get the member's committee array by checking both email and school_email
  SELECT m.committee INTO member_committees
  FROM public.members m
  WHERE m.email = user_email OR m.school_email = user_email
  LIMIT 1;
  
  -- If no member found or no committees, return empty
  IF member_committees IS NULL OR array_length(member_committees, 1) IS NULL THEN
    RETURN;
  END IF;
  
  -- Return committees that match member's committees AND have workspace_enabled = true
  RETURN QUERY
  SELECT 
    c.id AS committee_id,
    c.name AS committee_name,
    c.slug AS committee_slug,
    c.tools AS committee_tools,
    c.color AS committee_color,
    c.icon AS committee_icon,
    c.description AS committee_description,
    c.workspace_enabled
  FROM public.committees c
  WHERE c.name = ANY(member_committees)
    AND c.workspace_enabled = true
    AND c.is_active = true;
END;
$function$;

-- --- increment_job_view_count() ---
DROP FUNCTION IF EXISTS public.increment_job_view_count();
CREATE OR REPLACE FUNCTION public.increment_job_view_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE jobs 
  SET view_count = view_count + 1
  WHERE id = NEW.job_id;
  RETURN NEW;
END;
$function$;

-- --- increment_job_view_count(job_id uuid) ---
DROP FUNCTION IF EXISTS public.increment_job_view_count(job_id uuid);
CREATE OR REPLACE FUNCTION public.increment_job_view_count(job_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.jobs
  SET view_count = COALESCE(view_count, 0) + 1
  WHERE id = job_id;
END;
$function$;

-- --- increment_talking_points_copy(bill_uuid uuid) ---
CREATE OR REPLACE FUNCTION public.increment_talking_points_copy(bill_uuid uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$ BEGIN UPDATE public.legislation_tracked_bills SET talking_points_copy_count = COALESCE(talking_points_copy_count, 0) + 1 WHERE id = bill_uuid; END; $function$;

-- --- increment_talking_points_share(bill_uuid uuid, platform text) ---
CREATE OR REPLACE FUNCTION public.increment_talking_points_share(bill_uuid uuid, platform text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$ BEGIN UPDATE public.legislation_tracked_bills SET talking_points_share_count = COALESCE(talking_points_share_count, 0) + 1 WHERE id = bill_uuid; END; $function$;

-- --- increment_template_use_count(template_id uuid) ---
CREATE OR REPLACE FUNCTION public.increment_template_use_count(template_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$ BEGIN UPDATE public.form_templates SET use_count = COALESCE(use_count, 0) + 1 WHERE id = template_id; END; $function$;

-- --- install_knowledge_trigger(p_table_name text, p_schema_name text) ---
CREATE OR REPLACE FUNCTION public.install_knowledge_trigger(p_table_name text, p_schema_name text DEFAULT 'public'::text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_trigger_name TEXT;
  v_delete_trigger_name TEXT;
BEGIN
  v_trigger_name := 'knowledge_sync_' || p_table_name;
  v_delete_trigger_name := 'knowledge_delete_' || p_table_name;
  
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', v_trigger_name, p_schema_name, p_table_name);
  EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I', v_delete_trigger_name, p_schema_name, p_table_name);
  
  EXECUTE format(
    'CREATE TRIGGER %I AFTER INSERT OR UPDATE ON %I.%I FOR EACH ROW EXECUTE FUNCTION public.sync_table_to_knowledge()',
    v_trigger_name, p_schema_name, p_table_name
  );
  
  EXECUTE format(
    'CREATE TRIGGER %I AFTER DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION public.remove_from_knowledge_on_delete()',
    v_delete_trigger_name, p_schema_name, p_table_name
  );
  
  UPDATE public.knowledge_table_config
  SET trigger_installed = true, updated_at = NOW()
  WHERE table_name = p_table_name AND schema_name = p_schema_name;
  
  RETURN true;
END;
$function$;

-- --- is_member_donor(member_uuid uuid) ---
CREATE OR REPLACE FUNCTION public.is_member_donor(member_uuid uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM donors 
    WHERE member_id = member_uuid 
      AND donation_count > 0
  );
END;
$function$;

-- --- link_bill_sponsor_to_legislator() ---
CREATE OR REPLACE FUNCTION public.link_bill_sponsor_to_legislator()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Only try to link if entity_type is 'person' and legislator_id is not already set
  IF NEW.entity_type = 'person' AND NEW.legislator_id IS NULL THEN
    
    -- First priority: Match by openstates_person_id (most reliable)
    IF NEW.openstates_person_id IS NOT NULL THEN
      SELECT id INTO NEW.legislator_id
      FROM public.legislation_legislators
      WHERE openstates_person_id = NEW.openstates_person_id
      LIMIT 1;
    END IF;
    
    -- Second priority: Match by chamber + district (if still no match)
    IF NEW.legislator_id IS NULL AND NEW.chamber IS NOT NULL AND NEW.district IS NOT NULL THEN
      SELECT id INTO NEW.legislator_id
      FROM public.legislation_legislators
      WHERE chamber = NEW.chamber 
        AND district = NEW.district
        AND is_current = true
      LIMIT 1;
    END IF;
    
    -- Third priority: Match by name (case-insensitive, only if still no match)
    IF NEW.legislator_id IS NULL AND NEW.name IS NOT NULL THEN
      SELECT id INTO NEW.legislator_id
      FROM public.legislation_legislators
      WHERE LOWER(TRIM(name)) = LOWER(TRIM(NEW.name))
        AND is_current = true
      LIMIT 1;
    END IF;
    
  END IF;
  
  -- Now auto-populate linked_member_id from the legislator if we have a legislator_id
  IF NEW.legislator_id IS NOT NULL AND NEW.linked_member_id IS NULL THEN
    SELECT linked_member_id INTO NEW.linked_member_id
    FROM public.legislation_legislators
    WHERE id = NEW.legislator_id
      AND linked_member_id IS NOT NULL;
  END IF;
  
  -- Also try to match linked_member_id directly by name if still null
  IF NEW.linked_member_id IS NULL AND NEW.entity_type = 'person' AND NEW.name IS NOT NULL THEN
    SELECT id INTO NEW.linked_member_id
    FROM public.members
    WHERE LOWER(TRIM(name)) = LOWER(TRIM(NEW.name))
    LIMIT 1;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- link_hanaway_campaign_participant(p_email text, p_name text, p_zip_code text) ---
CREATE OR REPLACE FUNCTION public.link_hanaway_campaign_participant(p_email text, p_name text, p_zip_code text DEFAULT NULL::text)
 RETURNS TABLE(subscriber_id uuid, member_id uuid, donor_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_subscriber_id UUID;
  v_member_id UUID;
  v_donor_id UUID;
  v_existing_subscriber RECORD;
BEGIN
  -- Normalize email
  p_email := LOWER(TRIM(p_email));
  
  -- Check if subscriber already exists
  SELECT * INTO v_existing_subscriber
  FROM subscribers
  WHERE email = p_email;
  
  IF v_existing_subscriber.id IS NOT NULL THEN
    -- Subscriber exists
    v_subscriber_id := v_existing_subscriber.id;
    v_member_id := v_existing_subscriber.member_id;
    v_donor_id := v_existing_subscriber.donor_id;
    
    -- Update subscriber with new info if provided
    UPDATE subscribers
    SET 
      name = COALESCE(p_name, name),
      zip_code = COALESCE(p_zip_code, zip_code),
      updated_at = NOW(),
      source = 'hanaway-campaign'
    WHERE id = v_subscriber_id;
    
  ELSE
    -- Check if member exists with this email
    SELECT id INTO v_member_id
    FROM members
    WHERE email = p_email
    LIMIT 1;
    
    -- Check if donor exists with this email
    SELECT id INTO v_donor_id
    FROM donors
    WHERE email = p_email
    LIMIT 1;
    
    -- Create new subscriber
    INSERT INTO subscribers (
      email,
      name,
      zip_code,
      subscription_status,
      source,
      member_id,
      donor_id,
      optin_date
    ) VALUES (
      p_email,
      p_name,
      p_zip_code,
      'subscribed',
      'hanaway-campaign',
      v_member_id,
      v_donor_id,
      NOW()
    )
    RETURNING id INTO v_subscriber_id;
  END IF;
  
  -- Return the IDs
  RETURN QUERY SELECT v_subscriber_id, v_member_id, v_donor_id;
END;
$function$;

-- --- link_recipients_to_subscribers(p_campaign_id uuid) ---
CREATE OR REPLACE FUNCTION public.link_recipients_to_subscribers(p_campaign_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(updated_count integer, unmatched_count integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_updated INT := 0;
  v_unmatched INT := 0;
BEGIN
  -- Update subscriber_id for recipients where email matches
  WITH updated AS (
    UPDATE public.email_campaign_recipients ecr
    SET subscriber_id = s.id,
        updated_at = NOW()
    FROM public.subscribers s
    WHERE LOWER(ecr.email) = LOWER(s.email)
    AND ecr.subscriber_id IS NULL
    AND (p_campaign_id IS NULL OR ecr.campaign_id = p_campaign_id)
    RETURNING ecr.id
  )
  SELECT COUNT(*) INTO v_updated FROM updated;
  
  -- Count unmatched
  SELECT COUNT(*) INTO v_unmatched
  FROM public.email_campaign_recipients ecr
  WHERE ecr.subscriber_id IS NULL
  AND (p_campaign_id IS NULL OR ecr.campaign_id = p_campaign_id);
  
  RETURN QUERY SELECT v_updated, v_unmatched;
END;
$function$;

-- --- link_sponsors_to_legislators() ---
CREATE OR REPLACE FUNCTION public.link_sponsors_to_legislators()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  linked_count INT;
BEGIN
  UPDATE public.legislation_bill_sponsors lbs
  SET legislator_id = ll.id
  FROM public.legislation_legislators ll
  WHERE lbs.legislator_id IS NULL
    AND lbs.openstates_person_id IS NOT NULL
    AND lbs.openstates_person_id = ll.openstates_person_id;
  
  GET DIAGNOSTICS linked_count = ROW_COUNT;
  
  -- Mark bills as sponsor-linked
  UPDATE public.legislation_bill_sync_status bss
  SET 
    needs_sponsor_link = FALSE,
    last_sponsor_link_at = NOW(),
    updated_at = NOW()
  WHERE needs_sponsor_link = TRUE
    AND NOT EXISTS (
      SELECT 1 FROM public.legislation_bill_sponsors lbs 
      WHERE lbs.bill_id = bss.bill_id 
      AND lbs.legislator_id IS NULL
      AND lbs.openstates_person_id IS NOT NULL
    );
  
  RETURN linked_count;
END;
$function$;

-- --- log_api_key_call(p_key_id integer, p_success boolean, p_was_rate_limited boolean) ---
CREATE OR REPLACE FUNCTION public.log_api_key_call(p_key_id integer, p_success boolean, p_was_rate_limited boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.legislation_api_keys
  SET 
    calls_today = calls_today + 1,
    total_calls = total_calls + 1,
    total_successes = CASE WHEN p_success THEN total_successes + 1 ELSE total_successes END,
    total_errors = CASE WHEN NOT p_success THEN total_errors + 1 ELSE total_errors END,
    last_call_at = NOW(),
    consecutive_429s = CASE 
      WHEN p_was_rate_limited THEN consecutive_429s + 1 
      WHEN p_success THEN 0 
      ELSE consecutive_429s 
    END,
    is_rate_limited = CASE WHEN p_was_rate_limited THEN TRUE ELSE is_rate_limited END,
    rate_limited_until = CASE 
      WHEN p_was_rate_limited THEN NOW() + interval '1 hour' 
      ELSE rate_limited_until 
    END,
    updated_at = NOW()
  WHERE id = p_key_id;
END;
$function$;

-- --- manual_refresh_dashboard_metrics() ---
CREATE OR REPLACE FUNCTION public.manual_refresh_dashboard_metrics()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_start_time TIMESTAMPTZ;
  v_end_time TIMESTAMPTZ;
  v_duration INTERVAL;
BEGIN
  v_start_time := clock_timestamp();
  
  PERFORM public.refresh_crm_dashboard_metrics();
  
  v_end_time := clock_timestamp();
  v_duration := v_end_time - v_start_time;
  
  RETURN json_build_object(
    'success', true,
    'refreshed_at', NOW(),
    'duration_ms', EXTRACT(MILLISECONDS FROM v_duration)::INTEGER
  );
END;
$function$;

-- --- manually_match_slack_user(p_slack_user_id text, p_member_id uuid) ---
CREATE OR REPLACE FUNCTION public.manually_match_slack_user(p_slack_user_id text, p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_slack_info RECORD;
BEGIN
    -- Get Slack user info from unmatched table
    SELECT * INTO v_slack_info
    FROM slack_users_unmatched
    WHERE slack_user_id = p_slack_user_id;
    
    -- Create the mapping
    INSERT INTO slack_user_mapping (
        member_id,
        slack_user_id,
        slack_email,
        slack_real_name,
        slack_display_name,
        matched_by,
        match_confidence,
        manually_verified
    ) VALUES (
        p_member_id,
        p_slack_user_id,
        v_slack_info.slack_email,
        v_slack_info.slack_real_name,
        v_slack_info.slack_display_name,
        'manual',
        1.00,
        true
    )
    ON CONFLICT (slack_user_id) DO UPDATE
    SET member_id = EXCLUDED.member_id,
        manually_verified = true,
        match_confidence = 1.00;
    
    -- Update members table
    UPDATE members
    SET slack_user_id = p_slack_user_id
    WHERE id = p_member_id;
    
    -- Remove from unmatched
    DELETE FROM slack_users_unmatched
    WHERE slack_user_id = p_slack_user_id;
    
    RETURN jsonb_build_object(
        'status', 'success',
        'member_id', p_member_id,
        'slack_user_id', p_slack_user_id
    );
END;
$function$;

-- --- mark_bill_detail_synced(p_bill_id uuid, p_action_count integer, p_vote_count integer, p_version_count integer, p_api_updated_at timestamp with time zone, p_error text) ---
CREATE OR REPLACE FUNCTION public.mark_bill_detail_synced(p_bill_id uuid, p_action_count integer DEFAULT 0, p_vote_count integer DEFAULT 0, p_version_count integer DEFAULT 0, p_api_updated_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_error text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.legislation_bill_sync_status (bill_id, last_detail_sync_at, needs_detail_sync)
  VALUES (p_bill_id, CASE WHEN p_error IS NULL THEN NOW() ELSE NULL END, p_error IS NOT NULL)
  ON CONFLICT (bill_id) DO UPDATE SET
    last_detail_sync_at = CASE WHEN p_error IS NULL THEN NOW() ELSE public.legislation_bill_sync_status.last_detail_sync_at END,
    detail_sync_error = p_error,
    needs_detail_sync = CASE WHEN p_error IS NULL THEN FALSE ELSE TRUE END,
    needs_text_extract = CASE 
      WHEN p_error IS NULL AND p_version_count > public.legislation_bill_sync_status.version_count_at_sync THEN TRUE 
      ELSE public.legislation_bill_sync_status.needs_text_extract 
    END,
    action_count_at_sync = COALESCE(p_action_count, public.legislation_bill_sync_status.action_count_at_sync),
    vote_count_at_sync = COALESCE(p_vote_count, public.legislation_bill_sync_status.vote_count_at_sync),
    version_count_at_sync = COALESCE(p_version_count, public.legislation_bill_sync_status.version_count_at_sync),
    api_updated_at = COALESCE(p_api_updated_at, public.legislation_bill_sync_status.api_updated_at),
    updated_at = NOW();
  
  -- Also update main table
  IF p_error IS NULL THEN
    UPDATE public.legislation_tracked_bills
    SET last_synced_at = NOW(), sync_error = NULL
    WHERE id = p_bill_id;
  END IF;
END;
$function$;

-- --- mark_bill_sponsors_linked(p_bill_id uuid) ---
CREATE OR REPLACE FUNCTION public.mark_bill_sponsors_linked(p_bill_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.legislation_bill_sync_status (bill_id, last_sponsor_link_at, needs_sponsor_link)
  VALUES (p_bill_id, NOW(), FALSE)
  ON CONFLICT (bill_id) DO UPDATE SET
    last_sponsor_link_at = NOW(),
    sponsor_link_error = NULL,
    needs_sponsor_link = FALSE,
    updated_at = NOW();
END;
$function$;

-- --- mark_bill_text_extracted(p_bill_id uuid, p_error text) ---
CREATE OR REPLACE FUNCTION public.mark_bill_text_extracted(p_bill_id uuid, p_error text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.legislation_bill_sync_status (bill_id, last_text_extract_at, needs_text_extract)
  VALUES (p_bill_id, CASE WHEN p_error IS NULL THEN NOW() ELSE NULL END, FALSE)
  ON CONFLICT (bill_id) DO UPDATE SET
    last_text_extract_at = CASE WHEN p_error IS NULL THEN NOW() ELSE public.legislation_bill_sync_status.last_text_extract_at END,
    text_extract_error = p_error,
    needs_text_extract = FALSE,
    updated_at = NOW();
END;
$function$;

-- --- match_candidates_to_members() ---
CREATE OR REPLACE FUNCTION public.match_candidates_to_members()
 RETURNS json
 LANGUAGE sql
AS $function$
  WITH matches AS (
    SELECT c.id AS candidate_id, c.name AS candidate_name,
           m.id AS member_id, m.name AS member_name, m.date_of_birth
    FROM public.candidates c
    JOIN public.members m ON (
      LOWER(TRIM(c.first_name)) = LOWER(TRIM(split_part(m.name, ' ', 1)))
      AND LOWER(TRIM(c.last_name)) = LOWER(TRIM(
        CASE 
          WHEN array_length(string_to_array(m.name, ' '), 1) > 2 
          THEN split_part(m.name, ' ', 3)
          ELSE split_part(m.name, ' ', 2)
        END
      ))
    )
    WHERE c.election_year = 2026
      AND c.member_id IS NULL
  ),
  updated AS (
    UPDATE public.candidates c SET
      member_id = m.member_id,
      date_of_birth = COALESCE(c.date_of_birth, m.date_of_birth),
      estimated_age = COALESCE(
        CASE WHEN m.date_of_birth IS NOT NULL 
             THEN EXTRACT(YEAR FROM age(m.date_of_birth))::int 
        END,
        c.estimated_age
      ),
      updated_at = now()
    FROM matches m
    WHERE c.id = m.candidate_id
    RETURNING c.name, c.member_id, c.date_of_birth
  )
  SELECT COALESCE(json_agg(row_to_json(u)), '[]'::json) FROM updated u;
$function$;

-- --- match_legislators_to_members() ---
CREATE OR REPLACE FUNCTION public.match_legislators_to_members()
 RETURNS TABLE(legislator_id uuid, legislator_name text, member_id uuid, member_name text, matched boolean)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  WITH matches AS (
    SELECT 
      ll.id AS leg_id,
      ll.name AS leg_name,
      m.id AS mem_id,
      m.name AS mem_name
    FROM public.legislation_legislators ll
    INNER JOIN public.members m ON LOWER(TRIM(ll.name)) = LOWER(TRIM(m.name))
    WHERE ll.linked_member_id IS NULL
  )
  UPDATE public.legislation_legislators ll
  SET linked_member_id = matches.mem_id
  FROM matches
  WHERE ll.id = matches.leg_id
  RETURNING ll.id, ll.name, ll.linked_member_id, matches.mem_name, true;
END;
$function$;

-- --- normalize_chapter_name(name text) ---
CREATE OR REPLACE FUNCTION public.normalize_chapter_name(name text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  IF name IS NULL OR name = '' THEN
    RETURN NULL;
  END IF;
  
  RETURN LOWER(
    REGEXP_REPLACE(
      REGEXP_REPLACE(name, '[^a-zA-Z0-9\s]', '', 'g'),  -- Remove special chars
      '\s+', '', 'g'  -- Remove all spaces
    )
  );
END;
$function$;

-- --- normalize_county_name() ---
CREATE OR REPLACE FUNCTION public.normalize_county_name()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.county is not null then
    -- remove "County" (case-insensitive), trim spaces, and collapse doubles
    new.county := trim(
      regexp_replace(
        replace(new.county, 'County', ''),
        '\s+',
        ' ',
        'g'
      )
    );
  end if;
  return new;
end;
$function$;

-- --- notify_job_approval() ---
CREATE OR REPLACE FUNCTION public.notify_job_approval()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- This function can be customized to send notifications
  -- For now, it's a placeholder
  
  -- Check if status changed to 'approved' or 'rejected'
  IF OLD.status != NEW.status THEN
    -- Example: Send notification
    -- PERFORM pg_notify('job_status_changed', json_build_object(
    --   'job_id', NEW.id,
    --   'old_status', OLD.status,
    --   'new_status', NEW.status,
    --   'submitter_email', NEW.submitter_email
    -- )::text);
    NULL;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- notify_new_job_submission() ---
CREATE OR REPLACE FUNCTION public.notify_new_job_submission()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- This function can be customized to send notifications
  -- For now, it's a placeholder that does nothing harmful
  -- You can integrate with your notification system here
  
  -- Example: Insert into a notifications table or call an edge function
  -- PERFORM pg_notify('new_job_submission', json_build_object(
  --   'job_id', NEW.id,
  --   'title', NEW.title,
  --   'organization', NEW.organization,
  --   'submitter_email', NEW.submitter_email
  -- )::text);
  
  RETURN NEW;
END;
$function$;

-- --- queue_bill_for_text_extraction(p_bill_id uuid, p_pdf_path text, p_pdf_size integer, p_page_count integer, p_priority integer, p_pages_per_chunk integer) ---
CREATE OR REPLACE FUNCTION public.queue_bill_for_text_extraction(p_bill_id uuid, p_pdf_path text, p_pdf_size integer DEFAULT NULL::integer, p_page_count integer DEFAULT NULL::integer, p_priority integer DEFAULT 100, p_pages_per_chunk integer DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_queue_id uuid;
  v_bill_identifier text;
  v_total_chunks integer;
BEGIN
  -- Get bill identifier
  SELECT bill_identifier INTO v_bill_identifier
  FROM public.legislation_tracked_bills
  WHERE id = p_bill_id;
  
  IF v_bill_identifier IS NULL THEN
    RAISE EXCEPTION 'Bill not found: %', p_bill_id;
  END IF;
  
  -- Calculate total chunks if page count known
  IF p_page_count IS NOT NULL THEN
    v_total_chunks := CEIL(p_page_count::numeric / p_pages_per_chunk);
  END IF;
  
  -- Insert or update queue entry
  INSERT INTO public.legislation_text_extraction_queue (
    bill_id,
    bill_identifier,
    pdf_storage_path,
    pdf_size_bytes,
    pdf_total_pages,
    total_chunks,
    pages_per_chunk,
    priority,
    status
  ) VALUES (
    p_bill_id,
    v_bill_identifier,
    p_pdf_path,
    p_pdf_size,
    p_page_count,
    v_total_chunks,
    p_pages_per_chunk,
    p_priority,
    'queued'
  )
  ON CONFLICT (bill_id) DO UPDATE SET
    pdf_storage_path = EXCLUDED.pdf_storage_path,
    pdf_size_bytes = COALESCE(EXCLUDED.pdf_size_bytes, public.legislation_text_extraction_queue.pdf_size_bytes),
    pdf_total_pages = COALESCE(EXCLUDED.pdf_total_pages, public.legislation_text_extraction_queue.pdf_total_pages),
    total_chunks = COALESCE(EXCLUDED.total_chunks, public.legislation_text_extraction_queue.total_chunks),
    priority = EXCLUDED.priority,
    status = CASE 
      WHEN public.legislation_text_extraction_queue.status = 'failed' THEN 'queued'
      ELSE public.legislation_text_extraction_queue.status
    END,
    updated_at = now()
  RETURNING id INTO v_queue_id;
  
  -- Update bill status
  UPDATE public.legislation_tracked_bills
  SET 
    text_extraction_status = 'pending',
    text_extraction_deferred = true,
    text_extraction_deferred_reason = 'Large file queued for chunked extraction'
  WHERE id = p_bill_id;
  
  RETURN v_queue_id;
END;
$function$;

-- --- queue_job_alerts(p_job_id uuid, p_template_id uuid) ---
CREATE OR REPLACE FUNCTION public.queue_job_alerts(p_job_id uuid, p_template_id uuid)
 RETURNS TABLE(queued integer, total integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_queued INT := 0;
  v_total INT := 0;
BEGIN
  -- Insert pending notification for each subscribed member
  WITH inserted AS (
    INSERT INTO job_notification_log (
      template_id,
      trigger_type,
      recipient_member_id,
      recipient_email,
      recipient_name,
      job_id,
      channel,
      status
    )
    SELECT 
      p_template_id,
      'new_job_alert',
      m.id,
      m.email,
      m.name,
      p_job_id,
      'email',
      'pending'
    FROM members m
    WHERE m.subscribed_to_job_alerts = TRUE
      AND m.email IS NOT NULL
      -- Prevent duplicate queuing (same job+member combo not already in log)
      AND NOT EXISTS (
        SELECT 1 FROM job_notification_log jnl
        WHERE jnl.job_id = p_job_id
          AND jnl.recipient_member_id = m.id
          AND jnl.trigger_type = 'new_job_alert'
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_queued FROM inserted;

  -- Count total subscribed members
  SELECT COUNT(*) INTO v_total
  FROM members
  WHERE subscribed_to_job_alerts = TRUE
    AND email IS NOT NULL;

  RETURN QUERY SELECT v_queued, v_total;
END;
$function$;

-- --- queue_slack_avatar_sync() ---
CREATE OR REPLACE FUNCTION public.queue_slack_avatar_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Check if avatar sync is needed
  IF public.slack_avatar_needs_sync(
    NEW.slack_avatar_url,
    NEW.cached_avatar_path,
    NEW.cached_avatar_source_url
  ) THEN
    -- Add to sync queue (only if not already pending for this user)
    INSERT INTO public.slack_avatar_sync_queue (
      slack_user_mapping_id,
      slack_user_id,
      slack_avatar_url,
      status
    ) 
    SELECT 
      NEW.id,
      NEW.slack_user_id,
      NEW.slack_avatar_url,
      'pending'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.slack_avatar_sync_queue 
      WHERE slack_user_mapping_id = NEW.id 
      AND status = 'pending'
    );
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- queue_unmatched_avatar_sync() ---
CREATE OR REPLACE FUNCTION public.queue_unmatched_avatar_sync()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Check if avatar sync is needed (has URL but not cached, or URL changed)
  IF (
    NEW.slack_avatar_url IS NOT NULL 
    AND NEW.slack_avatar_url != ''
    AND (
      NEW.cached_avatar_path IS NULL 
      OR NEW.cached_avatar_source_url IS NULL
      OR NEW.cached_avatar_source_url != NEW.slack_avatar_url
    )
  ) THEN
    -- Add to sync queue (reuse the same queue table with a flag)
    INSERT INTO public.slack_avatar_sync_queue (
      slack_user_mapping_id,
      slack_user_id,
      slack_avatar_url,
      status
    ) 
    SELECT 
      NULL,  -- NULL mapping_id indicates unmatched user
      NEW.slack_user_id,
      NEW.slack_avatar_url,
      'pending'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.slack_avatar_sync_queue 
      WHERE slack_user_id = NEW.slack_user_id 
      AND status = 'pending'
    );
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- recalculate_all_legislator_sponsorship_counts() ---
CREATE OR REPLACE FUNCTION public.recalculate_all_legislator_sponsorship_counts()
 RETURNS TABLE(legislators_updated integer, total_sponsorships integer, total_cosponsorships integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_legislators_updated integer;
    v_total_sponsorships integer;
    v_total_cosponsorships integer;
BEGIN
    -- Update all legislators with their calculated counts
    WITH sponsor_counts AS (
        SELECT 
            bs.legislator_id,
            COUNT(*) FILTER (WHERE bs.sponsorship_classification = 'primary') AS sponsored_count,
            COUNT(*) FILTER (WHERE bs.sponsorship_classification = 'cosponsor') AS cosponsored_count
        FROM public.legislation_bill_sponsors bs
        WHERE bs.legislator_id IS NOT NULL
        GROUP BY bs.legislator_id
    )
    UPDATE public.legislation_legislators leg
    SET 
        bills_sponsored_count = COALESCE(sc.sponsored_count, 0),
        bills_cosponsored_count = COALESCE(sc.cosponsored_count, 0),
        updated_at = NOW()
    FROM sponsor_counts sc
    WHERE leg.id = sc.legislator_id;
    
    GET DIAGNOSTICS v_legislators_updated = ROW_COUNT;
    
    -- Also reset counts to 0 for legislators with no sponsorships
    UPDATE public.legislation_legislators
    SET 
        bills_sponsored_count = 0,
        bills_cosponsored_count = 0,
        updated_at = NOW()
    WHERE id NOT IN (
        SELECT DISTINCT legislator_id 
        FROM public.legislation_bill_sponsors 
        WHERE legislator_id IS NOT NULL
    )
    AND (bills_sponsored_count != 0 OR bills_cosponsored_count != 0);
    
    -- Get totals for reporting
    SELECT 
        COALESCE(SUM(bills_sponsored_count), 0),
        COALESCE(SUM(bills_cosponsored_count), 0)
    INTO v_total_sponsorships, v_total_cosponsorships
    FROM public.legislation_legislators;
    
    RETURN QUERY SELECT v_legislators_updated, v_total_sponsorships::integer, v_total_cosponsorships::integer;
END;
$function$;

-- --- recalculate_email_campaign_statistics() ---
CREATE OR REPLACE FUNCTION public.recalculate_email_campaign_statistics()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_start_of_month date;
    v_start_of_year date;
BEGIN
    v_start_of_month := date_trunc('month', CURRENT_DATE);
    v_start_of_year := date_trunc('year', CURRENT_DATE);
    
    -- Insert or update the singleton row
    INSERT INTO public.email_campaign_statistics (id)
    VALUES ('00000000-0000-0000-0000-000000000001')
    ON CONFLICT (id) DO NOTHING;
    
    -- Update all statistics
    UPDATE public.email_campaign_statistics
    SET
        updated_at = now(),
        
        -- Campaign counts
        total_campaigns = (SELECT COUNT(*) FROM public.email_campaigns WHERE sent_at IS NOT NULL),
        active_campaigns = (SELECT COUNT(*) FROM public.email_campaigns WHERE sent_at IS NULL),
        campaigns_sent_this_month = (SELECT COUNT(*) FROM public.email_campaigns WHERE sent_at >= v_start_of_month),
        campaigns_sent_this_year = (SELECT COUNT(*) FROM public.email_campaigns WHERE sent_at >= v_start_of_year),
        
        -- Email volumes
        total_emails_sent = (SELECT COALESCE(SUM(total_sent), 0) FROM public.email_campaigns),
        total_emails_delivered = (SELECT COALESCE(SUM(total_delivered), 0) FROM public.email_campaigns),
        total_emails_this_month = (SELECT COALESCE(SUM(total_sent), 0) FROM public.email_campaigns WHERE sent_at >= v_start_of_month),
        total_emails_this_year = (SELECT COALESCE(SUM(total_sent), 0) FROM public.email_campaigns WHERE sent_at >= v_start_of_year),
        
        -- Engagement totals
        total_opens = (SELECT COALESCE(SUM(total_opens), 0) FROM public.email_campaigns),
        total_unique_opens = (SELECT COALESCE(SUM(unique_opens), 0) FROM public.email_campaigns),
        total_clicks = (SELECT COALESCE(SUM(total_clicks), 0) FROM public.email_campaigns),
        total_unique_clicks = (SELECT COALESCE(SUM(unique_clicks), 0) FROM public.email_campaigns),
        total_unsubscribes = (SELECT COALESCE(SUM(total_unsubscribes), 0) FROM public.email_campaigns),
        total_complaints = (SELECT COALESCE(SUM(total_complaints), 0) FROM public.email_campaigns),
        total_bounces = (SELECT COALESCE(SUM(total_bounces), 0) FROM public.email_campaigns),
        
        -- Average rates
        average_open_rate = (SELECT COALESCE(AVG(open_rate), 0) FROM public.email_campaigns WHERE total_sent > 0),
        average_click_rate = (SELECT COALESCE(AVG(click_rate), 0) FROM public.email_campaigns WHERE total_sent > 0),
        average_click_to_open_rate = (SELECT COALESCE(AVG(click_to_open_rate), 0) FROM public.email_campaigns WHERE unique_opens > 0),
        average_unsubscribe_rate = (
            SELECT CASE 
                WHEN SUM(total_delivered) > 0 
                THEN (SUM(total_unsubscribes)::numeric / SUM(total_delivered) * 100)
                ELSE 0 
            END
            FROM public.email_campaigns
        ),
        average_bounce_rate = (
            SELECT CASE 
                WHEN SUM(total_sent) > 0 
                THEN (SUM(total_bounces)::numeric / SUM(total_sent) * 100)
                ELSE 0 
            END
            FROM public.email_campaigns
        ),
        delivery_rate = (
            SELECT CASE 
                WHEN SUM(total_sent) > 0 
                THEN (SUM(total_delivered)::numeric / SUM(total_sent) * 100)
                ELSE 0 
            END
            FROM public.email_campaigns
        ),
        
        -- Performance by month (last 12 months)
        campaigns_by_month = (
            SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            FROM (
                SELECT 
                    to_char(sent_at, 'YYYY-MM') as month,
                    COUNT(*) as count
                FROM public.email_campaigns
                WHERE sent_at >= (CURRENT_DATE - interval '12 months')
                GROUP BY to_char(sent_at, 'YYYY-MM')
                ORDER BY month DESC
                LIMIT 12
            ) t
        ),
        opens_by_month = (
            SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            FROM (
                SELECT 
                    to_char(sent_at, 'YYYY-MM') as month,
                    SUM(total_opens) as count
                FROM public.email_campaigns
                WHERE sent_at >= (CURRENT_DATE - interval '12 months')
                GROUP BY to_char(sent_at, 'YYYY-MM')
                ORDER BY month DESC
                LIMIT 12
            ) t
        ),
        
        -- Top campaigns by opens
        top_campaigns_by_opens = (
            SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            FROM (
                SELECT 
                    name,
                    subject,
                    total_opens as opens,
                    open_rate
                FROM public.email_campaigns
                WHERE sent_at IS NOT NULL
                ORDER BY total_opens DESC NULLS LAST
                LIMIT 10
            ) t
        ),
        
        -- Top campaigns by clicks
        top_campaigns_by_clicks = (
            SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            FROM (
                SELECT 
                    name,
                    subject,
                    total_clicks as clicks,
                    click_rate
                FROM public.email_campaigns
                WHERE sent_at IS NOT NULL
                ORDER BY total_clicks DESC NULLS LAST
                LIMIT 10
            ) t
        )
    WHERE id = '00000000-0000-0000-0000-000000000001';
END;
$function$;

-- --- record_text_extraction_error(p_queue_id uuid, p_worker_id text, p_error_message text) ---
CREATE OR REPLACE FUNCTION public.record_text_extraction_error(p_queue_id uuid, p_worker_id text, p_error_message text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_record RECORD;
  v_error_history jsonb;
BEGIN
  SELECT * INTO v_record
  FROM public.legislation_text_extraction_queue
  WHERE id = p_queue_id;
  
  IF v_record IS NULL THEN
    RETURN false;
  END IF;
  
  -- Add to error history
  v_error_history := v_record.error_history || jsonb_build_array(
    jsonb_build_object(
      'error', p_error_message,
      'attempt', v_record.attempts + 1,
      'chunk', v_record.current_chunk,
      'pages_processed', v_record.pages_processed,
      'timestamp', now()
    )
  );
  
  -- Update queue record
  UPDATE public.legislation_text_extraction_queue
  SET 
    attempts = attempts + 1,
    last_error = p_error_message,
    error_history = v_error_history,
    status = CASE 
      WHEN attempts + 1 >= max_attempts THEN 'failed'
      ELSE 'queued' -- Reset to queued for retry
    END,
    locked_by = NULL,
    locked_at = NULL,
    lock_expires_at = NULL,
    updated_at = now()
  WHERE id = p_queue_id;
  
  -- Update bill status if permanently failed
  IF v_record.attempts + 1 >= v_record.max_attempts THEN
    UPDATE public.legislation_tracked_bills
    SET 
      text_extraction_status = 'failed',
      sync_error = 'Text extraction failed after ' || v_record.max_attempts || ' attempts: ' || p_error_message,
      text_extraction_attempts = v_record.attempts + 1
    WHERE id = v_record.bill_id;
  ELSE
    UPDATE public.legislation_tracked_bills
    SET 
      text_extraction_attempts = v_record.attempts + 1
    WHERE id = v_record.bill_id;
  END IF;
  
  RETURN true;
END;
$function$;

-- --- remove_from_knowledge_on_delete() ---
CREATE OR REPLACE FUNCTION public.remove_from_knowledge_on_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM public.knowledge_documents
  WHERE source_table = TG_TABLE_NAME
    AND source_id = (OLD.id)::UUID;
  RETURN OLD;
END;
$function$;

-- --- render_notification_template(p_template text, p_variables jsonb) ---
CREATE OR REPLACE FUNCTION public.render_notification_template(p_template text, p_variables jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_result TEXT := p_template;
    v_key TEXT;
    v_value TEXT;
BEGIN
    IF p_template IS NULL OR p_variables IS NULL THEN
        RETURN p_template;
    END IF;
    
    FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_variables)
    LOOP
        v_result := REPLACE(v_result, '{{' || v_key || '}}', COALESCE(v_value, ''));
    END LOOP;
    
    RETURN v_result;
END;
$function$;

-- --- request_bill_text_extraction(p_bill_id uuid) ---
CREATE OR REPLACE FUNCTION public.request_bill_text_extraction(p_bill_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_request_id bigint;
BEGIN
  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/extract-bill-text-openstates',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDIxNzE5OSwiZXhwIjoyMDc1NzkzMTk5fQ.aNG79mrHw8P1TjJ6uYqP0ceSK65DOjaVUMt-MazXnWU',
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

-- --- reset_api_key_daily_counts() ---
CREATE OR REPLACE FUNCTION public.reset_api_key_daily_counts()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.legislation_api_keys
  SET 
    calls_today = 0,
    is_rate_limited = FALSE,
    rate_limited_until = NULL,
    consecutive_429s = 0,
    last_reset_at = NOW(),
    updated_at = NOW()
  WHERE last_reset_at::date < CURRENT_DATE;
END;
$function$;

-- --- save_text_extraction_chunk(p_queue_id uuid, p_worker_id text, p_chunk_text text, p_pages_in_chunk integer, p_actual_total_pages integer, p_is_final_chunk boolean) ---
CREATE OR REPLACE FUNCTION public.save_text_extraction_chunk(p_queue_id uuid, p_worker_id text, p_chunk_text text, p_pages_in_chunk integer, p_actual_total_pages integer DEFAULT NULL::integer, p_is_final_chunk boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_record RECORD;
  v_new_chunks jsonb;
  v_all_text text;
  v_text_hash text;
  v_word_count integer;
BEGIN
  -- Get current record
  SELECT * INTO v_record
  FROM public.legislation_text_extraction_queue
  WHERE id = p_queue_id AND locked_by = p_worker_id
  FOR UPDATE;
  
  IF v_record IS NULL THEN
    RAISE EXCEPTION 'Queue item not found or not locked by this worker';
  END IF;
  
  -- Add new chunk to array
  v_new_chunks := v_record.extracted_chunks || jsonb_build_object(
    'chunk_index', v_record.current_chunk,
    'start_page', v_record.pages_processed,
    'end_page', v_record.pages_processed + p_pages_in_chunk,
    'text_length', length(p_chunk_text),
    'extracted_at', now()
  );
  
  -- Update queue record
  UPDATE public.legislation_text_extraction_queue
  SET 
    current_chunk = current_chunk + 1,
    pages_processed = pages_processed + p_pages_in_chunk,
    pdf_total_pages = COALESCE(p_actual_total_pages, pdf_total_pages),
    total_chunks = CASE 
      WHEN p_actual_total_pages IS NOT NULL 
      THEN CEIL(p_actual_total_pages::numeric / pages_per_chunk)
      ELSE total_chunks
    END,
    extracted_chunks = v_new_chunks,
    last_chunk_at = now(),
    lock_expires_at = now() + interval '60 seconds', -- Extend lock
    updated_at = now()
  WHERE id = p_queue_id;
  
  -- Update bill with partial text (append)
  UPDATE public.legislation_tracked_bills
  SET 
    -- For chunked extraction, we store chunks separately and combine at the end
    text_extraction_chunks = v_new_chunks,
    text_extraction_pages_processed = v_record.pages_processed + p_pages_in_chunk,
    text_extraction_total_pages = COALESCE(p_actual_total_pages, text_extraction_total_pages),
    text_extraction_last_chunk_at = now()
  WHERE id = v_record.bill_id;
  
  -- If this is the final chunk, combine all text and finalize
  IF p_is_final_chunk THEN
    PERFORM public.finalize_text_extraction(p_queue_id, p_worker_id);
  END IF;
  
  RETURN true;
END;
$function$;

-- --- search_candidates(p_party text, p_office_level text, p_district text, p_min_age integer, p_max_age integer, p_young_dem_only boolean, p_search text, p_limit integer, p_offset integer) ---
CREATE OR REPLACE FUNCTION public.search_candidates(p_party text DEFAULT NULL::text, p_office_level text DEFAULT NULL::text, p_district text DEFAULT NULL::text, p_min_age integer DEFAULT NULL::integer, p_max_age integer DEFAULT NULL::integer, p_young_dem_only boolean DEFAULT false, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS SETOF candidates
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT c.*
    FROM public.candidates c
    WHERE (p_party IS NULL OR c.party = p_party)
      AND (p_office_level IS NULL OR c.office_level = p_office_level)
      AND (p_district IS NULL OR c.district = p_district)
      AND (p_min_age IS NULL OR c.estimated_age >= p_min_age)
      AND (p_max_age IS NULL OR c.estimated_age <= p_max_age)
      AND (p_young_dem_only = false OR c.is_young_dem = true)
      AND (p_search IS NULL OR c.name ILIKE '%' || p_search || '%')
    ORDER BY c.young_dem_score DESC, c.name ASC
    LIMIT p_limit OFFSET p_offset;
END;
$function$;

-- --- search_committees_unified(p_query text, p_status text, p_party text, p_source text, p_limit integer, p_offset integer) ---
CREATE OR REPLACE FUNCTION public.search_committees_unified(p_query text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_party text DEFAULT NULL::text, p_source text DEFAULT 'both'::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(id integer, source text, committee_id text, committee_name text, committee_type text, committee_status text, party_affiliation text, candidate_name text, treasurer_name text, state text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT * FROM (
    (
      SELECT
        m.id::int,
        'MEC'::text AS source,
        m.mec_id AS committee_id,
        regexp_replace(m.committee_name, '^0+', '') AS committee_name,
        m.committee_type,
        m.committee_status,
        m.party_affiliation,
        m.candidate_name,
        m.treasurer_name,
        NULL::text AS state
      FROM public.mec_committees m
      WHERE
        (p_source = 'both' OR p_source = 'mec')
        AND (p_query IS NULL OR (
          m.committee_name ILIKE '%' || p_query || '%'
          OR m.candidate_name ILIKE '%' || p_query || '%'
          OR m.treasurer_name ILIKE '%' || p_query || '%'
        ))
        AND (p_status IS NULL OR m.committee_status = p_status)
        AND (p_party IS NULL OR m.party_affiliation = p_party)

      UNION ALL

      SELECT
        f.id::int,
        'FEC'::text,
        f.cmte_id,
        f.cmte_name,
        f.cmte_type,
        CASE WHEN f.cmte_type IS NOT NULL THEN 'Active' ELSE 'Unknown' END,
        f.party,
        fc.cand_name,
        f.treasurer_name,
        f.state
      FROM public.fec_committees f
      LEFT JOIN public.fec_candidates fc ON fc.cand_id = f.cand_id
      WHERE
        (p_source = 'both' OR p_source = 'fec')
        AND (p_query IS NULL OR (
          f.cmte_name ILIKE '%' || p_query || '%'
          OR fc.cand_name ILIKE '%' || p_query || '%'
          OR f.treasurer_name ILIKE '%' || p_query || '%'
        ))
        AND (p_party IS NULL OR f.party = p_party)
    )
  ) combined
  ORDER BY combined.committee_name ASC
  LIMIT p_limit OFFSET p_offset;
END;
$function$;

-- --- search_donors_v2(p_name_query text, p_state text, p_city text, p_zip text, p_year_from integer, p_year_to integer, p_min_total numeric, p_max_total numeric, p_party text, p_employer text, p_occupation text, p_gender text, p_age_min integer, p_age_max integer, p_has_phone boolean, p_has_email boolean, p_is_homeowner boolean, p_individuals_only boolean, p_limit integer, p_offset integer) ---
CREATE OR REPLACE FUNCTION public.search_donors_v2(p_name_query text DEFAULT NULL::text, p_state text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_zip text DEFAULT NULL::text, p_year_from integer DEFAULT NULL::integer, p_year_to integer DEFAULT NULL::integer, p_min_total numeric DEFAULT NULL::numeric, p_max_total numeric DEFAULT NULL::numeric, p_party text DEFAULT NULL::text, p_employer text DEFAULT NULL::text, p_occupation text DEFAULT NULL::text, p_gender text DEFAULT NULL::text, p_age_min integer DEFAULT NULL::integer, p_age_max integer DEFAULT NULL::integer, p_has_phone boolean DEFAULT NULL::boolean, p_has_email boolean DEFAULT NULL::boolean, p_is_homeowner boolean DEFAULT NULL::boolean, p_individuals_only boolean DEFAULT true, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS TABLE(donor_id bigint, donor_name text, last_name text, first_name text, company_name text, committee_name text, city text, state text, zip text, employer text, occupation text, total_amount numeric, contribution_count integer, first_year integer, last_year integer, committees_donated_to jsonb, gender text, age_estimate integer, generation text, party_lean text, party_lean_confidence numeric, phone_mobile text, phone_home text, email_personal text, social_profile_count integer, giving_capacity_estimate numeric, wealth_score numeric, engagement_score numeric, is_homeowner boolean, current_employer text, current_job_title text, estimated_income_range text, ethnicity text)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  _needs_enrichment_filter boolean;
  _date_from date := CASE WHEN p_year_from IS NOT NULL THEN make_date(p_year_from, 1, 1) ELSE NULL END;
  _date_to date := CASE WHEN p_year_to IS NOT NULL THEN make_date(p_year_to, 12, 31) ELSE NULL END;
BEGIN
  _needs_enrichment_filter := (
    p_party IS NOT NULL OR
    p_gender IS NOT NULL OR
    p_age_min IS NOT NULL OR
    p_age_max IS NOT NULL OR
    p_has_phone IS NOT NULL OR
    p_has_email IS NOT NULL OR
    p_is_homeowner IS NOT NULL
  );

  IF _needs_enrichment_filter THEN
    RETURN QUERY
    SELECT
      d.id as donor_id,
      CASE
        WHEN d.donor_type = 'individual' THEN COALESCE(d.first_name || ' ' || d.last_name, d.last_name)
        WHEN d.company_name IS NOT NULL THEN d.company_name
        ELSE d.committee_name
      END as donor_name,
      d.last_name, d.first_name, d.company_name, d.committee_name,
      d.city, d.state, d.zip, d.employer, d.occupation,
      d.total_contributed as total_amount,
      d.contribution_count::int,
      EXTRACT(YEAR FROM d.first_contribution_date)::int as first_year,
      EXTRACT(YEAR FROM d.last_contribution_date)::int as last_year,
      d.committees_donated_to,
      e.gender, e.age_estimate, e.generation, e.party_lean, e.party_lean_confidence,
      e.phone_mobile, e.phone_home, e.email_personal, e.social_profile_count,
      e.giving_capacity_estimate, e.wealth_score, e.engagement_score,
      e.is_homeowner, e.current_employer, e.current_job_title,
      e.estimated_income_range, e.ethnicity
    FROM public.mec_donors d
    INNER JOIN public.donor_enrichment e ON e.donor_id = d.id
    WHERE
      (p_name_query IS NULL OR (
        d.last_name ILIKE '%' || p_name_query || '%'
        OR d.first_name ILIKE '%' || p_name_query || '%'
        OR d.company_name ILIKE '%' || p_name_query || '%'
        OR d.committee_name ILIKE '%' || p_name_query || '%'
      ))
      AND (p_state IS NULL OR d.state = p_state)
      AND (p_city IS NULL OR d.city ILIKE '%' || p_city || '%')
      AND (p_zip IS NULL OR d.zip LIKE p_zip || '%')
      AND (_date_from IS NULL OR d.last_contribution_date >= _date_from)
      AND (_date_to IS NULL OR d.first_contribution_date <= _date_to)
      AND (p_min_total IS NULL OR d.total_contributed >= p_min_total)
      AND (p_max_total IS NULL OR d.total_contributed <= p_max_total)
      AND (p_party IS NULL OR e.party_lean = p_party)
      AND (p_employer IS NULL OR d.employer ILIKE '%' || p_employer || '%'
           OR e.current_employer ILIKE '%' || p_employer || '%')
      AND (p_occupation IS NULL OR d.occupation ILIKE '%' || p_occupation || '%')
      AND (p_gender IS NULL OR e.gender = p_gender)
      AND (p_age_min IS NULL OR e.age_estimate >= p_age_min)
      AND (p_age_max IS NULL OR e.age_estimate <= p_age_max)
      AND (p_has_phone IS NULL OR (p_has_phone = true AND (e.phone_mobile IS NOT NULL OR e.phone_home IS NOT NULL)))
      AND (p_has_email IS NULL OR (p_has_email = true AND e.email_personal IS NOT NULL))
      AND (p_is_homeowner IS NULL OR e.is_homeowner = p_is_homeowner)
      AND (NOT p_individuals_only OR d.donor_type = 'individual')
    ORDER BY d.total_contributed DESC NULLS LAST
    LIMIT p_limit OFFSET p_offset;

  ELSE
    RETURN QUERY
    WITH top_donors AS (
      SELECT d2.*
      FROM public.mec_donors d2
      WHERE
        (p_name_query IS NULL OR (
          d2.last_name ILIKE '%' || p_name_query || '%'
          OR d2.first_name ILIKE '%' || p_name_query || '%'
          OR d2.company_name ILIKE '%' || p_name_query || '%'
          OR d2.committee_name ILIKE '%' || p_name_query || '%'
        ))
        AND (p_state IS NULL OR d2.state = p_state)
        AND (p_city IS NULL OR d2.city ILIKE '%' || p_city || '%')
        AND (p_zip IS NULL OR d2.zip LIKE p_zip || '%')
        AND (_date_from IS NULL OR d2.last_contribution_date >= _date_from)
        AND (_date_to IS NULL OR d2.first_contribution_date <= _date_to)
        AND (p_min_total IS NULL OR d2.total_contributed >= p_min_total)
        AND (p_max_total IS NULL OR d2.total_contributed <= p_max_total)
        AND (p_employer IS NULL OR d2.employer ILIKE '%' || p_employer || '%')
        AND (p_occupation IS NULL OR d2.occupation ILIKE '%' || p_occupation || '%')
        AND (NOT p_individuals_only OR d2.donor_type = 'individual')
      ORDER BY d2.total_contributed DESC NULLS LAST
      LIMIT p_limit OFFSET p_offset
    )
    SELECT
      d.id as donor_id,
      CASE
        WHEN d.donor_type = 'individual' THEN COALESCE(d.first_name || ' ' || d.last_name, d.last_name)
        WHEN d.company_name IS NOT NULL THEN d.company_name
        ELSE d.committee_name
      END as donor_name,
      d.last_name, d.first_name, d.company_name, d.committee_name,
      d.city, d.state, d.zip, d.employer, d.occupation,
      d.total_contributed as total_amount,
      d.contribution_count::int,
      EXTRACT(YEAR FROM d.first_contribution_date)::int as first_year,
      EXTRACT(YEAR FROM d.last_contribution_date)::int as last_year,
      d.committees_donated_to,
      e.gender, e.age_estimate, e.generation, e.party_lean, e.party_lean_confidence,
      e.phone_mobile, e.phone_home, e.email_personal, e.social_profile_count,
      e.giving_capacity_estimate, e.wealth_score, e.engagement_score,
      e.is_homeowner, e.current_employer, e.current_job_title,
      e.estimated_income_range, e.ethnicity
    FROM top_donors d
    LEFT JOIN public.donor_enrichment e ON e.donor_id = d.id
    ORDER BY d.total_contributed DESC NULLS LAST;

  END IF;
END;
$function$;

-- --- search_knowledge_base(query_embedding vector, match_count integer, match_threshold double precision, filter_source_type text, filter_source_table text, filter_metadata jsonb) ---
CREATE OR REPLACE FUNCTION public.search_knowledge_base(query_embedding vector, match_count integer DEFAULT 10, match_threshold double precision DEFAULT 0.5, filter_source_type text DEFAULT NULL::text, filter_source_table text DEFAULT NULL::text, filter_metadata jsonb DEFAULT NULL::jsonb)
 RETURNS TABLE(id uuid, source_type text, source_table text, source_id uuid, source_bucket text, source_file_path text, title text, content text, metadata jsonb, similarity double precision)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    kd.id,
    kd.source_type,
    kd.source_table,
    kd.source_id,
    kd.source_bucket,
    kd.source_file_path,
    kd.title,
    kd.content,
    kd.metadata,
    (1 - (kd.embedding <=> query_embedding))::float as similarity
  FROM knowledge_documents kd
  WHERE kd.embedding IS NOT NULL
    AND kd.embedding_status = 'completed'
    AND (filter_source_type IS NULL OR kd.source_type = filter_source_type)
    AND (filter_source_table IS NULL OR kd.source_table = filter_source_table)
    AND (filter_metadata IS NULL OR kd.metadata @> filter_metadata)
    AND (1 - (kd.embedding <=> query_embedding)) > match_threshold
  ORDER BY kd.embedding <=> query_embedding
  LIMIT match_count;
END;
$function$;

-- --- set_member_user_id() ---
CREATE OR REPLACE FUNCTION public.set_member_user_id()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.user_id IS NULL THEN
    NEW.user_id := NEW.id;
  END IF;
  RETURN NEW;
END;
$function$;

-- --- slack_avatar_needs_sync(p_slack_avatar_url text, p_cached_avatar_path text, p_cached_avatar_source_url text) ---
CREATE OR REPLACE FUNCTION public.slack_avatar_needs_sync(p_slack_avatar_url text, p_cached_avatar_path text, p_cached_avatar_source_url text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Needs sync if:
  -- 1. Has a slack avatar URL AND
  -- 2. Either no cached path OR source URL changed
  RETURN (
    p_slack_avatar_url IS NOT NULL 
    AND p_slack_avatar_url != ''
    AND (
      p_cached_avatar_path IS NULL 
      OR p_cached_avatar_source_url IS NULL
      OR p_cached_avatar_source_url != p_slack_avatar_url
    )
  );
END;
$function$;

-- --- sync_committees_to_slack() ---
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
            FROM slack_user_mapping sum
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
                    FROM slack_channel_committee_mapping
                    WHERE committee_name = committee AND is_active = true
                LOOP
                    INSERT INTO slack_channel_membership_log (
                        member_id,
                        slack_user_id,
                        slack_channel_id,
                        action,
                        source,
                        success,
                        metadata
                    ) VALUES (
                        NEW.id,
                        slack_user_id,
                        channel_record.slack_channel_id,
                        'invited',
                        'supabase_trigger',
                        false,
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
                    FROM slack_channel_committee_mapping
                    WHERE committee_name = committee AND is_active = true
                LOOP
                    INSERT INTO slack_channel_membership_log (
                        member_id,
                        slack_user_id,
                        slack_channel_id,
                        action,
                        source,
                        success,
                        metadata
                    ) VALUES (
                        NEW.id,
                        slack_user_id,
                        channel_record.slack_channel_id,
                        'removed',
                        'supabase_trigger',
                        false,
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

-- --- sync_dashboard_metrics_to_knowledge() ---
CREATE OR REPLACE FUNCTION public.sync_dashboard_metrics_to_knowledge()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  doc_content TEXT;
  existing_doc_id UUID;
  new_hash TEXT;
BEGIN
  -- Generate the formatted content
  doc_content := public.format_dashboard_metrics_for_knowledge();
  
  -- Calculate hash of new content
  new_hash := md5(doc_content);
  
  -- Check if document already exists
  SELECT id INTO existing_doc_id
  FROM public.knowledge_documents
  WHERE source_type = 'metrics'
    AND source_table = 'crm_dashboard_metrics'
    AND title = 'MOYD Organization Dashboard Metrics and Statistics'
  LIMIT 1;
  
  IF existing_doc_id IS NOT NULL THEN
    -- Update existing document if content changed
    UPDATE public.knowledge_documents
    SET 
      content = doc_content,
      content_hash = new_hash,
      updated_at = NOW(),
      embedding_status = 'pending'
    WHERE id = existing_doc_id
      AND content_hash != new_hash;
    
    -- Re-queue for embedding if updated
    IF FOUND THEN
      INSERT INTO public.knowledge_embedding_queue (document_id, priority, status)
      VALUES (existing_doc_id, 150, 'pending')
      ON CONFLICT (document_id) DO UPDATE SET status = 'pending', priority = 150;
      
      RAISE NOTICE 'Updated dashboard metrics document and queued for re-embedding';
    END IF;
  ELSE
    -- Insert new document
    INSERT INTO public.knowledge_documents (
      source_type,
      source_table,
      title,
      content,
      content_hash,
      metadata,
      embedding_status,
      retrieval_boost
    ) VALUES (
      'metrics',
      'crm_dashboard_metrics',
      'MOYD Organization Dashboard Metrics and Statistics',
      doc_content,
      new_hash,
      jsonb_build_object(
        'priority', 'high',
        'category', 'analytics',
        'auto_updated', true
      ),
      'pending',
      1.8
    )
    RETURNING id INTO existing_doc_id;
    
    -- Queue for embedding
    INSERT INTO public.knowledge_embedding_queue (document_id, priority, status)
    VALUES (existing_doc_id, 150, 'pending');
    
    RAISE NOTICE 'Created new dashboard metrics document: %', existing_doc_id;
  END IF;
END;
$function$;

-- --- sync_donor_to_subscribers() ---
CREATE OR REPLACE FUNCTION public.sync_donor_to_subscribers()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Donors.email is NULLABLE - skip if null or empty
  IF NEW.email IS NULL OR TRIM(NEW.email) = '' THEN
    RETURN NEW;
  END IF;

  -- Insert/update in public.subscribers
  INSERT INTO public.subscribers (
    email,
    name,
    phone,
    phone_e164,
    date_of_birth,
    address,
    city,
    state,
    zip_code,
    county,
    congressional_district,
    employer,
    donor_id,
    member_id,
    source,
    updated_at
  ) VALUES (
    TRIM(NEW.email),
    TRIM(NEW.name), -- name is NOT NULL in donors
    NEW.phone,
    NEW.phone_e164,
    NEW.date_of_birth,
    NEW.address,
    NEW.city,
    NEW.state,
    NEW.zip_code,
    NEW.county,
    NEW.congressional_district,
    NEW.employer,
    NEW.id, -- donor_id
    NEW.member_id,
    'donor',
    NOW()
  )
  ON CONFLICT (email) 
  DO UPDATE SET
    name = EXCLUDED.name,
    phone = COALESCE(EXCLUDED.phone, public.subscribers.phone),
    phone_e164 = COALESCE(EXCLUDED.phone_e164, public.subscribers.phone_e164),
    date_of_birth = COALESCE(EXCLUDED.date_of_birth, public.subscribers.date_of_birth),
    address = COALESCE(EXCLUDED.address, public.subscribers.address),
    city = COALESCE(EXCLUDED.city, public.subscribers.city),
    state = COALESCE(EXCLUDED.state, public.subscribers.state),
    zip_code = COALESCE(EXCLUDED.zip_code, public.subscribers.zip_code),
    county = COALESCE(EXCLUDED.county, public.subscribers.county),
    congressional_district = COALESCE(EXCLUDED.congressional_district, public.subscribers.congressional_district),
    employer = COALESCE(EXCLUDED.employer, public.subscribers.employer),
    donor_id = EXCLUDED.donor_id,
    member_id = COALESCE(EXCLUDED.member_id, public.subscribers.member_id),
    updated_at = NOW();

  RETURN NEW;
END;
$function$;

-- --- sync_email_log_timestamp() ---
CREATE OR REPLACE FUNCTION public.sync_email_log_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  select created_at
    into new.email_log_created_at
  from public.email_logs
  where id = new.email_log_id;

  return new;
end;
$function$;

-- --- sync_event_attendee_to_subscribers() ---
CREATE OR REPLACE FUNCTION public.sync_event_attendee_to_subscribers()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_email TEXT;
  v_name TEXT;
  v_phone TEXT;
BEGIN
  -- Event attendees can have guest_email OR be linked to a member
  IF NEW.guest_email IS NOT NULL AND TRIM(NEW.guest_email) != '' THEN
    -- Guest attendee
    v_email := TRIM(NEW.guest_email);
    v_name := COALESCE(NULLIF(TRIM(NEW.guest_name), ''), v_email);
    v_phone := NEW.guest_phone;
  ELSIF NEW.member_id IS NOT NULL THEN
    -- Member attendee - get their details
    SELECT email, name, phone INTO v_email, v_name, v_phone
    FROM public.members
    WHERE id = NEW.member_id;
  ELSE
    -- No email available
    RETURN NEW;
  END IF;

  -- Skip if no email
  IF v_email IS NULL OR v_email = '' THEN
    RETURN NEW;
  END IF;

  -- Insert/update in public.subscribers
  INSERT INTO public.subscribers (
    email,
    name,
    phone,
    date_of_birth,
    address,
    city,
    state,
    zip_code, -- Note: event_attendees has "zip" not "zip_code"
    employer,
    member_id,
    source,
    updated_at
  ) VALUES (
    v_email,
    v_name,
    v_phone,
    NEW.date_of_birth,
    NEW.address,
    NEW.city,
    NEW.state,
    NEW.zip, -- event_attendees.zip → subscribers.zip_code
    NEW.employer,
    NEW.member_id,
    'event_attendee',
    NOW()
  )
  ON CONFLICT (email) 
  DO UPDATE SET
    name = COALESCE(EXCLUDED.name, public.subscribers.name),
    phone = COALESCE(EXCLUDED.phone, public.subscribers.phone),
    date_of_birth = COALESCE(EXCLUDED.date_of_birth, public.subscribers.date_of_birth),
    address = COALESCE(EXCLUDED.address, public.subscribers.address),
    city = COALESCE(EXCLUDED.city, public.subscribers.city),
    state = COALESCE(EXCLUDED.state, public.subscribers.state),
    zip_code = COALESCE(EXCLUDED.zip_code, public.subscribers.zip_code),
    employer = COALESCE(EXCLUDED.employer, public.subscribers.employer),
    member_id = COALESCE(EXCLUDED.member_id, public.subscribers.member_id),
    source = CASE 
      WHEN public.subscribers.source = 'mailchimp' THEN 'event_attendee'
      WHEN public.subscribers.source IS NULL THEN 'event_attendee'
      ELSE public.subscribers.source 
    END,
    updated_at = NOW();

  RETURN NEW;
END;
$function$;

-- --- sync_existing_subscribers() ---
CREATE OR REPLACE FUNCTION public.sync_existing_subscribers()
 RETURNS TABLE(total_processed integer, linked_to_members integer, linked_to_donors integer, enriched_records integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total integer := 0;
  v_members integer := 0;
  v_donors integer := 0;
  v_enriched integer := 0;
  v_subscriber RECORD;
BEGIN
  -- Loop through all subscribers
  FOR v_subscriber IN 
    SELECT id, email, phone, date_of_birth, address, county, congressional_district, house_district, senate_district
    FROM subscribers
  LOOP
    v_total := v_total + 1;
    
    -- Update each subscriber (triggers the auto-link function)
    UPDATE subscribers
    SET updated_at = now()
    WHERE id = v_subscriber.id;
    
    -- Check if linked to member
    IF (SELECT member_id FROM subscribers WHERE id = v_subscriber.id) IS NOT NULL THEN
      v_members := v_members + 1;
    END IF;
    
    -- Check if linked to donor
    IF (SELECT donor_id FROM subscribers WHERE id = v_subscriber.id) IS NOT NULL THEN
      v_donors := v_donors + 1;
    END IF;
    
    -- Check if data was enriched
    DECLARE
      v_new_subscriber RECORD;
    BEGIN
      SELECT phone, date_of_birth, address INTO v_new_subscriber
      FROM subscribers WHERE id = v_subscriber.id;
      
      IF (v_subscriber.phone IS NULL AND v_new_subscriber.phone IS NOT NULL) OR
         (v_subscriber.date_of_birth IS NULL AND v_new_subscriber.date_of_birth IS NOT NULL) OR
         (v_subscriber.address IS NULL AND v_new_subscriber.address IS NOT NULL) THEN
        v_enriched := v_enriched + 1;
      END IF;
    END;
  END LOOP;
  
  RETURN QUERY SELECT v_total, v_members, v_donors, v_enriched;
END;
$function$;

-- --- sync_full_table(p_table_name text, p_schema_name text) ---
CREATE OR REPLACE FUNCTION public.sync_full_table(p_table_name text, p_schema_name text DEFAULT 'public'::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_config RECORD;
  v_count INT := 0;
  v_record RECORD;
  v_title TEXT;
  v_content TEXT;
  v_metadata JSONB;
  v_record_json JSONB;
  v_col TEXT;
BEGIN
  SELECT * INTO v_config
  FROM public.knowledge_table_config
  WHERE table_name = p_table_name AND schema_name = p_schema_name AND is_enabled = true;
  
  IF v_config IS NULL THEN
    RAISE EXCEPTION 'Table % is not enabled for indexing', p_table_name;
  END IF;
  
  FOR v_record IN EXECUTE format('SELECT * FROM %I.%I', p_schema_name, p_table_name) LOOP
    v_record_json := to_jsonb(v_record);
    
    v_title := v_config.title_template;
    IF v_title IS NOT NULL THEN
      FOR v_col IN SELECT jsonb_object_keys(v_record_json) LOOP
        v_title := REPLACE(v_title, '{{' || v_col || '}}', COALESCE(v_record_json->>v_col, ''));
      END LOOP;
    ELSE
      v_title := p_table_name || ': ' || COALESCE(v_record_json->>'name', v_record_json->>'title', v_record_json->>'id', 'Unknown');
    END IF;
    
    IF v_config.content_template IS NOT NULL THEN
      v_content := v_config.content_template;
      FOR v_col IN SELECT jsonb_object_keys(v_record_json) LOOP
        v_content := REPLACE(v_content, '{{' || v_col || '}}', COALESCE(v_record_json->>v_col, ''));
      END LOOP;
    ELSE
      v_content := '';
      FOR v_col IN SELECT jsonb_object_keys(v_record_json) LOOP
        IF v_record_json->>v_col IS NOT NULL AND LENGTH(v_record_json->>v_col) > 0 THEN
          IF v_col NOT IN ('id', 'created_at', 'updated_at', 'search_vector', 'embedding') THEN
            v_content := v_content || v_col || ': ' || v_record_json->>v_col || E'\n';
          END IF;
        END IF;
      END LOOP;
    END IF;
    
    v_metadata := jsonb_build_object('_table', p_table_name);
    IF v_config.metadata_columns IS NOT NULL THEN
      FOREACH v_col IN ARRAY v_config.metadata_columns LOOP
        IF v_record_json ? v_col THEN
          v_metadata := v_metadata || jsonb_build_object(v_col, v_record_json->v_col);
        END IF;
      END LOOP;
    END IF;
    
    PERFORM public.upsert_knowledge_document(
      'database',
      p_table_name,
      (v_record_json->>v_config.primary_key_column)::UUID,
      v_title,
      v_content,
      v_metadata,
      NULL,
      NULL
    );
    
    v_count := v_count + 1;
  END LOOP;
  
  UPDATE public.knowledge_table_config
  SET last_full_sync_at = NOW()
  WHERE table_name = p_table_name AND schema_name = p_schema_name;
  
  RETURN v_count;
END;
$function$;

-- --- sync_member_email_to_auth() ---
CREATE OR REPLACE FUNCTION public.sync_member_email_to_auth()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Only run when email actually changes
  IF (TG_OP = 'UPDATE' AND OLD.email IS DISTINCT FROM NEW.email) THEN
    
    -- Ensure new email is not null or empty
    IF NEW.email IS NULL OR NEW.email = '' THEN
      RAISE EXCEPTION 'Email cannot be empty';
    END IF;
    
    -- Check if new email already exists in auth.users (excluding current user)
    IF EXISTS (
      SELECT 1 FROM auth.users 
      WHERE email = NEW.email 
      AND id != NEW.id
    ) THEN
      RAISE EXCEPTION 'Email address is already in use by another account';
    END IF;
    
    -- Update the auth.users email
    UPDATE auth.users
    SET 
      email = NEW.email,
      updated_at = NOW()
    WHERE id = NEW.id;
    
    -- Also update the identity data
    UPDATE auth.identities
    SET 
      identity_data = jsonb_set(
        identity_data,
        '{email}',
        to_jsonb(NEW.email)
      ),
      updated_at = NOW()
    WHERE user_id = NEW.id
    AND provider = 'email';
    
    RAISE NOTICE 'Auth user email updated from % to % for member %', OLD.email, NEW.email, NEW.id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to sync email to auth: %', SQLERRM;
END;
$function$;

-- --- sync_member_last_sign_in() ---
CREATE OR REPLACE FUNCTION public.sync_member_last_sign_in()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.members
  SET last_sign_in_at = NEW.last_sign_in_at
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$function$;

-- --- sync_quick_link_updates_to_portal() ---
CREATE OR REPLACE FUNCTION public.sync_quick_link_updates_to_portal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Update corresponding member_portal_resources record if it exists
  UPDATE member_portal_resources
  SET 
    title = NEW.title,
    description = NEW.notes,
    url = NEW.url,
    storage_url = NEW.storage_url,
    sort_order = NEW.sort_order,
    category = NEW.category,
    icon_url = NEW.icon_url,
    updated_at = now()
  WHERE url = OLD.url OR storage_url = OLD.storage_url;
  
  RETURN NEW;
END;
$function$;

-- --- sync_received_email_to_history() ---
CREATE OR REPLACE FUNCTION public.sync_received_email_to_history()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Add single email to history
    INSERT INTO public.member_email_history (
      log_id, member_id, member_name, member_email, email_type,
      subject, body, from_address, to_address, email_date,
      gmail_message_id, gmail_thread_id
    )
    SELECT
      NEW.id, 
      m.id, 
      m.name, 
      m.email, 
      'received'::text,
      NEW.subject, 
      COALESCE(NEW.body_html, NEW.body_text, NEW.snippet),
      NEW.from_address, 
      NEW.to_address, 
      NEW.date,
      NEW.gmail_message_id, 
      NEW.gmail_thread_id
    FROM members m
    WHERE m.id = NEW.member_id
    ON CONFLICT (log_id) DO UPDATE SET
      subject = EXCLUDED.subject,
      body = EXCLUDED.body,
      from_address = EXCLUDED.from_address,
      to_address = EXCLUDED.to_address,
      email_date = EXCLUDED.email_date,
      gmail_message_id = EXCLUDED.gmail_message_id,
      gmail_thread_id = EXCLUDED.gmail_thread_id,
      updated_at = NOW();
      
  ELSIF TG_OP = 'UPDATE' THEN
    -- Update single email in history
    UPDATE public.member_email_history
    SET subject = NEW.subject,
        body = COALESCE(NEW.body_html, NEW.body_text, NEW.snippet),
        from_address = NEW.from_address,
        to_address = NEW.to_address,
        email_date = NEW.date,
        gmail_message_id = NEW.gmail_message_id,
        gmail_thread_id = NEW.gmail_thread_id,
        updated_at = NOW()
    WHERE log_id = NEW.id AND email_type = 'received';
    
  ELSIF TG_OP = 'DELETE' THEN
    -- Remove single email from history
    DELETE FROM public.member_email_history
    WHERE log_id = OLD.id AND email_type = 'received';
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- sync_sent_email_to_history() ---
CREATE OR REPLACE FUNCTION public.sync_sent_email_to_history()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Add sent emails to history (one per member)
    INSERT INTO public.member_email_history (
      log_id, member_id, member_name, member_email, email_type,
      subject, body, from_address, to_address, email_date,
      gmail_message_id, gmail_thread_id
    )
    SELECT
      NEW.id,
      m.id, 
      m.name, 
      m.email, 
      'sent'::text,
      NEW.subject, 
      NEW.body, 
      NEW.sender,
      array_to_string(NEW.recipient_emails, ', '::text),
      NEW.created_at, 
      NEW.gmail_message_id, 
      NEW.gmail_thread_id
    FROM members m
    JOIN email_log_members elm ON m.id = elm.member_id
    WHERE elm.email_log_id = NEW.id
    ON CONFLICT (log_id) DO UPDATE SET
      subject = EXCLUDED.subject,
      body = EXCLUDED.body,
      from_address = EXCLUDED.from_address,
      to_address = EXCLUDED.to_address,
      email_date = EXCLUDED.email_date,
      updated_at = NOW();
      
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.member_email_history
    SET subject = NEW.subject,
        body = NEW.body,
        from_address = NEW.sender,
        to_address = array_to_string(NEW.recipient_emails, ', '::text),
        gmail_message_id = NEW.gmail_message_id,
        gmail_thread_id = NEW.gmail_thread_id,
        updated_at = NOW()
    WHERE log_id = NEW.id AND email_type = 'sent';
    
  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.member_email_history
    WHERE log_id = OLD.id AND email_type = 'sent';
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- sync_table_to_knowledge() ---
CREATE OR REPLACE FUNCTION public.sync_table_to_knowledge()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_config RECORD;
  v_title TEXT;
  v_content TEXT;
  v_metadata JSONB;
  v_record JSONB;
  v_col TEXT;
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
  
  RETURN NEW;
END;
$function$;

-- --- trigger_district_lookup() ---
CREATE OR REPLACE FUNCTION public.trigger_district_lookup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Only trigger if address or county was provided
  IF NEW.address IS NOT NULL OR NEW.county IS NOT NULL THEN
    -- Call the Edge Function asynchronously using pg_net
    PERFORM net.http_post(
      url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/lookup-districts',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDIyMTcxOSwiZXhwIjoyMDc1Nzk3NzE5fQ.aNG79mrHw8P1TjJ6uYqP0ceSK65DOjaVUMt-MazXnWU'
      ),
      body := jsonb_build_object(
        'memberId', NEW.id::text
      )
    );
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- trigger_email_application_submitted() ---
CREATE OR REPLACE FUNCTION public.trigger_email_application_submitted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Confirmation to applicant (application_submitted)
  PERFORM public.call_job_notification_edge_function('application_submitted', NEW.job_id, NEW.id);
  
  -- Notification to job poster (application_received)
  PERFORM public.call_job_notification_edge_function('application_received', NEW.job_id, NEW.id);
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Application email notification failed: %', SQLERRM;
    RETURN NEW;
END;
$function$;

-- --- trigger_email_job_approved_subscribers() ---
CREATE OR REPLACE FUNCTION public.trigger_email_job_approved_subscribers()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Only fire when status changes to approved
  IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'approved' AND NEW.status = 'approved') THEN
    PERFORM public.call_job_notification_edge_function('new_job_alert', NEW.id);
  END IF;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Job approved subscribers notification failed: % - %', SQLSTATE, SQLERRM;
    RETURN NEW;
END;
$function$;

-- --- trigger_email_job_submitted() ---
CREATE OR REPLACE FUNCTION public.trigger_email_job_submitted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NEW.status = 'pending' THEN
    PERFORM public.call_job_notification_edge_function('job_submitted', NEW.id);
  END IF;
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Job submitted email notification failed: %', SQLERRM;
    RETURN NEW;
END;
$function$;

-- --- trigger_extract_bill_text_on_insert() ---
CREATE OR REPLACE FUNCTION public.trigger_extract_bill_text_on_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_request_id bigint;
BEGIN
  -- Only trigger if the bill doesn't already have text and has an openstates_bill_id
  IF NEW.current_bill_text IS NULL 
     AND NEW.openstates_bill_id IS NOT NULL 
     AND NEW.sync_error IS NULL
     AND (NEW.text_extraction_deferred IS NULL OR NEW.text_extraction_deferred = false)
  THEN
    -- Queue HTTP request to extract text (async, non-blocking)
    SELECT net.http_post(
      url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/extract-bill-text-openstates',
      headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDIxNzE5OSwiZXhwIjoyMDc1NzkzMTk5fQ.aNG79mrHw8P1TjJ6uYqP0ceSK65DOjaVUMt-MazXnWU',
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

-- --- trigger_legislation_statistics_refresh() ---
CREATE OR REPLACE FUNCTION public.trigger_legislation_statistics_refresh()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Use pg_notify to signal that a refresh is needed
  -- This allows for debouncing via an external listener or pg_cron
  PERFORM pg_notify('legislation_stats_refresh', 'refresh_needed');
  
  -- For immediate refresh (can be resource intensive during bulk ops):
  -- Uncomment the line below if you want immediate refresh
  PERFORM public.refresh_legislation_statistics();
  
  RETURN NULL;
END;
$function$;

-- --- trigger_notify_exec_job_submitted() ---
CREATE OR REPLACE FUNCTION public.trigger_notify_exec_job_submitted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  request_id bigint;
BEGIN
  -- Call the executive notification Edge Function
  SELECT net.http_post(
    url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/notify-executive-job-submission',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDIxNzE5OSwiZXhwIjoyMDc1NzkzMTk5fQ.aNG79mrHw8P1TjJ6uYqP0ceSK65DOjaVUMt-MazXnWU'
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

-- --- trigger_populate_donor_geography() ---
CREATE OR REPLACE FUNCTION public.trigger_populate_donor_geography()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  function_url text;
  request_id bigint;
BEGIN
  -- Only process if we have a ZIP code and it's a Missouri address
  IF NEW.zip_code IS NULL OR NEW.state IS NULL OR upper(trim(NEW.state)) != 'MO' THEN
    RETURN NEW;
  END IF;

  -- Set your Supabase project URL (replace with your actual URL)
  function_url := 'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/populate-donor-geography';

  -- Make async HTTP request using pg_net
  -- Since you have JWT verification OFF, we don't need the Authorization header
  SELECT net.http_post(
    url := function_url,
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object(
      'donorId', NEW.id::text,
      'zipCode', NEW.zip_code,
      'state', NEW.state
    )
  ) INTO request_id;

  RETURN NEW;
END;
$function$;

-- --- trigger_recalculate_email_stats() ---
CREATE OR REPLACE FUNCTION public.trigger_recalculate_email_stats()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Recalculate stats asynchronously (via pg_notify for background processing)
    -- For now, just do it directly - could be optimized later
    PERFORM public.recalculate_email_campaign_statistics();
    RETURN NULL;
END;
$function$;

-- --- trigger_refresh_dashboard_metrics() ---
CREATE OR REPLACE FUNCTION public.trigger_refresh_dashboard_metrics()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Use pg_advisory_xact_lock to prevent concurrent refreshes
  -- This creates a transaction-level lock that prevents multiple 
  -- triggers from refreshing simultaneously
  IF pg_try_advisory_xact_lock(42424242) THEN
    -- Only refresh if last update was more than 30 seconds ago
    -- This debounces rapid changes
    IF NOT EXISTS (
      SELECT 1 FROM public.crm_dashboard_metrics 
      WHERE updated_at > NOW() - INTERVAL '30 seconds'
    ) THEN
      PERFORM public.refresh_crm_dashboard_metrics();
    END IF;
  END IF;
  
  RETURN NULL; -- For AFTER triggers
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but DON'T fail - this prevents auth issues
    RAISE WARNING 'Dashboard metrics refresh failed: %', SQLERRM;
    RETURN NULL;
END;
$function$;

-- --- trigger_refresh_legislation_statistics() ---
CREATE OR REPLACE FUNCTION public.trigger_refresh_legislation_statistics()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Use pg_notify to trigger async refresh (prevents slowdown on writes)
  PERFORM pg_notify('refresh_legislation_stats', '');
  RETURN NULL;
END;
$function$;

-- --- trigger_refresh_stats_on_extraction() ---
CREATE OR REPLACE FUNCTION public.trigger_refresh_stats_on_extraction()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Only trigger on completion
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    -- Mark statistics as needing refresh (async)
    UPDATE public.legislation_statistics
    SET updated_at = now()
    WHERE id = (SELECT id FROM public.legislation_statistics LIMIT 1);
  END IF;
  RETURN NEW;
END;
$function$;

-- --- trigger_sync_dashboard_metrics() ---
CREATE OR REPLACE FUNCTION public.trigger_sync_dashboard_metrics()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF (
    NEW.total_members != OLD.total_members OR
    NEW.total_subscribers != OLD.total_subscribers OR
    NEW.total_donors != OLD.total_donors OR
    NEW.total_donations_amount != OLD.total_donations_amount OR
    NEW.new_members_this_month != OLD.new_members_this_month OR
    NEW.total_slack_messages != OLD.total_slack_messages
  ) THEN
    PERFORM public.sync_dashboard_metrics_to_knowledge();
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- trigger_update_campaign_stats() ---
CREATE OR REPLACE FUNCTION public.trigger_update_campaign_stats()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Only update for significant changes, not every insert during bulk import
  -- This trigger is designed for ongoing updates, not initial imports
  IF TG_OP = 'UPDATE' THEN
    IF OLD.opened IS DISTINCT FROM NEW.opened
       OR OLD.clicked IS DISTINCT FROM NEW.clicked
       OR OLD.bounced IS DISTINCT FROM NEW.bounced
       OR OLD.unsubscribed IS DISTINCT FROM NEW.unsubscribed THEN
      PERFORM public.update_campaign_stats_from_recipients(NEW.campaign_id);
    END IF;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- trigger_update_link_stats() ---
CREATE OR REPLACE FUNCTION public.trigger_update_link_stats()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.link_id IS NOT NULL THEN
    UPDATE public.email_campaign_links
    SET total_clicks = total_clicks + 1,
        unique_clicks = (
          SELECT COUNT(DISTINCT email) 
          FROM public.email_campaign_link_clicks 
          WHERE link_id = NEW.link_id
        )
    WHERE id = NEW.link_id;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- uninstall_knowledge_trigger(p_table_name text, p_schema_name text) ---
CREATE OR REPLACE FUNCTION public.uninstall_knowledge_trigger(p_table_name text, p_schema_name text DEFAULT 'public'::text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
BEGIN
  EXECUTE format('DROP TRIGGER IF EXISTS knowledge_sync_%I ON %I.%I', p_table_name, p_schema_name, p_table_name);
  EXECUTE format('DROP TRIGGER IF EXISTS knowledge_delete_%I ON %I.%I', p_table_name, p_schema_name, p_table_name);
  
  UPDATE public.knowledge_table_config
  SET trigger_installed = false, updated_at = NOW()
  WHERE table_name = p_table_name AND schema_name = p_schema_name;
  
  RETURN true;
END;
$function$;

-- --- update_campaign_stats() ---
CREATE OR REPLACE FUNCTION public.update_campaign_stats()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Update campaign statistics when recipient status changes
  UPDATE campaigns
  SET
    total_sent = (
      SELECT COUNT(*) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND status = 'sent'
    ),
    total_delivered = (
      SELECT COUNT(*) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND delivered_at IS NOT NULL
    ),
    total_opened = (
      SELECT COUNT(DISTINCT id) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND opened_at IS NOT NULL
    ),
    total_clicked = (
      SELECT COUNT(DISTINCT id) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND clicked_at IS NOT NULL
    ),
    total_bounced = (
      SELECT COUNT(*) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND bounced_at IS NOT NULL
    ),
    total_complained = (
      SELECT COUNT(*) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND complained_at IS NOT NULL
    ),
    total_unsubscribed = (
      SELECT COUNT(*) FROM campaign_recipients 
      WHERE campaign_id = NEW.campaign_id AND unsubscribed_at IS NOT NULL
    ),
    updated_at = NOW()
  WHERE id = NEW.campaign_id;
  
  RETURN NEW;
END;
$function$;

-- --- update_campaign_stats_from_recipients(p_campaign_id uuid) ---
CREATE OR REPLACE FUNCTION public.update_campaign_stats_from_recipients(p_campaign_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE public.email_campaigns
  SET
    total_recipients = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id
    ),
    total_sent = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND sent_at IS NOT NULL
    ),
    total_delivered = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id 
      AND sent_at IS NOT NULL 
      AND bounced = FALSE 
      AND failed = FALSE
    ),
    total_soft_bounces = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND bounce_type = 'soft'
    ),
    total_hard_bounces = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND bounce_type = 'hard'
    ),
    total_bounces = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND bounced = TRUE
    ),
    unique_opens = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND opened = TRUE
    ),
    total_opens = (
      SELECT COALESCE(SUM(open_count), 0) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id
    ),
    unique_clicks = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND clicked = TRUE
    ),
    total_clicks = (
      SELECT COALESCE(SUM(click_count), 0) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id
    ),
    total_unsubscribes = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND unsubscribed = TRUE
    ),
    total_complaints = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND complained = TRUE
    ),
    total_failed = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND failed = TRUE
    ),
    total_webview = (
      SELECT COUNT(*) FROM public.email_campaign_recipients 
      WHERE campaign_id = p_campaign_id AND viewed_in_browser = TRUE
    ),
    -- Calculate rates
    open_rate = ROUND(
      (SELECT COUNT(*) FROM public.email_campaign_recipients 
       WHERE campaign_id = p_campaign_id AND opened = TRUE)::DECIMAL /
      NULLIF((SELECT COUNT(*) FROM public.email_campaign_recipients 
              WHERE campaign_id = p_campaign_id 
              AND sent_at IS NOT NULL 
              AND bounced = FALSE 
              AND failed = FALSE), 0) * 100,
      2
    ),
    click_rate = ROUND(
      (SELECT COUNT(*) FROM public.email_campaign_recipients 
       WHERE campaign_id = p_campaign_id AND clicked = TRUE)::DECIMAL /
      NULLIF((SELECT COUNT(*) FROM public.email_campaign_recipients 
              WHERE campaign_id = p_campaign_id 
              AND sent_at IS NOT NULL 
              AND bounced = FALSE 
              AND failed = FALSE), 0) * 100,
      2
    ),
    click_to_open_rate = ROUND(
      (SELECT COUNT(*) FROM public.email_campaign_recipients 
       WHERE campaign_id = p_campaign_id AND clicked = TRUE)::DECIMAL /
      NULLIF((SELECT COUNT(*) FROM public.email_campaign_recipients 
              WHERE campaign_id = p_campaign_id AND opened = TRUE), 0) * 100,
      2
    ),
    updated_at = NOW()
  WHERE id = p_campaign_id;
END;
$function$;

-- --- update_committees_updated_at() ---
CREATE OR REPLACE FUNCTION public.update_committees_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  new.updated_at = now();
  RETURN new;
END;
$function$;

-- --- update_donation_thank_you_status() ---
CREATE OR REPLACE FUNCTION public.update_donation_thank_you_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.donations SET sent_thank_you = true WHERE id = NEW.donation_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.donations 
    SET sent_thank_you = EXISTS (
      SELECT 1 FROM public.donation_thank_yous WHERE donation_id = OLD.donation_id
    )
    WHERE id = OLD.donation_id;
  END IF;
  RETURN NULL;
END;
$function$;

-- --- update_donor_totals() ---
CREATE OR REPLACE FUNCTION public.update_donor_totals()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Recalculate totals for the donor
  UPDATE donors
  SET 
    total_donated = (
      SELECT COALESCE(SUM(amount), 0)
      FROM donations
      WHERE donor_id = NEW.donor_id 
        AND status = 'completed'
    ),
    donation_count = (
      SELECT COUNT(*)
      FROM donations
      WHERE donor_id = NEW.donor_id 
        AND status = 'completed'
    ),
    first_donation_date = (
      SELECT MIN(donation_date)
      FROM donations
      WHERE donor_id = NEW.donor_id 
        AND status = 'completed'
    ),
    last_donation_date = (
      SELECT MAX(donation_date)
      FROM donations
      WHERE donor_id = NEW.donor_id 
        AND status = 'completed'
    ),
    is_recurring_donor = (
      SELECT COALESCE(bool_or(recurring), false)
      FROM donations
      WHERE donor_id = NEW.donor_id
    ),
    updated_at = now()
  WHERE id = NEW.donor_id;
  
  RETURN NEW;
END;
$function$;

-- --- update_email_campaign_stats_from_recipients() ---
CREATE OR REPLACE FUNCTION public.update_email_campaign_stats_from_recipients()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  target_campaign_id uuid;
  click_stats RECORD;
BEGIN
  -- Get the campaign_id from either NEW or OLD record
  IF TG_OP = 'DELETE' THEN
    target_campaign_id := OLD.campaign_id;
  ELSE
    target_campaign_id := NEW.campaign_id;
  END IF;

  -- Get click stats from the link_clicks table
  SELECT 
    COUNT(*) AS total_clicks,
    COUNT(DISTINCT email) AS unique_clicks
  INTO click_stats
  FROM public.email_campaign_link_clicks
  WHERE campaign_id = target_campaign_id;

  -- Update all stats in one query
  UPDATE public.email_campaigns ec
  SET
    total_recipients = stats.total_recipients,
    total_sent = stats.total_sent,
    total_delivered = stats.total_delivered,
    total_bounces = stats.total_bounces,
    total_soft_bounces = stats.total_soft_bounces,
    total_hard_bounces = stats.total_hard_bounces,
    total_opens = stats.total_opens,
    unique_opens = stats.unique_opens,
    open_rate = CASE 
      WHEN stats.total_sent > 0 
      THEN ROUND((stats.unique_opens::numeric / stats.total_sent::numeric) * 100, 2)
      ELSE 0 
    END,
    total_clicks = click_stats.total_clicks,
    unique_clicks = click_stats.unique_clicks,
    click_rate = CASE 
      WHEN stats.total_sent > 0 
      THEN ROUND((click_stats.unique_clicks::numeric / stats.total_sent::numeric) * 100, 2)
      ELSE 0 
    END,
    click_to_open_rate = CASE 
      WHEN stats.unique_opens > 0 
      THEN ROUND((click_stats.unique_clicks::numeric / stats.unique_opens::numeric) * 100, 2)
      ELSE 0 
    END,
    total_unsubscribes = stats.total_unsubscribes,
    total_complaints = stats.total_complaints,
    total_failed = stats.total_failed,
    total_webview = stats.total_webview,
    updated_at = NOW()
  FROM (
    SELECT
      COUNT(*) AS total_recipients,
      COUNT(*) FILTER (WHERE sent_at IS NOT NULL) AS total_sent,
      COUNT(*) FILTER (WHERE delivered_at IS NOT NULL) AS total_delivered,
      COUNT(*) FILTER (WHERE bounced = true) AS total_bounces,
      COUNT(*) FILTER (WHERE bounced = true AND bounce_type = 'soft') AS total_soft_bounces,
      COUNT(*) FILTER (WHERE bounced = true AND bounce_type = 'hard') AS total_hard_bounces,
      COALESCE(SUM(open_count), 0) AS total_opens,
      COUNT(*) FILTER (WHERE opened = true) AS unique_opens,
      COUNT(*) FILTER (WHERE unsubscribed = true) AS total_unsubscribes,
      COUNT(*) FILTER (WHERE complained = true) AS total_complaints,
      COUNT(*) FILTER (WHERE failed = true) AS total_failed,
      COUNT(*) FILTER (WHERE viewed_in_browser = true) AS total_webview
    FROM public.email_campaign_recipients
    WHERE campaign_id = target_campaign_id
  ) AS stats
  WHERE ec.id = target_campaign_id;

  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- --- update_email_templates_updated_at() ---
CREATE OR REPLACE FUNCTION public.update_email_templates_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$;

-- --- update_event_attendee_count() ---
CREATE OR REPLACE FUNCTION public.update_event_attendee_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.events 
    SET attendee_count = (
      SELECT COUNT(*) 
      FROM public.event_attendees 
      WHERE event_id = OLD.event_id 
      AND rsvp_status = 'attending'
    )
    WHERE id = OLD.event_id;
    RETURN OLD;
  ELSE
    UPDATE public.events 
    SET attendee_count = (
      SELECT COUNT(*) 
      FROM public.event_attendees 
      WHERE event_id = NEW.event_id 
      AND rsvp_status = 'attending'
    )
    WHERE id = NEW.event_id;
    RETURN NEW;
  END IF;
END;
$function$;

-- --- update_executive_committee_flag() ---
CREATE OR REPLACE FUNCTION public.update_executive_committee_flag()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.executive_committee := ('Executive Committee' = ANY(NEW.committee));
  RETURN NEW;
END;
$function$;

-- --- update_form_page_count() ---
CREATE OR REPLACE FUNCTION public.update_form_page_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.page_count := public.calculate_form_page_count(NEW.schema);
  RETURN NEW;
END;
$function$;

-- --- update_form_submission_count() ---
CREATE OR REPLACE FUNCTION public.update_form_submission_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.form_schemas
    SET submission_count = COALESCE(submission_count, 0) + 1
    WHERE id = NEW.form_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.form_schemas
    SET submission_count = GREATEST(0, COALESCE(submission_count, 0) - 1)
    WHERE id = OLD.form_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

-- --- update_form_submissions_updated_at() ---
CREATE OR REPLACE FUNCTION public.update_form_submissions_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- --- update_job_application_count() ---
CREATE OR REPLACE FUNCTION public.update_job_application_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.jobs
    SET application_count = COALESCE(application_count, 0) + 1
    WHERE id = NEW.job_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.jobs
    SET application_count = GREATEST(0, COALESCE(application_count, 0) - 1)
    WHERE id = OLD.job_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$function$;

-- --- update_job_member_interaction() ---
CREATE OR REPLACE FUNCTION public.update_job_member_interaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  duration_secs INT;
  scroll_pct INT;
  current_devices TEXT[];
  current_browsers TEXT[];
  is_new_session BOOLEAN;
  current_session_count INT;
BEGIN
  -- Extract values from event_data
  duration_secs := COALESCE((NEW.event_data->>'duration_seconds')::int, 0);
  scroll_pct := COALESCE(
    (NEW.event_data->>'scroll_depth_percent')::int,
    (NEW.event_data->>'percent')::int, 
    0
  );

  -- Check if this is a new session
  SELECT 
    COALESCE(session_count, 0),
    COALESCE(devices_used, '{}'),
    COALESCE(browsers_used, '{}'),
    last_session_id IS DISTINCT FROM NEW.session_id
  INTO current_session_count, current_devices, current_browsers, is_new_session
  FROM job_member_interactions
  WHERE job_id = NEW.job_id AND member_id = NEW.member_id;

  -- Add device to array if not already present
  IF NEW.device_type IS NOT NULL AND NOT (NEW.device_type = ANY(current_devices)) THEN
    current_devices := array_append(current_devices, NEW.device_type);
  END IF;

  -- Add browser to array if not already present
  IF NEW.browser IS NOT NULL AND NOT (NEW.browser = ANY(current_browsers)) THEN
    current_browsers := array_append(current_browsers, NEW.browser);
  END IF;

  -- Upsert interaction record
  INSERT INTO job_member_interactions (
    job_id,
    member_id,
    has_viewed,
    has_clicked_apply,
    has_applied,
    has_shared,
    has_copied_text,
    has_printed,
    first_viewed_at,
    last_viewed_at,
    apply_clicked_at,
    applied_at,
    shared_at,
    copied_text_at,
    printed_at,
    view_count,
    total_time_seconds,
    max_scroll_depth_percent,
    last_device_type,
    last_browser,
    last_os,
    devices_used,
    browsers_used,
    last_city,
    last_region,
    last_country,
    last_ip_address,
    session_count,
    last_session_id,
    first_referrer_url,
    first_referrer_domain,
    first_utm_source,
    first_utm_medium,
    first_utm_campaign,
    external_apply_clicks,
    last_external_apply_url
  ) VALUES (
    NEW.job_id,
    NEW.member_id,
    NEW.event_type = 'view',
    NEW.event_type IN ('apply_click', 'apply_external'),
    NEW.event_type = 'apply_submit',
    NEW.event_type = 'share',
    NEW.event_type = 'copy_text',
    NEW.event_type = 'print',
    CASE WHEN NEW.event_type = 'view' THEN NEW.created_at END,
    CASE WHEN NEW.event_type IN ('view', 'view_end') THEN NEW.created_at END,
    CASE WHEN NEW.event_type IN ('apply_click', 'apply_external') THEN NEW.created_at END,
    CASE WHEN NEW.event_type = 'apply_submit' THEN NEW.created_at END,
    CASE WHEN NEW.event_type = 'share' THEN NEW.created_at END,
    CASE WHEN NEW.event_type = 'copy_text' THEN NEW.created_at END,
    CASE WHEN NEW.event_type = 'print' THEN NEW.created_at END,
    CASE WHEN NEW.event_type = 'view' THEN 1 ELSE 0 END,
    duration_secs,
    scroll_pct,
    NEW.device_type,
    NEW.browser,
    NEW.os,
    CASE WHEN NEW.device_type IS NOT NULL THEN ARRAY[NEW.device_type] ELSE '{}' END,
    CASE WHEN NEW.browser IS NOT NULL THEN ARRAY[NEW.browser] ELSE '{}' END,
    NEW.city,
    NEW.region,
    NEW.country,
    NEW.ip_address,
    CASE WHEN NEW.event_type = 'view' THEN 1 ELSE 0 END,
    NEW.session_id,
    NEW.referrer_url,
    NEW.referrer_domain,
    NEW.utm_source,
    NEW.utm_medium,
    NEW.utm_campaign,
    CASE WHEN NEW.event_type = 'apply_external' THEN 1 ELSE 0 END,
    CASE WHEN NEW.event_type = 'apply_external' THEN NEW.event_data->>'application_url' END
  )
  ON CONFLICT (job_id, member_id) DO UPDATE SET
    -- Flags
    has_viewed = job_member_interactions.has_viewed OR (NEW.event_type = 'view'),
    has_clicked_apply = job_member_interactions.has_clicked_apply OR (NEW.event_type IN ('apply_click', 'apply_external')),
    has_applied = job_member_interactions.has_applied OR (NEW.event_type = 'apply_submit'),
    has_shared = job_member_interactions.has_shared OR (NEW.event_type = 'share'),
    has_copied_text = job_member_interactions.has_copied_text OR (NEW.event_type = 'copy_text'),
    has_printed = job_member_interactions.has_printed OR (NEW.event_type = 'print'),
    
    -- Timestamps
    first_viewed_at = COALESCE(job_member_interactions.first_viewed_at, 
      CASE WHEN NEW.event_type = 'view' THEN NEW.created_at END),
    last_viewed_at = CASE 
      WHEN NEW.event_type IN ('view', 'view_end', 'scroll_depth') THEN NEW.created_at 
      ELSE job_member_interactions.last_viewed_at 
    END,
    apply_clicked_at = COALESCE(job_member_interactions.apply_clicked_at, 
      CASE WHEN NEW.event_type IN ('apply_click', 'apply_external') THEN NEW.created_at END),
    applied_at = COALESCE(job_member_interactions.applied_at, 
      CASE WHEN NEW.event_type = 'apply_submit' THEN NEW.created_at END),
    shared_at = COALESCE(job_member_interactions.shared_at, 
      CASE WHEN NEW.event_type = 'share' THEN NEW.created_at END),
    copied_text_at = COALESCE(job_member_interactions.copied_text_at,
      CASE WHEN NEW.event_type = 'copy_text' THEN NEW.created_at END),
    printed_at = COALESCE(job_member_interactions.printed_at,
      CASE WHEN NEW.event_type = 'print' THEN NEW.created_at END),
    
    -- Counters
    view_count = job_member_interactions.view_count + CASE WHEN NEW.event_type = 'view' THEN 1 ELSE 0 END,
    total_time_seconds = job_member_interactions.total_time_seconds + duration_secs,
    max_scroll_depth_percent = GREATEST(job_member_interactions.max_scroll_depth_percent, scroll_pct),
    external_apply_clicks = job_member_interactions.external_apply_clicks + 
      CASE WHEN NEW.event_type = 'apply_external' THEN 1 ELSE 0 END,
    
    -- Device info (update to latest)
    last_device_type = COALESCE(NEW.device_type, job_member_interactions.last_device_type),
    last_browser = COALESCE(NEW.browser, job_member_interactions.last_browser),
    last_os = COALESCE(NEW.os, job_member_interactions.last_os),
    devices_used = CASE 
      WHEN NEW.device_type IS NOT NULL AND NOT (NEW.device_type = ANY(COALESCE(job_member_interactions.devices_used, '{}')))
      THEN array_append(COALESCE(job_member_interactions.devices_used, '{}'), NEW.device_type)
      ELSE COALESCE(job_member_interactions.devices_used, '{}')
    END,
    browsers_used = CASE 
      WHEN NEW.browser IS NOT NULL AND NOT (NEW.browser = ANY(COALESCE(job_member_interactions.browsers_used, '{}')))
      THEN array_append(COALESCE(job_member_interactions.browsers_used, '{}'), NEW.browser)
      ELSE COALESCE(job_member_interactions.browsers_used, '{}')
    END,
    
    -- Location (update to latest)
    last_city = COALESCE(NEW.city, job_member_interactions.last_city),
    last_region = COALESCE(NEW.region, job_member_interactions.last_region),
    last_country = COALESCE(NEW.country, job_member_interactions.last_country),
    last_ip_address = COALESCE(NEW.ip_address, job_member_interactions.last_ip_address),
    
    -- Session tracking
    session_count = job_member_interactions.session_count + 
      CASE WHEN NEW.event_type = 'view' AND job_member_interactions.last_session_id IS DISTINCT FROM NEW.session_id THEN 1 ELSE 0 END,
    last_session_id = COALESCE(NEW.session_id, job_member_interactions.last_session_id),
    
    -- First touch attribution (only set once)
    first_referrer_url = COALESCE(job_member_interactions.first_referrer_url, NEW.referrer_url),
    first_referrer_domain = COALESCE(job_member_interactions.first_referrer_domain, NEW.referrer_domain),
    first_utm_source = COALESCE(job_member_interactions.first_utm_source, NEW.utm_source),
    first_utm_medium = COALESCE(job_member_interactions.first_utm_medium, NEW.utm_medium),
    first_utm_campaign = COALESCE(job_member_interactions.first_utm_campaign, NEW.utm_campaign),
    
    -- External apply tracking
    last_external_apply_url = CASE 
      WHEN NEW.event_type = 'apply_external' THEN NEW.event_data->>'application_url'
      ELSE job_member_interactions.last_external_apply_url
    END,
    
    updated_at = NOW();
  
  RETURN NEW;
END;
$function$;

-- --- update_legislation_ai_batches_updated_at() ---
CREATE OR REPLACE FUNCTION public.update_legislation_ai_batches_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

-- --- update_legislator_sponsorship_counts() ---
CREATE OR REPLACE FUNCTION public.update_legislator_sponsorship_counts()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_old_legislator_id uuid;
    v_new_legislator_id uuid;
    v_old_classification text;
    v_new_classification text;
BEGIN
    -- Handle DELETE
    IF TG_OP = 'DELETE' THEN
        v_old_legislator_id := OLD.legislator_id;
        v_old_classification := OLD.sponsorship_classification;
        
        IF v_old_legislator_id IS NOT NULL THEN
            IF v_old_classification = 'primary' THEN
                UPDATE public.legislation_legislators
                SET bills_sponsored_count = GREATEST(0, COALESCE(bills_sponsored_count, 0) - 1),
                    updated_at = NOW()
                WHERE id = v_old_legislator_id;
            ELSIF v_old_classification = 'cosponsor' THEN
                UPDATE public.legislation_legislators
                SET bills_cosponsored_count = GREATEST(0, COALESCE(bills_cosponsored_count, 0) - 1),
                    updated_at = NOW()
                WHERE id = v_old_legislator_id;
            END IF;
        END IF;
        
        RETURN OLD;
    END IF;
    
    -- Handle INSERT
    IF TG_OP = 'INSERT' THEN
        v_new_legislator_id := NEW.legislator_id;
        v_new_classification := NEW.sponsorship_classification;
        
        IF v_new_legislator_id IS NOT NULL THEN
            IF v_new_classification = 'primary' THEN
                UPDATE public.legislation_legislators
                SET bills_sponsored_count = COALESCE(bills_sponsored_count, 0) + 1,
                    updated_at = NOW()
                WHERE id = v_new_legislator_id;
            ELSIF v_new_classification = 'cosponsor' THEN
                UPDATE public.legislation_legislators
                SET bills_cosponsored_count = COALESCE(bills_cosponsored_count, 0) + 1,
                    updated_at = NOW()
                WHERE id = v_new_legislator_id;
            END IF;
        END IF;
        
        RETURN NEW;
    END IF;
    
    -- Handle UPDATE
    IF TG_OP = 'UPDATE' THEN
        v_old_legislator_id := OLD.legislator_id;
        v_new_legislator_id := NEW.legislator_id;
        v_old_classification := OLD.sponsorship_classification;
        v_new_classification := NEW.sponsorship_classification;
        
        -- Only process if legislator_id or classification changed
        IF (v_old_legislator_id IS DISTINCT FROM v_new_legislator_id) OR 
           (v_old_classification IS DISTINCT FROM v_new_classification) THEN
            
            -- Decrement old legislator's count
            IF v_old_legislator_id IS NOT NULL THEN
                IF v_old_classification = 'primary' THEN
                    UPDATE public.legislation_legislators
                    SET bills_sponsored_count = GREATEST(0, COALESCE(bills_sponsored_count, 0) - 1),
                        updated_at = NOW()
                    WHERE id = v_old_legislator_id;
                ELSIF v_old_classification = 'cosponsor' THEN
                    UPDATE public.legislation_legislators
                    SET bills_cosponsored_count = GREATEST(0, COALESCE(bills_cosponsored_count, 0) - 1),
                        updated_at = NOW()
                    WHERE id = v_old_legislator_id;
                END IF;
            END IF;
            
            -- Increment new legislator's count
            IF v_new_legislator_id IS NOT NULL THEN
                IF v_new_classification = 'primary' THEN
                    UPDATE public.legislation_legislators
                    SET bills_sponsored_count = COALESCE(bills_sponsored_count, 0) + 1,
                        updated_at = NOW()
                    WHERE id = v_new_legislator_id;
                ELSIF v_new_classification = 'cosponsor' THEN
                    UPDATE public.legislation_legislators
                    SET bills_cosponsored_count = COALESCE(bills_cosponsored_count, 0) + 1,
                        updated_at = NOW()
                    WHERE id = v_new_legislator_id;
                END IF;
            END IF;
        END IF;
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$function$;

-- --- update_member_intro_sent_at() ---
CREATE OR REPLACE FUNCTION public.update_member_intro_sent_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.status = 'sent' THEN
    UPDATE members
    SET intro_sent_at = NEW.sent_at
    WHERE id = NEW.member_id;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- update_membership_eligible() ---
CREATE OR REPLACE FUNCTION public.update_membership_eligible()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.membership_eligible := (
    NEW.date_of_birth IS NULL 
    OR NEW.date_of_birth > (CURRENT_DATE - INTERVAL '36 years')
  );
  RETURN NEW;
END;
$function$;

-- --- update_quick_links_updated_at() ---
CREATE OR REPLACE FUNCTION public.update_quick_links_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- --- update_recipient_click_status(p_campaign_id uuid) ---
CREATE OR REPLACE FUNCTION public.update_recipient_click_status(p_campaign_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE public.email_campaign_recipients ecr
  SET 
    clicked = true,
    first_clicked_at = COALESCE(ecr.first_clicked_at, sub.first_click),
    last_clicked_at = sub.last_click,
    click_count = sub.click_count
  FROM (
    SELECT 
      recipient_id,
      MIN(clicked_at) as first_click,
      MAX(clicked_at) as last_click,
      COUNT(*) as click_count
    FROM public.email_campaign_link_clicks
    WHERE campaign_id = p_campaign_id
      AND recipient_id IS NOT NULL
    GROUP BY recipient_id
  ) sub
  WHERE ecr.id = sub.recipient_id
    AND ecr.campaign_id = p_campaign_id;
END;
$function$;

-- --- update_sync_needs_on_bill_change() ---
CREATE OR REPLACE FUNCTION public.update_sync_needs_on_bill_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF OLD.openstates_data IS DISTINCT FROM NEW.openstates_data THEN
    UPDATE public.legislation_bill_sync_status
    SET needs_sponsor_link = TRUE, updated_at = NOW()
    WHERE bill_id = NEW.id;
  END IF;
  
  IF COALESCE(NEW.version_count, 0) > COALESCE(OLD.version_count, 0) THEN
    UPDATE public.legislation_bill_sync_status
    SET needs_text_extract = TRUE, updated_at = NOW()
    WHERE bill_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$function$;

-- --- update_template_use_count() ---
CREATE OR REPLACE FUNCTION public.update_template_use_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.template_id IS NOT NULL THEN
    UPDATE public.form_templates
    SET use_count = use_count + 1
    WHERE id = NEW.template_id;
  END IF;
  RETURN NEW;
END;
$function$;

-- --- update_updated_at_column() ---
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$;

-- --- update_vote_count() ---
CREATE OR REPLACE FUNCTION public.update_vote_count()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Update the results_data on the form_schema to track vote count
  UPDATE public.form_schemas
  SET results_data = COALESCE(results_data, '{}'::jsonb) || 
    jsonb_build_object('total_votes', (
      SELECT COUNT(*) FROM public.votes WHERE voting_form_id = NEW.voting_form_id
    ))
  WHERE id = NEW.voting_form_id;
  
  RETURN NEW;
END;
$function$;

-- --- upsert_gmail_account(p_email text, p_access_token text, p_refresh_token text, p_encryption_key text) ---
CREATE OR REPLACE FUNCTION public.upsert_gmail_account(p_email text, p_access_token text, p_refresh_token text, p_encryption_key text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.gmail_accounts (email, oauth_token_encrypted, oauth_refresh_token_encrypted, status)
  VALUES (
    p_email,
    pgp_sym_encrypt(p_access_token, p_encryption_key),
    pgp_sym_encrypt(p_refresh_token, p_encryption_key),
    'active'
  )
  ON CONFLICT (email) DO UPDATE SET
    oauth_token_encrypted = pgp_sym_encrypt(p_access_token, p_encryption_key),
    oauth_refresh_token_encrypted = pgp_sym_encrypt(p_refresh_token, p_encryption_key),
    status = 'active',
    updated_at = now();
END;
$function$;

-- --- upsert_knowledge_document(p_source_type text, p_source_table text, p_source_id uuid, p_title text, p_content text, p_metadata jsonb, p_source_bucket text, p_source_file_path text) ---
CREATE OR REPLACE FUNCTION public.upsert_knowledge_document(p_source_type text, p_source_table text, p_source_id uuid, p_title text, p_content text, p_metadata jsonb DEFAULT '{}'::jsonb, p_source_bucket text DEFAULT NULL::text, p_source_file_path text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_id UUID;
  v_content_hash TEXT;
  v_existing_hash TEXT;
BEGIN
  -- Generate content hash
  v_content_hash := md5(p_content);
  
  -- Check for existing document
  IF p_source_bucket IS NOT NULL AND p_source_file_path IS NOT NULL THEN
    SELECT id, content_hash INTO v_doc_id, v_existing_hash
    FROM public.knowledge_documents
    WHERE source_bucket = p_source_bucket 
      AND source_file_path = p_source_file_path
      AND chunk_index = 0;
  ELSIF p_source_table IS NOT NULL AND p_source_id IS NOT NULL THEN
    SELECT id, content_hash INTO v_doc_id, v_existing_hash
    FROM public.knowledge_documents
    WHERE source_type = p_source_type
      AND source_table = p_source_table
      AND source_id = p_source_id
      AND chunk_index = 0;
  END IF;
  
  -- If exists and unchanged, return existing ID
  IF v_doc_id IS NOT NULL AND v_existing_hash = v_content_hash THEN
    RETURN v_doc_id;
  END IF;
  
  -- If exists but changed, update it
  IF v_doc_id IS NOT NULL THEN
    UPDATE public.knowledge_documents
    SET 
      title = p_title,
      content = p_content,
      content_hash = v_content_hash,
      metadata = p_metadata,
      embedding_status = 'pending',
      embedding = NULL,
      updated_at = NOW()
    WHERE id = v_doc_id;
    
    -- Queue for re-embedding
    INSERT INTO public.knowledge_embedding_queue (document_id, priority, status)
    VALUES (v_doc_id, 50, 'pending')
    ON CONFLICT (document_id) DO UPDATE SET status = 'pending', updated_at = NOW();
    
    RETURN v_doc_id;
  END IF;
  
  -- Insert new document
  INSERT INTO public.knowledge_documents (
    source_type, source_table, source_id, source_bucket, source_file_path,
    title, content, content_hash, metadata
  ) VALUES (
    p_source_type, p_source_table, p_source_id, p_source_bucket, p_source_file_path,
    p_title, p_content, v_content_hash, p_metadata
  )
  RETURNING id INTO v_doc_id;
  
  -- Queue for embedding
  INSERT INTO public.knowledge_embedding_queue (document_id, priority, status)
  VALUES (v_doc_id, 100, 'pending');
  
  RETURN v_doc_id;
END;
$function$;

-- --- user_has_committee_access(user_email text) ---
CREATE OR REPLACE FUNCTION public.user_has_committee_access(user_email text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  has_access boolean;
begin
  select exists (
    select 1
    from public.members m
    cross join unnest(m.committee) as user_committee
    inner join public.committees c on c.name = user_committee and c.is_active = true
    where lower(m.email) = lower(user_email)
  ) into has_access;
  
  return has_access;
end;
$function$;


-- =============================================================
-- CANDIDATES FOR DROP - verify with pg_cron and n8n before un-commenting
-- These RPCs are in drift AND appear on the audit's 'orphan RPCs to
-- consider dropping' list. Left commented. Before dropping:
--   1. Check pg_cron.job for any calls
--   2. Search n8n workflows in .n8n/workflows/
--   3. grep the entire /lib and /supabase/functions trees once more
-- =============================================================

/*
DROP FUNCTION IF EXISTS public.get_candidate_full(p_candidate_id uuid);
DROP FUNCTION IF EXISTS public.get_candidate_stats();
DROP FUNCTION IF EXISTS public.get_chapter_overview(school_name_param text);
DROP FUNCTION IF EXISTS public.get_emails_for_mautic_sync(p_offset integer, p_limit integer);
DROP FUNCTION IF EXISTS public.get_member_attendance_stats(member_uuid uuid);
DROP FUNCTION IF EXISTS public.get_member_donations(member_uuid uuid);
DROP FUNCTION IF EXISTS public.get_member_profile_with_pending_changes(p_member_id uuid);
DROP FUNCTION IF EXISTS public.get_top_employers(lim integer);
DROP FUNCTION IF EXISTS public.import_mailchimp_campaign(p_name text, p_subject text, p_audience text, p_send_date timestamp with time zone, p_send_weekday text, p_total_recipients integer, p_successful_deliveries integer, p_soft_bounces integer, p_hard_bounces integer, p_unique_opens integer, p_open_rate numeric, p_total_opens integer, p_unique_clicks integer, p_click_rate numeric, p_total_clicks integer, p_unsubscribes integer, p_abuse_complaints integer, p_times_forwarded integer, p_forwarded_opens integer, p_times_liked_facebook integer, p_unique_id text);
DROP FUNCTION IF EXISTS public.import_mailchimp_recipient(p_campaign_id uuid, p_email text, p_first_name text, p_last_name text, p_member_rating integer, p_reason text, p_description text, p_sent_at timestamp with time zone);
DROP FUNCTION IF EXISTS public.link_recipients_by_mautic_id(p_campaign_id uuid);
DROP FUNCTION IF EXISTS public.record_mautic_click(p_campaign_source_id text, p_email text, p_url text, p_clicked_at timestamp with time zone, p_mautic_lead_id integer, p_ip_address text, p_user_agent text);
DROP FUNCTION IF EXISTS public.record_mautic_donotcontact(p_mautic_lead_id integer, p_email text, p_reason text, p_comments text, p_channel text);
DROP FUNCTION IF EXISTS public.refresh_all_email_campaign_stats();
DROP FUNCTION IF EXISTS public.refresh_campaign_stats(p_campaign_id uuid);
DROP FUNCTION IF EXISTS public.refresh_crm_dashboard_metrics();
DROP FUNCTION IF EXISTS public.refresh_legislation_statistics();
DROP FUNCTION IF EXISTS public.refresh_link_click_counts(p_campaign_id uuid);
DROP FUNCTION IF EXISTS public.refresh_member_email_history();
DROP FUNCTION IF EXISTS public.search_donors(p_state text, p_year_from integer, p_year_to integer, p_min_total numeric, p_max_total numeric, p_party text, p_name_query text, p_individuals_only boolean, p_limit integer, p_offset integer);
DROP FUNCTION IF EXISTS public.upsert_mautic_campaign(p_mautic_email_id integer, p_name text, p_subject text, p_from_name text, p_from_email text, p_reply_to text, p_sent_at timestamp with time zone, p_sent_count integer, p_read_count integer, p_html_content text);
DROP FUNCTION IF EXISTS public.upsert_mautic_recipient(p_campaign_id uuid, p_mautic_stat_id bigint, p_email text, p_mautic_lead_id integer, p_tracking_hash text, p_first_name text, p_last_name text, p_date_sent timestamp with time zone, p_is_read boolean, p_date_read timestamp with time zone, p_open_count integer, p_last_opened timestamp with time zone, p_open_details jsonb, p_is_failed boolean, p_viewed_in_browser boolean, p_retry_count integer, p_source text, p_source_id integer, p_ip_id integer, p_list_id integer);
*/

-- Bodies of drop-candidates (commented; uncomment to backfill instead of drop):
/*
-- get_candidate_full(p_candidate_id uuid)
CREATE OR REPLACE FUNCTION public.get_candidate_full(p_candidate_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'candidate', row_to_json(c),
        'contacts', COALESCE((SELECT jsonb_agg(row_to_json(cc) ORDER BY cc.contact_date DESC) FROM public.candidate_contacts cc WHERE cc.candidate_id = c.id), '[]'::jsonb),
        'endorsements', COALESCE((SELECT jsonb_agg(row_to_json(ce) ORDER BY ce.endorsement_date DESC) FROM public.candidate_endorsements ce WHERE ce.candidate_id = c.id), '[]'::jsonb),
        'news', COALESCE((SELECT jsonb_agg(row_to_json(cn) ORDER BY cn.published_date DESC) FROM public.candidate_news cn WHERE cn.candidate_id = c.id), '[]'::jsonb),
        'election_history', COALESCE((SELECT jsonb_agg(row_to_json(eh) ORDER BY eh.election_year DESC) FROM public.election_history eh WHERE eh.office = c.office AND (eh.district = c.district OR (eh.district IS NULL AND c.district IS NULL))), '[]'::jsonb)
    ) INTO result
    FROM public.candidates c
    WHERE c.id = p_candidate_id;
    RETURN result;
END;
$function$;

-- get_candidate_stats()
CREATE OR REPLACE FUNCTION public.get_candidate_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN jsonb_build_object(
        'total_candidates', (SELECT count(*) FROM public.candidates WHERE election_year = 2026),
        'total_democrats', (SELECT count(*) FROM public.candidates WHERE party = 'Democratic' AND election_year = 2026),
        'total_republicans', (SELECT count(*) FROM public.candidates WHERE party = 'Republican' AND election_year = 2026),
        'total_libertarians', (SELECT count(*) FROM public.candidates WHERE party = 'Libertarian' AND election_year = 2026),
        'young_dems', (SELECT count(*) FROM public.candidates WHERE is_young_dem = true AND election_year = 2026),
        'avg_young_dem_age', (SELECT round(avg(estimated_age), 1) FROM public.candidates WHERE is_young_dem = true AND election_year = 2026),
        'moyd_endorsed', (SELECT count(*) FROM public.candidates WHERE moyd_endorsed = true AND election_year = 2026),
        'moyd_contacted', (SELECT count(*) FROM public.candidates WHERE moyd_contacted = true AND election_year = 2026),
        'with_photos', (SELECT count(*) FROM public.candidates WHERE photo_url IS NOT NULL AND photo_url <> '' AND election_year = 2026),
        'with_mec_linked', (SELECT count(*) FROM public.candidates WHERE mec_committee_ids IS NOT NULL AND array_length(mec_committee_ids, 1) > 0 AND election_year = 2026),
        'with_member_linked', (SELECT count(*) FROM public.candidates WHERE member_id IS NOT NULL AND election_year = 2026),
        'avg_age', (SELECT round(avg(estimated_age), 1) FROM public.candidates WHERE estimated_age IS NOT NULL AND election_year = 2026),
        'contested_races', jsonb_build_object(
            'us_house', (SELECT count(*) FROM (SELECT district FROM public.candidates WHERE party='Democratic' AND office LIKE 'U.S.%' AND election_year=2026 INTERSECT SELECT district FROM public.candidates WHERE party='Republican' AND office LIKE 'U.S.%' AND election_year=2026) x),
            'state_senate', (SELECT count(*) FROM (SELECT district FROM public.candidates WHERE party='Democratic' AND office LIKE '%Senator%' AND election_year=2026 INTERSECT SELECT district FROM public.candidates WHERE party='Republican' AND office LIKE '%Senator%' AND election_year=2026) x),
            'state_house', (SELECT count(*) FROM (SELECT district FROM public.candidates WHERE party='Democratic' AND office LIKE '%Representative%' AND election_year=2026 INTERSECT SELECT district FROM public.candidates WHERE party='Republican' AND office LIKE '%Representative%' AND election_year=2026) x),
            'total', (SELECT count(*) FROM (
                SELECT office || COALESCE(district,'') FROM public.candidates WHERE party='Democratic' AND office NOT LIKE '%Judge%' AND election_year=2026
                INTERSECT
                SELECT office || COALESCE(district,'') FROM public.candidates WHERE party='Republican' AND office NOT LIKE '%Judge%' AND election_year=2026
            ) x)
        ),
        'uncontested_dem', (SELECT count(DISTINCT office || COALESCE(district,'')) FROM public.candidates WHERE party='Democratic' AND office || COALESCE(district,'') NOT IN (SELECT office || COALESCE(district,'') FROM public.candidates WHERE party='Republican' AND election_year=2026) AND office NOT LIKE '%Judge%' AND election_year=2026),
        'by_office_level', (SELECT jsonb_object_agg(office_level, cnt) FROM (SELECT office_level, count(*) as cnt FROM public.candidates WHERE election_year=2026 GROUP BY office_level) sub),
        'young_dems_list', (SELECT jsonb_agg(row_to_json(sub)) FROM (SELECT district, name, estimated_age as age, office FROM public.candidates WHERE is_young_dem = true AND election_year=2026 ORDER BY district::int NULLS LAST) sub),
        'election_history_count', (SELECT count(*) FROM public.election_history),
        'historical_candidates_count', (SELECT count(*) FROM public.historical_candidates)
    );
END;
$function$;

-- get_chapter_overview(school_name_param text)
CREATE OR REPLACE FUNCTION public.get_chapter_overview(school_name_param text)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  result JSON;
  standardized_name TEXT;
BEGIN
  -- Create the standardized name format
  standardized_name := school_name_param || ' Governing Documents';
  
  SELECT json_build_object(
    'chapter_name', standardized_name,
    'school_name', school_name_param,
    'member_count', (
      SELECT COUNT(*) 
      FROM public.members 
      WHERE chapter_name ILIKE '%' || school_name_param || '%'
    ),
    'members', (
      SELECT json_agg(
        json_build_object(
          'name', name,
          'email', email,
          'chapter_position', chapter_position,
          'date_joined', date_joined
        ) ORDER BY name
      )
      FROM public.members
      WHERE chapter_name ILIKE '%' || school_name_param || '%'
    ),
    'documents', (
      SELECT json_agg(
        json_build_object(
          'document_type', document_type,
          'public_url', public_url,
          'uploaded_at', uploaded_at,
          'file_size', file_size
        ) ORDER BY document_type
      )
      FROM public.chapter_documents
      WHERE chapter_name = standardized_name
    ),
    'chapter_type', (
      SELECT chapter_type 
      FROM public.chapter_documents 
      WHERE chapter_name = standardized_name 
      LIMIT 1
    )
  ) INTO result;
  
  RETURN result;
END;
$function$;

-- get_emails_for_mautic_sync(p_offset integer, p_limit integer)
CREATE OR REPLACE FUNCTION public.get_emails_for_mautic_sync(p_offset integer DEFAULT 0, p_limit integer DEFAULT 1000)
 RETURNS TABLE(email text, first_name text, last_name text, city text, state text, zipcode text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (dc.contact_value)
    dc.contact_value as email,
    de.full_name as first_name,  -- will parse in Python
    '' as last_name,
    de.current_city as city,
    de.current_state as state,
    de.current_zip as zipcode
  FROM public.donor_contacts dc
  JOIN public.donor_enrichment de ON dc.donor_id = de.donor_id
  WHERE dc.contact_type = 'email'
    AND dc.confidence IN ('verified_full_dns', 'verified_mx', 'verified_spf', 'high', 'medium')
    AND ('mec' = ANY(de.data_sources) OR 'fec' = ANY(de.data_sources))
  ORDER BY dc.contact_value, dc.id
  OFFSET p_offset
  LIMIT p_limit;
END;
$function$;

-- get_member_attendance_stats(member_uuid uuid)
CREATE OR REPLACE FUNCTION public.get_member_attendance_stats(member_uuid uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  total_meetings INT;
  attended_meetings INT;
  attendance_rate DECIMAL;
  total_minutes INT;
BEGIN
  -- Count total meetings
  SELECT COUNT(*) INTO total_meetings FROM meetings;
  
  -- Count meetings attended by this member
  SELECT COUNT(*) INTO attended_meetings 
  FROM meeting_attendance 
  WHERE member_id = member_uuid;
  
  -- Calculate attendance rate
  attendance_rate = CASE 
    WHEN total_meetings > 0 THEN (attended_meetings::DECIMAL / total_meetings * 100)
    ELSE 0 
  END;
  
  -- Sum total time in meetings
  SELECT COALESCE(SUM(total_duration_minutes), 0) INTO total_minutes
  FROM meeting_attendance
  WHERE member_id = member_uuid;
  
  RETURN json_build_object(
    'total_meetings', total_meetings,
    'attended_meetings', attended_meetings,
    'missed_meetings', total_meetings - attended_meetings,
    'attendance_rate', ROUND(attendance_rate, 2),
    'total_minutes', total_minutes,
    'total_hours', ROUND(total_minutes::DECIMAL / 60, 1)
  );
END;
$function$;

-- get_member_donations(member_uuid uuid)
CREATE OR REPLACE FUNCTION public.get_member_donations(member_uuid uuid)
 RETURNS TABLE(total_amount numeric, donation_count integer, first_donation timestamp with time zone, last_donation timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    d.total_donated,
    d.donation_count,
    d.first_donation_date,
    d.last_donation_date
  FROM donors d
  WHERE d.member_id = member_uuid;
END;
$function$;

-- get_member_profile_with_pending_changes(p_member_id uuid)
CREATE OR REPLACE FUNCTION public.get_member_profile_with_pending_changes(p_member_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_member_data JSONB;
  v_pending_changes JSONB;
  v_field_record RECORD;
BEGIN
  -- Get base member data
  SELECT to_jsonb(m.*) INTO v_member_data
  FROM members m
  WHERE m.id = p_member_id;
  
  IF v_member_data IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Get all pending changes for this member
  FOR v_field_record IN
    SELECT DISTINCT ON (field_name) 
      field_name, 
      new_value, 
      change_type
    FROM member_profile_changes
    WHERE member_id = p_member_id 
      AND status = 'pending'
    ORDER BY field_name, created_at DESC
  LOOP
    -- Apply the pending change to the returned data
    IF v_field_record.change_type = 'delete' THEN
      v_member_data := jsonb_set(v_member_data, ARRAY[v_field_record.field_name], 'null'::jsonb);
    ELSE
      v_member_data := jsonb_set(
        v_member_data, 
        ARRAY[v_field_record.field_name], 
        to_jsonb(v_field_record.new_value)
      );
    END IF;
  END LOOP;
  
  RETURN v_member_data;
END;
$function$;

-- get_top_employers(lim integer)
CREATE OR REPLACE FUNCTION public.get_top_employers(lim integer DEFAULT 200)
 RETURNS TABLE(employer text, donor_count bigint)
 LANGUAGE sql
 STABLE
AS $function$
    SELECT UPPER(TRIM(f.employer)) as employer,
           COUNT(DISTINCT f.contributor_name) as donor_count
    FROM public.fec_contributions f
    WHERE f.state = 'MO'
      AND f.employer IS NOT NULL
      AND TRIM(f.employer) != ''
      AND UPPER(TRIM(f.employer)) NOT IN (
        'UNKNOWN','UNEMPLOYED','REALTOR','FARMER','OWNER','TEACHER',
        'CONSULTANT','ATTEMPTED','LAWYER','BUSINESS OWNER','SELF EMPLOYEED',
        'UNK','NO EMPLOYER LISTED','COMMUNITY VOLUNTEER','PIPEFITTER',
        'PIPEFITTERS','NOT APPLICABLE','NA','N/A','NONE','SELF',
        'SELF-EMPLOYED','SELF EMPLOYED','RETIRED','NOT EMPLOYED',
        'HOMEMAKER','INFORMATION REQUESTED','HOUSEWIFE','ATTORNEY',
        'PHYSICIAN','STUDENT','REQUESTED',
        'INFORMATION REQUESTED PER BEST EFFORTS'
      )
    GROUP BY UPPER(TRIM(f.employer))
    ORDER BY donor_count DESC
    LIMIT lim;
$function$;

-- import_mailchimp_campaign(p_name text, p_subject text, p_audience text, p_send_date timestamp with time zone, p_send_weekday text, p_total_recipients integer, p_successful_deliveries integer, p_soft_bounces integer, p_hard_bounces integer, p_unique_opens integer, p_open_rate numeric, p_total_opens integer, p_unique_clicks integer, p_click_rate numeric, p_total_clicks integer, p_unsubscribes integer, p_abuse_complaints integer, p_times_forwarded integer, p_forwarded_opens integer, p_times_liked_facebook integer, p_unique_id text)
CREATE OR REPLACE FUNCTION public.import_mailchimp_campaign(p_name text, p_subject text, p_audience text, p_send_date timestamp with time zone, p_send_weekday text, p_total_recipients integer, p_successful_deliveries integer, p_soft_bounces integer, p_hard_bounces integer, p_unique_opens integer, p_open_rate numeric, p_total_opens integer, p_unique_clicks integer, p_click_rate numeric, p_total_clicks integer, p_unsubscribes integer, p_abuse_complaints integer, p_times_forwarded integer DEFAULT 0, p_forwarded_opens integer DEFAULT 0, p_times_liked_facebook integer DEFAULT 0, p_unique_id text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_campaign_id UUID;
  v_total_bounces INT;
BEGIN
  v_total_bounces := p_soft_bounces + p_hard_bounces;
  
  INSERT INTO public.email_campaigns (
    source,
    source_campaign_id,
    name,
    subject,
    audience_name,
    sent_at,
    send_weekday,
    total_recipients,
    total_sent,
    total_delivered,
    total_soft_bounces,
    total_hard_bounces,
    total_bounces,
    unique_opens,
    open_rate,
    total_opens,
    unique_clicks,
    click_rate,
    total_clicks,
    total_unsubscribes,
    total_complaints,
    times_forwarded,
    forwarded_opens,
    times_liked_facebook,
    click_to_open_rate
  ) VALUES (
    'mailchimp',
    p_unique_id,
    p_name,
    p_subject,
    p_audience,
    p_send_date,
    p_send_weekday,
    p_total_recipients,
    p_total_recipients, -- sent = recipients for Mailchimp
    p_successful_deliveries,
    p_soft_bounces,
    p_hard_bounces,
    v_total_bounces,
    p_unique_opens,
    p_open_rate,
    p_total_opens,
    p_unique_clicks,
    p_click_rate,
    p_total_clicks,
    p_unsubscribes,
    p_abuse_complaints,
    p_times_forwarded,
    p_forwarded_opens,
    p_times_liked_facebook,
    CASE WHEN p_unique_opens > 0 
      THEN ROUND(p_unique_clicks::DECIMAL / p_unique_opens * 100, 2)
      ELSE 0 
    END
  )
  ON CONFLICT (source, source_campaign_id) 
  WHERE source_campaign_id IS NOT NULL
  DO UPDATE SET
    name = EXCLUDED.name,
    subject = EXCLUDED.subject,
    total_recipients = EXCLUDED.total_recipients,
    total_delivered = EXCLUDED.total_delivered,
    unique_opens = EXCLUDED.unique_opens,
    total_opens = EXCLUDED.total_opens,
    unique_clicks = EXCLUDED.unique_clicks,
    total_clicks = EXCLUDED.total_clicks,
    updated_at = NOW()
  RETURNING id INTO v_campaign_id;
  
  RETURN v_campaign_id;
END;
$function$;

-- import_mailchimp_recipient(p_campaign_id uuid, p_email text, p_first_name text, p_last_name text, p_member_rating integer, p_reason text, p_description text, p_sent_at timestamp with time zone)
CREATE OR REPLACE FUNCTION public.import_mailchimp_recipient(p_campaign_id uuid, p_email text, p_first_name text DEFAULT NULL::text, p_last_name text DEFAULT NULL::text, p_member_rating integer DEFAULT NULL::integer, p_reason text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_sent_at timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_recipient_id UUID;
  v_unsubscribed BOOLEAN := FALSE;
  v_subscriber_id UUID;
BEGIN
  -- Check if this is an unsubscribe record
  IF p_reason IS NOT NULL AND p_reason != '' THEN
    v_unsubscribed := TRUE;
  END IF;
  
  -- Try to find matching subscriber
  SELECT id INTO v_subscriber_id
  FROM public.subscribers
  WHERE LOWER(email) = LOWER(p_email)
  LIMIT 1;
  
  INSERT INTO public.email_campaign_recipients (
    campaign_id,
    subscriber_id,
    source,
    email,
    first_name,
    last_name,
    full_name,
    sent_at,
    opened,
    open_count,
    member_rating,
    unsubscribed,
    unsubscribe_reason,
    unsubscribe_description
  ) VALUES (
    p_campaign_id,
    v_subscriber_id,
    'mailchimp',
    LOWER(p_email),
    p_first_name,
    p_last_name,
    TRIM(COALESCE(p_first_name, '') || ' ' || COALESCE(p_last_name, '')),
    COALESCE(p_sent_at, (SELECT sent_at FROM public.email_campaigns WHERE id = p_campaign_id)),
    p_member_rating >= 2, -- Assume opened if rating >= 2
    CASE WHEN p_member_rating >= 2 THEN 1 ELSE 0 END,
    p_member_rating,
    v_unsubscribed,
    p_reason,
    p_description
  )
  ON CONFLICT (campaign_id, email) 
  DO UPDATE SET
    subscriber_id = COALESCE(email_campaign_recipients.subscriber_id, EXCLUDED.subscriber_id),
    first_name = COALESCE(EXCLUDED.first_name, email_campaign_recipients.first_name),
    last_name = COALESCE(EXCLUDED.last_name, email_campaign_recipients.last_name),
    member_rating = COALESCE(EXCLUDED.member_rating, email_campaign_recipients.member_rating),
    unsubscribed = EXCLUDED.unsubscribed OR email_campaign_recipients.unsubscribed,
    unsubscribe_reason = COALESCE(EXCLUDED.unsubscribe_reason, email_campaign_recipients.unsubscribe_reason),
    updated_at = NOW()
  RETURNING id INTO v_recipient_id;
  
  RETURN v_recipient_id;
END;
$function$;

-- link_recipients_by_mautic_id(p_campaign_id uuid)
CREATE OR REPLACE FUNCTION public.link_recipients_by_mautic_id(p_campaign_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(updated_count integer)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_updated INT := 0;
BEGIN
  WITH updated AS (
    UPDATE public.email_campaign_recipients ecr
    SET subscriber_id = s.id,
        updated_at = NOW()
    FROM public.subscribers s
    WHERE ecr.mautic_lead_id = s.mautic_id
    AND ecr.subscriber_id IS NULL
    AND s.mautic_id IS NOT NULL
    AND (p_campaign_id IS NULL OR ecr.campaign_id = p_campaign_id)
    RETURNING ecr.id
  )
  SELECT COUNT(*) INTO v_updated FROM updated;
  
  RETURN QUERY SELECT v_updated;
END;
$function$;

-- record_mautic_click(p_campaign_source_id text, p_email text, p_url text, p_clicked_at timestamp with time zone, p_mautic_lead_id integer, p_ip_address text, p_user_agent text)
CREATE OR REPLACE FUNCTION public.record_mautic_click(p_campaign_source_id text, p_email text, p_url text, p_clicked_at timestamp with time zone DEFAULT now(), p_mautic_lead_id integer DEFAULT NULL::integer, p_ip_address text DEFAULT NULL::text, p_user_agent text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_campaign_id UUID;
  v_link_id UUID;
  v_recipient_id UUID;
  v_subscriber_id UUID;
BEGIN
  -- Find the campaign
  SELECT id INTO v_campaign_id
  FROM public.email_campaigns
  WHERE source = 'mautic' AND source_campaign_id = p_campaign_source_id;
  
  IF v_campaign_id IS NULL THEN
    RETURN; -- Campaign not found, skip
  END IF;
  
  -- Find or create the link
  INSERT INTO public.email_campaign_links (campaign_id, url, source, source_link_id)
  VALUES (v_campaign_id, p_url, 'mautic', NULL)
  ON CONFLICT (campaign_id, url) DO NOTHING;
  
  SELECT id INTO v_link_id
  FROM public.email_campaign_links
  WHERE campaign_id = v_campaign_id AND url = p_url;
  
  -- Find the recipient
  SELECT id, subscriber_id INTO v_recipient_id, v_subscriber_id
  FROM public.email_campaign_recipients
  WHERE campaign_id = v_campaign_id 
    AND (LOWER(email) = LOWER(p_email) OR mautic_lead_id = p_mautic_lead_id)
  LIMIT 1;
  
  -- Record the click
  INSERT INTO public.email_campaign_link_clicks (
    campaign_id,
    link_id,
    recipient_id,
    subscriber_id,
    email,
    url,
    clicked_at,
    ip_address,
    user_agent
  ) VALUES (
    v_campaign_id,
    v_link_id,
    v_recipient_id,
    v_subscriber_id,
    LOWER(p_email),
    p_url,
    p_clicked_at,
    p_ip_address,
    p_user_agent
  );
  
  -- Update recipient click stats
  IF v_recipient_id IS NOT NULL THEN
    UPDATE public.email_campaign_recipients
    SET clicked = TRUE,
        first_clicked_at = COALESCE(first_clicked_at, p_clicked_at),
        last_clicked_at = p_clicked_at,
        click_count = click_count + 1,
        updated_at = NOW()
    WHERE id = v_recipient_id;
  END IF;
END;
$function$;

-- record_mautic_donotcontact(p_mautic_lead_id integer, p_email text, p_reason text, p_comments text, p_channel text)
CREATE OR REPLACE FUNCTION public.record_mautic_donotcontact(p_mautic_lead_id integer, p_email text, p_reason text, p_comments text DEFAULT NULL::text, p_channel text DEFAULT 'email'::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Update all recipient records for this email
  UPDATE public.email_campaign_recipients
  SET
    bounced = CASE WHEN p_reason = 'bounced' THEN TRUE ELSE bounced END,
    bounced_at = CASE WHEN p_reason = 'bounced' THEN NOW() ELSE bounced_at END,
    bounce_type = CASE WHEN p_reason = 'bounced' THEN 'hard' ELSE bounce_type END,
    bounce_reason = CASE WHEN p_reason = 'bounced' THEN p_comments ELSE bounce_reason END,
    unsubscribed = CASE WHEN p_reason IN ('unsubscribed', 'manual') THEN TRUE ELSE unsubscribed END,
    unsubscribed_at = CASE WHEN p_reason IN ('unsubscribed', 'manual') THEN NOW() ELSE unsubscribed_at END,
    unsubscribe_reason = CASE WHEN p_reason IN ('unsubscribed', 'manual') THEN p_reason ELSE unsubscribe_reason END,
    unsubscribe_description = CASE WHEN p_reason IN ('unsubscribed', 'manual') THEN p_comments ELSE unsubscribe_description END,
    complained = CASE WHEN p_reason = 'spam' THEN TRUE ELSE complained END,
    complained_at = CASE WHEN p_reason = 'spam' THEN NOW() ELSE complained_at END,
    updated_at = NOW()
  WHERE LOWER(email) = LOWER(p_email)
    OR mautic_lead_id = p_mautic_lead_id;
    
  -- Also update subscriber status if unsubscribed
  IF p_reason IN ('unsubscribed', 'manual', 'spam') THEN
    UPDATE public.subscribers
    SET subscription_status = 'unsubscribed',
        updated_at = NOW()
    WHERE LOWER(email) = LOWER(p_email)
      OR mautic_id = p_mautic_lead_id;
  END IF;
END;
$function$;

-- refresh_all_email_campaign_stats()
CREATE OR REPLACE FUNCTION public.refresh_all_email_campaign_stats()
 RETURNS TABLE(campaign_id uuid, recipients integer, opened integer, clicked integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT 
      ecr.campaign_id,
      COUNT(*) as total_count,
      COUNT(*) FILTER (WHERE sent_at IS NOT NULL) as sent_count,
      COUNT(*) FILTER (WHERE delivered_at IS NOT NULL) as delivered_count,
      COUNT(*) FILTER (WHERE opened = true) as opened_count,
      COUNT(*) FILTER (WHERE clicked = true) as clicked_count,
      COUNT(*) FILTER (WHERE bounced = true) as bounced_count,
      COUNT(*) FILTER (WHERE failed = true) as failed_count,
      COUNT(*) FILTER (WHERE unsubscribed = true) as unsubscribed_count
    FROM public.email_campaign_recipients ecr
    GROUP BY ecr.campaign_id
  )
  UPDATE public.email_campaigns ec
  SET 
    total_recipients = COALESCE(s.total_count, 0),
    total_sent = COALESCE(s.sent_count, 0),
    total_delivered = COALESCE(s.delivered_count, 0),
    total_opens = COALESCE(s.opened_count, 0),
    unique_opens = COALESCE(s.opened_count, 0),
    total_clicks = COALESCE(s.clicked_count, 0),
    unique_clicks = COALESCE(s.clicked_count, 0),
    total_bounces = COALESCE(s.bounced_count, 0),
    total_failed = COALESCE(s.failed_count, 0),
    total_unsubscribes = COALESCE(s.unsubscribed_count, 0),
    open_rate = CASE 
      WHEN COALESCE(s.sent_count, 0) > 0 
      THEN ROUND((COALESCE(s.opened_count, 0)::numeric / s.sent_count::numeric) * 100, 2)::text
      ELSE '0.00'
    END,
    click_rate = CASE 
      WHEN COALESCE(s.sent_count, 0) > 0 
      THEN ROUND((COALESCE(s.clicked_count, 0)::numeric / s.sent_count::numeric) * 100, 2)::text
      ELSE '0.00'
    END,
    updated_at = NOW()
  FROM stats s
  WHERE ec.id = s.campaign_id
  RETURNING ec.id, s.total_count::int, s.opened_count::int, s.clicked_count::int;
END;
$function$;

-- refresh_campaign_stats(p_campaign_id uuid)
CREATE OR REPLACE FUNCTION public.refresh_campaign_stats(p_campaign_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Update recipient click status from clicks table
  PERFORM public.update_recipient_click_status(p_campaign_id);
  
  -- Update link click counts
  PERFORM public.refresh_link_click_counts(p_campaign_id);
  
  -- Force a stats refresh
  UPDATE public.email_campaigns ec
  SET 
    total_recipients = COALESCE(sub.total_count, 0),
    total_sent = COALESCE(sub.sent_count, 0),
    total_delivered = COALESCE(sub.delivered_count, 0),
    total_opens = COALESCE(sub.opened_count, 0),
    unique_opens = COALESCE(sub.opened_count, 0),
    total_clicks = COALESCE(sub.clicked_count, 0),
    unique_clicks = COALESCE(sub.clicked_count, 0),
    total_bounces = COALESCE(sub.bounced_count, 0),
    total_failed = COALESCE(sub.failed_count, 0),
    total_unsubscribes = COALESCE(sub.unsubscribed_count, 0),
    open_rate = CASE 
      WHEN COALESCE(sub.sent_count, 0) > 0 
      THEN ROUND((COALESCE(sub.opened_count, 0)::numeric / sub.sent_count::numeric) * 100, 2)::text
      ELSE '0.00'
    END,
    click_rate = CASE 
      WHEN COALESCE(sub.sent_count, 0) > 0 
      THEN ROUND((COALESCE(sub.clicked_count, 0)::numeric / sub.sent_count::numeric) * 100, 2)::text
      ELSE '0.00'
    END,
    updated_at = NOW()
  FROM (
    SELECT 
      campaign_id,
      COUNT(*) as total_count,
      COUNT(*) FILTER (WHERE sent_at IS NOT NULL) as sent_count,
      COUNT(*) FILTER (WHERE delivered_at IS NOT NULL) as delivered_count,
      COUNT(*) FILTER (WHERE opened = true) as opened_count,
      COUNT(*) FILTER (WHERE clicked = true) as clicked_count,
      COUNT(*) FILTER (WHERE bounced = true) as bounced_count,
      COUNT(*) FILTER (WHERE failed = true) as failed_count,
      COUNT(*) FILTER (WHERE unsubscribed = true) as unsubscribed_count
    FROM public.email_campaign_recipients
    WHERE campaign_id = p_campaign_id
    GROUP BY campaign_id
  ) sub
  WHERE ec.id = p_campaign_id;
END;
$function$;

-- refresh_crm_dashboard_metrics()
CREATE OR REPLACE FUNCTION public.refresh_crm_dashboard_metrics()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_metrics_id UUID;
  v_total_members INTEGER;
  v_total_members_with_phone INTEGER;
  v_total_subscribers INTEGER;
  v_total_donors INTEGER;
  v_total_chapters INTEGER;
  v_total_chartered_chapters INTEGER;
  v_total_college_chapters INTEGER;
  v_total_highschool_chapters INTEGER;
  v_total_county_chapters INTEGER;
  v_total_unique_colleges INTEGER;
  v_total_unique_high_schools INTEGER;
  v_total_unique_counties INTEGER;
  v_total_unique_cds INTEGER;
  v_total_unique_house INTEGER;
  v_total_unique_senate INTEGER;
  v_total_donations_amount NUMERIC;
  v_total_donation_count INTEGER;
  v_average_donation NUMERIC;
  v_total_recurring_donors INTEGER;
  v_donations_this_month NUMERIC;
  v_donations_this_year NUMERIC;
  v_total_slack_messages INTEGER;
  v_slack_messages_this_month INTEGER;
  v_total_social_impressions BIGINT;
  v_new_members_week INTEGER;
  v_new_members_month INTEGER;
  v_new_members_year INTEGER;
  v_new_subscribers_month INTEGER;
  v_total_campaigns INTEGER;
  v_campaigns_sent INTEGER;
  v_total_emails_sent INTEGER;
  v_total_emails_opened INTEGER;
  v_total_emails_clicked INTEGER;
  v_avg_open_rate NUMERIC;
  v_avg_click_rate NUMERIC;
  v_total_events INTEGER;
  v_upcoming_events INTEGER;
  v_total_attendees INTEGER;
  v_age_14_17 INTEGER;
  v_age_18_21 INTEGER;
  v_age_22_25 INTEGER;
  v_age_26_30 INTEGER;
  v_age_31_36 INTEGER;
  v_age_unknown INTEGER;
  v_avg_age NUMERIC;
BEGIN
  -- Get or create the metrics row
  SELECT id INTO v_metrics_id FROM public.crm_dashboard_metrics LIMIT 1;
  
  IF v_metrics_id IS NULL THEN
    INSERT INTO public.crm_dashboard_metrics (id) VALUES (gen_random_uuid())
    RETURNING id INTO v_metrics_id;
  END IF;

  -- =========================================================================
  -- CORE COUNTS
  -- NOTE: All member queries exclude membership_eligible = FALSE
  -- =========================================================================
  
  -- Total members (excluding ineligible)
  SELECT COUNT(*) INTO v_total_members 
  FROM public.members 
  WHERE membership_eligible IS NOT FALSE;
  
  -- Members with phone numbers (excluding ineligible)
  SELECT COUNT(*) INTO v_total_members_with_phone 
  FROM public.members 
  WHERE phone IS NOT NULL AND phone != ''
    AND membership_eligible IS NOT FALSE;
  
  -- Total subscribers (from public schema explicitly)
  SELECT COUNT(*) INTO v_total_subscribers 
  FROM public.subscribers;
  
  -- Total donors
  SELECT COUNT(*) INTO v_total_donors FROM public.donors;
  
  -- Chapter counts
  SELECT COUNT(*) INTO v_total_chapters FROM public.chapters;
  SELECT COUNT(*) INTO v_total_chartered_chapters FROM public.chapters WHERE is_chartered = true;
  SELECT COUNT(*) INTO v_total_college_chapters FROM public.chapters WHERE chapter_type = 'college';
  SELECT COUNT(*) INTO v_total_highschool_chapters FROM public.chapters WHERE chapter_type = 'highschool';
  SELECT COUNT(*) INTO v_total_county_chapters FROM public.chapters WHERE chapter_type = 'county';
  
  -- Unique counts from members (excluding ineligible)
  SELECT COUNT(DISTINCT college) INTO v_total_unique_colleges 
  FROM public.members 
  WHERE college IS NOT NULL AND college != ''
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(DISTINCT high_school) INTO v_total_unique_high_schools 
  FROM public.members 
  WHERE high_school IS NOT NULL AND high_school != ''
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(DISTINCT county) INTO v_total_unique_counties 
  FROM public.members 
  WHERE county IS NOT NULL AND county != ''
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(DISTINCT congressional_district) INTO v_total_unique_cds 
  FROM public.members 
  WHERE congressional_district IS NOT NULL AND congressional_district != ''
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(DISTINCT house_district) INTO v_total_unique_house 
  FROM public.members 
  WHERE house_district IS NOT NULL AND house_district != ''
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(DISTINCT senate_district) INTO v_total_unique_senate 
  FROM public.members 
  WHERE senate_district IS NOT NULL AND senate_district != ''
    AND membership_eligible IS NOT FALSE;

  -- =========================================================================
  -- FINANCIAL METRICS
  -- =========================================================================
  
  SELECT COALESCE(SUM(amount), 0), COUNT(*) 
  INTO v_total_donations_amount, v_total_donation_count
  FROM public.donations WHERE status = 'completed';
  
  v_average_donation := CASE WHEN v_total_donation_count > 0 
    THEN v_total_donations_amount / v_total_donation_count 
    ELSE 0 END;
  
  SELECT COUNT(*) INTO v_total_recurring_donors 
  FROM public.donors WHERE is_recurring_donor = true;
  
  SELECT COALESCE(SUM(amount), 0) INTO v_donations_this_month
  FROM public.donations 
  WHERE status = 'completed' 
    AND donation_date >= date_trunc('month', CURRENT_DATE);
  
  SELECT COALESCE(SUM(amount), 0) INTO v_donations_this_year
  FROM public.donations 
  WHERE status = 'completed' 
    AND donation_date >= date_trunc('year', CURRENT_DATE);

  -- =========================================================================
  -- ENGAGEMENT METRICS
  -- =========================================================================
  
  SELECT COUNT(*) INTO v_total_slack_messages FROM public.slack_messages WHERE deleted_at IS NULL;
  
  SELECT COUNT(*) INTO v_slack_messages_this_month 
  FROM public.slack_messages 
  WHERE deleted_at IS NULL 
    AND posted_at >= date_trunc('month', CURRENT_DATE);
  
  -- Social media stats (optional table)
  BEGIN
    SELECT COALESCE(SUM(impressions), 0) INTO v_total_social_impressions
    FROM public.social_media_stats;
  EXCEPTION WHEN undefined_table THEN
    v_total_social_impressions := 0;
  END;

  -- =========================================================================
  -- TIME-BASED METRICS (excluding ineligible members)
  -- =========================================================================
  
  SELECT COUNT(*) INTO v_new_members_week
  FROM public.members 
  WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_new_members_month
  FROM public.members 
  WHERE created_at >= date_trunc('month', CURRENT_DATE)
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_new_members_year
  FROM public.members 
  WHERE created_at >= date_trunc('year', CURRENT_DATE)
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_new_subscribers_month
  FROM public.subscribers 
  WHERE created_at >= date_trunc('month', CURRENT_DATE);

  -- =========================================================================
  -- CAMPAIGN METRICS (optional table)
  -- =========================================================================
  
  BEGIN
    SELECT COUNT(*) INTO v_total_campaigns FROM public.campaigns;
    SELECT COUNT(*) INTO v_campaigns_sent FROM public.campaigns WHERE status = 'sent';
    
    SELECT 
      COALESCE(SUM(total_sent), 0),
      COALESCE(SUM(total_opened), 0),
      COALESCE(SUM(total_clicked), 0)
    INTO v_total_emails_sent, v_total_emails_opened, v_total_emails_clicked
    FROM public.campaigns WHERE status = 'sent';
    
    v_avg_open_rate := CASE WHEN v_total_emails_sent > 0 
      THEN (v_total_emails_opened::NUMERIC / v_total_emails_sent) * 100 
      ELSE 0 END;
    
    v_avg_click_rate := CASE WHEN v_total_emails_opened > 0 
      THEN (v_total_emails_clicked::NUMERIC / v_total_emails_opened) * 100 
      ELSE 0 END;
  EXCEPTION WHEN undefined_table THEN
    v_total_campaigns := 0;
    v_campaigns_sent := 0;
    v_total_emails_sent := 0;
    v_total_emails_opened := 0;
    v_total_emails_clicked := 0;
    v_avg_open_rate := 0;
    v_avg_click_rate := 0;
  END;

  -- =========================================================================
  -- EVENT METRICS (optional table)
  -- =========================================================================
  
  BEGIN
    SELECT COUNT(*) INTO v_total_events FROM public.events;
    
    SELECT COUNT(*) INTO v_upcoming_events 
    FROM public.events WHERE event_date > NOW() AND status = 'published';
    
    SELECT COALESCE(SUM(attendee_count), 0) INTO v_total_attendees FROM public.events;
  EXCEPTION WHEN undefined_table THEN
    v_total_events := 0;
    v_upcoming_events := 0;
    v_total_attendees := 0;
  END;

  -- =========================================================================
  -- AGE CALCULATIONS (excluding ineligible members)
  -- =========================================================================
  
  SELECT COUNT(*) INTO v_age_14_17
  FROM public.members 
  WHERE date_of_birth IS NOT NULL 
    AND EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth)) BETWEEN 14 AND 17
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_age_18_21
  FROM public.members 
  WHERE date_of_birth IS NOT NULL 
    AND EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth)) BETWEEN 18 AND 21
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_age_22_25
  FROM public.members 
  WHERE date_of_birth IS NOT NULL 
    AND EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth)) BETWEEN 22 AND 25
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_age_26_30
  FROM public.members 
  WHERE date_of_birth IS NOT NULL 
    AND EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth)) BETWEEN 26 AND 30
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_age_31_36
  FROM public.members 
  WHERE date_of_birth IS NOT NULL 
    AND EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth)) BETWEEN 31 AND 36
    AND membership_eligible IS NOT FALSE;
  
  SELECT COUNT(*) INTO v_age_unknown
  FROM public.members 
  WHERE date_of_birth IS NULL
    AND membership_eligible IS NOT FALSE;
  
  SELECT COALESCE(AVG(EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth))), 0) INTO v_avg_age
  FROM public.members 
  WHERE date_of_birth IS NOT NULL
    AND membership_eligible IS NOT FALSE;

  -- =========================================================================
  -- UPDATE THE METRICS ROW
  -- =========================================================================
  
  UPDATE public.crm_dashboard_metrics SET
    updated_at = NOW(),
    
    -- Core counts
    total_members = v_total_members,
    total_members_with_phone = v_total_members_with_phone,
    total_subscribers = v_total_subscribers,
    total_donors = v_total_donors,
    total_chapters = v_total_chapters,
    total_chartered_chapters = v_total_chartered_chapters,
    total_college_chapters = v_total_college_chapters,
    total_highschool_chapters = v_total_highschool_chapters,
    total_county_chapters = v_total_county_chapters,
    total_unique_colleges = v_total_unique_colleges,
    total_unique_high_schools = v_total_unique_high_schools,
    total_unique_counties = v_total_unique_counties,
    total_unique_congressional_districts = v_total_unique_cds,
    total_unique_house_districts = v_total_unique_house,
    total_unique_senate_districts = v_total_unique_senate,
    
    -- Financial metrics
    total_donations_amount = v_total_donations_amount,
    total_donation_count = v_total_donation_count,
    average_donation_amount = v_average_donation,
    total_recurring_donors = v_total_recurring_donors,
    donations_this_month = v_donations_this_month,
    donations_this_year = v_donations_this_year,
    
    -- Top 5 donors
    top_5_donors = (
      SELECT COALESCE(jsonb_agg(row_to_json(d)), '[]'::jsonb)
      FROM (
        SELECT name, email, total_donated
        FROM public.donors
        WHERE total_donated > 0
        ORDER BY total_donated DESC
        LIMIT 5
      ) d
    ),
    
    -- Engagement metrics
    total_slack_messages = v_total_slack_messages,
    slack_messages_this_month = v_slack_messages_this_month,
    total_social_impressions = v_total_social_impressions,
    
    -- Top 50 Slack members (excluding ineligible)
    top_50_slack_members = (
      SELECT COALESCE(jsonb_agg(row_to_json(s)), '[]'::jsonb)
      FROM (
        SELECT 
          m.id,
          m.name,
          m.email,
          COUNT(sm.id) as message_count
        FROM public.members m
        JOIN public.slack_messages sm ON sm.member_id = m.id
        WHERE sm.deleted_at IS NULL
          AND m.membership_eligible IS NOT FALSE
        GROUP BY m.id, m.name, m.email
        ORDER BY message_count DESC
        LIMIT 50
      ) s
    ),
    
    -- Geographic breakdowns (excluding ineligible)
    members_by_county = (
      SELECT COALESCE(jsonb_agg(row_to_json(c)), '[]'::jsonb)
      FROM (
        SELECT county as name, COUNT(*) as count
        FROM public.members
        WHERE county IS NOT NULL AND county != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY county
        ORDER BY count DESC
      ) c
    ),
    
    members_by_congressional_district = (
      SELECT COALESCE(jsonb_agg(row_to_json(cd)), '[]'::jsonb)
      FROM (
        SELECT congressional_district as name, COUNT(*) as count
        FROM public.members
        WHERE congressional_district IS NOT NULL AND congressional_district != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY congressional_district
        ORDER BY congressional_district
      ) cd
    ),
    
    members_by_house_district = (
      SELECT COALESCE(jsonb_agg(row_to_json(hd)), '[]'::jsonb)
      FROM (
        SELECT house_district as name, COUNT(*) as count
        FROM public.members
        WHERE house_district IS NOT NULL AND house_district != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY house_district
        ORDER BY house_district
      ) hd
    ),
    
    members_by_senate_district = (
      SELECT COALESCE(jsonb_agg(row_to_json(sd)), '[]'::jsonb)
      FROM (
        SELECT senate_district as name, COUNT(*) as count
        FROM public.members
        WHERE senate_district IS NOT NULL AND senate_district != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY senate_district
        ORDER BY senate_district
      ) sd
    ),
    
    members_by_community_type = (
      SELECT COALESCE(jsonb_agg(row_to_json(ct)), '[]'::jsonb)
      FROM (
        SELECT community_type as name, COUNT(*) as count
        FROM public.members
        WHERE community_type IS NOT NULL AND community_type != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY community_type
        ORDER BY count DESC
      ) ct
    ),
    
    -- Age distribution (excluding ineligible)
    members_by_age = (
      SELECT COALESCE(jsonb_agg(row_to_json(a) ORDER BY (a.age)::int), '[]'::jsonb)
      FROM (
        SELECT 
          EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth))::INTEGER as age,
          COUNT(*) as count
        FROM public.members
        WHERE date_of_birth IS NOT NULL
          AND EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth)) BETWEEN 14 AND 36
          AND membership_eligible IS NOT FALSE
        GROUP BY EXTRACT(YEAR FROM age(CURRENT_DATE, date_of_birth))
      ) a
    ),
    
    age_14_17_count = v_age_14_17,
    age_18_21_count = v_age_18_21,
    age_22_25_count = v_age_22_25,
    age_26_30_count = v_age_26_30,
    age_31_36_count = v_age_31_36,
    age_unknown_count = v_age_unknown,
    average_member_age = v_avg_age,
    
    -- Education breakdowns (excluding ineligible)
    members_by_college = (
      SELECT COALESCE(jsonb_agg(row_to_json(col)), '[]'::jsonb)
      FROM (
        SELECT college as name, COUNT(*) as count
        FROM public.members
        WHERE college IS NOT NULL AND college != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY college
        ORDER BY count DESC
      ) col
    ),
    
    members_by_high_school = (
      SELECT COALESCE(jsonb_agg(row_to_json(hs)), '[]'::jsonb)
      FROM (
        SELECT high_school as name, COUNT(*) as count
        FROM public.members
        WHERE high_school IS NOT NULL AND high_school != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY high_school
        ORDER BY count DESC
      ) hs
    ),
    
    members_by_graduation_year = (
      SELECT COALESCE(jsonb_agg(row_to_json(gy)), '[]'::jsonb)
      FROM (
        SELECT graduation_year as name, COUNT(*) as count
        FROM public.members
        WHERE graduation_year IS NOT NULL AND graduation_year != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY graduation_year
        ORDER BY graduation_year DESC
      ) gy
    ),
    
    members_by_education_level = (
      SELECT COALESCE(jsonb_agg(row_to_json(el)), '[]'::jsonb)
      FROM (
        SELECT education_level as name, COUNT(*) as count
        FROM public.members
        WHERE education_level IS NOT NULL AND education_level != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY education_level
        ORDER BY count DESC
      ) el
    ),
    
    members_by_in_school_status = (
      SELECT COALESCE(jsonb_agg(row_to_json(iss)), '[]'::jsonb)
      FROM (
        SELECT in_school as name, COUNT(*) as count
        FROM public.members
        WHERE in_school IS NOT NULL AND in_school != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY in_school
        ORDER BY count DESC
      ) iss
    ),
    
    -- Organizational breakdowns (excluding ineligible)
    members_by_chapter = (
      SELECT COALESCE(jsonb_agg(row_to_json(ch)), '[]'::jsonb)
      FROM (
        SELECT chapter_name as name, COUNT(*) as count
        FROM public.members
        WHERE chapter_name IS NOT NULL AND chapter_name != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY chapter_name
        ORDER BY count DESC
      ) ch
    ),
    
    members_by_chapter_status = (
      SELECT COALESCE(jsonb_agg(row_to_json(cs)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(current_chapter_member, 'Unknown') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY current_chapter_member
        ORDER BY count DESC
      ) cs
    ),
    
    members_by_chapter_position = (
      SELECT COALESCE(jsonb_agg(row_to_json(cp)), '[]'::jsonb)
      FROM (
        SELECT chapter_position as name, COUNT(*) as count
        FROM public.members
        WHERE chapter_position IS NOT NULL AND chapter_position != ''
          AND membership_eligible IS NOT FALSE
        GROUP BY chapter_position
        ORDER BY count DESC
      ) cp
    ),
    
    members_by_committee = (
      SELECT COALESCE(jsonb_agg(row_to_json(com)), '[]'::jsonb)
      FROM (
        SELECT unnest(committee) as name, COUNT(*) as count
        FROM public.members
        WHERE committee IS NOT NULL AND array_length(committee, 1) > 0
          AND membership_eligible IS NOT FALSE
        GROUP BY unnest(committee)
        ORDER BY count DESC
      ) com
    ),
    
    -- Demographic breakdowns (excluding ineligible)
    members_by_gender_identity = (
      SELECT COALESCE(jsonb_agg(row_to_json(gi)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(gender_identity, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY gender_identity
        ORDER BY count DESC
      ) gi
    ),
    
    members_by_pronouns = (
      SELECT COALESCE(jsonb_agg(row_to_json(pr)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(preferred_pronouns, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY preferred_pronouns
        ORDER BY count DESC
      ) pr
    ),
    
    members_by_race = (
      SELECT COALESCE(jsonb_agg(row_to_json(r)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(race, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY race
        ORDER BY count DESC
      ) r
    ),
    
    members_by_sexual_orientation = (
      SELECT COALESCE(jsonb_agg(row_to_json(so)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(sexual_orientation, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY sexual_orientation
        ORDER BY count DESC
      ) so
    ),
    
    members_by_hispanic_latino = (
      SELECT COALESCE(jsonb_agg(row_to_json(hl)), '[]'::jsonb)
      FROM (
        SELECT 
          CASE 
            WHEN hispanic_latino = true THEN 'Yes'
            WHEN hispanic_latino = false THEN 'No'
            ELSE 'Not Specified'
          END as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY hispanic_latino
        ORDER BY count DESC
      ) hl
    ),
    
    members_by_religion = (
      SELECT COALESCE(jsonb_agg(row_to_json(rel)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(religion, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY religion
        ORDER BY count DESC
      ) rel
    ),
    
    members_by_disability = (
      SELECT COALESCE(jsonb_agg(row_to_json(dis)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(disability, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY disability
        ORDER BY count DESC
      ) dis
    ),
    
    members_by_languages = (
      SELECT COALESCE(jsonb_agg(row_to_json(lang)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(languages, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY languages
        ORDER BY count DESC
      ) lang
    ),
    
    -- Professional breakdowns (excluding ineligible)
    members_by_industry = (
      SELECT COALESCE(jsonb_agg(row_to_json(ind)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(industry, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY industry
        ORDER BY count DESC
      ) ind
    ),
    
    members_by_employment_status = (
      SELECT COALESCE(jsonb_agg(row_to_json(emp)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(employed, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY employed
        ORDER BY count DESC
      ) emp
    ),
    
    -- Voter & Engagement breakdowns (excluding ineligible)
    members_by_voter_registration = (
      SELECT COALESCE(jsonb_agg(row_to_json(vr)), '[]'::jsonb)
      FROM (
        SELECT 
          CASE 
            WHEN registered_voter = true THEN 'Registered'
            WHEN registered_voter = false THEN 'Not Registered'
            ELSE 'Unknown'
          END as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY registered_voter
        ORDER BY count DESC
      ) vr
    ),
    
    members_by_desire_to_lead = (
      SELECT COALESCE(jsonb_agg(row_to_json(dtl)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(desire_to_lead, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY desire_to_lead
        ORDER BY count DESC
      ) dtl
    ),
    
    members_by_hours_per_week = (
      SELECT COALESCE(jsonb_agg(row_to_json(hpw)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(hours_per_week, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY hours_per_week
        ORDER BY count DESC
      ) hpw
    ),
    
    members_by_referral_source = (
      SELECT COALESCE(jsonb_agg(row_to_json(rs)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(referral_source, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY referral_source
        ORDER BY count DESC
      ) rs
    ),
    
    members_by_areas_of_interest = (
      SELECT COALESCE(jsonb_agg(row_to_json(aoi)), '[]'::jsonb)
      FROM (
        SELECT 
          COALESCE(areas_of_interest, 'Not Specified') as name, 
          COUNT(*) as count
        FROM public.members
        WHERE membership_eligible IS NOT FALSE
        GROUP BY areas_of_interest
        ORDER BY count DESC
      ) aoi
    ),
    
    -- Time-based metrics
    new_members_this_week = v_new_members_week,
    new_members_this_month = v_new_members_month,
    new_members_this_year = v_new_members_year,
    new_subscribers_this_month = v_new_subscribers_month,
    
    -- Members joined by month (last 12 months, excluding ineligible)
    members_joined_by_month = (
      SELECT COALESCE(jsonb_agg(row_to_json(mjm)), '[]'::jsonb)
      FROM (
        SELECT 
          TO_CHAR(created_at, 'YYYY-MM') as month,
          COUNT(*) as count
        FROM public.members
        WHERE created_at >= CURRENT_DATE - INTERVAL '12 months'
          AND membership_eligible IS NOT FALSE
        GROUP BY TO_CHAR(created_at, 'YYYY-MM')
        ORDER BY month DESC
      ) mjm
    ),
    
    -- Campaign metrics
    total_campaigns = v_total_campaigns,
    campaigns_sent = v_campaigns_sent,
    total_emails_sent = v_total_emails_sent,
    total_emails_opened = v_total_emails_opened,
    total_emails_clicked = v_total_emails_clicked,
    average_open_rate = v_avg_open_rate,
    average_click_rate = v_avg_click_rate,
    
    -- Event metrics
    total_events = v_total_events,
    upcoming_events = v_upcoming_events,
    total_event_attendees = v_total_attendees
    
  WHERE id = v_metrics_id;
  
END;
$function$;

-- refresh_legislation_statistics()
CREATE OR REPLACE FUNCTION public.refresh_legislation_statistics()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_start_time timestamptz;
  v_stats_id uuid;
  v_current_session text;
BEGIN
  v_start_time := clock_timestamp();
  
  -- Get or create the singleton statistics row
  SELECT id INTO v_stats_id FROM public.legislation_statistics LIMIT 1;
  
  IF v_stats_id IS NULL THEN
    INSERT INTO public.legislation_statistics (id) VALUES (gen_random_uuid())
    RETURNING id INTO v_stats_id;
  END IF;
  
  -- Determine current session (most recent session with bills)
  SELECT session INTO v_current_session
  FROM public.legislation_tracked_bills
  GROUP BY session
  ORDER BY MAX(created_at) DESC
  LIMIT 1;

  -- Update all statistics in one big UPDATE statement
  UPDATE public.legislation_statistics
  SET
    updated_at = now(),
    last_computed_at = now(),
    current_session = v_current_session,
    
    -- ==================== BILL COUNTS ====================
    total_bills = (SELECT COUNT(*) FROM public.legislation_tracked_bills),
    total_active_bills = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE is_archived = false),
    total_archived_bills = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE is_archived = true),
    
    -- Bills by chamber
    house_bills_count = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills 
      WHERE bill_identifier LIKE 'HB%' OR bill_identifier LIKE 'HCR%' OR bill_identifier LIKE 'HJR%'
    ),
    senate_bills_count = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills 
      WHERE bill_identifier LIKE 'SB%' OR bill_identifier LIKE 'SCR%' OR bill_identifier LIKE 'SJR%'
    ),
    
    -- Bills in current session
    bills_current_session_count = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE session = v_current_session
    ),
    
    -- Sessions tracked
    sessions_tracked = (
      SELECT COALESCE(jsonb_agg(DISTINCT session ORDER BY session DESC), '[]'::jsonb)
      FROM public.legislation_tracked_bills
    ),
    
    -- ==================== POSITION COUNTS ====================
    support_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE position = 'support'),
    oppose_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE position = 'oppose'),
    watching_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE position = 'watching'),
    neutral_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE position = 'neutral'),
    no_position_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE position IS NULL),
    
    -- ==================== PRIORITY COUNTS ====================
    critical_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE priority = 'critical'),
    high_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE priority = 'high'),
    medium_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE priority = 'medium'),
    low_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE priority = 'low'),
    no_priority_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE priority IS NULL),
    
    -- ==================== PASSAGE STATUS ====================
    passed_lower_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE passed_lower = true),
    passed_upper_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE passed_upper = true),
    passed_both_chambers_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE passed_lower = true AND passed_upper = true),
    signed_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE signed_by_governor = true),
    vetoed_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE vetoed = true),
    
    -- ==================== SPONSOR COUNTS BY PARTY ====================
    democrat_primary_sponsor_count = (
      SELECT COUNT(DISTINCT bs.bill_id)
      FROM public.legislation_bill_sponsors bs
      WHERE bs.is_primary = true AND bs.party = 'Democratic'
    ),
    republican_primary_sponsor_count = (
      SELECT COUNT(DISTINCT bs.bill_id)
      FROM public.legislation_bill_sponsors bs
      WHERE bs.is_primary = true AND bs.party = 'Republican'
    ),
    democrat_cosponsor_count = (
      SELECT COUNT(*)
      FROM public.legislation_bill_sponsors bs
      WHERE bs.is_primary = false AND bs.party = 'Democratic'
    ),
    republican_cosponsor_count = (
      SELECT COUNT(*)
      FROM public.legislation_bill_sponsors bs
      WHERE bs.is_primary = false AND bs.party = 'Republican'
    ),
    total_democrat_sponsorships = (
      SELECT COUNT(*)
      FROM public.legislation_bill_sponsors bs
      WHERE bs.party = 'Democratic'
    ),
    total_republican_sponsorships = (
      SELECT COUNT(*)
      FROM public.legislation_bill_sponsors bs
      WHERE bs.party = 'Republican'
    ),
    
    -- ==================== BIPARTISAN ANALYSIS ====================
    bipartisan_bills_count = (
      SELECT COUNT(DISTINCT bill_id)
      FROM public.legislation_bill_sponsors
      WHERE bill_id IN (
        SELECT bill_id FROM public.legislation_bill_sponsors WHERE party = 'Democratic'
        INTERSECT
        SELECT bill_id FROM public.legislation_bill_sponsors WHERE party = 'Republican'
      )
    ),
    democrat_only_bills_count = (
      SELECT COUNT(DISTINCT bill_id)
      FROM public.legislation_bill_sponsors
      WHERE bill_id NOT IN (
        SELECT bill_id FROM public.legislation_bill_sponsors WHERE party = 'Republican'
      )
      AND bill_id IN (
        SELECT bill_id FROM public.legislation_bill_sponsors WHERE party = 'Democratic'
      )
    ),
    republican_only_bills_count = (
      SELECT COUNT(DISTINCT bill_id)
      FROM public.legislation_bill_sponsors
      WHERE bill_id NOT IN (
        SELECT bill_id FROM public.legislation_bill_sponsors WHERE party = 'Democratic'
      )
      AND bill_id IN (
        SELECT bill_id FROM public.legislation_bill_sponsors WHERE party = 'Republican'
      )
    ),
    
    -- ==================== BILL TEXT STATUS ====================
    bills_with_text_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE current_bill_text IS NOT NULL),
    bills_without_text_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE current_bill_text IS NULL),
    bills_with_pdf_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE current_bill_pdf_path IS NOT NULL),
    bills_text_deferred_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE text_extraction_deferred = true),
    total_bill_text_word_count = (SELECT COALESCE(SUM(current_bill_text_word_count), 0) FROM public.legislation_tracked_bills),
    avg_bill_text_word_count = (SELECT COALESCE(AVG(current_bill_text_word_count), 0) FROM public.legislation_tracked_bills WHERE current_bill_text_word_count > 0),
    
    -- ==================== AI ANALYSIS STATUS ====================
    bills_ai_analyzed_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_analyzed_at IS NOT NULL AND ai_analysis_error IS NULL),
    bills_ai_pending_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_analysis_pending = true),
    bills_ai_error_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_analysis_error IS NOT NULL),
    bills_awaiting_ai_analysis_count = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills 
      WHERE current_bill_text IS NOT NULL 
      AND ai_analyzed_at IS NULL 
      AND ai_analysis_pending = false
      AND ai_analysis_error IS NULL
    ),
    
    -- AI Recommendations
    ai_recommends_support_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_position_recommendation = 'support'),
    ai_recommends_oppose_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_position_recommendation = 'oppose'),
    ai_recommends_watching_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_position_recommendation = 'watching'),
    ai_recommends_neutral_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_position_recommendation = 'neutral'),
    ai_recommends_critical_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_priority_recommendation = 'critical'),
    ai_recommends_high_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_priority_recommendation = 'high'),
    ai_recommends_medium_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_priority_recommendation = 'medium'),
    ai_recommends_low_count = (SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE ai_priority_recommendation = 'low'),
    
    -- ==================== ACTIONS ====================
    total_actions_count = (SELECT COUNT(*) FROM public.legislation_bill_actions),
    bills_with_recent_action_7d_count = (
      SELECT COUNT(DISTINCT bill_id) FROM public.legislation_bill_actions 
      WHERE action_date >= CURRENT_DATE - INTERVAL '7 days'
    ),
    bills_with_recent_action_30d_count = (
      SELECT COUNT(DISTINCT bill_id) FROM public.legislation_bill_actions 
      WHERE action_date >= CURRENT_DATE - INTERVAL '30 days'
    ),
    avg_actions_per_bill = (
      SELECT COALESCE(AVG(action_count), 0) FROM public.legislation_tracked_bills
    ),
    actions_this_week = (
      SELECT COUNT(*) FROM public.legislation_bill_actions 
      WHERE action_date >= date_trunc('week', CURRENT_DATE)
    ),
    actions_this_month = (
      SELECT COUNT(*) FROM public.legislation_bill_actions 
      WHERE action_date >= date_trunc('month', CURRENT_DATE)
    ),
    
    -- ==================== VOTES ====================
    total_votes_count = (SELECT COUNT(*) FROM public.legislation_bill_votes),
    votes_passed_count = (SELECT COUNT(*) FROM public.legislation_bill_votes WHERE result = 'pass'),
    votes_failed_count = (SELECT COUNT(*) FROM public.legislation_bill_votes WHERE result = 'fail'),
    avg_votes_per_bill = (
      SELECT COALESCE(AVG(vote_count), 0) FROM public.legislation_tracked_bills
    ),
    votes_this_week = (
      SELECT COUNT(*) FROM public.legislation_bill_votes 
      WHERE vote_date >= date_trunc('week', CURRENT_DATE)
    ),
    votes_this_month = (
      SELECT COUNT(*) FROM public.legislation_bill_votes 
      WHERE vote_date >= date_trunc('month', CURRENT_DATE)
    ),
    
    -- ==================== DOCUMENTS & VERSIONS ====================
    total_documents_count = (SELECT COUNT(*) FROM public.legislation_bill_documents WHERE document_type = 'document'),
    total_versions_count = (SELECT COUNT(*) FROM public.legislation_bill_documents WHERE document_type = 'version'),
    
    -- ==================== SPONSORS ====================
    total_sponsors_count = (SELECT COUNT(*) FROM public.legislation_bill_sponsors),
    total_primary_sponsors_count = (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE is_primary = true),
    total_cosponsors_count = (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE is_primary = false),
    avg_sponsors_per_bill = (
      SELECT COALESCE(AVG(sponsor_count), 0) FROM public.legislation_tracked_bills
    ),
    unique_sponsors_count = (
      SELECT COUNT(DISTINCT name) FROM public.legislation_bill_sponsors WHERE entity_type = 'person'
    ),
    
    -- ==================== LEGISLATORS ====================
    total_legislators_count = (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true),
    house_legislators_count = (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND chamber = 'lower'),
    senate_legislators_count = (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND chamber = 'upper'),
    democrat_legislators_count = (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic'),
    republican_legislators_count = (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican'),
    
    -- ==================== CATEGORIES & TAGS ====================
    bills_with_categories_count = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE categories IS NOT NULL AND array_length(categories, 1) > 0
    ),
    bills_with_tags_count = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills WHERE tags IS NOT NULL AND array_length(tags, 1) > 0
    ),
    
    -- Top categories
    top_categories = (
      SELECT COALESCE(jsonb_agg(cat_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object('category', category, 'count', COUNT(*)) as cat_data, COUNT(*) as cnt
        FROM public.legislation_tracked_bills, unnest(categories) as category
        GROUP BY category
        ORDER BY COUNT(*) DESC
        LIMIT 20
      ) sub
    ),
    
    -- Top subjects
    top_subjects = (
      SELECT COALESCE(jsonb_agg(subj_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object('subject', subject, 'count', COUNT(*)) as subj_data, COUNT(*) as cnt
        FROM public.legislation_tracked_bills, unnest(subjects) as subject
        GROUP BY subject
        ORDER BY COUNT(*) DESC
        LIMIT 20
      ) sub
    ),
    
    -- ==================== ALERTS ====================
    total_alerts_count = (SELECT COUNT(*) FROM public.legislation_alerts),
    active_alerts_count = (SELECT COUNT(*) FROM public.legislation_alerts WHERE is_active = true),
    alerts_sent_today_count = (
      SELECT COUNT(*) FROM public.legislation_alert_history 
      WHERE created_at >= CURRENT_DATE
    ),
    alerts_sent_this_week_count = (
      SELECT COUNT(*) FROM public.legislation_alert_history 
      WHERE created_at >= date_trunc('week', CURRENT_DATE)
    ),
    
    -- ==================== NOTES ====================
    total_notes_count = (SELECT COUNT(*) FROM public.legislation_bill_notes),
    bills_with_notes_count = (SELECT COUNT(DISTINCT bill_id) FROM public.legislation_bill_notes),
    
    -- ==================== SYNC STATUS ====================
    last_full_sync_at = (
      SELECT MAX(completed_at) FROM public.legislation_sync_log 
      WHERE sync_type = 'full' AND status = 'success'
    ),
    last_incremental_sync_at = (
      SELECT MAX(completed_at) FROM public.legislation_sync_log 
      WHERE sync_type = 'incremental' AND status = 'success'
    ),
    bills_needing_detail_sync_count = (
      SELECT COUNT(*) FROM public.legislation_bill_sync_status WHERE needs_detail_sync = true
    ),
    bills_needing_text_extract_count = (
      SELECT COUNT(*) FROM public.legislation_bill_sync_status WHERE needs_text_extract = true
    ),
    bills_needing_sponsor_link_count = (
      SELECT COUNT(*) FROM public.legislation_bill_sync_status WHERE needs_sponsor_link = true
    ),
    bills_with_sync_errors_count = (
      SELECT COUNT(*) FROM public.legislation_bill_sync_status 
      WHERE detail_sync_error IS NOT NULL OR text_extract_error IS NOT NULL OR sponsor_link_error IS NOT NULL
    ),
    
    -- ==================== TIME-BASED METRICS ====================
    bills_introduced_this_week = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills 
      WHERE first_action_date >= date_trunc('week', CURRENT_DATE)
    ),
    bills_introduced_this_month = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills 
      WHERE first_action_date >= date_trunc('month', CURRENT_DATE)
    ),
    bills_introduced_this_year = (
      SELECT COUNT(*) FROM public.legislation_tracked_bills 
      WHERE first_action_date >= date_trunc('year', CURRENT_DATE)
    ),
    
    -- Bill type counts
    bill_type_counts = (
      SELECT COALESCE(jsonb_object_agg(bill_type, cnt), '{}'::jsonb)
      FROM (
        SELECT 
          CASE 
            WHEN bill_identifier LIKE 'HB%' THEN 'HB'
            WHEN bill_identifier LIKE 'SB%' THEN 'SB'
            WHEN bill_identifier LIKE 'HCR%' THEN 'HCR'
            WHEN bill_identifier LIKE 'SCR%' THEN 'SCR'
            WHEN bill_identifier LIKE 'HJR%' THEN 'HJR'
            WHEN bill_identifier LIKE 'SJR%' THEN 'SJR'
            ELSE 'Other'
          END as bill_type,
          COUNT(*) as cnt
        FROM public.legislation_tracked_bills
        GROUP BY 1
      ) sub
    ),
    
    -- ==================== TOP 30 SPONSOR LEADERBOARDS ====================
    top_30_democrat_primary_sponsors = (
      SELECT COALESCE(jsonb_agg(sponsor_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'name', bs.name,
          'legislator_id', bs.legislator_id,
          'district', bs.district,
          'chamber', bs.chamber,
          'count', COUNT(*)
        ) as sponsor_data, COUNT(*) as cnt
        FROM public.legislation_bill_sponsors bs
        WHERE bs.is_primary = true AND bs.party = 'Democratic' AND bs.entity_type = 'person'
        GROUP BY bs.name, bs.legislator_id, bs.district, bs.chamber
        ORDER BY COUNT(*) DESC
        LIMIT 30
      ) sub
    ),
    
    top_30_republican_primary_sponsors = (
      SELECT COALESCE(jsonb_agg(sponsor_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'name', bs.name,
          'legislator_id', bs.legislator_id,
          'district', bs.district,
          'chamber', bs.chamber,
          'count', COUNT(*)
        ) as sponsor_data, COUNT(*) as cnt
        FROM public.legislation_bill_sponsors bs
        WHERE bs.is_primary = true AND bs.party = 'Republican' AND bs.entity_type = 'person'
        GROUP BY bs.name, bs.legislator_id, bs.district, bs.chamber
        ORDER BY COUNT(*) DESC
        LIMIT 30
      ) sub
    ),
    
    top_30_democrat_cosponsors = (
      SELECT COALESCE(jsonb_agg(sponsor_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'name', bs.name,
          'legislator_id', bs.legislator_id,
          'district', bs.district,
          'chamber', bs.chamber,
          'count', COUNT(*)
        ) as sponsor_data, COUNT(*) as cnt
        FROM public.legislation_bill_sponsors bs
        WHERE bs.is_primary = false AND bs.party = 'Democratic' AND bs.entity_type = 'person'
        GROUP BY bs.name, bs.legislator_id, bs.district, bs.chamber
        ORDER BY COUNT(*) DESC
        LIMIT 30
      ) sub
    ),
    
    top_30_republican_cosponsors = (
      SELECT COALESCE(jsonb_agg(sponsor_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'name', bs.name,
          'legislator_id', bs.legislator_id,
          'district', bs.district,
          'chamber', bs.chamber,
          'count', COUNT(*)
        ) as sponsor_data, COUNT(*) as cnt
        FROM public.legislation_bill_sponsors bs
        WHERE bs.is_primary = false AND bs.party = 'Republican' AND bs.entity_type = 'person'
        GROUP BY bs.name, bs.legislator_id, bs.district, bs.chamber
        ORDER BY COUNT(*) DESC
        LIMIT 30
      ) sub
    ),
    
    -- Top 10 most sponsored bills (keep as 10)
    top_10_most_sponsored_bills = (
      SELECT COALESCE(jsonb_agg(bill_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'bill_id', tb.id,
          'bill_identifier', tb.bill_identifier,
          'title', tb.title,
          'sponsor_count', tb.sponsor_count
        ) as bill_data, tb.sponsor_count as cnt
        FROM public.legislation_tracked_bills tb
        WHERE tb.sponsor_count > 0
        ORDER BY tb.sponsor_count DESC
        LIMIT 10
      ) sub
    ),
    
    -- Top 10 most active bills (keep as 10)
    top_10_most_active_bills = (
      SELECT COALESCE(jsonb_agg(bill_data ORDER BY cnt DESC), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'bill_id', tb.id,
          'bill_identifier', tb.bill_identifier,
          'title', tb.title,
          'action_count', tb.action_count,
          'latest_action_date', tb.latest_action_date
        ) as bill_data, tb.action_count as cnt
        FROM public.legislation_tracked_bills tb
        WHERE tb.action_count > 0
        ORDER BY tb.action_count DESC
        LIMIT 10
      ) sub
    ),
    
    -- ==================== AVERAGES PER LEGISLATOR ====================
    avg_bills_per_democrat_legislator = (
      SELECT CASE 
        WHEN (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic') > 0
        THEN (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE party = 'Democratic')::numeric / 
             (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic')
        ELSE 0
      END
    ),
    avg_bills_per_republican_legislator = (
      SELECT CASE 
        WHEN (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican') > 0
        THEN (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE party = 'Republican')::numeric / 
             (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican')
        ELSE 0
      END
    ),
    avg_primary_bills_per_democrat_legislator = (
      SELECT CASE 
        WHEN (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic') > 0
        THEN (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE party = 'Democratic' AND is_primary = true)::numeric / 
             (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic')
        ELSE 0
      END
    ),
    avg_primary_bills_per_republican_legislator = (
      SELECT CASE 
        WHEN (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican') > 0
        THEN (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE party = 'Republican' AND is_primary = true)::numeric / 
             (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican')
        ELSE 0
      END
    ),
    avg_cosponsored_bills_per_democrat_legislator = (
      SELECT CASE 
        WHEN (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic') > 0
        THEN (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE party = 'Democratic' AND is_primary = false)::numeric / 
             (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Democratic')
        ELSE 0
      END
    ),
    avg_cosponsored_bills_per_republican_legislator = (
      SELECT CASE 
        WHEN (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican') > 0
        THEN (SELECT COUNT(*) FROM public.legislation_bill_sponsors WHERE party = 'Republican' AND is_primary = false)::numeric / 
             (SELECT COUNT(*) FROM public.legislation_legislators WHERE is_current = true AND party = 'Republican')
        ELSE 0
      END
    ),
    
    -- Computation duration
    computation_duration_ms = EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::integer
    
  WHERE id = v_stats_id;
  
END;
$function$;

-- refresh_link_click_counts(p_campaign_id uuid)
CREATE OR REPLACE FUNCTION public.refresh_link_click_counts(p_campaign_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE public.email_campaign_links ecl
  SET 
    click_count = sub.total_clicks,
    unique_click_count = sub.unique_clicks
  FROM (
    SELECT 
      link_id,
      COUNT(*) as total_clicks,
      COUNT(DISTINCT email) as unique_clicks
    FROM public.email_campaign_link_clicks
    WHERE campaign_id = p_campaign_id
      AND link_id IS NOT NULL
    GROUP BY link_id
  ) sub
  WHERE ecl.id = sub.link_id
    AND ecl.campaign_id = p_campaign_id;
END;
$function$;

-- refresh_member_email_history()
CREATE OR REPLACE FUNCTION public.refresh_member_email_history()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Clear existing data
  TRUNCATE TABLE public.member_email_history;
  
  -- Insert sent emails
  INSERT INTO public.member_email_history (
    member_id,
    member_name,
    member_email,
    email_type,
    log_id,
    subject,
    body,
    from_address,
    to_address,
    email_date,
    gmail_message_id,
    gmail_thread_id
  )
  SELECT
    m.id as member_id,
    m.name as member_name,
    m.email as member_email,
    'sent'::text as email_type,
    el.id as log_id,
    el.subject,
    el.body,
    el.sender as from_address,
    array_to_string(el.recipient_emails, ', '::text) as to_address,
    el.created_at as email_date,
    el.gmail_message_id,
    el.gmail_thread_id
  FROM members m
  JOIN email_log_members elm ON m.id = elm.member_id
  JOIN email_logs el ON elm.email_log_id = el.id
  
  UNION ALL
  
  -- Insert received emails
  SELECT
    m.id as member_id,
    m.name as member_name,
    m.email as member_email,
    'received'::text as email_type,
    ei.id as log_id,
    ei.subject,
    COALESCE(ei.body_html, ei.body_text, ei.snippet) as body,
    ei.from_address,
    ei.to_address,
    ei.date as email_date,
    ei.gmail_message_id,
    ei.gmail_thread_id
  FROM members m
  JOIN email_inbox ei ON m.id = ei.member_id;
  
END;
$function$;

-- search_donors(p_state text, p_year_from integer, p_year_to integer, p_min_total numeric, p_max_total numeric, p_party text, p_name_query text, p_individuals_only boolean, p_limit integer, p_offset integer)
CREATE OR REPLACE FUNCTION public.search_donors(p_state text DEFAULT NULL::text, p_year_from integer DEFAULT NULL::integer, p_year_to integer DEFAULT NULL::integer, p_min_total numeric DEFAULT NULL::numeric, p_max_total numeric DEFAULT NULL::numeric, p_party text DEFAULT NULL::text, p_name_query text DEFAULT NULL::text, p_individuals_only boolean DEFAULT true, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS TABLE(contributor_last_name text, contributor_first_name text, contributor_company text, city text, state text, employer text, occupation text, total_amount numeric, contribution_count bigint, parties text[], committees text[], first_year integer, last_year integer, avg_amount numeric)
 LANGUAGE sql
 STABLE
AS $function$
  WITH filtered AS (
    SELECT
      c.contributor_last_name,
      c.contributor_first_name,
      c.contributor_company,
      c.city,
      c.state,
      c.employer,
      c.occupation,
      c.contribution_amount,
      c.filing_year,
      c.committee_name,
      COALESCE(cm.party_classification, 'unspecified') as party
    FROM public.mec_contributions c
    LEFT JOIN public.mec_committees cm ON c.mec_id = cm.mec_id
    WHERE
      (p_state IS NULL OR c.state = p_state)
      AND (p_year_from IS NULL OR c.filing_year >= p_year_from)
      AND (p_year_to IS NULL OR c.filing_year <= p_year_to)
      AND (p_party IS NULL OR COALESCE(cm.party_classification, 'unspecified') = p_party)
      AND (p_name_query IS NULL OR (
        c.contributor_last_name ILIKE '%' || p_name_query || '%'
        OR c.contributor_first_name ILIKE '%' || p_name_query || '%'
        OR c.contributor_company ILIKE '%' || p_name_query || '%'
      ))
      AND (
        NOT p_individuals_only
        OR (c.contributor_last_name IS NOT NULL AND c.contributor_last_name != ''
            AND c.is_committee_contributor IS NOT TRUE)
      )
  )
  SELECT
    f.contributor_last_name,
    f.contributor_first_name,
    f.contributor_company,
    f.city,
    f.state,
    MAX(f.employer) as employer,
    MAX(f.occupation) as occupation,
    SUM(f.contribution_amount) as total_amount,
    COUNT(*) as contribution_count,
    ARRAY_AGG(DISTINCT f.party) FILTER (WHERE f.party IS NOT NULL) as parties,
    ARRAY_AGG(DISTINCT f.committee_name) FILTER (WHERE f.committee_name IS NOT NULL) as committees,
    MIN(f.filing_year) as first_year,
    MAX(f.filing_year) as last_year,
    AVG(f.contribution_amount) as avg_amount
  FROM filtered f
  GROUP BY f.contributor_last_name, f.contributor_first_name, f.contributor_company, f.city, f.state
  HAVING (p_min_total IS NULL OR SUM(f.contribution_amount) >= p_min_total)
    AND (p_max_total IS NULL OR SUM(f.contribution_amount) <= p_max_total)
  ORDER BY SUM(f.contribution_amount) DESC
  LIMIT p_limit
  OFFSET p_offset;
$function$;

-- upsert_mautic_campaign(p_mautic_email_id integer, p_name text, p_subject text, p_from_name text, p_from_email text, p_reply_to text, p_sent_at timestamp with time zone, p_sent_count integer, p_read_count integer, p_html_content text)
CREATE OR REPLACE FUNCTION public.upsert_mautic_campaign(p_mautic_email_id integer, p_name text, p_subject text, p_from_name text DEFAULT NULL::text, p_from_email text DEFAULT NULL::text, p_reply_to text DEFAULT NULL::text, p_sent_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_sent_count integer DEFAULT 0, p_read_count integer DEFAULT 0, p_html_content text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_campaign_id UUID;
BEGIN
  INSERT INTO public.email_campaigns (
    source,
    source_campaign_id,
    name,
    subject,
    from_name,
    from_email,
    reply_to,
    html_content,
    sent_at,
    total_sent,
    total_recipients,
    unique_opens,
    total_opens
  ) VALUES (
    'mautic',
    p_mautic_email_id::TEXT,
    p_name,
    p_subject,
    p_from_name,
    p_from_email,
    p_reply_to,
    p_html_content,
    p_sent_at,
    p_sent_count,
    p_sent_count,
    p_read_count,
    p_read_count
  )
  ON CONFLICT (source, source_campaign_id) 
  WHERE source_campaign_id IS NOT NULL
  DO UPDATE SET
    name = EXCLUDED.name,
    subject = EXCLUDED.subject,
    from_name = COALESCE(EXCLUDED.from_name, email_campaigns.from_name),
    from_email = COALESCE(EXCLUDED.from_email, email_campaigns.from_email),
    total_sent = EXCLUDED.total_sent,
    unique_opens = EXCLUDED.unique_opens,
    updated_at = NOW()
  RETURNING id INTO v_campaign_id;
  
  RETURN v_campaign_id;
END;
$function$;

-- upsert_mautic_recipient(p_campaign_id uuid, p_mautic_stat_id bigint, p_email text, p_mautic_lead_id integer, p_tracking_hash text, p_first_name text, p_last_name text, p_date_sent timestamp with time zone, p_is_read boolean, p_date_read timestamp with time zone, p_open_count integer, p_last_opened timestamp with time zone, p_open_details jsonb, p_is_failed boolean, p_viewed_in_browser boolean, p_retry_count integer, p_source text, p_source_id integer, p_ip_id integer, p_list_id integer)
CREATE OR REPLACE FUNCTION public.upsert_mautic_recipient(p_campaign_id uuid, p_mautic_stat_id bigint, p_email text, p_mautic_lead_id integer DEFAULT NULL::integer, p_tracking_hash text DEFAULT NULL::text, p_first_name text DEFAULT NULL::text, p_last_name text DEFAULT NULL::text, p_date_sent timestamp with time zone DEFAULT NULL::timestamp with time zone, p_is_read boolean DEFAULT false, p_date_read timestamp with time zone DEFAULT NULL::timestamp with time zone, p_open_count integer DEFAULT 0, p_last_opened timestamp with time zone DEFAULT NULL::timestamp with time zone, p_open_details jsonb DEFAULT NULL::jsonb, p_is_failed boolean DEFAULT false, p_viewed_in_browser boolean DEFAULT false, p_retry_count integer DEFAULT 0, p_source text DEFAULT NULL::text, p_source_id integer DEFAULT NULL::integer, p_ip_id integer DEFAULT NULL::integer, p_list_id integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_recipient_id UUID;
  v_subscriber_id UUID;
BEGIN
  -- Try to find matching subscriber by mautic_id first, then email
  SELECT id INTO v_subscriber_id
  FROM public.subscribers
  WHERE (mautic_id IS NOT NULL AND mautic_id = p_mautic_lead_id)
     OR LOWER(email) = LOWER(p_email)
  ORDER BY mautic_id = p_mautic_lead_id DESC NULLS LAST
  LIMIT 1;
  
  INSERT INTO public.email_campaign_recipients (
    campaign_id,
    subscriber_id,
    source,
    source_stat_id,
    email,
    first_name,
    last_name,
    full_name,
    mautic_lead_id,
    mautic_tracking_hash,
    sent_at,
    opened,
    first_opened_at,
    last_opened_at,
    open_count,
    open_details,
    failed,
    viewed_in_browser,
    retry_count,
    mautic_source,
    mautic_source_id,
    mautic_ip_id,
    mautic_list_id
  ) VALUES (
    p_campaign_id,
    v_subscriber_id,
    'mautic',
    p_mautic_stat_id::TEXT,
    LOWER(p_email),
    p_first_name,
    p_last_name,
    TRIM(COALESCE(p_first_name, '') || ' ' || COALESCE(p_last_name, '')),
    p_mautic_lead_id,
    p_tracking_hash,
    p_date_sent,
    p_is_read,
    CASE WHEN p_is_read THEN COALESCE(p_date_read, p_date_sent) ELSE NULL END,
    p_last_opened,
    COALESCE(p_open_count, CASE WHEN p_is_read THEN 1 ELSE 0 END),
    p_open_details,
    p_is_failed,
    p_viewed_in_browser,
    p_retry_count,
    p_source,
    p_source_id,
    p_ip_id,
    p_list_id
  )
  ON CONFLICT (campaign_id, email) 
  DO UPDATE SET
    subscriber_id = COALESCE(email_campaign_recipients.subscriber_id, EXCLUDED.subscriber_id),
    mautic_lead_id = COALESCE(EXCLUDED.mautic_lead_id, email_campaign_recipients.mautic_lead_id),
    mautic_tracking_hash = COALESCE(EXCLUDED.mautic_tracking_hash, email_campaign_recipients.mautic_tracking_hash),
    opened = EXCLUDED.opened OR email_campaign_recipients.opened,
    first_opened_at = COALESCE(email_campaign_recipients.first_opened_at, EXCLUDED.first_opened_at),
    last_opened_at = GREATEST(email_campaign_recipients.last_opened_at, EXCLUDED.last_opened_at),
    open_count = GREATEST(email_campaign_recipients.open_count, EXCLUDED.open_count),
    open_details = COALESCE(EXCLUDED.open_details, email_campaign_recipients.open_details),
    failed = EXCLUDED.failed OR email_campaign_recipients.failed,
    viewed_in_browser = EXCLUDED.viewed_in_browser OR email_campaign_recipients.viewed_in_browser,
    updated_at = NOW()
  RETURNING id INTO v_recipient_id;
  
  RETURN v_recipient_id;
END;
$function$;

*/