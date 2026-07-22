-- endorsement_votes v2: 3-way vote + reason capture. Applied to prod
-- (faajpcarasilbfndzkmd) via psql 2026-07-21, pre-meeting.
-- Pre-flight verified before apply:
--   * existing CHECK name = endorsement_votes_vote_check (yes/no only)
--   * 58 legacy rows, all yes/no, 2 voters (Elmedin Karamovic, Chloé Ray),
--     both still executive_committee = true with non-null user_id
--   * exec roster = 16 members with user_id
--   * chair uid = f1ac8208-ad64-405f-8b55-8284ddef51cf (andrew@hartzler.us,
--     last_sign_in 2026-07-18; andrew@moyoungdemocrats.org auth account is
--     dormant since April and has no members row)
--   * supabase_realtime publication already includes endorsement_votes and
--     endorsement_decisions; after apply, publication attnames picked up
--     reason_codes + other_text automatically (verified).
-- RLS: intentionally unchanged (policies are column-agnostic and already in
-- wrapped (SELECT ...) form). JWT-simulation verified post-apply:
--   * exec inserts/updates OWN row incl vote='undecided' + reason_codes: OK
--   * exec writing another voter_id: RLS violation (blocked)
--   * anon select: 0 rows
-- Known accepted gap (flagged in spec §-1.4): endorsement_votes_staff_read
-- lets any committee member (is_staff), not just exec, read all ballots
-- including reason text. Tighten to exec-only if non-exec staff will have
-- live sessions during a meeting.

begin;

alter table public.endorsement_votes
  drop constraint if exists endorsement_votes_vote_check;

alter table public.endorsement_votes
  add constraint endorsement_votes_vote_check
  check (vote in ('yes', 'no', 'undecided'));

alter table public.endorsement_votes
  add column reason_codes text[] not null default '{}',
  add column other_text   text,
  add constraint endorsement_votes_other_text_len
    check (other_text is null or length(other_text) <= 2000);

commit;

-- Post-apply verification (all run 2026-07-21, all passed):
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--     where conrelid = 'public.endorsement_votes'::regclass;
--   select count(*) from public.endorsement_votes;                        -- 58
--   select count(*) from public.endorsement_votes where reason_codes <> '{}'; -- 0
--   select attnames from pg_publication_tables where tablename = 'endorsement_votes';
--     -- {candidate_id,voter_id,voter_name,vote,updated_at,reason_codes,other_text}

-- ---------------------------------------------------------------------------
-- Addendum, applied 2026-07-21 (Andrew-approved): close the read gap.
-- endorsement_votes_staff_read let ANY committee member (is_staff) read all
-- ballots + reason text. Replaced with exec-only read via the pre-existing
-- public.is_executive() (STABLE SECURITY DEFINER, search_path pinned),
-- wrapped (SELECT ...) form per the RLS InitPlan rule.
--
-- begin;
-- drop policy endorsement_votes_staff_read on public.endorsement_votes;
-- create policy endorsement_votes_exec_read on public.endorsement_votes
--   for select to authenticated
--   using ((select public.is_executive()));
-- commit;
--
-- JWT-simulation verified post-apply (all rolled back):
--   * exec (chair uid) reads all 58 ballots: OK
--   * non-exec staff (is_staff=t, is_executive=f) reads 0 rows: OK
--   * exec insert of own undecided+reason ballot: OK (own_write unchanged)
-- Rollback (if ever needed): recreate the old policy as
--   create policy endorsement_votes_staff_read on public.endorsement_votes
--     for select to authenticated using ((select is_staff()));
-- Note: endorsement_votes_own_write still uses is_staff(), so non-exec staff
-- can technically write (and read, via the ALL policy) their OWN vote row.
-- The hub UI is exec-gated so no one legitimately hits this; tighten to
-- is_executive() as a follow-up if desired.
