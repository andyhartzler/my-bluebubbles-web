// ============================================================================
// Shared secret gate for edge functions that have NO human caller.
//
// slack-initial-sync, fetch-slack-avatars, sync-slack-avatars and
// slack-archive-files all run with verify_jwt=false and had no auth check of
// any kind in their handlers, so any unauthenticated POST reached them.
// slack-initial-sync is the dangerous one: with autoCreateMembers it creates a
// member row for every Slack user, and its channel sync path writes committee
// assignments including 'Executive Committee', which is the CRM's access gate.
//
// Deliberately NOT a user-JWT gate: none of these four is called from the
// Flutter app (verified by grep over lib/ on 2026-08-05, which finds only
// slack-archive-messages). Their only callers are pg_cron and a person with a
// terminal, so one machine secret is the whole requirement.
//
// Same header and same secret as pg_cron job 94 uses for onboarding-followups.
// ============================================================================
export function requireCronSecret(
  req: Request,
  corsHeaders: Record<string, string>,
): Response | null {
  const expected = Deno.env.get("CRON_SECRET") ?? "";
  const presented = req.headers.get("x-cron-secret") ?? "";
  // No secret configured means the function stays closed rather than open. An
  // unset env var must never be the thing that makes an endpoint public.
  if (expected && presented && presented === expected) return null;
  return new Response(JSON.stringify({ error: "unauthorized" }), {
    status: 401,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ============================================================================
// Staff-JWT-OR-cron-secret gate, for functions that verify_jwt=true does NOT
// actually protect.
//
// verify_jwt=true only proves the caller presented SOME valid project JWT, and
// the anon key IS one. It ships in the public Flutter bundle, so a function
// whose only gate is verify_jwt is reachable by anyone who opens the app.
// Probed live on 2026-08-23: identify-meeting-host and import-historical-meetings
// both answered an anon-key-only POST, the second one actually running an import
// and returning meeting rows.
//
// This is the same shape as the inline gate in analyze-bill, analyze-bill-ai and
// mail-poll (1a2f879), factored out rather than copied a fourth time: a user JWT
// that passes is_staff(), OR the x-cron-secret pg_cron reads from the vault. It
// FAILS CLOSED both ways, because an unset CRON_SECRET can never equal a
// presented value that must itself be non-empty.
//
// Neither function has an app or cron caller, checked by grep over lib/ and
// cron.job, so gating them breaks nothing. A CRM caller would work anyway, since
// supabase.functions.invoke forwards the signed-in user's JWT and every CRM user
// is exec, which is what is_staff() tests.
// ============================================================================
export async function requireStaffOrCron(
  req: Request,
  corsHeaders: Record<string, string>,
): Promise<Response | null> {
  const json = (body: unknown, status: number) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) return null;

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return json({ error: "Missing Authorization header or x-cron-secret" }, 401);
  }

  const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
  const userClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: `Bearer ${jwt}` } } },
  );

  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return json({ error: "Invalid or expired JWT" }, 401);
  }

  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return json({ error: "Forbidden — staff access required" }, 403);
  }

  return null;
}
