// DIAGNOSTIC INSTRUMENTATION (temporary).
//
// Receives pointer-event traces from the iOS PWA top-bar dead-tap
// investigation (hamburger + search broken after force-close-relaunch,
// profile circle still works in same session). Inserts rows into
// public.pwa_debug_log so we can compare what the JS layer saw vs what
// Flutter's Listener saw.
//
// Anon-allowed by design — this is logging from a possibly-broken PWA
// session and we want it to fire even if the user isn't signed in /
// Supabase auth state isn't fully restored. Table has anon INSERT-only
// RLS; reads stay gated to authenticated. Will be removed once the
// root cause is identified.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabase = createClient(supabaseUrl, supabaseAnonKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface DebugEntry {
  ts_client?: string | null;
  layer?: string;
  event_type?: string;
  x?: number | null;
  y?: number | null;
  target_path?: string | null;
  user_agent?: string | null;
  display_mode?: string | null;
  standalone?: boolean | null;
  session_id?: string | null;
  metadata?: Record<string, unknown> | null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: { events?: DebugEntry[] } | DebugEntry | null = null;
  try {
    body = await req.json();
  } catch (_) {
    return new Response(JSON.stringify({ error: "invalid_json" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  if (!body) {
    return new Response(JSON.stringify({ error: "empty_body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const list: DebugEntry[] = Array.isArray((body as any).events)
    ? (body as any).events
    : [body as DebugEntry];

  // Cap batch size to keep the function fast and the table small.
  const trimmed = list.slice(0, 50);

  const rows = trimmed.map((e) => ({
    ts_client: e.ts_client ?? null,
    layer: (e.layer ?? "unknown").toString().slice(0, 16),
    event_type: (e.event_type ?? "unknown").toString().slice(0, 64),
    x: typeof e.x === "number" ? e.x : null,
    y: typeof e.y === "number" ? e.y : null,
    target_path: e.target_path?.toString().slice(0, 512) ?? null,
    user_agent: e.user_agent?.toString().slice(0, 512) ?? null,
    display_mode: e.display_mode?.toString().slice(0, 32) ?? null,
    standalone: typeof e.standalone === "boolean" ? e.standalone : null,
    session_id: e.session_id?.toString().slice(0, 64) ?? null,
    metadata: e.metadata ?? null,
  }));

  const { error } = await supabase.from("pwa_debug_log").insert(rows);
  if (error) {
    console.error("[pwa-debug-log] insert failed:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true, inserted: rows.length }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
