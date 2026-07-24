// ============================================================
// EDGE FUNCTION: analyze-bills-batch-check
// Checks status of analysis batches and processes completed results
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
// VALID CATEGORIES
// ============================================================
const VALID_CATEGORIES = [
  "climate", "healthcare", "education", "voting_rights", "labor",
  "housing", "criminal_justice", "lgbtq", "immigration", "guns",
  "taxes_budget", "transportation", "other"
];

// ============================================================
// PARSE CLAUDE JSON RESPONSE
// ============================================================
function parseAnalysisResponse(content: string): any {
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
// PROCESS SINGLE ANALYSIS RESULT
// ============================================================
async function processAnalysisResult(result: any): Promise<{ 
  billId: string; 
  success: boolean; 
  error?: string 
}> {
  const billId = result.custom_id;
  
  try {
    if (result.result.type === "succeeded") {
      const content = result.result.message.content[0].text;
      const analysis = parseAnalysisResponse(content);
      
      // Handle category - normalize to single category
      let category = analysis.category;
      if (Array.isArray(analysis.categories)) {
        category = analysis.categories[0];
      }
      
      // Validate category
      if (!VALID_CATEGORIES.includes(category)) {
        category = "other";
      }
      
      // Store as single-element array for backwards compatibility
      const categoriesArray = [category];
      
      // Calculate tokens used
      const tokensUsed = (result.result.message.usage?.input_tokens || 0) + 
                         (result.result.message.usage?.output_tokens || 0);
      
      // Update bill with analysis
      const { error: updateError } = await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_summary: analysis.summary,
          ai_summary_short: analysis.summary_short,
          ai_position_recommendation: analysis.position_recommendation,
          ai_priority_recommendation: analysis.priority_recommendation,
          ai_categories_recommendation: categoriesArray,
          ai_rationale: analysis.rationale,
          ai_key_provisions: analysis.key_provisions,
          ai_potential_impact: analysis.potential_impact,
          ai_analyzed_at: new Date().toISOString(),
          ai_analysis_version: "claude-sonnet-4-20250514-batch-v2",
          ai_analysis_pending: false,
          ai_analysis_error: null,
        })
        .eq("id", billId);

      if (updateError) {
        throw new Error(`Failed to update bill: ${updateError.message}`);
      }

      // Get bill text hash for history
      const { data: bill } = await supabase
        .from("legislation_tracked_bills")
        .select("current_bill_text_hash")
        .eq("id", billId)
        .single();

      // Store in history
      await supabase.from("legislation_ai_analysis_history").insert({
        bill_id: billId,
        summary: analysis.summary,
        summary_short: analysis.summary_short,
        position_recommendation: analysis.position_recommendation,
        priority_recommendation: analysis.priority_recommendation,
        categories_recommendation: categoriesArray,
        rationale: analysis.rationale,
        key_provisions: analysis.key_provisions,
        potential_impact: analysis.potential_impact,
        model_version: "claude-sonnet-4-20250514",
        prompt_version: "v2-single-category-batch",
        bill_text_hash: bill?.current_bill_text_hash,
        tokens_used: tokensUsed,
      });

      return { billId, success: true };
      
    } else if (result.result.type === "errored") {
      const errorMsg = result.result.error?.message || "Unknown error";
      
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_analysis_pending: false,
          ai_analysis_error: `Batch error: ${errorMsg}`,
        })
        .eq("id", billId);

      return { billId, success: false, error: errorMsg };
      
    } else if (result.result.type === "expired") {
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_analysis_pending: false,
          ai_analysis_error: "Batch request expired - will retry",
        })
        .eq("id", billId);

      return { billId, success: false, error: "Expired" };
      
    } else if (result.result.type === "canceled") {
      await supabase
        .from("legislation_tracked_bills")
        .update({
          ai_analysis_pending: false,
          ai_analysis_error: "Batch request canceled",
        })
        .eq("id", billId);

      return { billId, success: false, error: "Canceled" };
    }

    return { billId, success: false, error: `Unknown result type: ${result.result.type}` };
    
  } catch (err) {
    console.error(`Error processing bill ${billId}:`, err);
    
    await supabase
      .from("legislation_tracked_bills")
      .update({
        ai_analysis_pending: false,
        ai_analysis_error: `Processing error: ${err.message}`,
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
      .eq("batch_type", "analysis");

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
          message: "No analysis batches to check",
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
      console.log(`Analysis batch ${batch.anthropic_batch_id} status:`, statusData.processing_status);

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
        console.log(`Processing results for analysis batch ${batch.anthropic_batch_id}`);

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
            const processedResult = await processAnalysisResult(resultObj);
            
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
    console.error("Analysis batch check failed:", err);

    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});