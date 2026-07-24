// supabase/functions/extract-large-bill-text/index.ts
// SIMPLE chunked processor - splits PDF first, then extracts text
// This avoids the CPU timeout by only processing a few pages at a time
//
// KEY INSIGHT: unpdf extracts ALL pages even with mergePages:false
// SOLUTION: Use pdf-lib to split the PDF first, then extract from the small chunk
//
// NOTE: This function does NOT call OpenStates API - no API key rotation needed!
//
// v3 FIX: Properly prioritize in_progress bills to continue them before starting new ones

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { PDFDocument } from "https://esm.sh/pdf-lib@1.17.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const STORAGE_BUCKET = "legislation-pdfs";

// Only 5 pages per chunk to stay well under CPU limits
const PAGES_PER_CHUNK = 5;

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
    .filter((t: string) => t.length > 15)
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
// BILL PROCESSING
// ============================================================================

interface DeferredBill {
  id: string;
  bill_identifier: string;
  current_bill_pdf_path: string;
  current_bill_text: string | null;
  current_bill_text_url: string | null;
  current_bill_text_version: string | null;
  pdf_page_count: number | null;
  text_extraction_pages_processed: number | null;
  text_extraction_status: string | null;
}

async function findNextBillToProcess(): Promise<DeferredBill | null> {
  // =========================================================================
  // FIX: Two-step query to properly prioritize in_progress bills
  // =========================================================================
  
  // STEP 1: First, look for ANY bill that is currently in_progress
  // We MUST continue these before starting new ones!
  const { data: inProgressBill, error: inProgressError } = await supabase
    .from('legislation_tracked_bills')
    .select(`
      id,
      bill_identifier,
      current_bill_pdf_path,
      current_bill_text,
      current_bill_text_url,
      current_bill_text_version,
      pdf_page_count,
      text_extraction_pages_processed,
      text_extraction_status
    `)
    .eq('text_extraction_deferred', true)
    .eq('text_extraction_status', 'in_progress')
    .not('current_bill_pdf_path', 'is', null)
    .order('text_extraction_last_chunk_at', { ascending: true, nullsFirst: false }) // Oldest activity first
    .limit(1)
    .maybeSingle();  // Use maybeSingle to handle 0 or 1 results
  
  if (inProgressError) {
    console.error("Error finding in_progress bill:", inProgressError);
  }
  
  if (inProgressBill) {
    console.log(`📌 Continuing in_progress bill: ${inProgressBill.bill_identifier}`);
    return inProgressBill as DeferredBill;
  }
  
  // STEP 2: No in_progress bills, look for pending ones
  const { data: pendingBill, error: pendingError } = await supabase
    .from('legislation_tracked_bills')
    .select(`
      id,
      bill_identifier,
      current_bill_pdf_path,
      current_bill_text,
      current_bill_text_url,
      current_bill_text_version,
      pdf_page_count,
      text_extraction_pages_processed,
      text_extraction_status
    `)
    .eq('text_extraction_deferred', true)
    .not('current_bill_pdf_path', 'is', null)
    .or('text_extraction_status.is.null,text_extraction_status.eq.pending')
    .order('pdf_page_count', { ascending: true, nullsFirst: false }) // Smaller files first
    .limit(1)
    .maybeSingle();
  
  if (pendingError && pendingError.code !== 'PGRST116') {
    console.error("Error finding pending bill:", pendingError);
  }
  
  if (pendingBill) {
    console.log(`📋 Starting new pending bill: ${pendingBill.bill_identifier}`);
    return pendingBill as DeferredBill;
  }
  
  return null;
}

async function processOneBillChunk(bill: DeferredBill): Promise<{
  success: boolean;
  pagesProcessed: number;
  totalPages: number;
  isComplete: boolean;
  error?: string;
}> {
  const startPage = bill.text_extraction_pages_processed || 0;
  
  console.log(`📄 ${bill.bill_identifier}: Processing pages ${startPage + 1} - ${startPage + PAGES_PER_CHUNK}`);
  
  try {
    // 1. Download PDF from storage
    const { data: pdfData, error: downloadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .download(bill.current_bill_pdf_path);
    
    if (downloadError || !pdfData) {
      throw new Error(`Download failed: ${downloadError?.message || 'No data'}`);
    }
    
    const pdfBuffer = await pdfData.arrayBuffer();
    console.log(`   Downloaded ${(pdfBuffer.byteLength / 1024 / 1024).toFixed(2)} MB`);
    
    // 2. Extract this chunk (using the split-first approach)
    const chunk = await extractPdfChunk(pdfBuffer, startPage, PAGES_PER_CHUNK);
    
    // 3. Build the new text
    let newText: string;
    if (startPage === 0) {
      newText = chunk.text;
    } else {
      newText = (bill.current_bill_text || '') + '\n\n' + chunk.text;
    }
    
    // 4. Update the bill record
    const updateData: Record<string, any> = {
      current_bill_text: newText,
      text_extraction_status: chunk.isComplete ? 'completed' : 'in_progress',
      text_extraction_pages_processed: startPage + chunk.pagesExtracted,
      text_extraction_total_pages: chunk.totalPages,
      text_extraction_last_chunk_at: new Date().toISOString(),
    };
    
    if (startPage === 0) {
      updateData.text_extraction_started_at = new Date().toISOString();
      updateData.text_extraction_attempts = 1;
    }
    
    if (chunk.isComplete) {
      const textHash = await hashText(newText);
      const wordCount = countWords(newText);
      
      updateData.current_bill_text_hash = textHash;
      updateData.current_bill_text_word_count = wordCount;
      updateData.current_bill_text_extracted_at = new Date().toISOString();
      updateData.text_extraction_deferred = false;
      updateData.text_extraction_deferred_reason = null;
      updateData.pdf_page_count = chunk.totalPages;
      updateData.sync_error = null;
      
      console.log(`✅ ${bill.bill_identifier}: COMPLETE - ${wordCount} words from ${chunk.totalPages} pages`);
    } else {
      const pagesRemaining = chunk.totalPages - startPage - chunk.pagesExtracted;
      const chunksRemaining = Math.ceil(pagesRemaining / PAGES_PER_CHUNK);
      console.log(`   ${bill.bill_identifier}: Chunk done, ${pagesRemaining} pages remaining (~${chunksRemaining} more chunks)`);
    }
    
    const { error: updateError } = await supabase
      .from('legislation_tracked_bills')
      .update(updateData)
      .eq('id', bill.id);
    
    if (updateError) {
      throw new Error(`Update failed: ${updateError.message}`);
    }
    
    // 5. If complete, update text versions table
    if (chunk.isComplete && bill.current_bill_text_url) {
      const textHash = await hashText(newText);
      const wordCount = countWords(newText);
      
      await supabase
        .from('legislation_bill_text_versions')
        .upsert({
          bill_id: bill.id,
          version_name: bill.current_bill_text_version || 'Introduced',
          version_order: 1,
          source_url: bill.current_bill_text_url,
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
    
    return {
      success: true,
      pagesProcessed: startPage + chunk.pagesExtracted,
      totalPages: chunk.totalPages,
      isComplete: chunk.isComplete,
    };
    
  } catch (e: any) {
    console.error(`❌ ${bill.bill_identifier}: ${e.message}`);
    
    // Mark as failed if we've never made progress
    const shouldMarkFailed = (bill.text_extraction_pages_processed || 0) === 0;
    
    await supabase
      .from('legislation_tracked_bills')
      .update({
        sync_error: e.message.substring(0, 500),
        text_extraction_status: shouldMarkFailed ? 'failed' : 'in_progress',
      })
      .eq('id', bill.id);
    
    return {
      success: false,
      pagesProcessed: startPage,
      totalPages: bill.pdf_page_count || 0,
      isComplete: false,
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
  
  try {
    const body = await req.json().catch(() => ({}));
    const { 
      max_chunks = 1,
      max_time_ms = 7000,  // Leave more headroom
      bill_id = null,
    } = body;

    console.log(`🚀 Starting chunked extraction (max_chunks=${max_chunks}, pages_per_chunk=${PAGES_PER_CHUNK})`);

    const results = {
      chunks_processed: 0,
      bills_completed: 0,
      pages_per_chunk: PAGES_PER_CHUNK,
      errors: [] as string[],
      details: [] as Array<{
        bill_identifier: string;
        pages_processed: number;
        total_pages: number;
        is_complete: boolean;
        error?: string;
      }>,
    };

    for (let i = 0; i < max_chunks; i++) {
      const elapsed = Date.now() - startTime;
      if (elapsed > max_time_ms) {
        console.log(`⏱️ Time limit reached (${elapsed}ms)`);
        break;
      }
      
      let bill: DeferredBill | null;
      
      if (bill_id && i === 0) {
        // Specific bill requested - fetch it directly
        const { data } = await supabase
          .from('legislation_tracked_bills')
          .select(`
            id, bill_identifier, current_bill_pdf_path, current_bill_text,
            current_bill_text_url, current_bill_text_version, pdf_page_count,
            text_extraction_pages_processed, text_extraction_status
          `)
          .eq('id', bill_id)
          .single();
        bill = data as DeferredBill | null;
      } else {
        // Normal mode - find next bill to process
        bill = await findNextBillToProcess();
      }
      
      if (!bill) {
        console.log("📭 No more bills to process");
        break;
      }
      
      const result = await processOneBillChunk(bill);
      results.chunks_processed++;
      
      results.details.push({
        bill_identifier: bill.bill_identifier,
        pages_processed: result.pagesProcessed,
        total_pages: result.totalPages,
        is_complete: result.isComplete,
        error: result.error,
      });
      
      if (result.isComplete) {
        results.bills_completed++;
      }
      
      if (result.error) {
        results.errors.push(`${bill.bill_identifier}: ${result.error}`);
        break;
      }
    }

    const elapsed = Date.now() - startTime;
    console.log(`✅ Completed in ${elapsed}ms: ${results.chunks_processed} chunks`);

    return new Response(
      JSON.stringify({ success: true, elapsed_ms: elapsed, ...results }),
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