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
// from the Zoom host-name fallback beside it. This replaces that, scored.
//
// THE LIMIT THAT MATTERS, AND WHY ABSTAIN IS THE POINT
// The whole executive committee shares ONE Zoom account whose display name is
// "Missouri Young Democrats". In 30 of the 41 transcripts that label is the
// DOMINANT speaker, and in 25 of 41 the currently-recorded host never appears as
// a named speaker at all. So when the chair is the one driving the shared
// account, the transcript physically cannot name them: every word they say is
// attributed to an organisation. A model told to "respond with only a name" will
// pick the most plausible OTHER attendee instead, which is precisely how a
// confidently wrong host lands in a meeting record.
//
// This function is therefore built to return shared_account_chaired=true and no
// host in that case. An unidentified host is a fine outcome. A named person in a
// meeting they did not chair is not.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

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

interface Inference {
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
that label, and the transcript gives you no way to tell which human it is.

That matters because the chair is very often the one on the shared account: they
are the one admitting people from the waiting room, calling the meeting to order
and running the agenda. If the person doing those things is labelled "Missouri
Young Democrats", then the transcript CANNOT tell you who chaired, and you must
say so rather than picking the next most plausible attendee.

WHAT TO LOOK FOR
- who calls the meeting to order or moves the agenda along
- who is thanked or addressed by name as the one running it ("thanks for hosting", "over to you, X")
- who controls the waiting room, recording, or screen share
- who assigns action items and closes the meeting

Speaking the most is WEAK evidence on its own. A presenter or a guest speaker can
dominate a meeting they did not chair.

ANSWER FORMAT
Return ONLY a JSON object, no other text:
{
  "host_name": "<exact name from the attendee list, or null>",
  "confidence": <0.0 to 1.0>,
  "evidence": "<a short quote from the transcript that supports it, or why you cannot tell>",
  "reasoning": "<one or two sentences>",
  "shared_account_chaired": <true if the chair appears to be the person on the shared "Missouri Young Democrats" account>
}

RULES
- If shared_account_chaired is true, host_name MUST be null and confidence MUST be at most 0.3.
- NEVER return "Missouri Young Democrats" as host_name. It is not a person.
- host_name must match a name in the attendee list exactly, or be null.
- If you are guessing, say so with a low confidence. A null answer is a good
  answer. Naming the wrong person puts them in a permanent meeting record.

TRANSCRIPT
${excerpt(transcript)}`;
}

async function infer(
  title: string,
  date: string,
  candidates: Candidate[],
  transcript: string,
): Promise<Inference> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-opus-5",
      max_tokens: 2000,
      thinking: { type: "adaptive" },
      output_config: { effort: "medium" },
      messages: [{ role: "user", content: buildPrompt(title, date, candidates, transcript) }],
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`anthropic ${res.status}: ${body.slice(0, 300)}`);
  }

  const data = await res.json();

  // Check stop_reason before reading content: a refusal returns HTTP 200 with an
  // empty content array, so indexing content[0] blindly throws a confusing error.
  if (data.stop_reason === "refusal") {
    throw new Error("anthropic declined the request");
  }

  const text = (data.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("");

  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error(`no JSON in model reply: ${text.slice(0, 200)}`);
  const parsed = JSON.parse(match[0]);

  return {
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

    const write =
      !dry_run &&
      matched !== null &&
      matched.id !== "" &&
      !result.shared_account_chaired &&
      result.confidence >= WRITE_THRESHOLD;

    if (write && matched) {
      const { error: uErr } = await db
        .from("meetings")
        .update({
          meeting_host: matched.id,
          meeting_host_source: "transcript",
          meeting_host_confidence: result.confidence,
          meeting_host_evidence: `${result.reasoning} | ${result.evidence}`.slice(0, 1000),
          meeting_host_inferred_at: new Date().toISOString(),
        })
        .eq("id", meeting_id);
      if (uErr) return json({ error: `write failed: ${uErr.message}` }, 500);
    }

    return json({
      meeting_id,
      meeting_title: meeting.meeting_title,
      candidates: candidates.length,
      inferred_name: result.host_name,
      matched_member_id: matched?.id ?? null,
      matched_name: matched?.name ?? null,
      confidence: result.confidence,
      shared_account_chaired: result.shared_account_chaired,
      evidence: result.evidence,
      reasoning: result.reasoning,
      threshold: WRITE_THRESHOLD,
      written: write,
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
