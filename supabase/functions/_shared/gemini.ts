// Gemini on Vertex AI, for the edge layer.
//
// One call in, text and token counts out, shaped to drop into the fifteen
// functions that currently POST to api.anthropic.com or api.openai.com. It
// returns the text and the token counts and nothing else. Keep it that way.
//
// THE "ALL TEXT IN, TEXT OUT" ASSUMPTION WAS WRONG FOR THREE OF THE CALL SITES
// The first version of this file said every call site builds one prompt string,
// sends it, and parses JSON out of the reply itself. Reading them proved
// otherwise, and each of the three optional fields below exists because one real
// call site cannot work without it. None is speculative.
//
//   media    index-storage-files is an OCR path. It base64s a PDF or an image
//            and asks the model to read the text out of it. Text only, it does
//            nothing at all.
//   history  query-knowledge-base carries up to ten prior turns plus a system
//            prompt into the answer call. Flattening those into one string
//            would throw away the turn structure the model uses to resolve
//            "them", "that one", "the second".
//   json     import-historical-meetings sent OpenAI response_format json_object
//            and then JSON.parse()s the reply with no fence stripping. Gemini
//            without responseMimeType will sometimes wrap the object in a
//            ```json fence, the parse throws, the catch returns null, and the
//            meeting is written with an EMPTY summary and no error. A silent
//            data loss, so the flag is not optional in practice.
//
// WHY AN API KEY AND NOT THE SERVICE ACCOUNT IN _shared/google-auth.ts
// The obvious build was to mint a cloud-platform token for the edge service
// account, moyd-ai-agent@backend-everything, which google-auth.ts already does
// for every other Google API this project touches. That path is DEAD and no
// amount of scope or IAM fixes it. Probed live with that exact key on
// 2026-08-23: aiplatform.googleapis.com answers
//
//   403 PERMISSION_DENIED, reason BILLING_DISABLED,
//   "This API method requires billing to be enabled ... project #backend-everything"
//
// The token mints fine and the API is reachable. The project simply has no
// billing account, so Vertex refuses before it ever looks at permissions.
//
// The key below belongs to vertex-express@moyd-agent-helper, a project that DOES
// have billing, and is the same credential the `gem` CLI has been using all
// along. That is the whole reason this file reads an API key instead.
//
// IF BILLING IS EVER ENABLED ON backend-everything, the better build is
// getGoogleAccessToken({ scopes: ["https://www.googleapis.com/auth/cloud-platform"] })
// with a Bearer header against
// /v1/projects/backend-everything/locations/global/publishers/google/models/...
// Note that google-auth.ts currently REQUIRES a subject and signs a domain-wide
// delegation JWT; Vertex needs a plain two-legged service account token, so that
// helper would need the subject made optional first.

const ENDPOINT = "https://aiplatform.googleapis.com/v1/publishers/google/models";

/**
 * THERE IS NO LONGER A SINGLE DEFAULT_MODEL. THIS IS A LADDER, NEWEST FIRST.
 *
 * This file used to export `DEFAULT_MODEL = "gemini-3.6-flash"`, one constant,
 * no environment override. Every consumer that does not pass its own model rode
 * that one string, so the day 3.6 retires they would all have failed at once,
 * and they would have failed the way the retired Anthropic model failed in
 * process-membership-roster: a 404 that reads like a bug in the caller rather
 * than a retirement.
 *
 * The pattern below is the one that function already proved. This endpoint
 * publishes no "latest" alias and the credential cannot list models, so the
 * order has to be explicit, and callGemini takes the first id that answers. A
 * retirement then costs one extra request instead of an outage.
 */
export const PREFERRED_MODELS = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.6-flash"];

/**
 * GEMINI_MODEL jumps the queue with no deploy, which is the point of it: if a
 * newer id ships, or one of the three above breaks in a way the 404 walk cannot
 * see, set the variable and every consumer moves on the next invocation.
 *
 * It is PREPENDED rather than substituted, so a stale or mistyped value costs
 * one wasted request and then falls through to the ladder instead of taking
 * every caller down with it.
 */
function modelsToTry(): string[] {
  const pinned = Deno.env.get("GEMINI_MODEL");
  const seen = new Set<string>();
  return [pinned, ...PREFERRED_MODELS].filter((m): m is string => {
    if (!m || seen.has(m)) return false;
    seen.add(m);
    return true;
  });
}

/**
 * An id this endpoint does not publish comes back 404. Anything else is a real
 * failure and must stop rather than spend a second call on the same answer: a
 * 401 or 403 is a rejected credential and a 429 is a rate limit, and neither
 * changes because a different model was asked.
 *
 * Matched against the thrown message rather than a status field because the
 * throw below is the only error shape this file produces and its text is
 * `vertex <status>: <body>`. Do not change that text: process-membership-roster
 * matches `vertex 404`, `vertex 401` and `vertex 403` on it to tell an
 * applicant a configuration problem from an unreadable upload.
 */
function isUnknownModel(error: unknown): boolean {
  return /vertex 404|NOT_FOUND|Publisher model/i.test(String((error as Error)?.message ?? error));
}

/**
 * One inline attachment. `data` is RAW base64 with no `data:` prefix and no
 * newlines, which is what Deno's base64Encode already returns.
 *
 * SUPPORTED mimeTypes are application/pdf, image/png, image/jpeg, image/webp,
 * image/heic and image/heif. NOTE image/gif is NOT among them, and Anthropic
 * accepted it. A caller that used to send gifs has to decide what to do about
 * them rather than discovering a 400 in production.
 */
export interface GeminiMedia {
  mimeType: string;
  data: string;
}

/** A prior conversational turn. `assistant` is mapped to Gemini's `model`. */
export interface GeminiTurn {
  role: "user" | "assistant";
  content: string;
}

export interface GeminiOptions {
  prompt: string;
  /** Optional system instruction. Most call sites fold this into the prompt. */
  system?: string;
  /** Prior turns, oldest first. The prompt is appended after them as the final user turn. */
  history?: GeminiTurn[];
  /** Inline attachments, placed BEFORE the prompt text, which is the order both providers want. */
  media?: GeminiMedia[];
  /** Ask for application/json back. Use it wherever the caller does a bare JSON.parse. */
  json?: boolean;
  /**
   * Pin one model for this call. Highest priority of all, and it DISABLES the
   * ladder rather than heading it.
   *
   * That is deliberate. process-membership-roster runs its own walk over its own
   * ordered list and reports which id answered, in a warning line and in a health
   * check. If this helper quietly fell through to a different model behind that
   * loop, the id it reports would be the one it asked for rather than the one
   * that answered, and the health check would go on claiming a model resolves
   * after it had retired. A caller that names a model gets that model or an
   * error.
   */
  model?: string;
  maxTokens?: number;
  temperature?: number;
  /**
   * Extended thinking. OFF by default, and that default is load-bearing.
   *
   * These models think by default and bill thought tokens against
   * maxOutputTokens. Measured on gemini-3.6-flash with a two-word prompt: 75
   * thought tokens for a one-token answer. So a caller that ports Claude's
   * max_tokens: 2000 straight across can get an EMPTY reply with finishReason
   * MAX_TOKENS on a hard prompt, having paid for the reasoning and received
   * none of it. The measurement is from one rung of the ladder, and nothing in
   * the ladder changes it: every id it carries thinks by default.
   *
   * Turn it on deliberately, for judgement calls, and raise maxTokens with it.
   */
  thinking?: boolean;
}

export interface GeminiResult {
  text: string;
  promptTokens: number;
  outputTokens: number;
  /** Includes thought tokens, which is what the bill is actually against. */
  totalTokens: number;
  modelVersion: string;
}

/** One request against one model id. The walk in callGemini is what retries. */
async function requestOnce(
  opts: GeminiOptions,
  model: string,
  apiKey: string,
): Promise<GeminiResult> {
  const parts: Record<string, unknown>[] = [];
  for (const m of opts.media ?? []) {
    parts.push({ inlineData: { mimeType: m.mimeType, data: m.data } });
  }
  parts.push({ text: opts.prompt });

  const contents = [
    ...(opts.history ?? []).map((t) => ({
      role: t.role === "assistant" ? "model" : "user",
      parts: [{ text: t.content }],
    })),
    { role: "user", parts },
  ];

  const body: Record<string, unknown> = {
    contents,
    generationConfig: {
      temperature: opts.temperature ?? 0.4,
      maxOutputTokens: opts.maxTokens ?? 4096,
      ...(opts.json ? { responseMimeType: "application/json" } : {}),
      ...(opts.thinking ? {} : { thinkingConfig: { thinkingBudget: 0 } }),
    },
  };
  if (opts.system) body.systemInstruction = { parts: [{ text: opts.system }] };

  const res = await fetch(`${ENDPOINT}/${model}:generateContent`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`vertex ${res.status}: ${err.slice(0, 300)}`);
  }

  const data = await res.json();
  const candidate = data.candidates?.[0];

  const text: string = (candidate?.content?.parts ?? [])
    .map((p: { text?: string }) => p.text ?? "")
    .join("");

  // An empty reply arrives as HTTP 200 with a finishReason, exactly like an
  // Anthropic refusal does. Name the reason rather than handing the caller an
  // empty string it will fail to parse three lines later.
  //
  // This is NOT an unknown-model error, so it stops the walk rather than
  // spending the rest of the ladder on a prompt the model deliberately refused.
  if (!text) {
    const reason = candidate?.finishReason ?? "no candidates";
    throw new Error(`vertex returned no text (finishReason: ${reason})`);
  }

  const usage = data.usageMetadata ?? {};
  return {
    text,
    promptTokens: usage.promptTokenCount ?? 0,
    outputTokens: usage.candidatesTokenCount ?? 0,
    totalTokens: usage.totalTokenCount ?? 0,
    modelVersion: data.modelVersion ?? model,
  };
}

export async function callGemini(opts: GeminiOptions): Promise<GeminiResult> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

  // A caller-pinned model is the whole list, per the note on opts.model.
  const candidates = opts.model ? [opts.model] : modelsToTry();

  let lastError: unknown = null;
  for (const model of candidates) {
    try {
      const result = await requestOnce(opts, model, apiKey);
      if (model !== candidates[0]) {
        console.warn(`[gemini] preferred model "${candidates[0]}" unavailable; used "${model}"`);
      }
      return result;
    } catch (e) {
      lastError = e;
      // Only an unknown model id is worth another request. Everything else, a
      // bad credential above all, must fail here rather than ask the same
      // question of two more models and pay for all three.
      if (!isUnknownModel(e)) throw e;
      console.error(`[gemini] model "${model}" is not published here; trying the next`);
    }
  }
  // The last error is rethrown rather than a summary, so the `vertex 404: ...`
  // text callers match on survives the walk.
  throw lastError;
}

/** Convenience for the call sites that only want the string. */
export async function geminiText(opts: GeminiOptions): Promise<string> {
  return (await callGemini(opts)).text;
}
