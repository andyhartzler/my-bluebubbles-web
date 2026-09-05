-- ATOMIC OUTREACH ACTIVITY WRITES.
--
-- OutreachRepository.createActivity used to issue three sequential inserts:
-- the activity, then its candidate links, then its participants. A failure on
-- the second or third left an activity row with a partial roster and no way to
-- tell it apart from one the exec meant to leave empty. A PostgREST RPC call
-- runs inside a single transaction, so one function call replaces the three
-- inserts and either all of it lands or none of it does.
--
-- setActivityCandidates has the same problem in the other direction: an edit
-- that drops a nominee is a delete followed by an insert, and a failure between
-- the two leaves the activity linked to neither the old set nor the new one.
--
-- SECURITY INVOKER ON PURPOSE, on both functions.
--
-- These tables are executive-committee-only: 20260726_02 gates every one of
-- them on public.is_staff() for the authenticated role. Under SECURITY INVOKER
-- the statements below run as the calling exec, so those policies apply to the
-- RPC exactly as they applied to the three inserts it replaces. A caller who
-- fails is_staff() gets a with-check violation and writes nothing.
--
-- SECURITY DEFINER would run them as the function owner instead, which bypasses
-- RLS altogether and turns a plain EXECUTE grant into a hole straight through
-- is_staff(): anyone the CRM has ever signed in could write field activity and
-- attach real members to it. There is no reason to reach for it here, because
-- nothing in these bodies needs a privilege the exec does not already hold.
--
-- EXECUTE is revoked from public and anon regardless, so the anon key that
-- ships in the public web bundle cannot reach either function even to be
-- refused by RLS.

create or replace function public.create_outreach_activity(
  p_activity jsonb,
  p_candidate_ids uuid[] default '{}',
  p_participants jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.outreach_activities (
    kind, title, description, status, channel, scheduled_on, completed_at,
    counties, congressional_districts, senate_districts, house_districts,
    organizer_member_id, created_by
  )
  select
    p_activity->>'kind',
    p_activity->>'title',
    p_activity->>'description',
    coalesce(p_activity->>'status', 'planned'),
    p_activity->>'channel',
    (p_activity->>'scheduled_on')::date,
    (p_activity->>'completed_at')::timestamptz,
    coalesce(array(select jsonb_array_elements_text(p_activity->'counties')), '{}'),
    coalesce(array(select jsonb_array_elements_text(p_activity->'congressional_districts')), '{}'),
    coalesce(array(select jsonb_array_elements_text(p_activity->'senate_districts')), '{}'),
    coalesce(array(select jsonb_array_elements_text(p_activity->'house_districts')), '{}'),
    (p_activity->>'organizer_member_id')::uuid,
    (p_activity->>'created_by')::uuid
  returning id into v_id;

  if array_length(p_candidate_ids, 1) is not null then
    insert into public.outreach_activity_candidates (activity_id, candidate_id)
    select v_id, c from unnest(p_candidate_ids) as c
    on conflict do nothing;
  end if;

  -- attended is read with ->> and cast, so a participant whose 'attended' key
  -- is absent or json null lands as SQL NULL: "not yet recorded", which the
  -- schema keeps distinct from false.
  if jsonb_array_length(p_participants) > 0 then
    insert into public.outreach_participants (activity_id, member_id, role, attended)
    select
      v_id,
      (p->>'member_id')::uuid,
      coalesce(p->>'role', 'volunteer'),
      (p->>'attended')::boolean
    from jsonb_array_elements(p_participants) as p
    on conflict (activity_id, member_id) do nothing;
  end if;

  return v_id;
end;
$$;

-- Replace an activity's candidate set in one statement pair. Passing an empty
-- array clears every link; passing NULL is treated the same way rather than
-- silently leaving the old set in place.
create or replace function public.set_outreach_activity_candidates(
  p_activity_id uuid,
  p_candidate_ids uuid[] default '{}'
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from public.outreach_activity_candidates
   where activity_id = p_activity_id
     and (p_candidate_ids is null or not (candidate_id = any (p_candidate_ids)));

  if array_length(p_candidate_ids, 1) is not null then
    insert into public.outreach_activity_candidates (activity_id, candidate_id)
    select p_activity_id, c from unnest(p_candidate_ids) as c
    on conflict do nothing;
  end if;
end;
$$;

revoke all on function public.create_outreach_activity(jsonb, uuid[], jsonb)
  from public, anon;
grant execute on function public.create_outreach_activity(jsonb, uuid[], jsonb)
  to authenticated, service_role;

revoke all on function public.set_outreach_activity_candidates(uuid, uuid[])
  from public, anon;
grant execute on function public.set_outreach_activity_candidates(uuid, uuid[])
  to authenticated, service_role;

comment on function public.create_outreach_activity(jsonb, uuid[], jsonb) is
  'Insert an outreach activity with its candidate links and participants in one transaction. SECURITY INVOKER: the executive-only RLS on all three tables still applies.';
comment on function public.set_outreach_activity_candidates(uuid, uuid[]) is
  'Replace the candidate set on an outreach activity atomically. SECURITY INVOKER: the executive-only RLS still applies.';
