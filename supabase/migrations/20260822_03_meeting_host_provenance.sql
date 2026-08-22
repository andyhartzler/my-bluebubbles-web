-- Meeting host provenance.
--
-- meetings.meeting_host has been populated since the historical import by an
-- unscored LLM pass over the transcript (import-historical-meetings ->
-- inferMeetingHost, gpt, temperature 0.1, "respond with ONLY the person's
-- name"). Nothing recorded that those values were machine guesses, so a
-- confidently wrong guess is indistinguishable in the CRM from a fact.
--
-- These columns make the distinction explicit. Every future writer MUST set
-- meeting_host_source together with meeting_host.
--   human      - a person confirmed it
--   zoom       - Zoom named a real human as host (not the shared account)
--   transcript - inferred from the transcript by an LLM, with a confidence
--   face       - inferred from the recording by face matching, with a confidence
--   legacy     - written before provenance existed; origin not recorded
alter table public.meetings
  add column if not exists meeting_host_source text
    check (meeting_host_source in ('human', 'zoom', 'transcript', 'face', 'legacy')),
  add column if not exists meeting_host_confidence numeric
    check (meeting_host_confidence >= 0 and meeting_host_confidence <= 1),
  add column if not exists meeting_host_evidence text,
  add column if not exists meeting_host_inferred_at timestamptz;

comment on column public.meetings.meeting_host_source is
  'How meeting_host was determined. Anything other than human or zoom is a machine inference and must be shown as such.';
comment on column public.meetings.meeting_host_confidence is
  '0..1 self-reported confidence of the inference. Null for human/zoom/legacy.';
comment on column public.meetings.meeting_host_evidence is
  'Short quote or reason supporting the inference, so a human can check it.';

-- Everything already set predates provenance. It is not confirmed.
update public.meetings
   set meeting_host_source = 'legacy'
 where meeting_host is not null
   and meeting_host_source is null;

-- meeting_host without a source is the exact ambiguity this migration removes.
alter table public.meetings
  drop constraint if exists meetings_host_needs_source;
alter table public.meetings
  add constraint meetings_host_needs_source
  check (meeting_host is null or meeting_host_source is not null) not valid;
alter table public.meetings validate constraint meetings_host_needs_source;
