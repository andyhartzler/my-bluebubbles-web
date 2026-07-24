// ============================================================
// EDGE FUNCTION: talking-points-batch-check
// Checks status of talking points batches and processes completed results
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anthropicApiKey = Deno.env.get("ANTHROPIC_API_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================
// PARSE CLAUDE JSON RESPONSE
// ============================================================
function parseTalkingPointsResponse(content: string): any {
  try {
    const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/) || 
                      content.match(/```\s*([\s\S]*?)\s*```/);
    const jsonStr = jsonMatch ? jsonMatch[1] : content;
    return JSON.parse(jsonStr.trim());
  } catch (e) {
    throw new Error(`Failed to parse Claude response as JSON: ${e.message}`);
  }
}

// ============================================================
// VALIDATE TALKING POINTS STRUCTURE
// ============================================================
function validateTalkingPoints(data: any): boolean {
  if (!data) return false;
  if (!Array.isArray(data.talking_points)) return false;
  if (!data.call_to_action) return false;
  if (!Array.isArray(data.twitter_posts)) return false;
  if (!data.email_snippet) return false;
  if (!data.testimony_outline) return false;
  if (!data.target_audience_points) return false;
  return true;
}

// ============================================================
// PROCESS SINGLE TALKING POINTS RESULT
// ============================================================
async function processTalkingPointsResult(result: any): Promise<{ 
  billId: string; 
  success: boolean; 
  error?: string 
}> {
  const billId = result.custom_id;
  
  try {
    if (result.result.type === "succeeded") {
      const content = result.result.message.content[0].text;
      const talkingPoints = parseTalkingPointsResponse(content);
      
      // Validate the structure
      if (!validateTalkingPoints(talkingPoints)) {
        throw new Error("Invalid talking points structure returned from Claude");
      }
      
      // Calculate tokens used
      const tokensUsed = (result.result.message.usage?.input_tokens || 0) + 
                         (result.result.message.usage?.output_tokens || 0);
      
      // Get bill's current position for history
      const { data: bill } = await supabase
        .from("legislation_tracked_bills")
        .select("position, ai_position_recommendation")
        .eq("id", billId)
        .single();
      
      const position = bill?.position || bill?.ai_position_recommendation;
      
      // Update bill with talking points
      const { error: updateError } = await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_talking_points: talkingPoints.talking_points,
          ai_call_to_action: talkingPoints.call_to_action,
          ai_twitter_posts: talkingPoints.twitter_posts,
          ai_email_snippet: talkingPoints.email_snippet,
          ai_testimony_outline: talkingPoints.testimony_outline,
          ai_target_audience_points: talkingPoints.target_audience_points,
          ai_talking_points_generated_at: new Date().toISOString(),
          ai_talking_points_pending: false,
          ai_talking_points_error: null,
        })
        .eq("id", billId);

      if (updateError) {
        throw new Error(`Failed to update bill: ${updateError.message}`);
      }

      // Store in history
      await supabase.from("legislation_talking_points_history").insert({
        bill_id: billId,
        talking_points: talkingPoints.talking_points,
        call_to_action: talkingPoints.call_to_action,
        twitter_posts: talkingPoints.twitter_posts,
        email_snippet: talkingPoints.email_snippet,
        testimony_outline: talkingPoints.testimony_outline,
        target_audience_points: talkingPoints.target_audience_points,
        model_version: "claude-sonnet-4-20250514",
        prompt_version: "v1-talking-points-batch",
        position: position,
        tokens_used: tokensUsed,
      });

      return { billId, success: true };
      
    } else if (result.result.type === "errored") {
      const errorMsg = result.result.error?.message || "Unknown error";
      
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_talking_points_pending: false,
          ai_talking_points_error: `Batch error: ${errorMsg}`,
        })
        .eq("id", billId);

      return { billId, success: false, error: errorMsg };
      
    } else if (result.result.type === "expired") {
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_talking_points_pending: false,
          ai_talking_points_error: "Batch request expired - will retry",
        })
        .eq("id", billId);

      return { billId, success: false, error: "Expired" };
      
    } else if (result.result.type === "canceled") {
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_talking_points_pending: false,
          ai_talking_points_error: "Batch request canceled",
        })
        .eq("id", billId);

      return { billId, success: false, error: "Canceled" };
    }

    return { billId, success: false, error: `Unknown result type: ${result.result.type}` };
    
  } catch (err) {
    console.error(`Error processing talking points for bill ${billId}:`, err);
    
    await supabase
      .from("legislation_tracked_bills")
      .update({
        ai_talking_points_pending: false,
        ai_talking_points_error: `Processing error: ${err.message}`,
      })
      .eq("id", billId);

    return { billId, success: false, error: err.message };
  }
}

// ============================================================
// MAIN HANDLER
// ============================================================
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { 
      batchId = null, 
      processResults = true 
    } = await req.json();

    // Query for batches to check
    let batchQuery = supabase
      .from("legislation_ai_batches")
      .select("*")
      .eq("batch_type", "talking_points");

    if (batchId) {
      batchQuery = batchQuery.eq("id", batchId);
    } else {
      // Get all submitted/processing batches
      batchQuery = batchQuery.in("status", ["submitted", "processing"]);
    }

    const { data: batches, error: batchError } = await batchQuery;

    if (batchError) {
      throw new Error(`Failed to fetch batches: ${batchError.message}`);
    }

    if (!batches || batches.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No talking points batches to check",
          batches: [],
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const results: any[] = [];

    for (const batch of batches) {
      if (!batch.anthropic_batch_id) {
        results.push({
          batchId: batch.id,
          status: "error",
          message: "No Anthropic batch ID found",
        });
        continue;
      }

      // Check status with Anthropic
      const statusResponse = await fetch(
        `https://api.anthropic.com/v1/messages/batches/${batch.anthropic_batch_id}`,
        {
          method: "GET",
          headers: {
            "x-api-key": anthropicApiKey,
            "anthropic-version": "2023-06-01",
          },
        }
      );

      if (!statusResponse.ok) {
        const errorText = await statusResponse.text();
        results.push({
          batchId: batch.id,
          anthropicBatchId: batch.anthropic_batch_id,
          status: "error",
          message: `Failed to check status: ${statusResponse.status} - ${errorText}`,
        });
        continue;
      }

      const statusData = await statusResponse.json();
      console.log(`Talking points batch ${batch.anthropic_batch_id} status:`, statusData.processing_status);

      // Update our batch record
      const updateData: any = {
        processing_status: statusData.processing_status,
        succeeded_count: statusData.request_counts?.succeeded || 0,
        errored_count: statusData.request_counts?.errored || 0,
        expired_count: statusData.request_counts?.expired || 0,
        canceled_count: statusData.request_counts?.canceled || 0,
      };

      if (statusData.ended_at) {
        updateData.ended_at = statusData.ended_at;
      }

      if (statusData.results_url) {
        updateData.results_url = statusData.results_url;
      }

      // Determine our internal status
      if (statusData.processing_status === "ended") {
        updateData.status = "completed";
      } else if (statusData.processing_status === "in_progress") {
        updateData.status = "processing";
        if (!batch.started_at) {
          updateData.started_at = new Date().toISOString();
        }
      }

      await supabase
        .from("legislation_ai_batches")
        .update(updateData)
        .eq("id", batch.id);

      // Process results if batch is complete and we should process
      if (statusData.processing_status === "ended" && processResults && !batch.results_processed_at) {
        console.log(`Processing results for talking points batch ${batch.anthropic_batch_id}`);

        // Fetch results from Anthropic
        const resultsResponse = await fetch(
          `https://api.anthropic.com/v1/messages/batches/${batch.anthropic_batch_id}/results`,
          {
            method: "GET",
            headers: {
              "x-api-key": anthropicApiKey,
              "anthropic-version": "2023-06-01",
            },
          }
        );

        if (!resultsResponse.ok) {
          const errorText = await resultsResponse.text();
          results.push({
            batchId: batch.id,
            anthropicBatchId: batch.anthropic_batch_id,
            status: "completed",
            resultsProcessed: false,
            error: `Failed to fetch results: ${resultsResponse.status} - ${errorText}`,
          });
          continue;
        }

        // Results come as JSONL (newline-delimited JSON)
        const resultsText = await resultsResponse.text();
        const resultLines = resultsText.trim().split('\n').filter(line => line.trim());
        
        let successCount = 0;
        let errorCount = 0;
        const errors: any[] = [];

        for (const line of resultLines) {
          try {
            const resultObj = JSON.parse(line);
            const processedResult = await processTalkingPointsResult(resultObj);
            
            if (processedResult.success) {
              successCount++;
            } else {
              errorCount++;
              if (errors.length < 20) {
                errors.push({
                  billId: processedResult.billId,
                  error: processedResult.error,
                });
              }
            }
          } catch (parseErr) {
            console.error("Failed to parse result line:", parseErr);
            errorCount++;
          }
        }

        // Mark batch as processed
        await supabase
          .from("legislation_ai_batches")
          .update({
            results_processed_at: new Date().toISOString(),
          })
          .eq("id", batch.id);

        results.push({
          batchId: batch.id,
          anthropicBatchId: batch.anthropic_batch_id,
          status: "completed",
          resultsProcessed: true,
          successCount,
          errorCount,
          totalProcessed: resultLines.length,
          errors: errors,
        });

      } else {
        results.push({
          batchId: batch.id,
          anthropicBatchId: batch.anthropic_batch_id,
          status: statusData.processing_status,
          requestCounts: statusData.request_counts,
          resultsProcessed: !!batch.results_processed_at,
          expiresAt: statusData.expires_at,
        });
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        checkedAt: new Date().toISOString(),
        batches: results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Talking points batch check failed:", err);

    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});