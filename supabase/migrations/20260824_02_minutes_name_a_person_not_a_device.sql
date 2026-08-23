-- STORED MINUTES MUST NOT NAME A PERSON BY THEIR PHONE.
--
-- The recap model is handed the transcript with Zoom display names in it and
-- writes those names straight into public.meetings. When somebody dials in
-- from a device whose display name is not their name, the permanent record
-- assigns their work to a string that is not a person. One executive meeting
-- currently does exactly this, in its action_items: a member of the executive
-- committee is named there by a device label, and the minutes are what the
-- absent members read to catch up.
--
-- 20260822_02 already built the fix for the matcher:
-- public.meeting_attendee_aliases maps a display name to a members row, with
-- a note recording how it was established. The attendance side now resolves
-- correctly. The narrative columns were never revisited, so the text still
-- carries the wrong name.
--
-- NO NAMES ARE WRITTEN IN THIS FILE. This repository is public. The
-- replacement is driven entirely off the alias table, so what it does is a
-- rule rather than a list, and it stays correct for aliases added later.
--
-- WHICH ALIASES COUNT. Not all of them. An alias also exists for an ordinary
-- spelling variant, an unaccented form of a member's own name, and rewriting
-- that would be a cosmetic edit to a record nobody is wrong about. The test
-- applied here is whether the alias contains the member's family name:
--   present  -> a spelling of the person's name, left alone
--   absent   -> a device or handle, replaced
-- That is the distinction that matters, because only the second case leaves a
-- reader unable to tell who is meant.
update public.meetings m
   set action_items          = regexp_replace(m.action_items,          a.display_name, mem.name, 'g'),
       executive_recap       = regexp_replace(m.executive_recap,       a.display_name, mem.name, 'g'),
       agenda_reviewed       = regexp_replace(m.agenda_reviewed,       a.display_name, mem.name, 'g'),
       discussion_highlights = regexp_replace(m.discussion_highlights, a.display_name, mem.name, 'g'),
       decisions_rationales  = regexp_replace(m.decisions_rationales,  a.display_name, mem.name, 'g'),
       risks_open_questions  = regexp_replace(m.risks_open_questions,  a.display_name, mem.name, 'g')
  from public.meeting_attendee_aliases a
  join public.members mem on mem.id = a.member_id
 where
   -- device or handle, not a spelling of their name
   position(
     lower(split_part(mem.name, ' ', array_length(string_to_array(mem.name, ' '), 1)))
     in lower(a.display_name)
   ) = 0
   and (
        m.action_items          like '%' || a.display_name || '%'
     or m.executive_recap       like '%' || a.display_name || '%'
     or m.agenda_reviewed       like '%' || a.display_name || '%'
     or m.discussion_highlights like '%' || a.display_name || '%'
     or m.decisions_rationales  like '%' || a.display_name || '%'
     or m.risks_open_questions  like '%' || a.display_name || '%'
   );

-- This corrects the rows that exist today. It does not stop the recap writing
-- the same wrong name on the next meeting, because the fix for that belongs
-- in the summariser, which is not deployed from this repository. The
-- structured commitments added in 20260824_01 carry a real members id rather
-- than a name, so at least the assignment of work no longer depends on the
-- model getting a display name right.
