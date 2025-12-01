-- RPC Functions for Redesigned Segment Builder
-- Created: 2025-02-01
-- Purpose: Count functions for the new dropdown-based segment builder

-- ============================================================================
-- SUBSCRIBER COUNT FUNCTIONS
-- ============================================================================

-- Count all subscribers
CREATE OR REPLACE FUNCTION count_subscribers_all()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM subscribers
    WHERE subscription_status = 'subscribed'
  );
END;
$$;

-- Count subscribers by congressional district (with option to include nulls)
CREATE OR REPLACE FUNCTION count_subscribers_by_cd(
  p_congressional_district TEXT,
  p_include_null BOOLEAN DEFAULT FALSE
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM subscribers
    WHERE subscription_status = 'subscribed'
    AND (
      congressional_district = p_congressional_district
      OR (p_include_null AND congressional_district IS NULL)
    )
  );
END;
$$;

-- ============================================================================
-- DONOR COUNT FUNCTIONS
-- ============================================================================

-- Count all donors
CREATE OR REPLACE FUNCTION count_donors_all()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM donors
    WHERE email IS NOT NULL
  );
END;
$$;

-- Count donors by county
CREATE OR REPLACE FUNCTION count_donors_by_county(
  p_county TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM donors
    WHERE email IS NOT NULL
    AND county = p_county
  );
END;
$$;

-- Count donors by congressional district
CREATE OR REPLACE FUNCTION count_donors_by_cd(
  p_congressional_district TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM donors
    WHERE email IS NOT NULL
    AND congressional_district = p_congressional_district
  );
END;
$$;

-- ============================================================================
-- MEMBER COUNT FUNCTIONS
-- ============================================================================

-- Count all members
CREATE OR REPLACE FUNCTION count_members_all()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
  );
END;
$$;

-- Count members by congressional district
CREATE OR REPLACE FUNCTION count_members_by_cd(
  p_congressional_district TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
    AND congressional_district = p_congressional_district
  );
END;
$$;

-- Count members by county
CREATE OR REPLACE FUNCTION count_members_by_county(
  p_county TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
    AND county = p_county
  );
END;
$$;

-- Count members by chapter
CREATE OR REPLACE FUNCTION count_members_by_chapter(
  p_chapter TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
    AND chapter_name = p_chapter
  );
END;
$$;

-- Count members by school (checks both high_school and college)
CREATE OR REPLACE FUNCTION count_members_by_school(
  p_school TEXT
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
    AND (high_school = p_school OR college = p_school)
  );
END;
$$;

-- Count members with college filled
CREATE OR REPLACE FUNCTION count_members_with_college()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
    AND college IS NOT NULL
    AND college != ''
  );
END;
$$;

-- Count members with high school filled
CREATE OR REPLACE FUNCTION count_members_with_high_school()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT email)
    FROM members
    WHERE email IS NOT NULL
    AND opt_out = FALSE
    AND high_school IS NOT NULL
    AND high_school != ''
  );
END;
$$;

-- ============================================================================
-- EVENT ATTENDEE COUNT FUNCTION
-- ============================================================================

-- Drop the old function if it exists (with different parameter name)
DROP FUNCTION IF EXISTS count_unique_event_attendees(uuid[]);

-- Count unique event attendees across multiple events
CREATE OR REPLACE FUNCTION count_unique_event_attendees(
  event_ids UUID[]
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT COUNT(DISTINCT COALESCE(m.email, ea.guest_email))
    FROM event_attendees ea
    LEFT JOIN members m ON ea.member_id = m.id
    WHERE ea.event_id = ANY(event_ids)
    AND (m.email IS NOT NULL OR ea.guest_email IS NOT NULL)
  );
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION count_subscribers_all() TO authenticated;
GRANT EXECUTE ON FUNCTION count_subscribers_by_cd(TEXT, BOOLEAN) TO authenticated;

GRANT EXECUTE ON FUNCTION count_donors_all() TO authenticated;
GRANT EXECUTE ON FUNCTION count_donors_by_county(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION count_donors_by_cd(TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION count_members_all() TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_by_cd(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_by_county(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_by_chapter(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_by_school(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_with_college() TO authenticated;
GRANT EXECUTE ON FUNCTION count_members_with_high_school() TO authenticated;

GRANT EXECUTE ON FUNCTION count_unique_event_attendees(UUID[]) TO authenticated;
