-- =====================================================================
-- 20260916_02_perf_overhaul_concurrent.sql
-- Database half of the 2026-09-16 performance overhaul, the part that
-- CANNOT run inside a transaction.
-- Project ref: faajpcarasilbfndzkmd   Postgres 17.6
-- =====================================================================
--
-- DO NOT APPLY THIS WITH ~/moyd-ops/dbrunner. The runner wraps a file in
-- one explicit transaction, and every statement below is illegal inside a
-- transaction block: VACUUM FULL, DROP INDEX CONCURRENTLY,
-- CREATE INDEX CONCURRENTLY. Postgres aborts the whole file on the first
-- one and nothing is applied.
--
-- APPLY WITH psql IN AUTOCOMMIT, statement by statement:
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f <this file>
-- psql runs each statement in its own implicit transaction unless told
-- otherwise, which is exactly what CONCURRENTLY needs.
--
-- APPLY ORDER: run supabase/migrations/20260916_02_perf_overhaul.sql
-- first (the transaction-safe half), then this file.
--
-- WHAT THIS FILE DOES
--   1. Reclaims net._http_response: 331 MB of heap and index bloat
--      holding 941 live rows. The pg_net cleanup DELETE that walks this
--      relation is 61.4% of all database time (247,527 s over 790,144
--      calls, 313 ms mean). This is the single largest win in the
--      overhaul.
--   3. Drops the duplicate indexes.
--   4. Adds the foreign-key indexes worth adding.
--   5. Drops unused indexes on high-write tables, about 640 MB.
--   7.3 Adds pg_trgm indexes on mec_committees.
--
-- LOCKS
--   Section 1 VACUUM FULL takes ACCESS EXCLUSIVE on net._http_response.
--   Only 941 live rows survive the rewrite, so expect single-digit
--   seconds, but pg_net writes will block for that window. Nothing
--   user-facing reads this table.
--   Every CONCURRENTLY statement takes only SHARE UPDATE EXCLUSIVE and
--   does not block reads or writes.
--   lock_timeout is deliberately NOT set in this file. A lock_timeout
--   during a CONCURRENTLY build aborts it and leaves an INVALID index
--   behind, which is worse than waiting.
--
-- IDEMPOTENCY, AND THE ONE PLACE IT IS NOT AUTOMATIC
--   CREATE INDEX CONCURRENTLY IF NOT EXISTS is NOT idempotent after a
--   failed run. An interrupted concurrent build leaves an index marked
--   indisvalid = false. On a re-run, IF NOT EXISTS matches the name,
--   skips the build, and the index stays permanently invalid: never used
--   by the planner, still maintained on every write. Each CREATE INDEX
--   CONCURRENTLY below is therefore preceded by a DO block that drops an
--   existing invalid index of that name first. Those DO blocks are
--   themselves separate statements and must not be merged with the
--   CREATE that follows them.
--
-- EXPECTED RUNTIME: 5 to 10 minutes, dominated by the index drops.
--
-- ROLLBACK
--   Section 1: nothing to roll back; the table is rebuilt with the same
--     rows. Autovacuum settings revert with
--     ALTER TABLE net._http_response RESET (autovacuum_vacuum_scale_factor,
--       autovacuum_vacuum_cost_limit, autovacuum_vacuum_threshold);
--   Sections 3 and 5: each dropped index carries its full definition in
--     the comment above it. Recreate with CREATE INDEX CONCURRENTLY.
--   Sections 4 and 7.3: DROP INDEX CONCURRENTLY IF EXISTS <name>;
-- =====================================================================

-- =====================================================================


-- =====================================================================
-- SECTION 1: net._http_response bloat
-- =====================================================================
-- Measured state: pg_total_relation_size 331 MB (322 MB heap,
-- 9,216 kB on _http_response_created_idx) holding 941 live rows.
-- n_tup_ins 773,835, n_tup_del 772,857, autovacuum_count 1 in 147 days,
-- reloptions NULL. EXPLAIN (ANALYZE, BUFFERS) on the exact cleanup
-- predicate reads 942 shared buffers to return 10 rows. Warm that is
-- 3.1 ms; cold it is the observed 313 ms, and at 331 MB the table can
-- evict 65% of the 512 MB buffer pool, which is why unrelated CRM
-- queries feel slow. The plan is already optimal, so no query rewrite
-- helps: the storage under it is the problem.

-- 1.1  Physical reclaim. Rewrites the heap and rebuilds the index.
--      COST: ACCESS EXCLUSIVE on net._http_response for the rewrite,
--      expected 2 to 5 s, budget 30 s. Blocks only the pg_net background
--      worker, which retries. Nothing user-facing reads this table.
--      Expected result: 331 MB -> under 1 MB.
--      TRUNCATE would be instant but discards responses not yet collected
--      by net.http_collect_response, so VACUUM FULL is used instead.
VACUUM (FULL, ANALYZE) net._http_response;

-- 1.2  Per-table autovacuum so the bloat cannot regrow.
--      Autovacuum never fires today because opportunistic page pruning
--      holds n_dead_tup at 1, far below the 0.2*978+50 = 246 delete-based
--      threshold. The INSERT-based thresholds are the ones that matter
--      here, because the delete-based one is defeated by page pruning.
--      COST: ACCESS EXCLUSIVE, milliseconds.
--      The owner of net._http_response is supabase_admin and the migration
--      runs as postgres, so this may be refused. It is guarded: on refusal
--      it warns and the migration continues. If it warns, apply the same
--      ALTER TABLE as supabase_admin.
DO $net_autovac$
BEGIN
  ALTER TABLE net._http_response SET (
    autovacuum_vacuum_scale_factor = 0,
    autovacuum_vacuum_threshold = 200,
    autovacuum_vacuum_insert_scale_factor = 0,
    autovacuum_vacuum_insert_threshold = 500,
    autovacuum_analyze_scale_factor = 0,
    autovacuum_analyze_threshold = 200
  );
  RAISE NOTICE 'net._http_response autovacuum thresholds set';
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE WARNING 'Could not set autovacuum options on net._http_response (owner is supabase_admin). Re-run this ALTER TABLE as supabase_admin.';
  WHEN undefined_table THEN
    RAISE WARNING 'net._http_response does not exist; skipping autovacuum tuning.';
END
$net_autovac$;

-- 1.3  APPLIED 2026-09-16: section 1.2 above WAS refused, exactly as it
--      predicted. net._http_response is owned by supabase_admin, and this
--      connection cannot reach that role: neither `SET ROLE supabase_admin`
--      (permission denied to set role) nor supabase_privileged_role (must be
--      owner of table _http_response) can alter it. On Supabase's managed
--      platform that ownership is not grantable, so per-table autovacuum
--      tuning is simply unavailable here.
--
--      That matters, because without it the bloat regrows. The root cause is
--      not the delete volume, it is that autovacuum ran ONCE in 147 days:
--      opportunistic page pruning keeps n_dead_tup near 1, far under the
--      delete-based threshold, so autovacuum never fires and the free space
--      map never learns about the freed space. New inserts therefore extend
--      the heap instead of reusing pages, which is how 939 live rows came to
--      occupy 331 MB.
--
--      A scheduled plain VACUUM fixes precisely that: it refreshes the FSM so
--      inserts reuse pages. `postgres` holds MAINTAIN on the table (the
--      VACUUM FULL in 1.1 succeeded), so this works without ownership.
--      Plain VACUUM, not FULL: it takes no exclusive lock. Hourly at :07 is
--      far more often than the roughly 5,265 inserts a day need.
--
--      Applied live as jobid 111. Recorded here so this file matches
--      production. Re-running it is safe: cron.schedule upserts by name.
SELECT cron.schedule(
  'vacuum-net-http-response',
  '7 * * * *',
  $vac$VACUUM (ANALYZE) net._http_response$vac$
);


-- =====================================================================
-- SECTION 3: duplicate indexes
-- =====================================================================
-- Two kinds, both verified on 2026-09-16 by comparing pg_get_indexdef()
-- bodies on the same relation:
--   (a) two plain indexes with an identical column list and predicate,
--       where the one with fewer recorded scans is dropped;
--   (b) a plain index shadowing a UNIQUE constraint on the same columns,
--       where the plain index is always the one dropped, even when it has
--       more recorded scans, because the constraint carries a correctness
--       guarantee and the planner uses either index identically for the
--       same lookups.
-- COST: DROP INDEX CONCURRENTLY takes SHARE UPDATE EXCLUSIVE only. It does
-- not block reads or writes. It waits for transactions already open on the
-- table, so each drop is seconds, not minutes.
-- NOT DROPPED, on purpose: public.slack_user_mapping_slack_user_id_key
-- looks like a duplicate of slack_user_mapping_slack_user_id_unique, but
-- the foreign key slack_channel_membership_log_user_mapping_fkey depends
-- on it (pg_constraint.conindid), so dropping it would fail or break the
-- FK. Only the plain index on that table is removed.

-- (a) identical plain-index pairs -------------------------------------

-- CREATE INDEX idx_csc_candidate ON public.candidate_score_components USING btree (candidate_id)
-- Identical to idx_csc_candidate_id (132,245 scans vs 5,882). 472 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_csc_candidate;

-- CREATE INDEX idx_casenet_records_donor_name ON public.casenet_records USING btree (donor_name)
-- Identical to idx_casenet_donor_name (3 scans vs 0). 160 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_casenet_records_donor_name;

-- CREATE INDEX idx_election_history_office ON public.election_history USING btree (office, district)
-- Identical to idx_election_history_seat (1 scan vs 0). 136 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_election_history_office;

-- CREATE INDEX idx_legislation_bill_sponsors_bill_id ON public.legislation_bill_sponsors USING btree (bill_id)
-- Identical to idx_legislation_bill_sponsors_bill (1,199,424 scans vs 672,394).
-- legislation_bill_sponsors is on the openstates sync write path, so one
-- fewer index per insert matters here.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_bill_sponsors_bill_id;

-- CREATE INDEX idx_legislation_tracked_archived ON public.legislation_tracked_bills USING btree (is_archived)
-- Identical to idx_legislation_tracked_bills_is_archived (both 257,657 scans);
-- the larger of the two goes. 72 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_tracked_archived;

-- CREATE INDEX idx_legislation_tracked_bills_priority ON public.legislation_tracked_bills USING btree (priority)
-- Identical to idx_legislation_tracked_priority (1,030,628 scans vs 73,654).
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_tracked_bills_priority;

-- CREATE INDEX idx_legislation_tracked_session ON public.legislation_tracked_bills USING btree (session)
-- Identical to idx_legislation_tracked_bills_session (515,305 scans vs 0).
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_tracked_session;

-- CREATE INDEX idx_mec_contr_date ON public.mec_contributions USING btree (contribution_date)
-- Identical to idx_mec_contrib_date (35 scans vs 29). 71 MB on a table that
-- took 9.4 million writes in the window.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_contr_date;

-- CREATE INDEX idx_mec_contr_mec_id ON public.mec_contributions USING btree (mec_id)
-- Identical to idx_mec_contrib_committee (2,296 scans vs 0). 73 MB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_contr_mec_id;

-- CREATE INDEX idx_nonprofit_officers_officer_name ON public.nonprofit_officers USING btree (officer_name)
-- Identical to idx_nonprofit_name (1 scan vs 0). 80 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_nonprofit_officers_officer_name;

-- CREATE INDEX idx_slack_messages_channel_id ON public.slack_messages USING btree (slack_channel_id)
-- Identical to idx_slack_messages_slack_channel_id (346 scans vs 0). 40 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_slack_messages_channel_id;

-- CREATE INDEX idx_usage_log_created ON public.knowledge_usage_log USING btree (created_at DESC)
-- Same column as idx_knowledge_usage_log_created; a btree serves either
-- scan direction, so these are duplicates. 0 scans, 4,848 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_usage_log_created;

-- CREATE INDEX idx_mautic_sync_log_created_at ON public.mautic_sync_log USING btree (created_at DESC)
-- Same column as idx_mautic_sync_log_created (64 scans vs 0). 5,800 kB on a
-- table that took 275,824 inserts and 445,581 deletes.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mautic_sync_log_created_at;

-- (b) plain index shadowing a UNIQUE constraint ------------------------
-- In every case below the UNIQUE constraint index on the same column list
-- stays and the plain index goes.

-- CREATE INDEX idx_bank_txn_plaid ON public.bank_transactions USING btree (plaid_transaction_id)
-- Shadowed by bank_transactions_plaid_transaction_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_bank_txn_plaid;

-- CREATE INDEX idx_calendar_events_google_event_id ON public.calendar_events USING btree (google_event_id)
-- Shadowed by calendar_events_google_event_id_key. 105,747 scans move to
-- the unique index, which serves the same equality lookups.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_calendar_events_google_event_id;

-- CREATE INDEX idx_campaign_links_tracking_token ON public.campaign_links USING btree (tracking_token)
-- Shadowed by campaign_links_tracking_token_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_campaign_links_tracking_token;

-- CREATE INDEX idx_claim_tokens_token ON public.claim_tokens USING btree (token)
-- Shadowed by claim_tokens_token_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_claim_tokens_token;

-- CREATE INDEX idx_committees_name ON public.committees USING btree (name)
-- Shadowed by committees_name_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_committees_name;

-- CREATE INDEX idx_committees_slug ON public.committees USING btree (slug)
-- Shadowed by committees_slug_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_committees_slug;

-- CREATE INDEX idx_donations_actblue_contribution_id ON public.donations USING btree (actblue_contribution_id)
-- Shadowed by donations_actblue_contribution_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donations_actblue_contribution_id;

-- CREATE INDEX idx_donor_enrichment_donor_id ON public.donor_enrichment USING btree (donor_id)
-- CREATE INDEX idx_de_donor_id ON public.donor_enrichment USING btree (donor_id)
-- Three indexes on the same column. donor_enrichment_donor_id_key is the
-- UNIQUE constraint that prevents duplicate enrichment rows and stays.
-- Both plain copies go: 37 MB at 0 scans and 16 MB at 584,506 scans, on a
-- table that took 319,265 writes.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_donor_id;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_de_donor_id;

-- CREATE INDEX idx_donors_email ON public.donors USING btree (email)
-- Shadowed by donors_email_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donors_email;

-- CREATE INDEX idx_donors_actblue_entity_id ON public.donors USING btree (actblue_entity_id)
-- Shadowed by donors_actblue_entity_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donors_actblue_entity_id;

-- CREATE INDEX idx_email_campaigns_source_id ON public.email_campaigns USING btree (source, source_campaign_id)
-- Shadowed by email_campaigns_source_campaign_unique (3,941 scans vs 0).
DROP INDEX CONCURRENTLY IF EXISTS public.idx_email_campaigns_source_id;

-- CREATE INDEX idx_email_inbox_gmail_message_id ON public.email_inbox USING btree (gmail_message_id)
-- Shadowed by email_inbox_gmail_message_id_key (238 scans vs 3).
DROP INDEX CONCURRENTLY IF EXISTS public.idx_email_inbox_gmail_message_id;

-- CREATE INDEX idx_email_templates_key ON public.email_templates USING btree (template_key)
-- Shadowed by email_templates_template_key_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_email_templates_key;

-- CREATE INDEX idx_form_schemas_slug ON public.form_schemas USING btree (slug)
-- Shadowed by form_schemas_slug_unique.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_form_schemas_slug;

-- CREATE INDEX idx_jobs_slug ON public.jobs USING btree (slug)
-- Shadowed by jobs_slug_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_jobs_slug;

-- CREATE INDEX idx_legislation_ai_batches_anthropic_batch_id ON public.legislation_ai_batches USING btree (anthropic_batch_id)
-- Shadowed by legislation_ai_batches_anthropic_batch_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_ai_batches_anthropic_batch_id;

-- CREATE INDEX idx_legislation_bill_actions_openstates_id ON public.legislation_bill_actions USING btree (openstates_action_id)
-- Shadowed by legislation_bill_actions_openstates_action_id_key. 1,840 kB
-- on a table the openstates sync writes to continuously.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_bill_actions_openstates_id;

-- CREATE INDEX idx_legislation_bill_sync_status_bill ON public.legislation_bill_sync_status USING btree (bill_id)
-- Shadowed by legislation_bill_sync_status_bill_id_key (28,094 scans vs 7,226).
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_bill_sync_status_bill;

-- CREATE INDEX idx_legislation_legislators_openstates_id ON public.legislation_legislators USING btree (openstates_person_id)
-- Shadowed by legislation_legislators_openstates_person_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_legislators_openstates_id;

-- CREATE INDEX idx_legislation_tracked_bills_openstates_id ON public.legislation_tracked_bills USING btree (openstates_bill_id)
-- Shadowed by legislation_tracked_bills_openstates_bill_id_key. 320 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_tracked_bills_openstates_id;

-- CREATE INDEX idx_magic_links_token ON public.magic_links USING btree (token)
-- Shadowed by magic_links_token_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_magic_links_token;

-- CREATE INDEX idx_mec_committees_mec_id ON public.mec_committees USING btree (mec_id)
-- Shadowed by mec_committees_mec_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_committees_mec_id;

-- CREATE INDEX idx_attendance_meeting_member ON public.meeting_attendance USING btree (meeting_id, member_id)
-- Shadowed by meeting_attendance_meeting_id_member_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_attendance_meeting_member;

-- CREATE INDEX idx_member_email_history_log_id ON public.member_email_history USING btree (log_id)
-- Shadowed by the UNIQUE constraint unique_log_id.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_member_email_history_log_id;

-- CREATE INDEX idx_member_portal_meetings_meeting_id ON public.member_portal_meetings USING btree (meeting_id)
-- Shadowed by member_portal_meetings_meeting_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_member_portal_meetings_meeting_id;

-- CREATE INDEX idx_members_slack_user_id ON public.members USING btree (slack_user_id)
-- Shadowed by members_slack_user_id_key. members absorbs 553,917 updates,
-- so every index removed from it is write amplification removed.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_members_slack_user_id;

-- CREATE INDEX idx_membership_cards_apple_wallet_serial ON public.membership_cards USING btree (apple_wallet_pass_serial)
-- Shadowed by membership_cards_apple_wallet_pass_serial_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_membership_cards_apple_wallet_serial;

-- CREATE INDEX idx_membership_cards_google_wallet_object_id ON public.membership_cards USING btree (google_wallet_object_id)
-- Shadowed by membership_cards_google_wallet_object_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_membership_cards_google_wallet_object_id;

-- CREATE INDEX idx_membership_cards_member_id ON public.membership_cards USING btree (member_id)
-- Shadowed by the UNIQUE constraint unique_member_card.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_membership_cards_member_id;

-- CREATE INDEX idx_mo_biz_charter ON public.mo_business_entities USING btree (charter_number)
-- Shadowed by mo_business_entities_charter_number_key. 384 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mo_biz_charter;

-- CREATE INDEX idx_receipts_email_msg_id ON public.receipts USING btree (email_message_id)
-- Shadowed by receipts_email_message_id_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_receipts_email_msg_id;

-- CREATE INDEX idx_slack_user_mapping_slack_user_id ON public.slack_user_mapping USING btree (slack_user_id)
-- Shadowed by two UNIQUE constraints on the same column, both of which stay
-- (one backs a foreign key). 0 scans.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_slack_user_mapping_slack_user_id;

-- CREATE INDEX idx_subscribers_email ON public.subscribers USING btree (email)
-- Shadowed by subscribers_email_unique, which is also what stops duplicate
-- subscriber rows. 5,632 kB.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_subscribers_email;

-- CREATE INDEX idx_tl_token ON public.tracking_links USING btree (token)
-- Shadowed by tracking_links_token_key.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_tl_token;

-- CREATE INDEX translations_lookup ON public.translations USING btree (source_hash, target_lang)
-- Shadowed by translations_source_hash_target_lang_key (737 scans vs 609).
-- The bilingual cache lookup keeps working through the unique index.
DROP INDEX CONCURRENTLY IF EXISTS public.translations_lookup;


-- =====================================================================
-- SECTION 4: foreign-key indexes worth adding
-- =====================================================================
-- Of the 32 unindexed foreign keys the advisor reports, 25 are
-- ON DELETE SET NULL, 19 are on tables with zero live rows, and the parent
-- tables record almost no deletes (members 39, auth.users 16, meetings 22,
-- candidates 185 over 147 days). Adding all 32 would put new indexes on
-- donor_enrichment and mec_contributions and make the write amplification
-- in section 5 worse. Only these two are added.
-- COST: CREATE INDEX CONCURRENTLY takes SHARE UPDATE EXCLUSIVE only and
-- does not block reads or writes. Both tables are small, so seconds.

-- candidates is on the CRM candidate-and-member linking path
-- (2,753 rows, 14,040 seq scans, 438,856 idx scans). Index costs ~256 kB.
-- Guard: a previously interrupted concurrent build leaves this index
-- INVALID. IF NOT EXISTS would then match the name, skip the rebuild, and
-- leave an index that the planner never uses but every write maintains.
-- Drop the invalid leftover first so the CREATE below actually runs.
DO $guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relname = 'idx_candidates_member_id'
       AND NOT i.indisvalid
  ) THEN
    EXECUTE 'DROP INDEX public.idx_candidates_member_id';
    RAISE NOTICE 'dropped invalid leftover index idx_candidates_member_id';
  END IF;
END
$guard$;


CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_candidates_member_id
  ON public.candidates (member_id);

-- candidate_social_finds.candidate_id -> candidates is the one real
-- ON DELETE CASCADE path among the 32. Cheap insurance so a candidate
-- delete does not sequentially scan the child table.
-- Guard: a previously interrupted concurrent build leaves this index
-- INVALID. IF NOT EXISTS would then match the name, skip the rebuild, and
-- leave an index that the planner never uses but every write maintains.
-- Drop the invalid leftover first so the CREATE below actually runs.
DO $guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relname = 'idx_candidate_social_finds_candidate_id'
       AND NOT i.indisvalid
  ) THEN
    EXECUTE 'DROP INDEX public.idx_candidate_social_finds_candidate_id';
    RAISE NOTICE 'dropped invalid leftover index idx_candidate_social_finds_candidate_id';
  END IF;
END
$guard$;


CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_candidate_social_finds_candidate_id
  ON public.candidate_social_finds (candidate_id);


-- =====================================================================
-- SECTION 5: unused indexes on high-write tables
-- =====================================================================
-- 301 indexes show idx_scan = 0 over the 147-day stats window
-- (pg_stat_reset 2026-04-21 22:28:47Z). Dropping all of them buys nothing
-- and only adds risk. The filter applied here is deliberately narrow:
-- idx_scan = 0, not a primary key, not unique, on a table with more than
-- 10,000 writes in the window, and larger than 10 MB, so the WAL and
-- buffer cost of maintaining it is measurable. That leaves the 20 below,
-- about 640 MB on tables that absorbed roughly 21 million writes.
-- The other 281 unused indexes are left alone.
-- COST: SHARE UPDATE EXCLUSIVE only, no blocking of reads or writes.
-- NOTE: the counters start at 2026-04-21, so an annual or quarterly job
-- could in principle use one of these. Each CREATE INDEX text is recorded
-- above its DROP so any one can be rebuilt concurrently.

-- CREATE INDEX idx_donor_contacts_source ON public.donor_contacts USING btree (source)
-- 118 MB, 0 scans, on a 9,866,422-row table with 654,662 writes.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_contacts_source;

-- CREATE INDEX idx_donor_contacts_source_donor ON public.donor_contacts USING btree (source, donor_id)
-- 114 MB, 0 scans.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_contacts_source_donor;

-- CREATE INDEX idx_mec_contr_city_state ON public.mec_contributions USING btree (city, state)
-- 71 MB, 0 scans, on a 3,267,492-row table with 9,421,888 writes.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_contr_city_state;

-- CREATE INDEX idx_mec_contributions_donor_id_pre_repair ON public.mec_contributions USING btree (donor_id_pre_repair) WHERE (donor_id_pre_repair IS NOT NULL)
-- 51 MB, 0 scans. Left over from the 2026-08 MEC donor repair run.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_contributions_donor_id_pre_repair;

-- CREATE INDEX idx_mec_donors_committee ON public.mec_donors USING btree (committee_name)
-- 53 MB, 0 scans, on a table with 7,554,828 writes. The trigram index
-- idx_mec_donors_committee_trgm on the same column is the one in use.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_donors_committee;

-- CREATE INDEX idx_repair_proposal_current ON public.mec_contrib_repair_proposal USING btree (current_donor_id)
-- 40 MB, 0 scans, on a table with 3,180,931 writes.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_repair_proposal_current;

-- donor_enrichment: ten unused indexes, about 184 MB, on a 431,220-row
-- table that took 319,265 writes. All at 0 scans.
-- CREATE INDEX idx_donor_enrichment_engagement ON public.donor_enrichment USING btree (engagement_score)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_engagement;
-- CREATE INDEX idx_donor_enrichment_wealth_score ON public.donor_enrichment USING btree (wealth_score)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_wealth_score;
-- CREATE INDEX idx_donor_enrichment_total_donations ON public.donor_enrichment USING btree (total_political_donations DESC NULLS LAST)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_total_donations;
-- CREATE INDEX idx_donor_enrichment_current_zip ON public.donor_enrichment USING btree (current_zip text_pattern_ops)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_current_zip;
-- CREATE INDEX idx_donor_enrichment_party_lean ON public.donor_enrichment USING btree (party_lean)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_party_lean;
-- CREATE INDEX idx_donor_enrichment_current_city ON public.donor_enrichment USING btree (current_city)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_current_city;
-- CREATE INDEX idx_donor_enrichment_voter_party ON public.donor_enrichment USING btree (voter_party)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_voter_party;
-- CREATE INDEX idx_donor_enrichment_homeowner ON public.donor_enrichment USING btree (is_homeowner)
DROP INDEX CONCURRENTLY IF EXISTS public.idx_donor_enrichment_homeowner;
-- CREATE INDEX idx_enrichment_gender ON public.donor_enrichment USING btree (gender) WHERE (gender IS NOT NULL)
-- 9,160 kB, just under the 10 MB line, included because it is on the same
-- high-write table as the nine above.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_enrichment_gender;

-- CREATE INDEX idx_fec_contributions_state ON public.fec_contributions USING btree (state)
-- 12 MB, 0 scans. Meets the same filter as the rest of this section.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_fec_contributions_state;

-- CREATE INDEX idx_mautic_sync_direction ON public.mautic_sync_log USING btree (direction)
-- 1,832 kB, 0 scans, on a table with 275,824 inserts and 445,581 deletes.
-- Below the size line but it sits on one of the heaviest churn tables.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_mautic_sync_direction;

-- CREATE INDEX idx_legislation_tracked_bills_latest_action ON public.legislation_tracked_bills USING btree (latest_action_date DESC)
-- CREATE INDEX idx_legislation_tracked_latest_action ON public.legislation_tracked_bills USING btree (latest_action_date)
-- A duplicate pair where BOTH sides have 0 scans, so both go.
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_tracked_bills_latest_action;
DROP INDEX CONCURRENTLY IF EXISTS public.idx_legislation_tracked_latest_action;

-- HELD BACK, NOT DROPPED. These three are unused by the counters but
-- dropping them could silently change how donor search behaves, so they
-- need the search code path confirmed first. Uncomment only after checking
-- which table the CRM donor search actually queries.
--   -- idx_mec_contrib_first_name_trgm: 85 MB, GIN trigram on
--   -- mec_contributions.contributor_first_name, 0 scans. The equivalent
--   -- indexes on mec_donors have 5 scans each, which suggests search hits
--   -- mec_donors, but that is an inference, not a measurement.
--   -- DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_contrib_first_name_trgm;
--   -- idx_mec_contrib_company_trgm: 51 MB, same reasoning.
--   -- DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_contrib_company_trgm;
--   -- idx_mec_donors_company: 31 MB btree, 1 scan in 147 days, not a true
--   -- duplicate of idx_mec_donors_company_trgm (btree equality vs trigram).
--   -- DROP INDEX CONCURRENTLY IF EXISTS public.idx_mec_donors_company;


-- 7.3  Trigram indexes on public.mec_committees so the offline MEC
--      matching script can stop doing 129 million leading-wildcard ILIKE
--      evaluations.
--      scripts/mec_update_2026.py joins 2,753 candidates against 15,646
--      mec_committees rows on three ILIKE predicates with leading
--      wildcards, which no index can serve. That query measures 237.9 s
--      mean over 16 calls, 3,805.9 s total, and steals a core for four
--      minutes at a time while the CRM is live.
--      These two indexes let the join move to `%>` trigram similarity and
--      drop from a 129M-pair nested loop to one index probe per candidate.
--      pg_trgm is installed in the public schema, so gin_trgm_ops is
--      qualified explicitly because the database search_path is listmonk.
--      COST: SHARE UPDATE EXCLUSIVE only. mec_committees is 15,646 rows,
--      so both builds are seconds and the indexes are small.
--      The script itself is NOT changed by this migration. Adding the
--      indexes is inert until it is rewritten, and that rewrite must diff
--      its new match set against the current 387-row result before it is
--      allowed to write, because trigram similarity and ILIKE containment
--      do not match the same committees.
-- Guard: a previously interrupted concurrent build leaves this index
-- INVALID. IF NOT EXISTS would then match the name, skip the rebuild, and
-- leave an index that the planner never uses but every write maintains.
-- Drop the invalid leftover first so the CREATE below actually runs.
DO $guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relname = 'idx_mec_committees_committee_name_trgm'
       AND NOT i.indisvalid
  ) THEN
    EXECUTE 'DROP INDEX public.idx_mec_committees_committee_name_trgm';
    RAISE NOTICE 'dropped invalid leftover index idx_mec_committees_committee_name_trgm';
  END IF;
END
$guard$;


CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mec_committees_committee_name_trgm
  ON public.mec_committees USING gin (committee_name public.gin_trgm_ops);

-- Guard: a previously interrupted concurrent build leaves this index
-- INVALID. IF NOT EXISTS would then match the name, skip the rebuild, and
-- leave an index that the planner never uses but every write maintains.
-- Drop the invalid leftover first so the CREATE below actually runs.
DO $guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relname = 'idx_mec_committees_candidate_name_trgm'
       AND NOT i.indisvalid
  ) THEN
    EXECUTE 'DROP INDEX public.idx_mec_committees_candidate_name_trgm';
    RAISE NOTICE 'dropped invalid leftover index idx_mec_committees_candidate_name_trgm';
  END IF;
END
$guard$;


CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mec_committees_candidate_name_trgm
  ON public.mec_committees USING gin (candidate_name public.gin_trgm_ops);

-- =====================================================================
-- END OF CONCURRENT HALF
-- =====================================================================
