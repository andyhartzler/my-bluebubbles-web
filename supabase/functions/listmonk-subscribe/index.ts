// ============================================
// Listmonk Subscribe Edge Function v3
// 
// Flow:
// 1. Insert/update public.subscribers
// 2. Existing trigger syncs to listmonk.subscribers
// 3. Call SECURITY DEFINER function to add to lists
//
// REQUIRED ENVIRONMENT VARIABLES:
// - SUPABASE_URL: (auto-set by Supabase)
// - SUPABASE_SERVICE_ROLE_KEY: (auto-set by Supabase)
//
// DEPLOY:
// supabase functions deploy listmonk-subscribe
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Get environment variables (auto-set by Supabase)
  const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
  const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("Missing Supabase environment variables!");
    return new Response(
      JSON.stringify({ error: "Server configuration error. Please contact support." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Create Supabase client with service role (bypasses RLS)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  try {
    const body = await req.json();
    const { name, email, lists, attribs } = body;

    console.log("=== Listmonk Subscribe Request ===");
    console.log("Email:", email);
    console.log("Name:", name);
    console.log("Lists:", lists);
    console.log("Attribs:", JSON.stringify(attribs));

    // ===== VALIDATION =====
    if (!email || !name) {
      return new Response(
        JSON.stringify({ error: "Name and email are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!lists || !Array.isArray(lists) || lists.length === 0) {
      return new Response(
        JSON.stringify({ error: "At least one list must be selected" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!attribs?.zip_code || !attribs?.date_of_birth) {
      return new Response(
        JSON.stringify({ error: "Zip code and date of birth are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Normalize email
    const normalizedEmail = email.toLowerCase().trim();

    // ===== STEP 1: Check if subscriber exists in public.subscribers =====
    console.log("Step 1: Checking for existing subscriber...");
    
    const { data: existingSubscriber, error: checkError } = await supabase
      .from("subscribers")
      .select("id, email, name")
      .eq("email", normalizedEmail)
      .maybeSingle();

    if (checkError) {
      console.error("Database check error:", checkError);
      return new Response(
        JSON.stringify({ error: "Failed to check subscription status." }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let subscriberId: string;
    let isNewSubscriber = false;

    if (existingSubscriber) {
      // ===== SUBSCRIBER EXISTS - UPDATE =====
      console.log("Step 2a: Subscriber exists, updating:", existingSubscriber.id);
      subscriberId = existingSubscriber.id;

      const { error: updateError } = await supabase
        .from("subscribers")
        .update({
          name: name,
          phone: attribs.phone || null,
          date_of_birth: attribs.date_of_birth || null,
          zip_code: attribs.zip_code || null,
          source: attribs.source || "Subscribe Form",
          subscription_status: "subscribed",
          optin_date: new Date().toISOString(),
        })
        .eq("id", subscriberId);

      if (updateError) {
        console.error("Update error:", updateError);
        return new Response(
          JSON.stringify({ error: "Failed to update subscription." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      console.log("Subscriber updated successfully");

    } else {
      // ===== NEW SUBSCRIBER - INSERT =====
      console.log("Step 2b: Creating new subscriber...");
      isNewSubscriber = true;

      const { data: newSubscriber, error: insertError } = await supabase
        .from("subscribers")
        .insert({
          email: normalizedEmail,
          name: name,
          phone: attribs.phone || null,
          date_of_birth: attribs.date_of_birth || null,
          zip_code: attribs.zip_code || null,
          source: attribs.source || "Subscribe Form",
          subscription_status: "subscribed",
          optin_date: new Date().toISOString(),
        })
        .select("id")
        .single();

      if (insertError) {
        console.error("Insert error:", insertError);
        
        // Check for duplicate email
        if (insertError.code === "23505") {
          return new Response(
            JSON.stringify({ error: "This email is already subscribed." }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        
        return new Response(
          JSON.stringify({ error: "Failed to create subscription." }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      subscriberId = newSubscriber.id;
      console.log("New subscriber created:", subscriberId);
    }

    // ===== STEP 3: Wait for trigger to sync to listmonk.subscribers =====
    // The trigger_sync_subscriber_to_listmonk runs AFTER INSERT/UPDATE
    // Give it a moment to complete
    console.log("Step 3: Waiting for trigger sync to listmonk...");
    await new Promise(resolve => setTimeout(resolve, 1500));

    // ===== STEP 4: Call SECURITY DEFINER function to add to lists =====
    console.log("Step 4: Adding subscriber to lists via database function...");
    console.log("Lists to add:", lists);

    const { data: listResult, error: listError } = await supabase
      .rpc("add_subscriber_to_listmonk_lists", {
        p_email: normalizedEmail,
        p_list_uuids: lists,
      });

    if (listError) {
      console.error("List assignment error:", listError);
      // Don't fail the whole request - subscriber was created
      return new Response(
        JSON.stringify({
          success: true,
          message: "Subscription created, but list assignment encountered an issue. You may need to confirm your subscription.",
          subscriber_id: subscriberId,
          warning: listError.message,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log("List assignment result:", JSON.stringify(listResult));

    // Check if the function reported an error
    if (listResult && !listResult.success) {
      console.error("Function returned error:", listResult.error);
      return new Response(
        JSON.stringify({
          success: true,
          message: "Subscription created, but list assignment is pending.",
          subscriber_id: subscriberId,
          warning: listResult.error,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ===== SUCCESS =====
    const listsAdded = listResult?.lists_added || [];
    console.log("=== Success! ===");
    console.log("Subscriber ID:", subscriberId);
    console.log("Listmonk ID:", listResult?.listmonk_id);
    console.log("Lists added:", listsAdded);

    return new Response(
      JSON.stringify({
        success: true,
        message: isNewSubscriber 
          ? "You have been subscribed successfully!" 
          : "Your subscription has been updated!",
        subscriber_id: subscriberId,
        listmonk_id: listResult?.listmonk_id,
        listmonk_uuid: listResult?.listmonk_uuid,
        lists_added: listsAdded,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ error: "An unexpected error occurred. Please try again." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});