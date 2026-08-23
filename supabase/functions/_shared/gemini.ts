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

export const DEFAULT_MODEL = "gemini-3.6-flash";

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
  model?: string;
  maxTokens?: number;
  temperature?: number;
  /**
   * Extended thinking. OFF by default, and that default is load-bearing.
   *
   * gemini-3.6-flash thinks by default and bills thought tokens against
   * maxOutputTokens. Measured on a two-word prompt: 75 thought tokens for a
   * one-token answer. So a caller that ports Claude's max_tokens: 2000 straight
   * across can get an EMPTY reply with finishReason MAX_TOKENS on a hard prompt,
   * having paid for the reasoning and received none of it.
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

export async function callGemini(opts: GeminiOptions): Promise<GeminiResult> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set");

  const model = opts.model ?? DEFAULT_MODEL;

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

/** Convenience for the call sites that only want the string. */
export async function geminiText(opts: GeminiOptions): Promise<string> {
  return (await callGemini(opts)).text;
}
