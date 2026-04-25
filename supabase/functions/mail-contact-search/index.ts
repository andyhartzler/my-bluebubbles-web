// mail-contact-search — composer autocomplete for tmail's To/Cc/Bcc fields.
//
// Backs `EdgeFnContactDataSource.getContactSuggestions()` in the Flutter app.
// The composer types a query into a recipient field; we substring-match it
// against `public.members.name` and `public.members.email` and return up to
// `limit` rows shaped for tmail's Contact model.
//
// Trust:
//   - resolveCaller gates the fn (Bearer token + provisioned mail alias).
//     The directory is exec-only; non-execs without an alias don't have
//     access to the composer at all, so this matches the existing surface.
//   - No message data is exposed — just the directory itself (name + email
//     + phone). This is the same data execs already see in the CRM
//     /members page.
//   - Service-role client used for the lookup, but only the SELECT happens
//     server-side; the caller never reaches the DB directly.
//
// Body:
//   { q: string, limit?: number }   // limit defaults to 10, capped at 25.
//
// Response:
//   { contacts: [{ id, name, email, phone }, ...] }

import { createClient } from "jsr:@supabase/supabase-js@2";
import { resolveCaller } from "../_shared/alias-resolver.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Escape PostgREST `like`/`ilike` wildcards in the user-supplied query so a
// search for "100%" doesn't blow up to a wildcard scan.
function escapeLikePattern(raw: string): string {
  return raw.replace(/[\\%_]/g, (ch) => `\\${ch}`);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "use POST" }, 405);
  }

  const caller = await resolveCaller(req);
  if (caller instanceof Response) return caller;

  let body: { q?: unknown; limit?: unknown };
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const rawQ = typeof body.q === "string" ? body.q : "";
  const q = rawQ.trim().toLowerCase();
  if (q.length === 0) {
    return jsonResponse({ contacts: [] });
  }

  let limit = 10;
  if (typeof body.limit === "number" && Number.isFinite(body.limit)) {
    limit = Math.min(Math.max(1, Math.trunc(body.limit)), 25);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const pattern = `%${escapeLikePattern(q)}%`;

  const { data, error } = await supabase
    .from("members")
    .select("id, name, email, phone")
    .not("email", "is", null)
    .or(`name.ilike.${pattern},email.ilike.${pattern}`)
    .order("name", { ascending: true })
    .limit(limit);

  if (error) {
    console.error("[mail-contact-search] members query failed:", error);
    return jsonResponse({ error: "query_failed", detail: error.message }, 500);
  }

  const contacts = (data ?? [])
    .filter((row) => typeof row.email === "string" && row.email.length > 0)
    .map((row) => ({
      id: String(row.id),
      name: (row.name ?? "") as string,
      email: row.email as string,
      phone: (row.phone ?? null) as string | null,
    }));

  return jsonResponse({ contacts });
});
