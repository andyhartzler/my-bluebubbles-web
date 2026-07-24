import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// 1x1 transparent GIF
const transparentGif = Uint8Array.from(
  atob("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"),
  (c) => c.charCodeAt(0)
);

serve(async (req) => {
  const url = new URL(req.url);
  const campaignId = url.searchParams.get("c");
  const recipientId = url.searchParams.get("r");

  if (!campaignId || !recipientId) {
    return new Response(transparentGif, {
      headers: { "Content-Type": "image/gif" },
    });
  }

  try {
    // Get current recipient data
    const { data: recipient } = await supabase
      .from("campaign_recipients")
      .select("open_count, opened_at")
      .eq("id", recipientId)
      .single();

    if (recipient) {
      const now = new Date().toISOString();
      const isFirstOpen = !recipient.opened_at;

      await supabase
        .from("campaign_recipients")
        .update({
          opened_at: recipient.opened_at || now,
          open_count: (recipient.open_count || 0) + 1,
          last_opened_at: now,
          delivered_at: recipient.delivered_at || now, // Mark as delivered on first open
        })
        .eq("id", recipientId);
    }
  } catch (err) {
    console.error("Failed to track open:", err);
  }

  // Always return the tracking pixel
  return new Response(transparentGif, {
    headers: {
      "Content-Type": "image/gif",
      "Cache-Control": "no-cache, no-store, must-revalidate",
    },
  });
});