-- public.search_knowledge_base was callable by `anon`: SECURITY DEFINER, EXECUTE
-- granted to PUBLIC (which anon and authenticated inherit), over a table owned by
-- postgres with relforcerowsecurity = false, so the definer bypassed RLS entirely.
--
-- knowledge_documents holds 78,830 rows mirroring public.subscribers (73,267),
-- public.members (419, including home addresses), public.donors (49) and 67 full
-- executive meeting transcripts. 20260807_10 closed the direct table read and did
-- nothing about this function, because a SECURITY DEFINER function does not consult
-- the caller's policies at all. Closing one without the other moves the door rather
-- than shutting it.
--
-- match_threshold is a caller-supplied double with no floor, so a negative value
-- matches everything. Confirmed against the live endpoint with the publishable key
-- before the fix, and 42501 permission denied after it.
--
-- REVOKED FROM PUBLIC RATHER THAN ONLY FROM anon. Revoking anon alone leaves the
-- PUBLIC grant, which anon holds anyway by membership, so the revoke would have
-- looked effective and changed nothing.
--
-- NO CALLER BREAKS. The only reference in either repo is
-- supabase/functions/query-knowledge-base/index.ts:1080, issued on the client built
-- from SUPABASE_SERVICE_ROLE_KEY at line 9, not the user client at line 26. That
-- function gates its own callers with is_staff() at line 38, which as of
-- 20260807_13 means executive rather than anyone-who-ticked-a-committee-box.
revoke execute on function public.search_knowledge_base(
  vector, integer, double precision, text, text, jsonb) from public;
revoke execute on function public.search_knowledge_base(
  vector, integer, double precision, text, text, jsonb) from anon;
revoke execute on function public.search_knowledge_base(
  vector, integer, double precision, text, text, jsonb) from authenticated;

grant execute on function public.search_knowledge_base(
  vector, integer, double precision, text, text, jsonb) to service_role;

-- A SECURITY DEFINER function with no search_path resolves unqualified names against
-- the caller's path, so a caller who can create objects can shadow a table name and
-- have it executed as the owner. Every other gate function in this schema (is_staff,
-- is_executive, is_committee_member) already pins this; this one did not.
alter function public.search_knowledge_base(
  vector, integer, double precision, text, text, jsonb) set search_path to 'public';
