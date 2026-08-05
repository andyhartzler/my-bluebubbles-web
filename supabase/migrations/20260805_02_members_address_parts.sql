-- ============================================================================
-- 20260805_02_members_address_parts
--
-- public.members has ONE address column and it holds a joined string:
-- "1 Main St, Columbia, Missouri, 65201". There is no city, no state and no
-- zip_code column anywhere on the table (checked against information_schema on
-- 2026-08-05: zero columns matching city/state/zip/postal).
--
-- Three things degrade from that, and all three are on the membership signup
-- path:
--   * lookup-districts has to re-parse a string it should have been handed as
--     parts. 413 members have an address and only 71 have any district.
--   * sync-to-mautic already maps member.city / member.state / member.zip_code,
--     so today it maps three fields that do not exist and Mautic gets nothing
--     to segment on.
--   * the Mautic loop-guard compares columns that are permanently null.
--
-- ORDER MATTERS. This lands AFTER the sync-to-mautic state fix, not before.
-- Mautic's `state` field is type `region` and its accepted choices are full
-- state names; the function used to normalize "Missouri" down to "MO", which
-- Mautic rejects with HTTP 400 "The selected choice is invalid". The member
-- sync survived only because members.state did not exist and the field was
-- omitted. Creating the column before fixing the normalizer would have newly
-- broken the one Mautic sync that currently works.
-- ============================================================================

ALTER TABLE public.members ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS state text;
ALTER TABLE public.members ADD COLUMN IF NOT EXISTS zip_code text;

COMMENT ON COLUMN public.members.city IS 'Address part, written by the membership form. members.address stays the joined display string.';
COMMENT ON COLUMN public.members.state IS 'Full state name ("Missouri"), not the code. sync-to-mautic sends this verbatim and Mautic''s region field only accepts full names.';
COMMENT ON COLUMN public.members.zip_code IS 'Address part, written by the membership form. Drives the ZIP-to-county lookup.';
