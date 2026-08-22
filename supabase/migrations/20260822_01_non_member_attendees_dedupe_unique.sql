-- Deduplicate public.non_member_attendees and make re-enrichment idempotent.
--
-- Root cause: meeting_attendance has UNIQUE (meeting_id, member_id), and
-- meetings-zap already swallows 23505 on every insert, so repeated enrichment
-- passes were harmless there. non_member_attendees had no equivalent key, so
-- each pass inserted a fresh row. The 2026-08-12 executive meeting accumulated
-- 6 identical rows for each of 2 guests (same first_join_time on all six,
-- i.e. six INSERT passes, not six rejoins).
--
-- A genuine rejoin is already expressible on this table: number_of_joins and
-- total_duration_minutes exist and meetings-zap aggregates a participant's
-- joins before writing. No schema change is needed to represent rejoins, only
-- a key that stops the same aggregate being written twice.
--
-- Merge rule: max(), not sum(). Every duplicate pass rewrote the same
-- already-aggregated value, so summing number_of_joins would turn 1 real join
-- into 6.

-- 1. Fold each duplicate group's values onto the surviving row.
with agg as (
  select
    meeting_id,
    display_name,
    coalesce(email, '')            as email_key,
    min(first_join_time)           as first_join_time,
    max(last_leave_time)           as last_leave_time,
    max(total_duration_minutes)    as total_duration_minutes,
    max(number_of_joins)           as number_of_joins,
    max(phone_number)              as phone_number,
    max(pronouns)                  as pronouns
  from public.non_member_attendees
  group by 1, 2, 3
  having count(*) > 1
),
keep as (
  select distinct on (meeting_id, display_name, coalesce(email, ''))
    id,
    meeting_id,
    display_name,
    coalesce(email, '') as email_key
  from public.non_member_attendees
  order by meeting_id, display_name, coalesce(email, ''), created_at nulls last, id
)
update public.non_member_attendees n
set
  first_join_time        = agg.first_join_time,
  last_leave_time        = agg.last_leave_time,
  total_duration_minutes = agg.total_duration_minutes,
  number_of_joins        = agg.number_of_joins,
  phone_number           = coalesce(n.phone_number, agg.phone_number),
  pronouns               = coalesce(n.pronouns, agg.pronouns)
from keep
join agg
  on  agg.meeting_id   = keep.meeting_id
  and agg.display_name = keep.display_name
  and agg.email_key    = keep.email_key
where n.id = keep.id;

-- 2. Drop the surplus rows, keeping the oldest row per person per meeting.
delete from public.non_member_attendees n
using (
  select
    id,
    row_number() over (
      partition by meeting_id, display_name, coalesce(email, '')
      order by created_at nulls last, id
    ) as rn
  from public.non_member_attendees
) d
where d.id = n.id
  and d.rn > 1;

-- 3. One row per person per meeting, enforced.
--    NULLS NOT DISTINCT is required: email is null for every attendee on the
--    affected meeting, and default null-distinct semantics would let the
--    duplicates straight back in.
alter table public.non_member_attendees
  add constraint non_member_attendees_meeting_person_key
  unique nulls not distinct (meeting_id, display_name, email);

comment on constraint non_member_attendees_meeting_person_key on public.non_member_attendees is
  'One row per guest per meeting. Rejoins belong in number_of_joins / total_duration_minutes, not extra rows. meetings-zap upserts on this key.';
