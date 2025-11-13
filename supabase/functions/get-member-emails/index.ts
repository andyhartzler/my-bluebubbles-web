import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { google } from "npm:googleapis@130";
import { createClient } from "npm:@supabase/supabase-js@2";

const DEFAULT_ALLOWED_ORIGIN = "*";
const DEFAULT_ALLOWED_METHODS = "POST, OPTIONS";
const DEFAULT_ALLOWED_HEADERS = [
  "authorization",
  "x-client-info",
  "apikey",
  "content-type",
  "prefer",
  "x-supabase-authorization",
];

const baseCorsHeaders: Record<string, string> = {
  "Access-Control-Max-Age": "86400",
};

function buildCorsHeaders(request: Request): Headers {
  const headers = new Headers(baseCorsHeaders);
  headers.set("Access-Control-Allow-Methods", DEFAULT_ALLOWED_METHODS);

  const origin = request.headers.get("Origin");
  if (origin && origin.trim().length > 0) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Credentials", "true");
    headers.set("Vary", "Origin, Access-Control-Request-Headers");
  } else {
    headers.set("Access-Control-Allow-Origin", DEFAULT_ALLOWED_ORIGIN);
    headers.set("Vary", "Access-Control-Request-Headers");
  }

  const requestedHeaders = request.headers.get("Access-Control-Request-Headers");
  const allowedHeaderSet = new Set(
    DEFAULT_ALLOWED_HEADERS.map((header) => header.trim()).filter((header) => header.length > 0),
  );

  if (requestedHeaders) {
    for (const header of requestedHeaders.split(",")) {
      const trimmed = header.trim();
      if (trimmed.length > 0) {
        allowedHeaderSet.add(trimmed.toLowerCase());
      }
    }
  }

  headers.set("Access-Control-Allow-Headers", Array.from(allowedHeaderSet).join(", "));

  return headers;
}

function jsonResponse(request: Request, body: unknown, init: ResponseInit = {}): Response {
  const headers = buildCorsHeaders(request);
  headers.set("Content-Type", "application/json");

  if (init.headers) {
    const extra = new Headers(init.headers);
    extra.forEach((value, key) => {
      headers.set(key, value);
    });
  }

  return new Response(JSON.stringify(body), { ...init, headers });
}

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error("Supabase environment variables are not configured");
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const ORG_EMAILS = [
  "info@moyoungdemocrats.org",
  "andrew@moyoungdemocrats.org",
  "collegedems@moyoungdemocrats.org",
  "comms@moyoungdemocrats.org",
  "creators@moyoungdemocrats.org",
  "events@moyoungdemocrats.org",
  "eboard@moyoungdemocrats.org",
  "fundraising@moyoungdemocrats.org",
  "highschool@moyoungdemocrats.org",
  "members@moyoungdemocrats.org",
  "membership@moyoungdemocrats.org",
  "policy@moyoungdemocrats.org",
  "political-affairs@moyoungdemocrats.org",
];

function decodeBody(encodedBody: string): string {
  try {
    const base64 = encodedBody.replace(/-/g, "+").replace(/_/g, "/");
    return decodeURIComponent(escape(atob(base64)));
  } catch (err) {
    console.error("Failed to decode body:", err);
    return "";
  }
}

function extractBody(payload: any): { html: string; text: string } {
  let html = "";
  let text = "";

  if (payload.body?.data) {
    const decoded = decodeBody(payload.body.data);
    if (payload.mimeType === "text/html") {
      html = decoded;
    } else {
      text = decoded;
    }
  }

  if (payload.parts) {
    for (const part of payload.parts) {
      if (part.mimeType === "text/html" && part.body?.data) {
        html = decodeBody(part.body.data);
      } else if (part.mimeType === "text/plain" && part.body?.data) {
        text = decodeBody(part.body.data);
      } else if (part.parts) {
        const nested = extractBody(part);
        if (nested.html) html = nested.html;
        if (nested.text) text = nested.text;
      }
    }
  }

  return { html, text };
}

function getHeader(headers: any[], name: string): string {
  const header = headers?.find(
    (h) => typeof h.name === "string" && h.name.toLowerCase() === name.toLowerCase(),
  );
  return header?.value || "";
}

interface EmailDetail {
  id: string;
  threadId?: string;
  from?: string;
  to?: string;
  cc?: string;
  subject?: string;
  date?: string;
  snippet?: string;
  bodyHtml?: string;
  bodyText?: string;
  messageId?: string;
  inReplyTo?: string;
  references?: string;
  labelIds: string[];
}

Deno.serve(async (req) => {
  const method = req.method?.toUpperCase();

  if (method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: buildCorsHeaders(req),
    });
  }

  if (method !== "POST") {
    return jsonResponse(req, { error: "Method not allowed" }, { status: 405 });
  }

  try {
    const { memberId, maxResults = 50, syncToDatabase = true } = await req.json();

    if (!memberId) {
      return jsonResponse(req, { error: "Missing required field: memberId" }, { status: 400 });
    }

    const { data: member, error: memberError } = await supabase
      .from("members")
      .select("email, school_email")
      .eq("id", memberId)
      .single();

    if (memberError || !member) {
      return jsonResponse(req, { error: "Member not found" }, { status: 404 });
    }

    const memberEmails = [member.email, member.school_email].filter(Boolean);

    if (memberEmails.length === 0) {
      return jsonResponse(
        req,
        {
          emails: [],
          message: "Member has no email addresses",
        },
        { status: 200 },
      );
    }

    const serviceAccount = JSON.parse(Deno.env.get("SERVICE_ACCOUNT_JSON"));
    const impersonateUser = Deno.env.get("GMAIL_IMPERSONATE_USER");

    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ["https://www.googleapis.com/auth/gmail.readonly"],
      clientOptions: {
        subject: impersonateUser,
      },
    });

    const gmail = google.gmail({
      version: "v1",
      auth,
    });

    const fromQuery = ORG_EMAILS.map((e) => `from:${e}`).join(" OR ");
    const toQuery = memberEmails.map((e) => `to:${e}`).join(" OR ");
    const query = `(${fromQuery}) (${toQuery})`;

    const maxResultsNumber = Number(maxResults) || 50;

    const searchResponse = await gmail.users.messages.list({
      userId: "me",
      q: query,
      maxResults: maxResultsNumber,
    });

    const messages = searchResponse.data.messages || [];

    if (messages.length === 0) {
      return jsonResponse(
        req,
        {
          emails: [],
          message: "No emails found for this member",
        },
        { status: 200 },
      );
    }

    const emailDetails: EmailDetail[] = [];

    for (const msg of messages) {
      try {
        const messageResponse = await gmail.users.messages.get({
          userId: "me",
          id: msg.id!,
          format: "full",
        });

        const message = messageResponse.data as any;
        const headers = message.payload?.headers || [];
        const from = getHeader(headers, "from");
        const to = getHeader(headers, "to");
        const cc = getHeader(headers, "cc");
        const subject = getHeader(headers, "subject");
        const date = getHeader(headers, "date");
        const messageId = getHeader(headers, "message-id");
        const inReplyTo = getHeader(headers, "in-reply-to");
        const references = getHeader(headers, "references");
        const { html, text } = extractBody(message.payload);

        emailDetails.push({
          id: message.id,
          threadId: message.threadId,
          from,
          to,
          cc,
          subject,
          date,
          snippet: message.snippet,
          bodyHtml: html,
          bodyText: text,
          messageId,
          inReplyTo,
          references,
          labelIds: message.labelIds || [],
        });
      } catch (err) {
        console.error(`Failed to fetch message ${msg.id}:`, err);
      }
    }

    if (syncToDatabase && emailDetails.length > 0) {
      try {
        const emailRecords = emailDetails.map((email) => {
          const extractEmail = (fullAddress: string | undefined) => {
            if (!fullAddress) return null;
            const match = fullAddress.match(/<(.+?)>/);
            return match ? match[1] : fullAddress;
          };

          const toAddress = extractEmail(email.to) ?? email.to ?? email.from ?? "";

          return {
            gmail_message_id: email.id,
            gmail_thread_id: email.threadId ?? email.id,
            from_address: email.from ?? "",
            to_address: toAddress,
            cc_address: email.cc ?? null,
            subject: email.subject ?? "",
            date: email.date ?? new Date().toISOString(),
            snippet: email.snippet ?? null,
            body_html: email.bodyHtml ?? null,
            body_text: email.bodyText ?? null,
            message_id: email.messageId ?? null,
            in_reply_to: email.inReplyTo ?? null,
            references_header: email.references ?? null,
            label_ids: email.labelIds,
            member_id: memberId,
            synced_at: new Date().toISOString(),
          };
        });

        const { error: upsertError } = await supabase
          .from("email_inbox")
          .upsert(emailRecords, {
            onConflict: "gmail_message_id",
            ignoreDuplicates: false,
          });

        if (upsertError) {
          console.error("Failed to cache emails:", upsertError);
        }
      } catch (cacheError) {
        console.error("Error during email caching:", cacheError);
      }
    }

    return jsonResponse(
      req,
      {
        success: true,
        memberId,
        memberEmails,
        emailCount: emailDetails.length,
        emails: emailDetails,
        cached: syncToDatabase,
        syncedAt: new Date().toISOString(),
      },
    );
  } catch (err) {
    console.error("Failed to fetch member emails:", err);
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse(req, { error: message }, { status: 500 });
  }
});
