// supabase/functions/extract-large-bill-text-chunked/index.ts
// ADVANCED chunked processor - uses queue table and stored functions
// Processes PDFs in small page batches to avoid CPU timeouts
// 
// v2 FIX: Uses pdf-lib to split PDF first, then extract text from small chunk
//         This prevents CPU timeout from extracting all pages at once
//
// NOTE: This function does NOT call OpenStates API - no API key rotation needed!
//
// REQUIRES: migration_chunked_text_extraction.sql (creates queue table + stored functions)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument } from "https://esm.sh/pdf-lib@1.17.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const STORAGE_BUCKET = "legislation-pdfs";
const PAGES_PER_CHUNK = 5; // Reduced to 5 pages per chunk for safety

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================================
// UTILITIES
// ============================================================================

function sanitizeText(text: string): string {
  return text
    .replace(/\x00/g, '')
    .replace(/[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
    .replace(/[\u0080-\u009F]/g, '')
    .replace(/[\uD800-\uDFFF]/g, '')
    .replace(/[\uFFFD\uFEFF]/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function countWords(text: string): number {
  return text.split(/\s+/).filter(w => w.length > 0).length;
}

async function hashText(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
    .substring(0, 32);
}

// ============================================================================
// PDF SPLITTING + EXTRACTION (THE KEY FIX!)
// ============================================================================

interface ChunkExtractionResult {
  text: string;
  pagesExtracted: number;
  totalPages: number;
  isComplete: boolean;
}

async function extractPdfChunk(
  pdfBuffer: ArrayBuffer,
  startPage: number,
  maxPages: number
): Promise<ChunkExtractionResult> {
  // Step 1: Load the full PDF with pdf-lib (fast, doesn't extract text)
  const fullPdf = await PDFDocument.load(pdfBuffer);
  const totalPages = fullPdf.getPageCount();
  
  console.log(`   PDF has ${totalPages} total pages`);
  
  const endPage = Math.min(startPage + maxPages, totalPages);
  const pagesToExtract = endPage - startPage;
  
  if (pagesToExtract <= 0) {
    return {
      text: '',
      pagesExtracted: 0,
      totalPages,
      isComplete: true,
    };
  }
  
  // Step 2: Create a NEW small PDF with only the pages we need
  console.log(`   Creating mini-PDF with pages ${startPage + 1}-${endPage}`);
  const miniPdf = await PDFDocument.create();
  
  // Copy only the pages we need (0-indexed)
  const pageIndices = [];
  for (let i = startPage; i < endPage; i++) {
    pageIndices.push(i);
  }
  
  const copiedPages = await miniPdf.copyPages(fullPdf, pageIndices);
  copiedPages.forEach(page => miniPdf.addPage(page));
  
  // Step 3: Save the mini PDF to bytes
  const miniPdfBytes = await miniPdf.save();
  console.log(`   Mini-PDF size: ${(miniPdfBytes.length / 1024).toFixed(1)} KB`);
  
  // Step 4: NOW extract text from the small PDF (much faster!)
  const { extractText } = await import("npm:unpdf");
  const result = await extractText(miniPdfBytes.buffer, { mergePages: false });
  
  if (!result.text || !Array.isArray(result.text)) {
    throw new Error("PDF extraction failed - no pages found");
  }
  
  // Step 5: Format the extracted text with page markers
  const combinedText = result.text
    .map((pageText: string, idx: number) => {
      const pageNum = startPage + idx + 1; // 1-indexed for display
      const cleanText = sanitizeText(pageText);
      return `[Page ${pageNum}]\n${cleanText}`;
    })
    .filter((t: string) => t.length > 15) // Skip nearly empty pages
    .join('\n\n');
  
  console.log(`   Extracted ${pagesToExtract} pages (${combinedText.length} chars)`);
  
  return {
    text: combinedText,
    pagesExtracted: pagesToExtract,
    totalPages,
    isComplete: endPage >= totalPages,
  };
}

// ============================================================================
// QUEUE-BASED PROCESSING (uses stored functions from public schema)
// ============================================================================

interface QueueWork {
  queue_id: string;
  bill_id: string;
  bill_identifier: string;
  pdf_storage_path: string;
  pdf_total_pages: number | null;
  current_chunk: number;
  pages_per_chunk: number;
  start_page: number;
  end_page: number;
  extracted_chunks: any[];
}

async function claimNextChunk(workerId: string): Promise<QueueWork | null> {
  // Call stored function to atomically claim work
  // Function: public.claim_text_extraction_chunk
  const { data, error } = await supabase.rpc('claim_text_extraction_chunk', {
    p_worker_id: workerId,
    p_lock_duration_seconds: 120
  });
  
  if (error) {
    console.error("Error claiming chunk:", error);
    return null;
  }
  
  if (!data || data.length === 0) {
    return null;
  }
  
  return data[0] as QueueWork;
}

async function saveChunkResult(
  queueId: string,
  workerId: string,
  chunkText: string,
  pagesInChunk: number,
  actualTotalPages: number | null,
  isFinalChunk: boolean
): Promise<boolean> {
  // Function: public.save_text_extraction_chunk
  const { error } = await supabase.rpc('save_text_extraction_chunk', {
    p_queue_id: queueId,
    p_worker_id: workerId,
    p_chunk_text: chunkText,
    p_pages_in_chunk: pagesInChunk,
    p_actual_total_pages: actualTotalPages,
    p_is_final_chunk: isFinalChunk
  });
  
  if (error) {
    console.error("Error saving chunk:", error);
    return false;
  }
  
  return true;
}

async function recordError(
  queueId: string,
  workerId: string,
  errorMessage: string
): Promise<void> {
  // Function: public.record_text_extraction_error
  await supabase.rpc('record_text_extraction_error', {
    p_queue_id: queueId,
    p_worker_id: workerId,
    p_error_message: errorMessage.substring(0, 500)
  });
}

async function processQueueChunk(workerId: string): Promise<{
  processed: boolean;
  billIdentifier?: string;
  pagesProcessed?: number;
  totalPages?: number;
  isComplete?: boolean;
  error?: string;
}> {
  // 1. Claim work from queue
  const work = await claimNextChunk(workerId);
  
  if (!work) {
    return { processed: false };
  }
  
  console.log(`📄 ${work.bill_identifier}: Processing chunk ${work.current_chunk} (pages ${work.start_page + 1}-${work.start_page + PAGES_PER_CHUNK})`);
  
  try {
    // 2. Download PDF from storage
    const { data: pdfData, error: downloadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .download(work.pdf_storage_path);
    
    if (downloadError || !pdfData) {
      throw new Error(`Download failed: ${downloadError?.message || 'No data'}`);
    }
    
    const pdfBuffer = await pdfData.arrayBuffer();
    console.log(`   Downloaded ${(pdfBuffer.byteLength / 1024 / 1024).toFixed(2)} MB`);
    
    // 3. Extract this chunk (using the split-first approach!)
    const chunk = await extractPdfChunk(pdfBuffer, work.start_page, PAGES_PER_CHUNK);
    
    // 4. Append text to bill record
    // Get current text first
    const { data: billData } = await supabase
      .from('legislation_tracked_bills')
      .select('current_bill_text')
      .eq('id', work.bill_id)
      .single();
    
    let newText: string;
    if (work.start_page === 0 || !billData?.current_bill_text) {
      newText = chunk.text;
    } else {
      newText = billData.current_bill_text + '\n\n' + chunk.text;
    }
    
    // Update bill with accumulated text
    const { error: updateError } = await supabase
      .from('legislation_tracked_bills')
      .update({
        current_bill_text: newText,
        text_extraction_pages_processed: work.start_page + chunk.pagesExtracted,
        text_extraction_total_pages: chunk.totalPages,
        text_extraction_last_chunk_at: new Date().toISOString(),
      })
      .eq('id', work.bill_id);
    
    if (updateError) {
      throw new Error(`Update failed: ${updateError.message}`);
    }
    
    // 5. Save chunk result to queue (with finalization if complete)
    const saved = await saveChunkResult(
      work.queue_id,
      workerId,
      chunk.text,
      chunk.pagesExtracted,
      chunk.totalPages,
      chunk.isComplete
    );
    
    if (!saved) {
      throw new Error("Failed to save chunk result");
    }
    
    // 6. If complete, finalize the bill record
    if (chunk.isComplete) {
      const textHash = await hashText(newText);
      const wordCount = countWords(newText);
      
      // Final update to bill
      await supabase
        .from('legislation_tracked_bills')
        .update({
          current_bill_text_hash: textHash,
          current_bill_text_word_count: wordCount,
          current_bill_text_extracted_at: new Date().toISOString(),
          text_extraction_status: 'completed',
          text_extraction_deferred: false,
          text_extraction_deferred_reason: null,
          pdf_page_count: chunk.totalPages,
          sync_error: null,
        })
        .eq('id', work.bill_id);
      
      // Also update text versions table
      const { data: billInfo } = await supabase
        .from('legislation_tracked_bills')
        .select('current_bill_text_url, current_bill_text_version')
        .eq('id', work.bill_id)
        .single();
      
      if (billInfo?.current_bill_text_url) {
        await supabase
          .from('legislation_bill_text_versions')
          .upsert({
            bill_id: work.bill_id,
            version_name: billInfo.current_bill_text_version || 'Introduced',
            version_order: 1,
            source_url: billInfo.current_bill_text_url,
            media_type: 'application/pdf',
            bill_text: newText,
            text_hash: textHash,
            word_count: wordCount,
            page_count: chunk.totalPages,
            extracted_at: new Date().toISOString(),
            extraction_method: 'chunked-large-file-processor',
            is_current: true,
          }, { onConflict: 'bill_id,source_url' });
      }
      
      console.log(`✅ ${work.bill_identifier}: COMPLETE - ${wordCount} words from ${chunk.totalPages} pages`);
    } else {
      const pagesRemaining = chunk.totalPages - work.start_page - chunk.pagesExtracted;
      console.log(`   ${work.bill_identifier}: Chunk ${work.current_chunk + 1} saved, ${pagesRemaining} pages remaining`);
    }
    
    return {
      processed: true,
      billIdentifier: work.bill_identifier,
      pagesProcessed: work.start_page + chunk.pagesExtracted,
      totalPages: chunk.totalPages,
      isComplete: chunk.isComplete,
    };
    
  } catch (e: any) {
    console.error(`❌ ${work.bill_identifier}: ${e.message}`);
    await recordError(work.queue_id, workerId, e.message);
    return {
      processed: true,
      billIdentifier: work.bill_identifier,
      error: e.message,
    };
  }
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  const startTime = Date.now();
  const workerId = crypto.randomUUID();
  
  try {
    const body = await req.json().catch(() => ({}));
    const { 
      max_chunks = 1,
      max_time_ms = 7000,
    } = body;

    console.log(`🚀 Worker ${workerId.substring(0, 8)} starting (max_chunks=${max_chunks}, pages_per_chunk=${PAGES_PER_CHUNK})`);

    const results = {
      worker_id: workerId.substring(0, 8),
      chunks_processed: 0,
      bills_completed: 0,
      pages_per_chunk: PAGES_PER_CHUNK,
      errors: [] as string[],
      details: [] as any[],
    };

    // Process up to max_chunks
    for (let i = 0; i < max_chunks; i++) {
      // Safety check: don't exceed time limit
      if (Date.now() - startTime > max_time_ms) {
        console.log(`⏱️ Time limit reached after ${i} chunks`);
        break;
      }
      
      const result = await processQueueChunk(workerId);
      
      if (!result.processed) {
        console.log("📭 No more work in queue");
        break;
      }
      
      results.chunks_processed++;
      results.details.push(result);
      
      if (result.isComplete) {
        results.bills_completed++;
      }
      
      if (result.error) {
        results.errors.push(`${result.billIdentifier}: ${result.error}`);
      }
    }

    const elapsed = Date.now() - startTime;
    console.log(`✅ Completed in ${elapsed}ms: ${results.chunks_processed} chunks, ${results.bills_completed} bills completed`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        elapsed_ms: elapsed,
        ...results 
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: any) {
    console.error("Fatal error:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});