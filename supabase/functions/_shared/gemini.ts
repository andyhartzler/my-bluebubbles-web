// Gemini on Vertex AI, for the edge layer.
//
// One text-in / text-out call, shaped to drop into the fifteen functions that
// currently POST to api.anthropic.com or api.openai.com. Those call sites all do
// the same thing: build one prompt string, send it, pull the text back out, and
// parse JSON from it themselves. So this returns the text and the token counts
// and nothing else. Keep it that way.
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

export interface GeminiOptions {
  prompt: string;
  /** Optional system instruction. Most call sites fold this into the prompt. */
  system?: string;
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

  const body: Record<string, unknown> = {
    contents: [{ role: "user", parts: [{ text: opts.prompt }] }],
    generationConfig: {
      temperature: opts.temperature ?? 0.4,
      maxOutputTokens: opts.maxTokens ?? 4096,
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
