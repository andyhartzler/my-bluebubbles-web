-- knowledge_documents was readable by EVERY authenticated account.
--
-- The policy was `to authenticated using (true)` over 78,830 rows that are a
-- verbatim mirror of the most sensitive data the org holds: 73,267 rows from
-- public.subscribers, all 419 from public.members (name, email, phone and street
-- address in a single document), 49 from public.donors, 67 full executive meeting
-- transcripts and 1,360 slack_messages. auth.users holds 495 accounts, 494 of them
-- confirmed, so 494 people could `select * from knowledge_documents` over
-- PostgREST and read all of it.
--
-- WHY THIS IS WORSE THAN AN ORDINARY OVER-BROAD GRANT: nothing here requires the
-- account holder to have ever signed up. trigger_auto_create_auth_user on
-- public.members inserts straight into auth.users with email_confirmed_at pre-set
-- for every person a chartering roster upload creates. A high school chapter
-- uploading forty names therefore mints up to forty confirmed accounts, in the
-- names of people who were never told an account exists, each of which could read
-- every subscriber and every member's home address. The chartering pipeline is a
-- machine for manufacturing readers of this table.
--
-- GATED ON is_executive() AND NOT is_staff(), WHICH IS A DELIBERATE DEPARTURE FROM
-- THE FUNCTION LAYER. query-knowledge-base gates its callers on is_staff(), and
-- copying that here was the obvious move and the wrong one: is_staff() is
-- `executive_committee = true OR committee IS NOT NULL`, and committee is populated
-- from the ordinary signup form, so it currently matches 273 of 419 members.
-- Gating on it would have left 73,267 subscriber records exposed to a majority of
-- the membership and would have read like a fix while barely being one.
--
-- The two are not the same capability and should not carry the same gate. The
-- function layer answers a semantic query and returns a handful of chunks. A
-- direct table read returns the entire corpus verbatim. Only the second is being
-- closed here.
--
-- NOTHING LOSES FUNCTIONALITY. query-knowledge-base performs its retrieval with the
-- SERVICE ROLE client, which bypasses RLS entirely, so AI assistant answers are
-- untouched for every staff caller that could get them yesterday. The only code in
-- either repo that reads this table on a user JWT is the AI assistant stats screen
-- in lib/features/ai_assistant/services/ai_assistant_service.dart, which reads
-- counts and source_table/source_type metadata and no content, and which lives in
-- the CRM. CRM access is already executive-committee-only, so its real audience is
-- unchanged.
--
-- VERIFIED AGAINST THE RUNNING SYSTEM, not against the policy text. Impersonating a
-- real non-executive member who holds a committee value (the exact population
-- is_staff() would have admitted) took them from 78,830 rows to 0. The chair still
-- reads 78,830. An unknown uid reads 0.
drop policy if exists "Authenticated users can view" on public.knowledge_documents;

create policy "Executives can view knowledge documents"
  on public.knowledge_documents
  for select
  to authenticated
  using (public.is_executive());
