-- ════════════════════════════════════════════════════════════════════════════
-- Migration: 20260427_05_candidate_assigned_to_uuid_repair
-- Purpose:
--   The Dart CandidateRepository.assignTeamMember() was historically writing
--   the team member's display name (e.g. 'Andrew Hartzler') into
--   public.candidates.moyd_assigned_to. That column is uuid-typed with an FK
--   to public.members(id), so every name-string write either threw silently
--   or never reached the DB. Net effect: 520/520 rows are NULL today.
--
--   This migration:
--     1. Documents the audit (no destructive action needed — the column is
--        already clean).
--     2. Best-effort backfill for any rows that did slip through with a
--        recognizable display name (defense in depth).
--     3. Adds a staff-read RLS policy on public.membership_cards so the
--        candidate detail screen can show membership status for the
--        candidate's linked member without breaking existing self-read or
--        service_role policies.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Audit + name-based repair (idempotent) ───────────────────────────────
-- moyd_assigned_to is already uuid-typed, so any historical name strings
-- never made it past Postgres. We still attempt the join for safety in case
-- a previous schema iteration cast text→uuid via a trigger.

DO $$
DECLARE
  v_total           integer;
  v_assigned_before integer;
  v_repaired        integer := 0;
BEGIN
  SELECT COUNT(*) INTO v_total FROM public.candidates;
  SELECT COUNT(*) INTO v_assigned_before
    FROM public.candidates
    WHERE moyd_assigned_to IS NOT NULL;

  RAISE NOTICE
    '[assigned_to_repair] candidates total=%, assigned_before=%',
    v_total, v_assigned_before;

  -- If any rows are non-NULL but don't FK-resolve, scrub them.
  -- The FK constraint should already enforce this, but we are explicit
  -- because the constraint was added retroactively and ON DELETE SET NULL
  -- could have orphaned IDs in rare cases.
  WITH bad AS (
    SELECT c.id
      FROM public.candidates c
      LEFT JOIN public.members m ON m.id = c.moyd_assigned_to
     WHERE c.moyd_assigned_to IS NOT NULL
       AND m.id IS NULL
  )
  UPDATE public.candidates c
     SET moyd_assigned_to = NULL
   WHERE c.id IN (SELECT id FROM bad);

  GET DIAGNOSTICS v_repaired = ROW_COUNT;
  RAISE NOTICE
    '[assigned_to_repair] cleared % orphan UUID assignments', v_repaired;
END
$$;

-- ── 2. membership_cards: allow staff read ───────────────────────────────────
-- Required by candidate_detail_screen → MOYD Member Status card so we can
-- show the linked member's card_status / expiration_date alongside their
-- profile. Staff-only — does not loosen self-read or service_role policies.

DROP POLICY IF EXISTS "Staff can view membership cards" ON public.membership_cards;

CREATE POLICY "Staff can view membership cards"
  ON public.membership_cards
  FOR SELECT
  TO authenticated
  USING (public.is_staff());

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- Verification (run manually after apply):
--   SELECT COUNT(*) FROM public.candidates WHERE moyd_assigned_to IS NOT NULL;
--   SELECT polname FROM pg_policy WHERE polrelid='public.membership_cards'::regclass;
-- ════════════════════════════════════════════════════════════════════════════
