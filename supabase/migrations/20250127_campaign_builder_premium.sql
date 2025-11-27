-- =====================================================
-- PREMIUM EMAIL CAMPAIGN BUILDER - DATABASE SETUP
-- =====================================================

-- ========================================
-- 1. STORAGE BUCKET FOR CAMPAIGN IMAGES
-- ========================================

-- Create campaign-images storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'campaign-images',
  'campaign-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

-- RLS Policies for campaign-images bucket
CREATE POLICY IF NOT EXISTS "Anyone can view campaign images"
ON storage.objects FOR SELECT
USING (bucket_id = 'campaign-images');

CREATE POLICY IF NOT EXISTS "Authenticated users can upload campaign images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'campaign-images');

CREATE POLICY IF NOT EXISTS "Authenticated users can delete their campaign images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'campaign-images');

CREATE POLICY IF NOT EXISTS "Authenticated users can update their campaign images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'campaign-images')
WITH CHECK (bucket_id = 'campaign-images');

-- ========================================
-- 2. DEDUPLICATION FUNCTIONS
-- ========================================

-- Function to count unique event attendees across multiple events
CREATE OR REPLACE FUNCTION count_unique_event_attendees(event_ids UUID[])
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM (
      -- From members who are attendees
      SELECT m.email
      FROM event_attendees ea
      JOIN members m ON ea.member_id = m.id
      WHERE ea.event_id = ANY(event_ids)
        AND m.email IS NOT NULL
        AND m.email != ''

      UNION

      -- From guest emails
      SELECT ea.guest_email AS email
      FROM event_attendees ea
      WHERE ea.event_id = ANY(event_ids)
        AND ea.guest_email IS NOT NULL
        AND ea.guest_email != ''
    ) AS all_emails
    WHERE email IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count all unique contacts across all tables (with optional filters)
CREATE OR REPLACE FUNCTION count_all_unique_contacts(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM (
      -- From subscribers
      SELECT email
      FROM subscribers
      WHERE email IS NOT NULL
        AND email != ''
        AND subscription_status = 'subscribed'
        AND (p_congressional_districts IS NULL OR congressional_district = ANY(p_congressional_districts))
        AND (p_counties IS NULL OR county = ANY(p_counties))

      UNION

      -- From members
      SELECT email
      FROM members
      WHERE email IS NOT NULL
        AND email != ''
        AND (p_congressional_districts IS NULL OR congressional_district = ANY(p_congressional_districts))
        AND (p_counties IS NULL OR county = ANY(p_counties))

      UNION

      -- From donors
      SELECT email
      FROM donors
      WHERE email IS NOT NULL
        AND email != ''
        AND (p_congressional_districts IS NULL OR congressional_district = ANY(p_congressional_districts))
        AND (p_counties IS NULL OR county = ANY(p_counties))

      UNION

      -- From event attendees (member emails)
      SELECT m.email
      FROM event_attendees ea
      JOIN members m ON ea.member_id = m.id
      WHERE m.email IS NOT NULL
        AND m.email != ''
        AND (p_congressional_districts IS NULL OR m.congressional_district = ANY(p_congressional_districts))
        AND (p_counties IS NULL OR m.county = ANY(p_counties))

      UNION

      -- From event attendees (guest emails)
      SELECT guest_email AS email
      FROM event_attendees
      WHERE guest_email IS NOT NULL
        AND guest_email != ''
    ) AS all_emails
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count subscribers with filters
CREATE OR REPLACE FUNCTION count_subscribers_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM subscribers
    WHERE email IS NOT NULL
      AND email != ''
      AND subscription_status = 'subscribed'
      AND (p_congressional_districts IS NULL OR congressional_district = ANY(p_congressional_districts))
      AND (p_counties IS NULL OR county = ANY(p_counties))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count members with filters
CREATE OR REPLACE FUNCTION count_members_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM members
    WHERE email IS NOT NULL
      AND email != ''
      AND current_chapter_member = 'Yes'
      AND (p_congressional_districts IS NULL OR congressional_district = ANY(p_congressional_districts))
      AND (p_counties IS NULL OR county = ANY(p_counties))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to count donors with filters
CREATE OR REPLACE FUNCTION count_donors_filtered(
  p_congressional_districts TEXT[] DEFAULT NULL,
  p_counties TEXT[] DEFAULT NULL
)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT LOWER(TRIM(email)))
    FROM donors
    WHERE email IS NOT NULL
      AND email != ''
      AND (p_congressional_districts IS NULL OR congressional_district = ANY(p_congressional_districts))
      AND (p_counties IS NULL OR county = ANY(p_counties))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- 3. CAMPAIGN DRAFTS TABLE (Auto-save)
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

CREATE POLICY "Users can view their own drafts"
ON campaign_drafts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own drafts"
ON campaign_drafts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own drafts"
ON campaign_drafts FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

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
-- 4. CAMPAIGN TEMPLATES TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS campaign_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  thumbnail_url TEXT,
  category TEXT, -- 'newsletter', 'event', 'fundraising', 'announcement'
  html_content TEXT NOT NULL,
  design_json JSONB NOT NULL,
  is_premium BOOLEAN DEFAULT false,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for templates
CREATE INDEX IF NOT EXISTS idx_campaign_templates_category ON campaign_templates(category);
CREATE INDEX IF NOT EXISTS idx_campaign_templates_premium ON campaign_templates(is_premium);

-- RLS Policies - everyone can view templates
ALTER TABLE campaign_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view templates"
ON campaign_templates FOR SELECT
TO authenticated
USING (true);

-- Only admins can insert/update templates (adjust as needed)
CREATE POLICY "Admins can manage templates"
ON campaign_templates FOR ALL
TO authenticated
USING (
  auth.jwt() ->> 'role' = 'admin' OR
  auth.jwt() ->> 'email' IN ('admin@moyoungdemocrats.org')
);

-- ========================================
-- 5. A/B TESTING TABLES
-- ========================================

CREATE TABLE IF NOT EXISTS campaign_ab_tests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL,
  test_type TEXT NOT NULL, -- 'subject_line', 'content', 'send_time'
  variant_a_subject TEXT,
  variant_b_subject TEXT,
  variant_a_content TEXT,
  variant_b_content JSONB,
  test_percentage INT DEFAULT 20, -- Percentage to use for testing
  winner_variant TEXT, -- 'A', 'B', or NULL if not determined
  variant_a_opens INT DEFAULT 0,
  variant_b_opens INT DEFAULT 0,
  variant_a_clicks INT DEFAULT 0,
  variant_b_clicks INT DEFAULT 0,
  test_started_at TIMESTAMPTZ,
  test_completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ab_tests_campaign ON campaign_ab_tests(campaign_id);

ALTER TABLE campaign_ab_tests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view ab tests"
ON campaign_ab_tests FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Authenticated users can create ab tests"
ON campaign_ab_tests FOR INSERT
TO authenticated
WITH CHECK (true);

-- ========================================
-- 6. DELIVERABILITY SCORES TABLE
-- ========================================

CREATE TABLE IF NOT EXISTS campaign_deliverability_scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID,
  draft_id UUID,
  overall_score INT NOT NULL CHECK (overall_score >= 0 AND overall_score <= 100),
  spam_score INT CHECK (spam_score >= 0 AND spam_score <= 100),
  spf_valid BOOLEAN DEFAULT false,
  dkim_valid BOOLEAN DEFAULT false,
  dmarc_valid BOOLEAN DEFAULT false,
  has_unsubscribe_link BOOLEAN DEFAULT false,
  has_physical_address BOOLEAN DEFAULT false,
  link_count INT DEFAULT 0,
  image_count INT DEFAULT 0,
  word_count INT DEFAULT 0,
  spam_words_found TEXT[],
  recommendations JSONB,
  analyzed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deliverability_campaign ON campaign_deliverability_scores(campaign_id);
CREATE INDEX IF NOT EXISTS idx_deliverability_draft ON campaign_deliverability_scores(draft_id);

-- ========================================
-- GRANT PERMISSIONS
-- ========================================

GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon;

COMMENT ON FUNCTION count_unique_event_attendees IS 'Counts unique email addresses across multiple events with deduplication';
COMMENT ON FUNCTION count_all_unique_contacts IS 'Counts all unique contacts across subscribers, members, donors, and event attendees with optional filtering';
COMMENT ON FUNCTION count_subscribers_filtered IS 'Counts unique subscribers with optional congressional district and county filters';
COMMENT ON FUNCTION count_members_filtered IS 'Counts unique members with optional congressional district and county filters';
COMMENT ON FUNCTION count_donors_filtered IS 'Counts unique donors with optional congressional district and county filters';
