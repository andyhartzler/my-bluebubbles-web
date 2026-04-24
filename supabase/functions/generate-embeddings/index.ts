// supabase/functions/generate-embeddings/index.ts
// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const openaiKey = Deno.env.get("OPENAI_API_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};

async function requireAuthorized(req) {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { actorId: null, actorRole: "service_role" };
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header or x-cron-secret" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } }
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — staff access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { actorId: userData.user.id, actorRole: "authenticated" };
}

// Rough token estimation: ~4 chars per token, but be conservative
const MAX_CHARS = 20000; // ~5000 tokens, safely under 8192 limit
async function generateEmbedding(text) {
  // Truncate to stay within token limits
  let truncated = text;
  if (text.length > MAX_CHARS) {
    // Keep beginning and end for context
    const halfLimit = Math.floor(MAX_CHARS / 2);
    truncated = text.slice(0, halfLimit) + "\n\n[... content truncated ...]\n\n" + text.slice(-halfLimit);
  }
  const response = await fetch("https://api.openai.com/v1/embeddings", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openaiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: "text-embedding-3-small",
      input: truncated,
      dimensions: 1536
    })
  });
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error: ${error}`);
  }
  const data = await response.json();
  return data.data[0].embedding;
}
// Format embedding array as pgvector string: [0.1,0.2,0.3]
function formatEmbeddingForPgvector(embedding) {
  return `[${embedding.join(",")}]`;
}
async function processBatch(batchSize = 20) {
  let processed = 0;
  let failed = 0;
  // Get pending items
  const { data: queueItems, error: queueError } = await supabase.from("knowledge_embedding_queue").select("id, document_id, attempts").eq("status", "pending").lt("attempts", 3).order("priority", {
    ascending: false
  }) // Higher priority first
  .order("created_at", {
    ascending: true
  }).limit(batchSize);
  if (queueError) {
    console.error("Queue fetch error:", queueError);
    return {
      processed: 0,
      failed: 0,
      remaining: 0
    };
  }
  if (!queueItems?.length) {
    const { count } = await supabase.from("knowledge_embedding_queue").select("*", {
      count: "exact",
      head: true
    }).eq("status", "pending");
    return {
      processed: 0,
      failed: 0,
      remaining: count || 0
    };
  }
  // Mark as processing
  const queueIds = queueItems.map((q)=>q.id);
  await supabase.from("knowledge_embedding_queue").update({
    status: "processing",
    last_attempt_at: new Date().toISOString()
  }).in("id", queueIds);
  for (const item of queueItems){
    try {
      // Get document
      const { data: doc, error: docError } = await supabase.from("knowledge_documents").select("id, content, title").eq("id", item.document_id).single();
      if (docError || !doc) {
        throw new Error(`Document not found: ${item.document_id}`);
      }
      // Skip empty content
      if (!doc.content || doc.content.trim().length < 10) {
        await supabase.from("knowledge_documents").update({
          embedding_status: "skipped",
          embedding_error: "Content too short"
        }).eq("id", doc.id);
        await supabase.from("knowledge_embedding_queue").update({
          status: "completed"
        }).eq("id", item.id);
        processed++;
        continue;
      }
      // Generate embedding
      const embedding = await generateEmbedding(doc.content);
      // Format for pgvector - must be a string like "[0.1,0.2,0.3]"
      const embeddingString = formatEmbeddingForPgvector(embedding);
      // Update document with embedding
      const { error: updateError } = await supabase.from("knowledge_documents").update({
        embedding: embeddingString,
        embedding_status: "completed",
        last_embedded_at: new Date().toISOString(),
        embedding_error: null
      }).eq("id", doc.id);
      // Check if update actually worked
      if (updateError) {
        throw new Error(`Failed to save embedding: ${updateError.message}`);
      }
      // Verify the embedding was saved
      const { data: verifyDoc } = await supabase.from("knowledge_documents").select("embedding").eq("id", doc.id).single();
      if (!verifyDoc?.embedding) {
        throw new Error("Embedding was not saved to database");
      }
      // Mark queue item complete
      await supabase.from("knowledge_embedding_queue").update({
        status: "completed"
      }).eq("id", item.id);
      processed++;
      console.log(`✓ Embedded: ${doc.title || doc.id}`);
      // Log usage
      // Log usage (wrapped in try-catch since this is optional)
      try {
        const tokenEstimate = Math.ceil(Math.min(doc.content.length, MAX_CHARS) / 4);
        await supabase.from("knowledge_usage_log").insert({
          service: "openai_embedding",
          operation: "embed",
          input_tokens: tokenEstimate,
          estimated_cost_cents: tokenEstimate / 1000000 * 2,
          request_metadata: {
            document_id: doc.id
          }
        });
      } catch  {
      // Ignore usage log errors
      }
      // Rate limiting delay
      await new Promise((r)=>setTimeout(r, 50));
    } catch (err) {
      console.error(`✗ Failed: ${item.document_id}`, err.message);
      const newAttempts = (item.attempts || 0) + 1;
      const shouldRetry = newAttempts < 3;
      await supabase.from("knowledge_embedding_queue").update({
        status: shouldRetry ? "pending" : "failed",
        attempts: newAttempts,
        error_message: err.message
      }).eq("id", item.id);
      await supabase.from("knowledge_documents").update({
        embedding_status: shouldRetry ? "pending" : "failed",
        embedding_error: err.message
      }).eq("id", item.document_id);
      failed++;
    }
  }
  // Get remaining count
  const { count } = await supabase.from("knowledge_embedding_queue").select("*", {
    count: "exact",
    head: true
  }).eq("status", "pending");
  return {
    processed,
    failed,
    remaining: count || 0
  };
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  try {
    let batchSize = 20;
    let processAll = false;
    let maxBatches = 1000;
    let limit = 0;
    if (req.method === "POST") {
      try {
        const body = await req.json();
        batchSize = body.batchSize || 20;
        processAll = body.processAll || false;
        maxBatches = body.maxBatches || 1000;
        limit = body.limit || 0;
        // If limit is provided, use it as batchSize for single batch
        if (limit > 0 && !processAll) {
          batchSize = limit;
        }
      } catch  {}
    }
    let totalProcessed = 0;
    let totalFailed = 0;
    let remaining = 0;
    let batchesRun = 0;
    if (processAll) {
      console.log(`Starting processAll mode with batchSize=${batchSize}, maxBatches=${maxBatches}`);
      do {
        const result = await processBatch(batchSize);
        totalProcessed += result.processed;
        totalFailed += result.failed;
        remaining = result.remaining;
        batchesRun++;
        console.log(`Batch ${batchesRun}: processed=${result.processed}, failed=${result.failed}, remaining=${remaining}`);
        if (remaining > 0) {
          await new Promise((r)=>setTimeout(r, 100));
        }
      }while (remaining > 0 && batchesRun < maxBatches)
      // Audit log (non-blocking)
      supabase.from("audit_log").insert({
        action: "EDGE_FN",
        actor_id: actorId,
        actor_role: actorRole,
        schema_name: "public",
        table_name: "edge_fn:generate-embeddings",
        row_id: null,
        context: {
          event: "generate-embeddings",
          mode: "processAll",
          batches_run: batchesRun,
          processed: totalProcessed,
          failed: totalFailed,
          remaining
        }
      }).then(() => {}).catch((e) => console.error("[generate-embeddings] audit_log insert failed:", e));
      return new Response(JSON.stringify({
        success: true,
        mode: "processAll",
        batchesRun,
        processed: totalProcessed,
        failed: totalFailed,
        remaining,
        completed: remaining === 0,
        message: remaining === 0 ? `✅ All done! Processed ${totalProcessed} documents in ${batchesRun} batches.` : `⏸️ Paused after ${batchesRun} batches. ${remaining} remaining.`
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    } else {
      const result = await processBatch(batchSize);
      // Audit log (non-blocking)
      supabase.from("audit_log").insert({
        action: "EDGE_FN",
        actor_id: actorId,
        actor_role: actorRole,
        schema_name: "public",
        table_name: "edge_fn:generate-embeddings",
        row_id: null,
        context: {
          event: "generate-embeddings",
          mode: "singleBatch",
          processed: result.processed,
          failed: result.failed,
          remaining: result.remaining
        }
      }).then(() => {}).catch((e) => console.error("[generate-embeddings] audit_log insert failed:", e));
      return new Response(JSON.stringify({
        success: true,
        mode: "singleBatch",
        processed: result.processed,
        failed: result.failed,
        remaining: result.remaining,
        message: `Processed ${result.processed}, failed ${result.failed}, ${result.remaining} remaining`
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
  } catch (err) {
    console.error("Error:", err);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
