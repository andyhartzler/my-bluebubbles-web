-- Make meetings.processing_status tell the truth, and give the stuck-meeting
-- watchdog a per-entity latch.
--
-- WHY. Three Executive Committee rows (2026-07-22, 07-29, 08-12) carried a
-- recording_url, a duration and an attendance count and NOTHING else: no
-- transcript, no recap, no action items. All three read
-- processing_status='completed'. That was false, and it is why the failure hid
-- for a month: every dashboard, every reconcile diff and every human reading the
-- row was told the meeting was done.
--
-- The status was set by a leg that had not completed the enrichment. Fixing the
-- writer is not enough, because the next writer added to this pipeline will make
-- the same claim. So processing_status is no longer a CLAIM any writer can make.
-- It is DERIVED from the row's own contents on every insert and update:
--
--   failed     processing_error is set. An explicit, terminal, human- or
--              pipeline-recorded failure. Wins over everything, so the hand
--              diagnosis on 2026-07-22 ("Zoom holds no audio_transcript for this
--              occurrence") survives, and so do the four other rows that carry
--              both an error and partial enrichment.
--   completed  a transcript or an executive recap actually landed. This is the
--              only state that may be read as "the minutes exist".
--   recorded   a recording landed and enrichment has not. THIS is the state the
--              three stranded rows should have been in.
--   received   skeleton row, no recording yet (zoom-webhook's minimal-row-first
--              write, or a meeting.ended event).
--
-- A trigger rather than a CHECK constraint on purpose. A CHECK would make the
-- statement FAIL, which on a fire-and-forget write path means the row is lost
-- rather than corrected, and it would break n8n mid-pipeline while it writes the
-- recording before the recap. Deriving corrects the value and lets the write
-- succeed, so a wrong writer degrades to an honest row rather than to no row.
--
-- Side effect worth knowing: this also retires the vocabulary drift already in
-- the table, one row reading 'Success' and one reading 'complete', and the
-- transient 'processing' meetings-zap writes and overwrites seconds later. None
-- of those is a state anything can act on. Nothing branches on this column:
-- the Flutter side carries it as a display string in meeting.dart and as a
-- free-text field in meeting_edit_sheet.dart, and no code compares it.

alter table public.meetings
  add column if not exists stuck_alerted_at timestamptz;

comment on column public.meetings.stuck_alerted_at is
  'Set once by zoom-reconcile when it first reports this meeting as stuck past '
  'the grace period. Judge ENTITIES, not EVENTS: the sweep runs daily but each '
  'stuck meeting is alerted on ONCE. Cleared automatically when the row reaches '
  'processing_status=completed, so a later regression can alert again.';

create or replace function public.meetings_derive_processing_status()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  new.processing_status := case
    when new.processing_error is not null then 'failed'
    when new.transcript_file_path is not null or new.executive_recap is not null then 'completed'
    when new.recording_url is not null then 'recorded'
    else 'received'
  end;

  -- A completed meeting is not stuck, so release the latch. This is what lets a
  -- meeting that is repaired and later regresses raise a second alert, without
  -- the sweep repeating itself every night in between.
  if new.processing_status = 'completed' then
    new.stuck_alerted_at := null;
  end if;

  return new;
end;
$$;

drop trigger if exists meetings_derive_processing_status on public.meetings;

create trigger meetings_derive_processing_status
  before insert or update on public.meetings
  for each row
  execute function public.meetings_derive_processing_status();

-- Backfill every existing row through the same derivation, so the stored values
-- and the rule agree from this point on rather than only for future writes.
update public.meetings set processing_status = processing_status;
