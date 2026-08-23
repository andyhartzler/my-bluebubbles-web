-- Enforce the under-18 exclusion for the face index IN THE DATABASE.
--
-- WHY THIS IS A TRIGGER AND NOT A LOADER CHECK. The exclusion previously
-- existed nowhere. The hardcoded roster the loader read listed all 15
-- executives, the one member currently under 18 among them. That member is
-- absent from the index today only because their single reference photo is a
-- 320px avatar that YuNet finds no face in. That is luck, not policy: a
-- clearer photo, or the next holder of a seat routinely filled by a minor,
-- would have been indexed silently.
--
-- The check is LIVE against members.date_of_birth rather than a name list, so
-- it stays correct as people age in and out. A NULL date_of_birth is REJECTED:
-- an unknown age cannot be shown to be an adult, and biometric data is the
-- wrong place to give the benefit of the doubt.
--
-- Enforcement is in two places on purpose:
--   1. a BEFORE INSERT OR UPDATE trigger, so no writer can bypass it, including
--      a service-role script that ignores RLS entirely;
--   2. public.member_face_index, a security_invoker view that re-applies the
--      age test on READ, so a row that became ineligible after it was written
--      (a corrected date_of_birth, someone leaving the executive committee)
--      stops being served without needing a sweep to notice.
create or replace function public.member_face_embedding_requires_adult()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  dob date;
begin
  select m.date_of_birth into dob
  from public.members m
  where m.id = new.member_id;

  if not found then
    raise exception 'member % does not exist', new.member_id
      using errcode = 'foreign_key_violation';
  end if;

  if dob is null then
    raise exception
      'refusing to index member %: date_of_birth is unknown, so adulthood cannot be established',
      new.member_id
      using errcode = 'check_violation';
  end if;

  -- age() is stable and evaluated per statement; this is the live check.
  if date_part('year', age(dob))::int < 18 then
    raise exception
      'refusing to index member %: under 18',
      new.member_id
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.member_face_embedding_requires_adult() is
  'Rejects face embeddings for members under 18 or with an unknown date_of_birth. Live check, not a name list: the High School Democrats chair seat is routinely held by a minor.';

drop trigger if exists member_face_embeddings_adults_only
  on public.member_face_embeddings;
create trigger member_face_embeddings_adults_only
  before insert or update on public.member_face_embeddings
  for each row execute function public.member_face_embedding_requires_adult();

-- Read path. security_invoker so the caller's RLS on the base table still
-- applies: this view widens nothing, it only narrows.
drop view if exists public.member_face_index;
create view public.member_face_index
with (security_invoker = on) as
  select e.id,
         e.member_id,
         e.embedding,
         e.source_bucket,
         e.source_path,
         e.detector_score,
         e.created_at
  from public.member_face_embeddings e
  join public.members m on m.id = e.member_id
  where m.executive_committee = true
    and m.date_of_birth is not null
    and date_part('year', age(m.date_of_birth))::int >= 18;

comment on view public.member_face_index is
  'The face index as it may actually be used. Re-applies the adult and executive tests on every read, so a row that became ineligible after it was written stops being served.';

revoke all on public.member_face_index from anon;

-- Any row already present that the trigger would now refuse is deleted rather
-- than grandfathered. This is a no-op today (verified: zero such rows) and
-- exists so that re-running this migration after a data correction cleans up.
delete from public.member_face_embeddings e
using public.members m
where m.id = e.member_id
  and (m.date_of_birth is null
       or date_part('year', age(m.date_of_birth))::int < 18);
