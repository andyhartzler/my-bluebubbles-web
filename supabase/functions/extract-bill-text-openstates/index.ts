// supabase/functions/extract-bill-text-openstates/index.ts
// v3 - With size-based routing to chunked extraction processor

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractText } from "npm:unpdf";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const OPEN_STATES_BASE_URL = "https://v3.openstates.org";
const STORAGE_BUCKET = "legislation-pdfs";
const RATE_LIMIT_DELAY_MS = 6500;

// Size thresholds - bills exceeding these get deferred to large file processor
const MAX_PDF_SIZE_BYTES = 2 * 1024 * 1024; // 2MB
const MAX_PAGES_QUICK_EXTRACT = 50; // If we detect >50 pages, bail

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================
// INLINE API KEY ROTATION (same as before)
// ============================================================

interface ApiKeyInfo {
  api_key: string;
  key_id: number;
  key_name: string;
  calls_remaining: number;
}

interface FetchResult<T> {
  success: boolean;
  data?: T;
  error?: string;
  keyId?: number;
  rateLimited?: boolean;
}

async function getApiKey(): Promise<ApiKeyInfo | null> {
  const { data, error } = await supabase.rpc('get_available_api_key');
  
  if (error || !data || data.length === 0) {
    const { data: fallbackKey } = await supabase
      .from('legislation_api_keys')
      .select('api_key, id, name')
      .eq('is_active', true)
      .lt('calls_today', 250)
      .order('calls_today', { ascending: true })
      .limit(1)
      .single();
    
    if (fallbackKey) {
      return {
        api_key: fallbackKey.api_key,
        key_id: fallbackKey.id,
        key_name: fallbackKey.name,
        calls_remaining: 250
      };
    }
    return null;
  }
  
  return {
    api_key: data[0].api_key,
    key_id: data[0].key_id,
    key_name: data[0].key_name,
    calls_remaining: data[0].calls_remaining
  };
}

async function logApiCall(keyId: number, success: boolean, wasRateLimited: boolean = false): Promise<void> {
  try {
    await supabase.rpc('log_api_key_call', {
      p_key_id: keyId,
      p_success: success,
      p_was_rate_limited: wasRateLimited
    });
  } catch (err) {
    console.log("Note: log_api_key_call not available");
  }
}

async function fetchOpenStates<T = any>(endpoint: string, params?: URLSearchParams): Promise<FetchResult<T>> {
  const maxAttempts = 6;
  let attempts = 0;

  while (attempts < maxAttempts) {
    const keyInfo = await getApiKey();
    
    if (!keyInfo) {
      return { success: false, error: "All API keys exhausted", rateLimited: true };
    }

    const queryString = params ? `?${params.toString()}` : "";
    const url = `${OPEN_STATES_BASE_URL}${endpoint}${queryString}`;

    console.log(`[Key ${keyInfo.key_id}] Fetching: ${endpoint}`);

    try {
      const response = await fetch(url, {
        headers: {
          "X-API-KEY": keyInfo.api_key,
          "Accept": "application/json",
        },
      });

      if (response.status === 429) {
        console.log(`[Key ${keyInfo.key_id}] Rate limited, switching...`);
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }

      if (!response.ok) {
        const errorText = await response.text().catch(() => "Unknown error");
        await logApiCall(keyInfo.key_id, false);
        return { success: false, error: `API error ${response.status}: ${errorText.substring(0, 200)}` };
      }

      await logApiCall(keyInfo.key_id, true);
      const data = await response.json();
      return { success: true, data: data as T, keyId: keyInfo.key_id };

    } catch (err: any) {
      if (err.message?.includes("429")) {
        await logApiCall(keyInfo.key_id, false, true);
        attempts++;
        continue;
      }
      await logApiCall(keyInfo.key_id, false);
      return { success: false, error: err.message };
    }
  }

  return { success: false, error: "Exhausted all API key attempts", rateLimited: true };
}

async function fetchBill(openstatesBillId: string): Promise<FetchResult<any>> {
  const params = new URLSearchParams();
  params.append("include", "versions");
  params.append("include", "documents");
  return fetchOpenStates(`/bills/${openstatesBillId}`, params);
}

// ============================================================
// TEXT EXTRACTION HELPERS
// ============================================================

async function hashText(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer)).map(b => b.toString(16).padStart(2, '0')).join('').substring(0, 32);
}

function countWords(text: string): number {
  return text.split(/\s+/).filter(w => w.length > 0).length;
}

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

function getStoragePath(session: string, identifier: string, version: string = "introduced"): string {
  const safeIdentifier = identifier.replace(/\s+/g, "-");
  const safeVersion = version.replace(/[^a-zA-Z0-9-]/g, "-").toLowerCase().substring(0, 50);
  return `${session}/${safeIdentifier}-${safeVersion}.pdf`;
}

// ============================================================
// PRE-FLIGHT SIZE CHECK
// ============================================================

interface SizeCheckResult {
  proceed: boolean;
  size?: number;
  reason?: string;
}

async function checkPdfSize(pdfUrl: string): Promise<SizeCheckResult> {
  try {
    // Try HEAD request first (faster, no download)
    const headResponse = await fetch(pdfUrl, {
      method: "HEAD",
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0",
      },
    });

    if (headResponse.ok) {
      const contentLength = headResponse.headers.get("content-length");
      if (contentLength) {
        const size = parseInt(contentLength, 10);
        if (size > MAX_PDF_SIZE_BYTES) {
          return { 
            proceed: false, 
            size, 
            reason: `PDF too large: ${(size / 1024 / 1024).toFixed(2)}MB exceeds ${MAX_PDF_SIZE_BYTES / 1024 / 1024}MB limit`
          };
        }
        return { proceed: true, size };
      }
    }

    // If HEAD doesn't give size, we'll check during download
    return { proceed: true };
  } catch (e) {
    console.log(`HEAD request failed for ${pdfUrl}, proceeding with caution`);
    return { proceed: true };
  }
}

// ============================================================
// PDF DOWNLOAD AND EXTRACTION (MODIFIED)
// ============================================================

interface ExtractionResult {
  text: string | null;
  pdfPath: string | null;
  error?: string;
  deferred?: boolean;
  deferredReason?: string;
  pageCount?: number;
  sizeBytes?: number;
}

async function downloadAndExtractPdf(
  pdfUrl: string, 
  storagePath: string,
  skipLargeFiles: boolean = true
): Promise<ExtractionResult> {
  console.log(`Downloading PDF: ${pdfUrl}`);
  
  try {
    const response = await fetch(pdfUrl, {
      headers: { 
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0",
        "Accept": "application/pdf,*/*",
      },
      redirect: "follow",
    });
    
    if (!response.ok) {
      return { text: null, pdfPath: null, error: `HTTP ${response.status}` };
    }

    const pdfBuffer = await response.arrayBuffer();
    const pdfBytes = new Uint8Array(pdfBuffer);
    const sizeBytes = pdfBytes.length;
    
    // Check size after download (in case HEAD didn't work)
    if (skipLargeFiles && sizeBytes > MAX_PDF_SIZE_BYTES) {
      const sizeMB = (sizeBytes / 1024 / 1024).toFixed(2);
      console.log(`⏸️ PDF too large (${sizeMB}MB), deferring to large file processor`);
      
      // Still upload to storage so the large file processor doesn't need to re-download
      console.log(`Uploading to storage for deferred processing: ${storagePath}`);
      await supabase.storage
        .from(STORAGE_BUCKET)
        .upload(storagePath, pdfBytes, {
          contentType: "application/pdf",
          upsert: true,
        });
      
      return { 
        text: null, 
        pdfPath: storagePath,
        deferred: true,
        deferredReason: `PDF size ${sizeMB}MB exceeds ${MAX_PDF_SIZE_BYTES / 1024 / 1024}MB threshold`,
        sizeBytes
      };
    }
    
    const header = String.fromCharCode(...pdfBytes.slice(0, 5));
    if (!header.startsWith("%PDF")) {
      return { text: null, pdfPath: null, error: "Not a valid PDF" };
    }
    
    console.log(`Uploading to storage: ${storagePath}`);
    const { error: uploadError } = await supabase.storage
      .from(STORAGE_BUCKET)
      .upload(storagePath, pdfBytes, {
        contentType: "application/pdf",
        upsert: true,
      });
    
    if (uploadError) {
      console.error("Storage upload error:", uploadError);
    }
    
    const { text, totalPages } = await extractText(pdfBuffer, { mergePages: true });
    
    // Check page count - defer if too many pages (BEFORE doing expensive text processing)
    if (skipLargeFiles && totalPages > MAX_PAGES_QUICK_EXTRACT) {
      console.log(`⏸️ PDF has ${totalPages} pages, deferring to large file processor`);
      return { 
        text: null, 
        pdfPath: uploadError ? null : storagePath,
        deferred: true,
        deferredReason: `PDF has ${totalPages} pages, exceeds ${MAX_PAGES_QUICK_EXTRACT} page threshold`,
        pageCount: totalPages,
        sizeBytes
      };
    }
    
    if (!text || text.trim().length < 50) {
      return { 
        text: null, 
        pdfPath: uploadError ? null : storagePath, 
        error: "No text in PDF",
        pageCount: totalPages,
        sizeBytes
      };
    }
    
    const cleanText = sanitizeText(text);
    
    console.log(`Extracted ${cleanText.length} chars from ${totalPages} pages`);
    return { 
      text: cleanText, 
      pdfPath: uploadError ? null : storagePath,
      pageCount: totalPages,
      sizeBytes
    };
  } catch (e: any) {
    console.error("PDF extraction error:", e);
    return { 
      text: null, 
      pdfPath: null, 
      error: `Extraction failed: ${e.message}` 
    };
  }
}

function findBestPdfUrl(versions: any[], documents: any[]): { url: string; note: string; date: string } | null {
  const allSources = [
    ...(versions || []).map((v: any) => ({ ...v, source: 'version' })),
    ...(documents || []).map((d: any) => ({ ...d, source: 'document' })),
  ];
  
  if (allSources.length === 0) return null;
  
  const sorted = allSources.sort((a, b) => {
    const dateA = a.date ? new Date(a.date).getTime() : 0;
    const dateB = b.date ? new Date(b.date).getTime() : 0;
    return dateB - dateA;
  });
  
  for (const item of sorted) {
    const links = item.links || [];
    const pdfLink = links.find((link: any) => 
      link.media_type === "application/pdf" || 
      link.url?.toLowerCase().endsWith(".pdf")
    );
    
    if (pdfLink?.url) {
      return {
        url: pdfLink.url,
        note: item.note || "Unknown Version",
        date: item.date || "",
      };
    }
  }
  
  return null;
}

// ============================================================
// HELPER: Mark bill for chunked extraction
// ============================================================

interface DeferredBillUpdate {
  text_extraction_deferred: boolean;
  text_extraction_deferred_reason: string | null;
  text_extraction_status: string;
  text_extraction_pages_processed: number;
  text_extraction_total_pages: number | null;
  text_extraction_attempts: number;
  text_extraction_started_at: null;
  text_extraction_last_chunk_at: null;
  pdf_size_bytes?: number;
  pdf_page_count?: number;
  current_bill_pdf_path?: string | null;
  current_bill_text_url?: string;
  current_bill_text_version?: string;
  sync_error: null;
}

function buildDeferredUpdate(
  reason: string,
  options: {
    sizeBytes?: number;
    pageCount?: number;
    pdfPath?: string | null;
    textUrl?: string;
    textVersion?: string;
  } = {}
): DeferredBillUpdate {
  const update: DeferredBillUpdate = {
    // Legacy deferred flag (for backwards compatibility)
    text_extraction_deferred: true,
    text_extraction_deferred_reason: reason,
    // NEW: Chunked extraction tracking columns
    text_extraction_status: 'pending',
    text_extraction_pages_processed: 0,
    text_extraction_total_pages: options.pageCount || null,
    text_extraction_attempts: 0,
    text_extraction_started_at: null,
    text_extraction_last_chunk_at: null,
    // Clear any previous error
    sync_error: null,
  };

  if (options.sizeBytes !== undefined) {
    update.pdf_size_bytes = options.sizeBytes;
  }
  if (options.pageCount !== undefined) {
    update.pdf_page_count = options.pageCount;
  }
  if (options.pdfPath !== undefined) {
    update.current_bill_pdf_path = options.pdfPath;
  }
  if (options.textUrl) {
    update.current_bill_text_url = options.textUrl;
  }
  if (options.textVersion) {
    update.current_bill_text_version = options.textVersion;
  }

  return update;
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
    const body = await req.json();
    const { 
      bill_id, 
      bill_ids, 
      session, 
      force = false, 
      limit = 10,
      skip_large_files = true,  // Set false to force process large files
      process_deferred = false  // Only process deferred bills
    } = body;

    let billsToProcess: any[] = [];

    if (bill_id) {
      const { data, error } = await supabase
        .from("legislation_tracked_bills")
        .select("id, openstates_bill_id, bill_identifier, session, current_bill_text_hash, current_bill_pdf_path, openstates_data, text_extraction_deferred, text_extraction_status")
        .eq("id", bill_id)
        .single();
      if (error) throw error;
      billsToProcess = [data];
    } else if (bill_ids && Array.isArray(bill_ids)) {
      const { data, error } = await supabase
        .from("legislation_tracked_bills")
        .select("id, openstates_bill_id, bill_identifier, session, current_bill_text_hash, current_bill_pdf_path, openstates_data, text_extraction_deferred, text_extraction_status")
        .in("id", bill_ids);
      if (error) throw error;
      billsToProcess = data || [];
    } else if (session) {
      let query = supabase
        .from("legislation_tracked_bills")
        .select("id, openstates_bill_id, bill_identifier, session, current_bill_text_hash, current_bill_pdf_path, openstates_data, text_extraction_deferred, text_extraction_status")
        .eq("session", session);
      
      if (process_deferred) {
        // Only get deferred bills (for large file processing mode)
        query = query.eq("text_extraction_deferred", true);
      } else if (!force) {
        // Normal mode: bills needing text that AREN'T deferred or already being processed
        query = query
          .is("current_bill_text", null)
          .is("sync_error", null)
          .or("text_extraction_deferred.is.null,text_extraction_deferred.eq.false")
          .or("text_extraction_status.is.null,text_extraction_status.neq.in_progress");
      }
      
      const { data, error } = await query.limit(limit);
      if (error) throw error;
      billsToProcess = data || [];
    } else {
      return new Response(
        JSON.stringify({ error: "Must provide bill_id, bill_ids, or session" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Processing ${billsToProcess.length} bills (skip_large=${skip_large_files}, deferred_only=${process_deferred})`);

    const results = {
      processed: 0,
      extracted: 0,
      skipped: 0,
      failed: 0,
      deferred: 0,
      pdfs_stored: 0,
      api_calls: 0,
      errors: [] as Array<{ bill_identifier: string; error: string }>,
      deferred_bills: [] as Array<{ bill_identifier: string; reason: string }>,
    };

    for (const bill of billsToProcess) {
      results.processed++;
      
      try {
        if (!bill.openstates_bill_id) {
          await supabase
            .from("legislation_tracked_bills")
            .update({ sync_error: "No OpenStates bill ID" })
            .eq("id", bill.id);
          results.failed++;
          results.errors.push({ bill_identifier: bill.bill_identifier, error: "No OpenStates bill ID" });
          continue;
        }
        
        let pdfInfo: { url: string; note: string; date: string } | null = null;
        
        if (bill.openstates_data?.versions || bill.openstates_data?.documents) {
          pdfInfo = findBestPdfUrl(bill.openstates_data.versions, bill.openstates_data.documents);
          if (pdfInfo) console.log(`Found PDF URL from cached data for ${bill.bill_identifier}`);
        }
        
        if (!pdfInfo) {
          console.log(`Fetching bill details from API for ${bill.bill_identifier}...`);
          const fetchResult = await fetchBill(bill.openstates_bill_id);
          results.api_calls++;
          
          if (!fetchResult.success) {
            results.failed++;
            results.errors.push({ bill_identifier: bill.bill_identifier, error: fetchResult.error || "API fetch failed" });
            await new Promise(r => setTimeout(r, RATE_LIMIT_DELAY_MS));
            continue;
          }
          
          const billData = fetchResult.data;
          pdfInfo = findBestPdfUrl(billData.versions, billData.documents);
          
          await supabase
            .from("legislation_tracked_bills")
            .update({ openstates_data: billData })
            .eq("id", bill.id);
          
          await new Promise(r => setTimeout(r, RATE_LIMIT_DELAY_MS));
        }
        
        if (!pdfInfo) {
          await supabase
            .from("legislation_tracked_bills")
            .update({ sync_error: "No PDF in versions or documents" })
            .eq("id", bill.id);
          results.failed++;
          results.errors.push({ bill_identifier: bill.bill_identifier, error: "No PDF in versions or documents" });
          continue;
        }

        // PRE-FLIGHT SIZE CHECK (only in normal mode)
        if (skip_large_files) {
          const sizeCheck = await checkPdfSize(pdfInfo.url);
          if (!sizeCheck.proceed) {
            console.log(`⏸️ ${bill.bill_identifier}: ${sizeCheck.reason}`);
            
            // Build update with all chunked extraction tracking fields
            const deferredUpdate = buildDeferredUpdate(
              sizeCheck.reason || "Size check failed",
              {
                sizeBytes: sizeCheck.size,
                textUrl: pdfInfo.url,
                textVersion: pdfInfo.note,
              }
            );
            
            await supabase
              .from("legislation_tracked_bills")
              .update(deferredUpdate)
              .eq("id", bill.id);
            
            results.deferred++;
            results.deferred_bills.push({ 
              bill_identifier: bill.bill_identifier, 
              reason: sizeCheck.reason || "Size check failed" 
            });
            continue;
          }
        }
        
        const storagePath = getStoragePath(bill.session, bill.bill_identifier, pdfInfo.note);
        const extractResult = await downloadAndExtractPdf(pdfInfo.url, storagePath, skip_large_files);
        
        // Handle deferred result
        if (extractResult.deferred) {
          // Build update with all chunked extraction tracking fields
          const deferredUpdate = buildDeferredUpdate(
            extractResult.deferredReason || "Large file",
            {
              sizeBytes: extractResult.sizeBytes,
              pageCount: extractResult.pageCount,
              pdfPath: extractResult.pdfPath,
              textUrl: pdfInfo.url,
              textVersion: pdfInfo.note,
            }
          );
          
          await supabase
            .from("legislation_tracked_bills")
            .update(deferredUpdate)
            .eq("id", bill.id);
          
          results.deferred++;
          results.deferred_bills.push({ 
            bill_identifier: bill.bill_identifier, 
            reason: extractResult.deferredReason || "Large file" 
          });
          if (extractResult.pdfPath) results.pdfs_stored++;
          continue;
        }
        
        if (!extractResult.text || extractResult.text.length < 100) {
          await supabase
            .from("legislation_tracked_bills")
            .update({ sync_error: extractResult.error || "Could not extract text" })
            .eq("id", bill.id);
          results.failed++;
          results.errors.push({ bill_identifier: bill.bill_identifier, error: extractResult.error || "Could not extract text" });
          continue;
        }
        
        const textHash = await hashText(extractResult.text);
        
        if (!force && bill.current_bill_text_hash === textHash && bill.current_bill_pdf_path) {
          results.skipped++;
          continue;
        }
        
        const wordCount = countWords(extractResult.text);
        
        const { error: updateError } = await supabase
          .from("legislation_tracked_bills")
          .update({
            current_bill_text: extractResult.text,
            current_bill_text_version: pdfInfo.note,
            current_bill_text_url: pdfInfo.url,
            current_bill_text_hash: textHash,
            current_bill_text_extracted_at: new Date().toISOString(),
            current_bill_text_word_count: wordCount,
            current_bill_pdf_path: extractResult.pdfPath,
            pdf_size_bytes: extractResult.sizeBytes,
            pdf_page_count: extractResult.pageCount,
            // Clear deferred flags since we successfully extracted
            text_extraction_deferred: false,
            text_extraction_deferred_reason: null,
            text_extraction_status: 'completed',
            sync_error: null,
          })
          .eq("id", bill.id);
        
        if (updateError) throw updateError;
        
        await supabase
          .from("legislation_bill_text_versions")
          .upsert({
            bill_id: bill.id,
            version_name: pdfInfo.note,
            version_order: 1,
            source_url: pdfInfo.url,
            media_type: "application/pdf",
            bill_text: extractResult.text,
            text_hash: textHash,
            word_count: wordCount,
            extracted_at: new Date().toISOString(),
            extraction_method: "openstates-api",
            is_current: true,
          }, { onConflict: "bill_id,source_url" });
        
        console.log(`✓ ${bill.bill_identifier}: ${wordCount} words (${pdfInfo.note})`);
        results.extracted++;
        if (extractResult.pdfPath) results.pdfs_stored++;
        
      } catch (e: any) {
        console.error(`Error ${bill.bill_identifier}:`, e.message);
        
        await supabase
          .from("legislation_tracked_bills")
          .update({ sync_error: e.message.substring(0, 500) })
          .eq("id", bill.id);
        
        results.failed++;
        results.errors.push({ bill_identifier: bill.bill_identifier, error: e.message });
      }
    }

    return new Response(
      JSON.stringify({ success: true, ...results }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err: any) {
    console.error("Error:", err);
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});