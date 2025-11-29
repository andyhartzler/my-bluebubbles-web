-- =====================================================
-- COMBINED CAMPAIGN BUILDER - DATABASE SETUP
-- This combines both migration files with corrected syntax
-- =====================================================

-- ========================================
-- 1. STORAGE BUCKET FOR CAMPAIGN ASSETS
-- ========================================

-- Create campaigns bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'campaigns',
  'campaigns',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

-- Drop existing policies if they exist, then create them
DROP POLICY IF EXISTS "Anyone can view campaign assets" ON storage.objects;
CREATE POLICY "Anyone can view campaign assets"
ON storage.objects FOR SELECT
USING (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Authenticated users can upload campaign assets" ON storage.objects;
CREATE POLICY "Authenticated users can upload campaign assets"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Authenticated users can update campaign assets" ON storage.objects;
CREATE POLICY "Authenticated users can update campaign assets"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Authenticated users can delete campaign assets" ON storage.objects;
CREATE POLICY "Authenticated users can delete campaign assets"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Anyone can view campaign images" ON storage.objects;
CREATE POLICY "Anyone can view campaign images"
ON storage.objects FOR SELECT
USING (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Authenticated users can upload campaign images" ON storage.objects;
CREATE POLICY "Authenticated users can upload campaign images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Authenticated users can delete their campaign images" ON storage.objects;
CREATE POLICY "Authenticated users can delete their campaign images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'campaigns');

DROP POLICY IF EXISTS "Authenticated users can update their campaign images" ON storage.objects;
CREATE POLICY "Authenticated users can update their campaign images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'campaigns')
WITH CHECK (bucket_id = 'campaigns');

-- ============================================================================
-- 2. RECIPIENT DEDUPLICATION FUNCTIONS
-- ============================================================================

-- Function to count subscribers with filters (congressional district, county)
CREATE OR REPLACE FUNCTION count_subscribers_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT LOWER(TRIM(email)))
  INTO v_count
  FROM subscribers
  WHERE subscription_status = 'subscribed'
    AND email IS NOT NULL
    AND email != ''
    AND (
      p_congressional_districts IS NULL
      OR congressional_district = ANY(p_congressional_districts)
    )
    AND (
      p_counties IS NULL
      OR county = ANY(p_counties)
    );

  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count members with filters
CREATE OR REPLACE FUNCTION count_members_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT LOWER(TRIM(email)))
  INTO v_count
  FROM members
  WHERE current_chapter_member = 'Yes'
    AND email IS NOT NULL
    AND email != ''
    AND (
      p_congressional_districts IS NULL
      OR congressional_district = ANY(p_congressional_districts)
    )
    AND (
      p_counties IS NULL
      OR county = ANY(p_counties)
    );

  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count donors with filters
CREATE OR REPLACE FUNCTION count_donors_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT LOWER(TRIM(email)))
  INTO v_count
  FROM donors
  WHERE email IS NOT NULL
    AND email != ''
    AND (
      p_congressional_districts IS NULL
      OR congressional_district = ANY(p_congressional_districts)
    )
    AND (
      p_counties IS NULL
      OR county = ANY(p_counties)
    );

  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count unique event attendees across multiple events
CREATE OR REPLACE FUNCTION count_unique_event_attendees(
  p_event_ids UUID[]
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT email_normalized)
  INTO v_count
  FROM (
    -- From members who are attendees
    SELECT LOWER(TRIM(m.email)) AS email_normalized
    FROM event_attendees ea
    JOIN members m ON ea.member_id = m.id
    WHERE ea.event_id = ANY(p_event_ids)
      AND m.email IS NOT NULL
      AND m.email != ''

    UNION

    -- From guest emails
    SELECT LOWER(TRIM(ea.guest_email)) AS email_normalized
    FROM event_attendees ea
    WHERE ea.event_id = ANY(p_event_ids)
      AND ea.guest_email IS NOT NULL
      AND ea.guest_email != ''
  ) AS all_attendee_emails;

  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count all unique contacts across all tables (deduplicated)
CREATE OR REPLACE FUNCTION count_all_unique_contacts(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(DISTINCT email_normalized)
  INTO v_count
  FROM (
    -- From subscribers
    SELECT LOWER(TRIM(email)) AS email_normalized
    FROM subscribers
    WHERE email IS NOT NULL
      AND email != ''
      AND subscription_status = 'subscribed'
      AND (
        p_congressional_districts IS NULL
        OR congressional_district = ANY(p_congressional_districts)
      )
      AND (
        p_counties IS NULL
        OR county = ANY(p_counties)
      )

    UNION

    -- From members
    SELECT LOWER(TRIM(email)) AS email_normalized
    FROM members
    WHERE email IS NOT NULL
      AND email != ''
      AND opt_out = false
      AND (
        p_congressional_districts IS NULL
        OR congressional_district = ANY(p_congressional_districts)
      )
      AND (
        p_counties IS NULL
        OR county = ANY(p_counties)
      )

    UNION

    -- From donors
    SELECT LOWER(TRIM(email)) AS email_normalized
    FROM donors
    WHERE email IS NOT NULL
      AND email != ''
      AND (
        p_congressional_districts IS NULL
        OR congressional_district = ANY(p_congressional_districts)
      )
      AND (
        p_counties IS NULL
        OR county = ANY(p_counties)
      )

    UNION

    -- From event attendees (member emails)
    SELECT LOWER(TRIM(m.email)) AS email_normalized
    FROM event_attendees ea
    JOIN members m ON ea.member_id = m.id
    WHERE m.email IS NOT NULL
      AND m.email != ''
      AND m.opt_out = false
      AND (
        p_congressional_districts IS NULL
        OR m.congressional_district = ANY(p_congressional_districts)
      )
      AND (
        p_counties IS NULL
        OR m.county = ANY(p_counties)
      )

    UNION

    -- From event attendees (guest emails)
    SELECT LOWER(TRIM(guest_email)) AS email_normalized
    FROM event_attendees
    WHERE guest_email IS NOT NULL
      AND guest_email != ''
  ) AS all_unique_emails;

  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 3. GET RECIPIENT LISTS (for campaign sending)
-- ============================================================================

-- Function to get all subscribers with filters (returns emails)
CREATE OR REPLACE FUNCTION get_subscribers_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS TABLE(email TEXT, name TEXT, congressional_district TEXT, county TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (LOWER(TRIM(s.email)))
    s.email,
    COALESCE(s.name, s.email) AS name,
    s.congressional_district,
    s.county
  FROM subscribers s
  WHERE s.subscription_status = 'subscribed'
    AND s.email IS NOT NULL
    AND s.email != ''
    AND (
      p_congressional_districts IS NULL
      OR s.congressional_district = ANY(p_congressional_districts)
    )
    AND (
      p_counties IS NULL
      OR s.county = ANY(p_counties)
    )
  ORDER BY LOWER(TRIM(s.email)), s.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all members with filters
CREATE OR REPLACE FUNCTION get_members_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS TABLE(email TEXT, name TEXT, congressional_district TEXT, county TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (LOWER(TRIM(m.email)))
    m.email,
    COALESCE(m.name, m.email) AS name,
    m.congressional_district,
    m.county
  FROM members m
  WHERE m.opt_out = false
    AND m.email IS NOT NULL
    AND m.email != ''
    AND (
      p_congressional_districts IS NULL
      OR m.congressional_district = ANY(p_congressional_districts)
    )
    AND (
      p_counties IS NULL
      OR m.county = ANY(p_counties)
    )
  ORDER BY LOWER(TRIM(m.email)), m.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all donors with filters
CREATE OR REPLACE FUNCTION get_donors_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS TABLE(email TEXT, name TEXT, congressional_district TEXT, county TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (LOWER(TRIM(d.email)))
    d.email,
    COALESCE(d.name, d.email) AS name,
    d.congressional_district,
    d.county
  FROM donors d
  WHERE d.email IS NOT NULL
    AND d.email != ''
    AND (
      p_congressional_districts IS NULL
      OR d.congressional_district = ANY(p_congressional_districts)
    )
    AND (
      p_counties IS NULL
      OR d.county = ANY(p_counties)
    )
  ORDER BY LOWER(TRIM(d.email)), d.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unique event attendees
CREATE OR REPLACE FUNCTION get_unique_event_attendees(
  p_event_ids UUID[]
)
RETURNS TABLE(email TEXT, name TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (LOWER(TRIM(email_col)))
    email_col AS email,
    name_col AS name
  FROM (
    -- From members who are attendees
    SELECT
      m.email AS email_col,
      COALESCE(m.name, m.email) AS name_col,
      m.created_at
    FROM event_attendees ea
    JOIN members m ON ea.member_id = m.id
    WHERE ea.event_id = ANY(p_event_ids)
      AND m.email IS NOT NULL
      AND m.email != ''

    UNION ALL

    -- From guest emails
    SELECT
      ea.guest_email AS email_col,
      COALESCE(ea.guest_name, ea.guest_email) AS name_col,
      ea.created_at
    FROM event_attendees ea
    WHERE ea.event_id = ANY(p_event_ids)
      AND ea.guest_email IS NOT NULL
      AND ea.guest_email != ''
  ) AS all_attendees
  ORDER BY LOWER(TRIM(email_col)), created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all unique contacts (everyone in database, deduplicated)
CREATE OR REPLACE FUNCTION get_all_unique_contacts()
RETURNS TABLE(email TEXT, name TEXT, source TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (LOWER(TRIM(email_col)))
    email_col AS email,
    name_col AS name,
    source_col AS source
  FROM (
    -- From subscribers
    SELECT
      email AS email_col,
      COALESCE(name, email) AS name_col,
      'subscriber' AS source_col,
      created_at
    FROM subscribers
    WHERE email IS NOT NULL
      AND email != ''
      AND subscription_status = 'subscribed'

    UNION ALL

    -- From members
    SELECT
      email AS email_col,
      COALESCE(name, email) AS name_col,
      'member' AS source_col,
      created_at
    FROM members
    WHERE email IS NOT NULL
      AND email != ''
      AND opt_out = false

    UNION ALL

    -- From donors
    SELECT
      email AS email_col,
      COALESCE(name, email) AS name_col,
      'donor' AS source_col,
      created_at
    FROM donors
    WHERE email IS NOT NULL
      AND email != ''

    UNION ALL

    -- From event attendees (member emails)
    SELECT
      m.email AS email_col,
      COALESCE(m.name, m.email) AS name_col,
      'event_attendee' AS source_col,
      ea.created_at
    FROM event_attendees ea
    JOIN members m ON ea.member_id = m.id
    WHERE m.email IS NOT NULL
      AND m.email != ''
      AND m.opt_out = false

    UNION ALL

    -- From event attendees (guest emails)
    SELECT
      guest_email AS email_col,
      COALESCE(guest_name, guest_email) AS name_col,
      'event_guest' AS source_col,
      created_at
    FROM event_attendees
    WHERE guest_email IS NOT NULL
      AND guest_email != ''
  ) AS all_contacts
  ORDER BY LOWER(TRIM(email_col)), created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. COUNT MISSING COUNTY DATA
-- ============================================================================

-- Count subscribers without county data
CREATE OR REPLACE FUNCTION count_subscribers_missing_county()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM subscribers
    WHERE email IS NOT NULL
      AND email != ''
      AND subscription_status = 'subscribed'
      AND (county IS NULL OR TRIM(county) = '')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Count members without county data
CREATE OR REPLACE FUNCTION count_members_missing_county()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM members
    WHERE email IS NOT NULL
      AND email != ''
      AND opt_out = false
      AND (county IS NULL OR TRIM(county) = '')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Count donors without county data
CREATE OR REPLACE FUNCTION count_donors_missing_county()
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM donors
    WHERE email IS NOT NULL
      AND email != ''
      AND (county IS NULL OR TRIM(county) = '')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 5. CAMPAIGN DRAFTS TABLE (Auto-save)
-- ========================================

CREATE TABLE IF NOT EXISTS campaign_drafts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  campaign_name TEXT,
  subject_line TEXT,
  preview_text TEXT,
  from_email TEXT,
  html_content TEXT,
  design_json JSONB,
  segment_type TEXT,
  segment_filters JSONB,
  selected_events UUID[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_campaign_drafts_user_id ON campaign_drafts(user_id);
CREATE INDEX IF NOT EXISTS idx_campaign_drafts_updated_at ON campaign_drafts(updated_at DESC);

-- RLS Policies for campaign drafts
ALTER TABLE campaign_drafts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own drafts" ON campaign_drafts;
CREATE POLICY "Users can view their own drafts"
ON campaign_drafts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own drafts" ON campaign_drafts;
CREATE POLICY "Users can create their own drafts"
ON campaign_drafts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own drafts" ON campaign_drafts;
CREATE POLICY "Users can update their own drafts"
ON campaign_drafts FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own drafts" ON campaign_drafts;
CREATE POLICY "Users can delete their own drafts"
ON campaign_drafts FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_campaign_draft_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS campaign_drafts_updated_at ON campaign_drafts;
CREATE TRIGGER campaign_drafts_updated_at
  BEFORE UPDATE ON campaign_drafts
  FOR EACH ROW
  EXECUTE FUNCTION update_campaign_draft_timestamp();

-- ========================================
-- 6. GRANT PERMISSIONS
-- ========================================

GRANT EXECUTE ON FUNCTION count_subscribers_filtered TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_filtered TO authenticated;
GRANT EXECUTE ON FUNCTION count_donors_filtered TO authenticated;
GRANT EXECUTE ON FUNCTION count_unique_event_attendees TO authenticated;
GRANT EXECUTE ON FUNCTION count_all_unique_contacts TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscribers_filtered TO authenticated;
GRANT EXECUTE ON FUNCTION get_members_filtered TO authenticated;
GRANT EXECUTE ON FUNCTION get_donors_filtered TO authenticated;
GRANT EXECUTE ON FUNCTION get_unique_event_attendees TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_unique_contacts TO authenticated;
GRANT EXECUTE ON FUNCTION count_subscribers_missing_county TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_missing_county TO authenticated;
GRANT EXECUTE ON FUNCTION count_donors_missing_county TO authenticated;

-- ========================================
-- 7. COMMENTS FOR DOCUMENTATION
-- ========================================

COMMENT ON FUNCTION count_subscribers_filtered IS 'Count unique subscriber emails with optional geographic filters';
COMMENT ON FUNCTION count_members_filtered IS 'Count unique member emails with optional geographic filters';
COMMENT ON FUNCTION count_donors_filtered IS 'Count unique donor emails with optional geographic filters';
COMMENT ON FUNCTION count_unique_event_attendees IS 'Count unique attendee emails across specified events';
COMMENT ON FUNCTION count_all_unique_contacts IS 'Count all unique emails across all tables (deduplicated)';
COMMENT ON FUNCTION get_subscribers_filtered IS 'Get deduplicated subscriber list with filters';
COMMENT ON FUNCTION get_members_filtered IS 'Get deduplicated member list with filters';
COMMENT ON FUNCTION get_donors_filtered IS 'Get deduplicated donor list with filters';
COMMENT ON FUNCTION get_unique_event_attendees IS 'Get deduplicated event attendee list';
COMMENT ON FUNCTION get_all_unique_contacts IS 'Get all unique contacts from all tables (deduplicated)';
COMMENT ON FUNCTION count_subscribers_missing_county IS 'Count subscribers without county data';
COMMENT ON FUNCTION count_members_missing_county IS 'Count members without county data';
COMMENT ON FUNCTION count_donors_missing_county IS 'Count donors without county data';
