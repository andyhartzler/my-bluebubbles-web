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
