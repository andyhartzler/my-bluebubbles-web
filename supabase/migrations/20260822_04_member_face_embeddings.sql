-- Face embeddings for member identification in meeting recordings.
--
-- SENSITIVITY. MOYD is a youth organisation and many members are minors. This
-- table holds biometric data derived from their photographs. Three rules follow
-- and none of them is optional:
--   1. RLS is on and every policy is gated on public.is_executive(). There is no
--      anon policy and no authenticated policy. Do not add one.
--   2. It stores the EMBEDDING and never the cropped face. A 128-float vector
--      that leaks is far less damaging than a folder of teenagers' faces. The
--      crop exists only in memory during extraction.
--   3. Nothing here is written to a public bucket. The form-uploads bucket in
--      particular is public and is not an acceptable home for any of this.
--
-- 128 dimensions is SFace (face_recognition_sface_2021dec), run locally with
-- YuNet detection. No image is sent to any third party to produce these.
create extension if not exists vector;

create table if not exists public.member_face_embeddings (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  embedding vector(128) not null,
  -- Where the face came from, so a bad reference photo can be traced and pulled
  -- rather than silently poisoning every future match for that member.
  source_bucket text not null,
  source_path text not null,
  detector_score real,
  created_at timestamptz not null default now(),
  unique (member_id, source_path)
);

comment on table public.member_face_embeddings is
  'Biometric face embeddings for executive identification in meeting recordings. Minors data. Executive-only by RLS. Stores vectors, never crops.';

create index if not exists member_face_embeddings_member_idx
  on public.member_face_embeddings (member_id);

alter table public.member_face_embeddings enable row level security;

drop policy if exists member_face_embeddings_exec_select on public.member_face_embeddings;
create policy member_face_embeddings_exec_select
  on public.member_face_embeddings for select
  to authenticated
  using ((select public.is_executive()));

drop policy if exists member_face_embeddings_exec_write on public.member_face_embeddings;
create policy member_face_embeddings_exec_write
  on public.member_face_embeddings for all
  to authenticated
  using ((select public.is_executive()))
  with check ((select public.is_executive()));

revoke all on public.member_face_embeddings from anon;
