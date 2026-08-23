// identify-meeting-host
//
// Infers who CHAIRED a meeting from its stored transcript, with a confidence and
// an explicit abstain. Writes meetings.meeting_host only above a threshold, and
// always stamps meeting_host_source='transcript' alongside it so a machine guess
// is never mistaken for a confirmed fact.
//
// WHY THIS EXISTS SEPARATELY FROM THE OLD PATH
// import-historical-meetings already had inferMeetingHost(): one gpt call, no
// confidence, no abstain except the literal string "UNKNOWN", and the result was
// written straight into meetings.meeting_host with nothing recording that it was
// a guess. Every one of the 41 hosts currently in that column came from it or
// from the Zoom host-name fallback beside it. That function was deleted on
// 2026-08-23 so there is one transcript inferrer and it is this one.
//
// THE LIMIT THAT MATTERS, AND WHY ABSTAIN IS THE POINT
// The whole executive committee shares ONE Zoom account whose display name is
// "Missouri Young Democrats". In 30 of the 41 transcripts that label is the
// DOMINANT speaker, and in 25 of 41 the currently-recorded host never appears as
// a named speaker at all. So when the chair is the one driving the shared
// account, the transcript usually cannot name them: every word they say is
// attributed to an organisation. A model told to "respond with only a name" will
// pick the most plausible OTHER attendee instead, which is precisely how a
// confidently wrong host lands in a meeting record.
//
// USUALLY, NOT ALWAYS, AND THE DIFFERENCE IS WHERE THE COVERAGE IS
// The first version of this prompt said flatly that a chair on the shared
// account could not be identified, and told the model to return no host in that
// case. That is wrong for one specific and common situation: the chair is on the
// shared account, but another attendee ADDRESSES THEM BY NAME, so the human is
// in the transcript after all. Every named answer the first measurement produced
// came from exactly that situation, with the model quietly setting
// shared_account_chaired=false so its own instructions would let it answer. The
// behaviour was right and the instruction was wrong.
//
// So the prompt now names three outcomes rather than one flag: named_directly,
// named_by_others, and unidentifiable. shared_account_chaired describes only
// where the chair sat and no longer decides anything. An unidentified host is
// still a fine outcome. A named person in a meeting they did not chair is still
// not.
//
// MEASURED ON gemini-3.6-flash, 2026-08-23. DO NOT RE-RUN THIS TO FIND OUT.
// 45 meetings that already carry a host and have a transcript, three passes each,
// 135 calls. 27 named, 18 abstained, 0 unstable: the matched member was identical
// across all three passes on all 45. Every one of the 27 was hand adjudicated
// against the transcript. 26 hold outright, 1 is thin, 0 are wrong, and 4
// disagree with the stored label, of which 3 are the STORED LABEL being wrong.
//
// Confidence came back bimodal with a wide empty band: abstains 0.10 to 0.20,
// named answers 0.80 to 0.95, nothing at all between. Any threshold in that gap
// produces identical output, so WRITE_THRESHOLD is left at 0.75 and there is no
// value in tuning it. It cannot be used to separate the strong named answers
// from the thin ones either: the thin ones sit at 0.80 and are not stable enough
// at that edge to be excluded by a number. Exclude them by reading the
// transcript, which is what meeting_host_evidence is stored for.
//
// The earlier warning that this inference was NON-DETERMINISTIC came from the
// Anthropic build. It did not carry over.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { callGemini } from "../_shared/gemini.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// THINKING IS ON FOR THIS ONE CALL AND THE BUDGET IS DELIBERATE.
//
// _shared/gemini.ts defaults thinking OFF because a caller that ports Claude's
// max_tokens straight across can otherwise get an empty reply with finishReason
// MAX_TOKENS, having paid for reasoning and received none of it. This call is
// the exception the default was written to allow for. It is a judgement call
// under an instruction to abstain, which is exactly the shape that degrades
// without reasoning, and the Anthropic call it replaces ran adaptive thinking at
// medium effort rather than a plain completion.
//
// So the budget is raised to match. The JSON answer is a couple of hundred
// tokens; everything above that is headroom so a hard transcript cannot run the
// thinking into the ceiling and return nothing. Do not lower this back to the
// 2000 the Anthropic call used: there, thinking was billed separately from the
// output cap, and here it is not.
const INFER_MAX_TOKENS = 8000;

// The shared-account display names. Anything matching these is an ORGANISATION,
// not a person, and must never be returned as a host.
const SHARED_ACCOUNT_PATTERNS = [
  /missouri young democrats/i,
  /^moyd$/i,
];

// Below this the inference is discarded rather than written. Chosen high on
// purpose: the cost of a miss is an empty field, the cost of a false positive is
// a named person recorded in a meeting they did not run.
const WRITE_THRESHOLD = 0.75;

// Transcripts here are one long run-on line with no newlines. The chair is
// identified in the opening minutes, so the head is what matters; the tail is
// included because adjournment often names them again.
const HEAD_CHARS = 28000;
const TAIL_CHARS = 4000;

interface Candidate {
  id: string;
  name: string;
}

// The three outcomes the prompt asks for. `named_by_others` is the case this
// function used to throw away: the chair was on the shared account, so the
// transcript could not name them DIRECTLY, but somebody else in the room
// addressed them by name, so the human is recoverable anyway.
type Resolution = "named_directly" | "named_by_others" | "unidentifiable";

interface Inference {
  resolution: Resolution | null;
  host_name: string | null;
  confidence: number;
  evidence: string;
  reasoning: string;
  shared_account_chaired: boolean;
}

function isSharedAccount(name: string): boolean {
  return SHARED_ACCOUNT_PATTERNS.some((p) => p.test(name.trim()));
}

function normalize(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    // Strip combining marks so "Chloé" matches "Chloe". This is not cosmetic:
    // public.members holds "Chloé Ray" with the accent, and the CRM guest list
    // failed to match her for exactly this reason.
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function excerpt(transcript: string): string {
  if (transcript.length <= HEAD_CHARS + TAIL_CHARS) return transcript;
  return (
    transcript.slice(0, HEAD_CHARS) +
    "\n\n[... middle of meeting omitted ...]\n\n" +
    transcript.slice(-TAIL_CHARS)
  );
}

function buildPrompt(
  title: string,
  date: string,
  candidates: Candidate[],
  transcript: string,
): string {
  const roster = candidates.map((c) => `- ${c.name}`).join("\n");
  return `You are reading a Zoom transcript for the Missouri Young Democrats to work out WHO CHAIRED the meeting.

Meeting: "${title}"
Date: ${date}

People known to have attended (the chair is almost always one of these):
${roster}

CRITICAL FACT ABOUT THESE TRANSCRIPTS
"Missouri Young Democrats" is a SHARED Zoom account used by the whole executive
committee. It is NOT a person. Whoever is signed into it that day appears under
that label, and the label alone tells you nothing about which human it is.

The chair is very often the one on the shared account: they are the one admitting
people from the waiting room, calling the meeting to order and running the agenda.
So when you see "Missouri Young Democrats" chairing, that is the START of the
question, not the answer.

THERE ARE THREE POSSIBLE OUTCOMES. WORK OUT WHICH ONE YOU ARE IN.

1. named_directly
   The person running the meeting speaks under their own name in the transcript.
   Ordinary case, nothing special about it.

2. named_by_others
   The person running the meeting is on the shared account, BUT somebody else in
   the meeting addresses or refers to them by name, so the human IS recoverable.
   Examples of what this looks like:
     - "thanks for running this, Dwayne"
     - "over to you, Lucy"
     - "Andrew, can you share your screen"  said to whoever is driving the call
     - a speaker answering a question that was put to the shared account by name
   THIS IS A VALID ANSWER. Return the name. Do not throw it away merely because
   the chair's own tile said "Missouri Young Democrats".
   You must quote the exact words that name them in the evidence field.

3. unidentifiable
   The person running the meeting is on the shared account and NOBODY names them.
   Then the transcript genuinely cannot tell you who chaired, and you must say so
   rather than picking the next most plausible attendee.

BE STRICT ABOUT THE DIFFERENCE BETWEEN 2 AND 3.
Outcome 2 needs somebody naming THE PERSON WHO IS RUNNING THE MEETING. A name
merely occurring in the transcript is not enough: attendees are named all the
time when they are called on, thanked, or assigned work, and none of that makes
them the chair. If the only thing you have is that a name appears, you are in
outcome 3.

WHAT TO LOOK FOR
- who calls the meeting to order or moves the agenda along
- who is thanked or addressed by name as the one running it
- who controls the waiting room, recording, or screen share
- who assigns action items and closes the meeting

Speaking the most is WEAK evidence on its own. A presenter or a guest speaker can
dominate a meeting they did not chair.

ANSWER FORMAT
Return ONLY a JSON object, no other text:
{
  "resolution": "named_directly" | "named_by_others" | "unidentifiable",
  "host_name": "<exact name from the attendee list, or null>",
  "confidence": <0.0 to 1.0>,
  "evidence": "<a short verbatim quote from the transcript that supports it, or why you cannot tell>",
  "reasoning": "<one or two sentences>",
  "shared_account_chaired": <true if the person running the meeting appeared under the shared "Missouri Young Democrats" label, whether or not you resolved their name>
}

CONFIDENCE BANDS, ONE PER OUTCOME. USE THE BAND THAT MATCHES YOUR RESOLUTION.
- named_directly:  0.75 to 0.95
- named_by_others: 0.55 to 0.90. Use 0.75 or above only when the person naming
  them is unmistakably talking to whoever is running the meeting. Use 0.55 to
  0.70 when it is a reasonable read but another attendee could be meant.
- unidentifiable:  0.00 to 0.30, and host_name MUST be null.

RULES
- NEVER return "Missouri Young Democrats" as host_name. It is not a person, and
  that is true in all three outcomes.
- host_name must match a name in the attendee list exactly, or be null.
- shared_account_chaired describes WHERE THE CHAIR SAT, not whether you answered.
  It is true in outcome 3 and it is also true in outcome 2. It does not by itself
  force host_name to null; only outcome 3 does that.
- Naming the wrong person puts them in a permanent meeting record. A null answer
  in outcome 3 is a good answer. A guess dressed up as outcome 2 is not.

TRANSCRIPT
${excerpt(transcript)}`;
}

async function infer(
  title: string,
  date: string,
  candidates: Candidate[],
  transcript: string,
): Promise<Inference> {
  // A refusal, or a reply truncated by the token ceiling, arrives from Vertex as
  // HTTP 200 with no text and a finishReason. callGemini throws and names the
  // reason rather than handing back an empty string that would fail to parse
  // three lines below, which is the same guard the Anthropic stop_reason check
  // here used to provide.
  const { text } = await callGemini({
    prompt: buildPrompt(title, date, candidates, transcript),
    maxTokens: INFER_MAX_TOKENS,
    thinking: true,
    // Low on purpose. The instruction this prompt is built around is "abstain
    // rather than guess", and sampling temperature is the knob that decides how
    // readily a model reaches for the next most plausible attendee instead.
    temperature: 0.2,
    // The prompt already demands a bare JSON object and the regex below already
    // tolerates stray prose. This makes the fenced-reply case impossible rather
    // than merely survivable.
    json: true,
  });

  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error(`no JSON in model reply: ${text.slice(0, 200)}`);
  const parsed = JSON.parse(match[0]);

  const RESOLUTIONS = ["named_directly", "named_by_others", "unidentifiable"];
  const resolution = RESOLUTIONS.includes(parsed.resolution)
    ? (parsed.resolution as Resolution)
    : null;

  return {
    resolution,
    host_name: parsed.host_name ?? null,
    confidence: typeof parsed.confidence === "number" ? parsed.confidence : 0,
    evidence: String(parsed.evidence ?? ""),
    reasoning: String(parsed.reasoning ?? ""),
    shared_account_chaired: parsed.shared_account_chaired === true,
  };
}

Deno.serve(async (req: Request) => {
  try {
    const { meeting_id, dry_run = true } = await req.json();
    if (!meeting_id) {
      return json({ error: "meeting_id required" }, 400);
    }

    const db = createClient(SUPABASE_URL, SERVICE_KEY);

    const { data: meeting, error: mErr } = await db
      .from("meetings")
      .select("id, meeting_title, meeting_date, transcript_file_path, meeting_host, meeting_host_source")
      .eq("id", meeting_id)
      .single();
    if (mErr || !meeting) return json({ error: `meeting not found: ${mErr?.message}` }, 404);
    if (!meeting.transcript_file_path) {
      return json({ meeting_id, skipped: "no transcript" });
    }

    const dl = await db.storage.from("meetings").download(meeting.transcript_file_path);
    if (dl.error || !dl.data) {
      return json({ error: `transcript unreadable: ${dl.error?.message}` }, 404);
    }
    const transcript = await dl.data.text();

    // Candidate roster: everyone the attendance tables place in the room, plus
    // the executive committee, since the chair is sometimes stamped onto the
    // attendance rows only AFTER a host is identified and so may be missing.
    const [att, guests, execs] = await Promise.all([
      db.from("meeting_attendance").select("member_id, members(id, name)").eq("meeting_id", meeting_id),
      db.from("non_member_attendees").select("display_name").eq("meeting_id", meeting_id),
      db.from("members").select("id, name").eq("executive_committee", true),
    ]);

    const byName = new Map<string, Candidate>();
    const add = (id: string | null, name: string | null) => {
      if (!name) return;
      if (isSharedAccount(name)) return;
      const key = normalize(name);
      if (!key || byName.has(key)) return;
      byName.set(key, { id: id ?? "", name });
    };
    for (const r of att.data ?? []) {
      const m = (r as { members?: { id: string; name: string } }).members;
      if (m) add(m.id, m.name);
    }
    for (const r of guests.data ?? []) add(null, (r as { display_name: string }).display_name);
    for (const r of execs.data ?? []) add((r as { id: string }).id, (r as { name: string }).name);

    const candidates = [...byName.values()];
    if (candidates.length === 0) {
      return json({ meeting_id, skipped: "no candidate attendees" });
    }

    const result = await infer(
      meeting.meeting_title ?? "",
      String(meeting.meeting_date ?? "").slice(0, 10),
      candidates,
      transcript,
    );

    // Resolve the model's answer back to a real member row. A name that does not
    // resolve is treated as an abstain rather than being written as free text:
    // meeting_host is a uuid and a half-matched name is not a person.
    let matched: Candidate | null = null;
    if (result.host_name && !isSharedAccount(result.host_name)) {
      matched = byName.get(normalize(result.host_name)) ?? null;
    }

    // Never overwrite a host this function did not itself write. The column
    // already holds rows stamped 'legacy', which came from the old unscored
    // OpenAI pass in import-historical-meetings, and it will hold
    // human-confirmed hosts the moment anyone confirms one. A machine guess
    // must never displace either. Only an empty slot, or this function's own
    // earlier inference, may be replaced.
    const hostSlotWritable =
      meeting.meeting_host === null || meeting.meeting_host_source === "transcript";

    // WHY THE GATE IS ON `resolution` AND NO LONGER ON `shared_account_chaired`.
    //
    // The old gate refused to write anything whenever the chair sat on the
    // shared account. That conflated two different situations. In one the chair
    // is on the shared account and NOBODY names them, so the transcript really
    // cannot answer and an abstain is correct. In the other the chair is on the
    // shared account but another attendee addresses them by name, so the human
    // IS in the transcript and throwing it away is a self-inflicted miss.
    //
    // The old prompt had a rule saying shared_account_chaired implied a null
    // host, and the model was overriding it: every named answer the previous
    // measurement produced came from the second case, with the model setting
    // the flag false in order to be allowed to answer. That is the model
    // routing around a wrong instruction, and it makes the flag mean two things
    // at once. So the flag now describes only WHERE THE CHAIR SAT, and
    // `resolution` carries the decision.
    //
    // If the model returns no usable resolution, fall back to the old rule
    // rather than to permissiveness: an unparsed answer must not become a
    // write.
    const resolved =
      result.resolution === null
        ? !result.shared_account_chaired
        : result.resolution !== "unidentifiable";

    const write =
      !dry_run &&
      hostSlotWritable &&
      matched !== null &&
      matched.id !== "" &&
      resolved &&
      result.confidence >= WRITE_THRESHOLD;

    // THE GUARD IS ENFORCED BY THE DATABASE, IN THE STATEMENT THAT WRITES.
    //
    // hostSlotWritable above is computed from a row read near the top of this
    // handler, and a model call sits between that read and this write. That gap
    // is seconds, sometimes tens of seconds. A human confirming the host in the
    // CRM inside that window would be silently overwritten by a machine guess,
    // which is the one outcome this whole function is written to prevent.
    //
    // Checking in application code cannot close that. Only the database can. So
    // the same rule appears twice: once in JS to decide whether to attempt the
    // write at all, and once inside claim_meeting_host where it is enforced.
    //
    // DO NOT PUT THIS BACK AS A .or() FILTER. It was written as
    //   .update({...}).eq("id", id).or("meeting_host.is.null,meeting_host_source.eq.transcript")
    // and that NEVER WORKED. Probed live on 2026-08-23: a PATCH carrying an `or=`
    // filter naming any column other than `id` answers 42703 "column
    // meetings.meeting_host does not exist", while the identical filter on a GET
    // returns the row and the same column as a plain `meeting_host=is.null`
    // filter on the same PATCH succeeds. Every write attempt this function made
    // came back as HTTP 500 "write failed: column meetings.meeting_host does not
    // exist", so nothing was ever backfilled. See migration
    // 20260823_02_claim_meeting_host.sql.
    if (write && matched) {
      const { data: claimed, error: uErr } = await db.rpc("claim_meeting_host", {
        p_meeting_id: meeting_id,
        p_host: matched.id,
        p_confidence: result.confidence,
        // The resolution is part of the evidence a human needs: "named by
        // another attendee" is a materially weaker claim than "spoke under
        // their own name", and the confidence alone does not say which.
        p_evidence:
          `[${result.resolution ?? "unspecified"}] ${result.reasoning} | ${result.evidence}`,
      });
      if (uErr) return json({ error: `write failed: ${uErr.message}` }, 500);
      // A NULL id back means the guard fired: somebody set a host while we were
      // thinking. That is a correct outcome, not an error, and it must be
      // visible rather than reported as a successful write.
      if (!claimed) {
        return json({
          meeting_id,
          wrote: false,
          skipped_reason: "host_set_by_another_writer_during_inference",
          would_have_written: matched.id,
          confidence: result.confidence,
        });
      }
    }

    return json({
      meeting_id,
      meeting_title: meeting.meeting_title,
      candidates: candidates.length,
      resolution: result.resolution,
      inferred_name: result.host_name,
      matched_member_id: matched?.id ?? null,
      matched_name: matched?.name ?? null,
      confidence: result.confidence,
      shared_account_chaired: result.shared_account_chaired,
      evidence: result.evidence,
      reasoning: result.reasoning,
      threshold: WRITE_THRESHOLD,
      written: write,
      host_slot_writable: hostSlotWritable,
      existing_host: meeting.meeting_host,
      existing_source: meeting.meeting_host_source,
    });
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    return json({ error: reason.slice(0, 500) }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
