-- PROMOTE A TOUCHPOINT TO AN ACTIVITY.
--
-- A touchpoint records one bulk contact: recipients, a body, an outcome, an
-- author. Sometimes that contact was field work in its own right (a text bank
-- run out of the Desk, an email blast for a nominee) and the exec wants it on
-- the activities board with a roster the rest of the CRM can work.
--
-- LINKED, NOT COPIED. The touchpoint keeps the body and the outcome; the
-- activity gets the roster, the nominees and the geography, and the touchpoint
-- carries the new activity's id. Neither row is the other's duplicate, and the
-- body is deliberately NOT copied into the activity description: there is one
-- place the words live and it is the touchpoint.
--
-- ONE TRANSACTION, for the same reason create_outreach_activity is one: the
-- activity, its nominee links, its roster and the stamp back onto the
-- touchpoint either all land or none of them do. A half-promoted touchpoint
-- would show an activity with no roster and no way to tell it from one an exec
-- meant to leave empty.
--
-- IDEMPOTENT. Promoting a row that already carries an activity_id returns that
-- activity rather than writing a second one. The read takes FOR UPDATE, so two
-- tabs pressing the button at once serialize: the second waits, re-reads the
-- row the first committed, and returns the same id. That is the same
-- compare-and-set discipline the send path uses, and for the same reason.
--
-- SECURITY INVOKER ON PURPOSE. outreach_touchpoints, outreach_activities,
-- outreach_activity_candidates and outreach_participants are all gated on
-- public.is_staff() for the authenticated role. Under INVOKER those policies
-- apply here exactly as they applied to the four statements this replaces.
-- DEFINER would run as the owner and turn a plain EXECUTE grant into a hole
-- straight through is_staff(); nothing in this body needs a privilege the
-- acting exec does not already hold.

create or replace function public.promote_touchpoint_to_activity(
  p_touchpoint_id uuid,
  p_created_by uuid,
  p_organizer_member_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  t public.outreach_touchpoints%rowtype;
  v_id uuid;
  v_delivered uuid[];
  v_kind text;
  v_label text;
  v_title text;
  v_when timestamptz;
begin
  select * into t
    from public.outreach_touchpoints
   where id = p_touchpoint_id
     for update;

  if not found then
    raise exception 'Touchpoint % does not exist', p_touchpoint_id
      using errcode = 'no_data_found';
  end if;

  -- Already promoted: hand back the activity written the first time.
  if t.activity_id is not null then
    return t.activity_id;
  end if;

  -- A draft has no outcome to log and a send that reached nobody has no
  -- roster. Both are refused rather than turned into an empty activity.
  if t.status not in ('sent', 'partial') then
    raise exception
      'Only a send that reached somebody can be logged as an activity (touchpoint % is %)',
      p_touchpoint_id, t.status
      using errcode = 'check_violation';
  end if;

  -- The roster is who the message actually REACHED. A recipient the provider
  -- rejected was not organized with, and putting them on the roster would make
  -- the activity overstate the work.
  select coalesce(array_agg(r), '{}'::uuid[])
    into v_delivered
    from unnest(t.recipient_member_ids) as r
   where not (r = any (t.failed_member_ids));

  v_when := coalesce(t.sent_at, now());
  v_kind := case t.channel when 'sms' then 'text_bank' else 'email_blast' end;
  v_label := case t.channel when 'sms' then 'Text' else 'Email' end;

  -- An email's subject is already the human name for what went out. A text has
  -- no subject, so it is named for what it did.
  v_title := nullif(btrim(coalesce(t.subject, '')), '');
  if v_title is null then
    v_title := format('%s to %s member%s',
                      v_label,
                      coalesce(array_length(v_delivered, 1), 0),
                      case when coalesce(array_length(v_delivered, 1), 0) = 1
                           then '' else 's' end);
  end if;

  insert into public.outreach_activities (
    kind, title, description, status, channel, scheduled_on, completed_at,
    counties, congressional_districts, senate_districts, house_districts,
    organizer_member_id, created_by
  )
  values (
    v_kind,
    v_title,
    format('Logged from a %s sent from the Mobilize Desk on %s. %s of %s reached. The message itself stays on the touchpoint.',
           lower(v_label),
           to_char(v_when, 'Mon FMDD, YYYY'),
           t.delivered_count,
           t.attempted_count),
    'completed',
    t.channel,
    v_when::date,
    v_when,
    t.counties,
    t.congressional_districts,
    t.senate_districts,
    t.house_districts,
    -- Attribution comes from the caller, never from the touchpoint's own
    -- actor: the two ids are separate id spaces (created_by references
    -- auth.users, organizer_member_id references public.members) and the Desk
    -- only offers this button on a send the acting exec made, so the acting
    -- exec is both the organizer and the creator of this row.
    p_organizer_member_id,
    p_created_by
  )
  returning id into v_id;

  if array_length(t.candidate_ids, 1) is not null then
    insert into public.outreach_activity_candidates (activity_id, candidate_id)
    select v_id, c from unnest(t.candidate_ids) as c
    on conflict do nothing;
  end if;

  -- attended stays NULL: "not yet recorded". Reaching somebody with a text is
  -- not the same as their turning out, and the schema keeps that distinct from
  -- an explicit false.
  if array_length(v_delivered, 1) is not null then
    insert into public.outreach_participants (activity_id, member_id, role, attended)
    select v_id, r, 'volunteer', null from unnest(v_delivered) as r
    on conflict (activity_id, member_id) do nothing;
  end if;

  update public.outreach_touchpoints
     set activity_id = v_id
   where id = p_touchpoint_id;

  return v_id;
end;
$$;

revoke all on function public.promote_touchpoint_to_activity(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.promote_touchpoint_to_activity(uuid, uuid, uuid)
  to authenticated, service_role;

comment on function public.promote_touchpoint_to_activity(uuid, uuid, uuid) is
  'Log a sent touchpoint as an outreach activity, with the recipients it actually reached as the roster, in one transaction. Idempotent: a touchpoint already carrying an activity_id returns that activity. SECURITY INVOKER: the executive-only RLS on all four tables still applies.';
