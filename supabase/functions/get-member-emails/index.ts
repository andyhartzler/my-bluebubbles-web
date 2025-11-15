import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.1";

const DEFAULT_ALLOWED_HEADERS = "authorization, x-client-info, apikey, content-type, prefer";

const baseCorsHeaders = {
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function buildCorsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("Origin");
  const requestedHeaders = request.headers.get("Access-Control-Request-Headers");

  const headerSet = new Set(
    `${DEFAULT_ALLOWED_HEADERS}${requestedHeaders ? "," + requestedHeaders : ""}`
      .split(",")
      .map((header) => header.trim())
      .filter((header) => header.length > 0)
      .map((header) => header.toLowerCase()),
  );

  const corsHeaders: Record<string, string> = {
    ...baseCorsHeaders,
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Headers": Array.from(headerSet).join(", "),
  };

  const varyValues: string[] = [];
  if (origin) {
    varyValues.push("Origin");
    corsHeaders["Access-Control-Allow-Credentials"] = "true";
  }
  if (requestedHeaders) {
    varyValues.push("Access-Control-Request-Headers");
  }
  if (varyValues.length > 0) {
    corsHeaders["Vary"] = varyValues.join(", ");
  }

  return corsHeaders;
}

const GMAIL_REFRESH_TOKEN = Deno.env.get("GMAIL_REFRESH_TOKEN");
const GMAIL_CLIENT_ID = Deno.env.get("GMAIL_CLIENT_ID");
const GMAIL_CLIENT_SECRET = Deno.env.get("GMAIL_CLIENT_SECRET");
const GMAIL_USER_ID = Deno.env.get("GMAIL_USER_ID") ?? "me";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const DEFAULT_MAX_RESULTS = Number(Deno.env.get("GMAIL_MAX_RESULTS") ?? "50");

interface GmailMessageListResponse {
  messages?: { id: string; threadId?: string }[];
  nextPageToken?: string;
}

interface GmailHeader {
  name?: string;
  value?: string;
}

interface GmailMessagePayload {
  headers?: GmailHeader[];
}

interface GmailMessageResponse {
  id: string;
  threadId?: string;
  historyId?: string;
  internalDate?: string;
  labelIds?: string[];
  snippet?: string;
  payload?: GmailMessagePayload;
}

interface EmailInboxRecord {
  gmail_message_id: string;
  gmail_thread_id: string;
  from_address: string;
  to_address: string;
  cc_address: string | null;
  subject: string;
  date: string;
  snippet: string | null;
  body_html: string | null;
  body_text: string | null;
  message_id: string | null;
  in_reply_to: string | null;
  references_header: string | null;
  label_ids: string[] | null;
  is_read: boolean;
  member_id: string | null;
  synced_at: string;
}

interface SyncOptions {
  forcedMemberId?: string | null;
}

interface SupabaseQueryResult<T> {
  data: T | null;
  error: { message: string } | null;
}

const logger = (requestId: string) => ({
  info: (message: string, meta: Record<string, unknown> = {}) =>
    console.log(JSON.stringify({ level: "info", requestId, message, ...meta })),
  warn: (message: string, meta: Record<string, unknown> = {}) =>
    console.warn(JSON.stringify({ level: "warn", requestId, message, ...meta })),
  error: (message: string, meta: Record<string, unknown> = {}) =>
    console.error(JSON.stringify({ level: "error", requestId, message, ...meta })),
});

function assertEnv(value: string | undefined, key: string): string {
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }

  return value;
}

async function getGmailAccessToken(): Promise<string> {
  const refreshToken = assertEnv(GMAIL_REFRESH_TOKEN, "GMAIL_REFRESH_TOKEN");
  const clientId = assertEnv(GMAIL_CLIENT_ID, "GMAIL_CLIENT_ID");
  const clientSecret = assertEnv(GMAIL_CLIENT_SECRET, "GMAIL_CLIENT_SECRET");

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to refresh Gmail access token: ${response.status} ${body}`);
  }

  const json = await response.json();
  return json.access_token as string;
}

async function listGmailMessages(accessToken: string, pageToken?: string): Promise<GmailMessageListResponse> {
  const params = new URLSearchParams({
    maxResults: `${DEFAULT_MAX_RESULTS}`,
  });

  if (pageToken) {
    params.set("pageToken", pageToken);
  }

  const response = await fetch(
    `https://gmail.googleapis.com/gmail/v1/users/${GMAIL_USER_ID}/messages?${params}`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to list Gmail messages: ${response.status} ${body}`);
  }

  return response.json() as Promise<GmailMessageListResponse>;
}

async function getGmailMessage(accessToken: string, id: string): Promise<GmailMessageResponse> {
  const response = await fetch(
    `https://gmail.googleapis.com/gmail/v1/users/${GMAIL_USER_ID}/messages/${id}?format=metadata&metadataHeaders=Subject&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Cc&metadataHeaders=Bcc&metadataHeaders=Date&metadataHeaders=Message-ID&metadataHeaders=References&metadataHeaders=In-Reply-To`,
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Failed to load Gmail message ${id}: ${response.status} ${body}`);
  }

  return response.json() as Promise<GmailMessageResponse>;
}

export function extractHeader(message: GmailMessageResponse, name: string): string | null {
  const headers = message.payload?.headers ?? [];
  const match = headers.find((header) => header.name?.toLowerCase() === name.toLowerCase());
  return match?.value ?? null;
}

export function parseEmailAddresses(value: string | null): string[] {
  if (!value) return [];

  return value
    .split(",")
    .map((segment) => segment.trim())
    .map((segment) => {
      const emailMatch = segment.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i);
      return emailMatch ? emailMatch[0].toLowerCase() : segment.toLowerCase();
    })
    .filter((segment, index, array) => segment.length > 0 && array.indexOf(segment) === index);
}

export function firstEmailAddress(value: string | null): string | null {
  const [first] = parseEmailAddresses(value);
  return first ?? null;
}

export async function resolveMemberId(
  supabase: SupabaseClient,
  email: string | null,
  log: ReturnType<typeof logger>,
): Promise<string | null> {
  if (!email) {
    return null;
  }

  try {
    const normalized = email.toLowerCase();
    const query = supabase
      .from("members")
      .select("id,email,school_email")
      .or(`email.ilike.${normalized},school_email.ilike.${normalized}`)
      .limit(1);

    const result = (await query.maybeSingle()) as SupabaseQueryResult<{ id: string } | null>;

    if (result.error) {
      log.warn("Failed to resolve member for email", {
        email,
        error: result.error.message,
      });
      return null;
    }

    if (!result.data) {
      log.info("No member found for email", { email });
      return null;
    }

    log.info("Resolved member for email", { email, memberId: result.data.id });
    return result.data.id;
  } catch (error) {
    log.error("Unexpected error resolving member", { email, error: `${error}` });
    return null;
  }
}

function normalizeRequiredAddress(
  addresses: string[],
  rawValue: string | null,
  fallback: string,
): string {
  if (addresses.length > 0) {
    return addresses.join(", ");
  }

  const trimmed = rawValue?.trim();
  if (trimmed && trimmed.length > 0) {
    return trimmed;
  }

  return fallback;
}

function normalizeOptionalAddress(addresses: string[], rawValue: string | null): string | null {
  if (addresses.length > 0) {
    return addresses.join(", ");
  }

  const trimmed = rawValue?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : null;
}

export async function buildEmailInboxRecord(
  supabase: SupabaseClient,
  message: GmailMessageResponse,
  log: ReturnType<typeof logger>,
  options: SyncOptions = {},
): Promise<EmailInboxRecord> {
  const from = extractHeader(message, "From");
  const to = extractHeader(message, "To");
  const cc = extractHeader(message, "Cc");
  const dateHeader = extractHeader(message, "Date");

  const fromAddress = firstEmailAddress(from);
  const memberId =
    (await resolveMemberId(supabase, fromAddress, log)) ?? options.forcedMemberId ?? null;
  const receivedAt = dateHeader ? new Date(dateHeader).toISOString() : null;
  const internalDate = message.internalDate ? new Date(Number(message.internalDate)).toISOString() : null;
  const toAddresses = parseEmailAddresses(to);
  const ccAddresses = parseEmailAddresses(cc);

  const resolvedFrom = fromAddress ?? "unknown@unknown.local";
  const resolvedTo = normalizeRequiredAddress(
    toAddresses,
    to,
    "undisclosed-recipients@unknown.local",
  );
  const resolvedCc = normalizeOptionalAddress(ccAddresses, cc);

  return {
    gmail_message_id: message.id,
    gmail_thread_id: message.threadId ?? message.id,
    snippet: message.snippet ?? null,
    subject: extractHeader(message, "Subject") ?? "No subject",
    from_address: resolvedFrom,
    to_address: resolvedTo,
    cc_address: resolvedCc,
    message_id: extractHeader(message, "Message-ID") ?? message.id,
    references_header: extractHeader(message, "References"),
    in_reply_to: extractHeader(message, "In-Reply-To"),
    date: receivedAt ?? internalDate ?? new Date().toISOString(),
    body_html: null,
    body_text: null,
    label_ids: message.labelIds ?? null,
    is_read: !(message.labelIds ?? []).includes("UNREAD"),
    member_id: memberId,
    synced_at: new Date().toISOString(),
  };
}

async function upsertEmailInboxRecord(
  supabase: SupabaseClient,
  record: EmailInboxRecord,
): Promise<void> {
  const { error } = await supabase
    .from("email_inbox")
    .upsert(record, { onConflict: "gmail_message_id" });

  if (error) {
    throw new Error(`Failed to upsert email_inbox record for ${record.gmail_message_id}: ${error.message}`);
  }
}

async function syncGmailMessages(
  supabase: SupabaseClient,
  log: ReturnType<typeof logger>,
  options: SyncOptions = {},
): Promise<{ processed: number; failures: number }> {
  const accessToken = await getGmailAccessToken();
  let pageToken: string | undefined;
  let processed = 0;
  let failures = 0;

  do {
    const listResponse = await listGmailMessages(accessToken, pageToken);
    const messages = listResponse.messages ?? [];

    for (const message of messages) {
      try {
        const fullMessage = await getGmailMessage(accessToken, message.id);
        const record = await buildEmailInboxRecord(supabase, fullMessage, log, options);

        if (options.forcedMemberId && record.member_id && record.member_id !== options.forcedMemberId) {
          log.info("Skipping Gmail message for different member", {
            gmailMessageId: record.gmail_message_id,
            memberId: record.member_id,
            forcedMemberId: options.forcedMemberId,
          });
          continue;
        }

        if (options.forcedMemberId && !record.member_id) {
          record.member_id = options.forcedMemberId;
        }

        await upsertEmailInboxRecord(supabase, record);
        processed += 1;
      } catch (error) {
        failures += 1;
        log.error("Failed to sync Gmail message", {
          messageId: message.id,
          error: `${error}`,
        });
      }
    }

    pageToken = listResponse.nextPageToken;
  } while (pageToken);

  return { processed, failures };
}

function createSupabaseClient(): SupabaseClient {
  const url = assertEnv(SUPABASE_URL, "SUPABASE_URL");
  const key = assertEnv(SUPABASE_SERVICE_ROLE_KEY, "SUPABASE_SERVICE_ROLE_KEY");

  return createClient(url, key, {
    auth: { persistSession: false },
  });
}

function extractMemberId(payload: Record<string, unknown> | null | undefined): string | null {
  if (!payload) {
    return null;
  }

  const candidates = ["memberId", "member_id"] as const;
  for (const key of candidates) {
    const value = payload[key];
    if (typeof value === "string") {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        return trimmed;
      }
    }
  }

  return null;
}

export async function handleRequest(req: Request): Promise<Response> {
  const requestId = crypto.randomUUID();
  const log = logger(requestId);
  const corsHeaders = buildCorsHeaders(req);

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabase = createSupabaseClient();
    let payload: Record<string, unknown> | null = null;

    if (req.headers.get("content-type")?.includes("application/json")) {
      try {
        payload = (await req.json()) as Record<string, unknown>;
      } catch (error) {
        log.warn("Failed to parse request body", { error: `${error}` });
      }
    }

    const forcedMemberId = extractMemberId(payload);
    const { processed, failures } = await syncGmailMessages(supabase, log, {
      forcedMemberId,
    });

    log.info("Finished Gmail sync", { processed, failures });

    return new Response(JSON.stringify({ processed, failures }), {
      status: failures > 0 && processed === 0 ? 500 : 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    log.error("Unexpected failure while syncing Gmail", { error: `${error}` });
    return new Response(JSON.stringify({ error: "Failed to sync Gmail", details: `${error}` }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
}

serve(handleRequest);
