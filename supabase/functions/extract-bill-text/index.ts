// supabase/functions/extract-bill-text/index.ts
// Downloads bill PDFs from Missouri Legislature, stores in Supabase Storage, and extracts text

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { extractText } from "npm:unpdf";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const STORAGE_BUCKET = "legislation-pdfs";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Hash for change detection
async function hashText(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer)).map(b => b.toString(16).padStart(2, '0')).join('').substring(0, 32);
}

// Count words
function countWords(text: string): number {
  return text.split(/\s+/).filter(w => w.length > 0).length;
}

// Parse bill identifier: "HB 1", "SB 123", "SJR 98", "HCR 5"
function parseBillIdentifier(identifier: string): { chamber: 'house' | 'senate'; type: string; number: string } | null {
  const match = identifier.match(/^(H|S)(B|JR|CR|R)\s*(\d+)$/i);
  if (!match) return null;
  return {
    chamber: match[1].toUpperCase() === 'H' ? 'house' : 'senate',
    type: match[1].toUpperCase() + match[2].toUpperCase(),
    number: match[3],
  };
}

// Build PDF URL for Missouri Legislature
function buildPdfUrl(identifier: string, session: string): string | null {
  const parsed = parseBillIdentifier(identifier);
  if (!parsed) return null;
  
  const year = parseInt(session);
  
  if (parsed.chamber === 'house') {
    // House: https://www.house.mo.gov/billtracking/bills251/hlrbillspdf/0001I.01I.pdf
    const sessionCode = `${(year - 1).toString().slice(-2)}1`; // 2026 -> "251"
    const paddedNumber = parsed.number.padStart(4, '0');
    return `https://www.house.mo.gov/billtracking/bills${sessionCode}/hlrbillspdf/${paddedNumber}I.01I.pdf`;
  } else {
    // Senate: https://www.senate.mo.gov/26info/pdf-bill/intro/SJR98.pdf
    const sessionCode = year.toString().slice(-2); // 2026 -> "26"
    return `https://www.senate.mo.gov/${sessionCode}info/pdf-bill/intro/${parsed.type}${parsed.number}.pdf`;
  }
}

// Generate storage path for a bill PDF
function getStoragePath(session: string, identifier: string, version: string = "introduced"): string {
  // Format: 2026/HB-1-introduced.pdf
  const safeIdentifier = identifier.replace(/\s+/g, "-");
  return `${session}/${safeIdentifier}-${version.toLowerCase()}.pdf`;
}

// Download PDF, upload to storage, and extract text
async function processPdf(pdfUrl: string, storagePath: string): Promise<{
  text: string | null;
  pdfPath: string | null;
  error?: string;
}> {
  console.log(`Downloading PDF: ${pdfUrl}`);
  
  const response = await fetch(pdfUrl, {
    headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0" },
  });
  
  if (!response.ok) {
    return { text: null, pdfPath: null, error: `HTTP ${response.status}` };
  }
  
  // Check Content-Type - some servers return 200 with HTML error page
  const contentType = response.headers.get("content-type") || "";
  if (!contentType.includes("pdf")) {
    return { text: null, pdfPath: null, error: "Not a PDF (wrong content-type)" };
  }
  
  const pdfBuffer = await response.arrayBuffer();
  const pdfBytes = new Uint8Array(pdfBuffer);
  
  // Verify it's actually a PDF (starts with %PDF)
  const header = String.fromCharCode(...pdfBytes.slice(0, 5));
  if (!header.startsWith("%PDF")) {
    return { text: null, pdfPath: null, error: "Not a valid PDF file" };
  }
  
  // Upload PDF to storage
  console.log(`Uploading to storage: ${storagePath}`);
  const { error: uploadError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(storagePath, pdfBytes, {
      contentType: "application/pdf",
      upsert: true,  // Overwrite if exists
    });
  
  if (uploadError) {
    console.error("Storage upload error:", uploadError);
    // Continue anyway - we can still extract text
  }
  
  // Extract text from PDF
  try {
    const { text, totalPages } = await extractText(pdfBuffer, { mergePages: true });
    
    if (!text || text.trim().length < 50) {
      return { 
        text: null, 
        pdfPath: uploadError ? null : storagePath, 
        error: "No text in PDF" 
      };
    }
    
    console.log(`Extracted ${text.length} chars from ${totalPages} pages`);
    return { 
      text, 
      pdfPath: uploadError ? null : storagePath 
    };
  } catch (e) {
    console.error("PDF extraction error:", e);
    return { 
      text: null, 
      pdfPath: uploadError ? null : storagePath, 
      error: `Extraction failed: ${e.message}` 
    };
  }
}

// Main handler
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { bill_id, bill_ids, session, force = false, limit = 10 } = body;

    let billsToProcess: any[] = [];

    if (bill_id) {
      const { data, error } = await supabase
        .from("legislation_tracked_bills")
        .select("id, bill_identifier, session, current_bill_text_hash, current_bill_pdf_path")
        .eq("id", bill_id)
        .single();
      if (error) throw error;
      billsToProcess = [data];
    } else if (bill_ids && Array.isArray(bill_ids)) {
      const { data, error } = await supabase
        .from("legislation_tracked_bills")
        .select("id, bill_identifier, session, current_bill_text_hash, current_bill_pdf_path")
        .in("id", bill_ids);
      if (error) throw error;
      billsToProcess = data || [];
    } else if (session) {
      let query = supabase
        .from("legislation_tracked_bills")
        .select("id, bill_identifier, session, current_bill_text_hash, current_bill_pdf_path")
        .eq("session", session);
      
      if (!force) {
        query = query
          .is("current_bill_text", null)
          .is("sync_error", null);  // Skip bills that already failed
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

    console.log(`Processing ${billsToProcess.length} bills`);

    const results = {
      processed: 0,
      extracted: 0,
      skipped: 0,
      failed: 0,
      pdfs_stored: 0,
      errors: [] as Array<{ bill_identifier: string; error: string }>,
    };

    for (const bill of billsToProcess) {
      results.processed++;
      
      try {
        const pdfUrl = buildPdfUrl(bill.bill_identifier, bill.session);
        
        if (!pdfUrl) {
          results.failed++;
          results.errors.push({ bill_identifier: bill.bill_identifier, error: "Invalid bill identifier format" });
          continue;
        }
        
        const storagePath = getStoragePath(bill.session, bill.bill_identifier, "introduced");
        const { text, pdfPath, error } = await processPdf(pdfUrl, storagePath);
        
        if (!text || text.length < 100) {
          // Mark this bill so we skip it next time
          await supabase
            .from("legislation_tracked_bills")
            .update({ sync_error: error || "PDF not available yet" })
            .eq("id", bill.id);
          
          results.failed++;
          results.errors.push({ 
            bill_identifier: bill.bill_identifier, 
            error: error || "PDF not available yet" 
          });
          continue;
        }
        
        const textHash = await hashText(text);
        
        // Skip if unchanged (but still update PDF path if missing)
        if (!force && bill.current_bill_text_hash === textHash && bill.current_bill_pdf_path) {
          results.skipped++;
          continue;
        }
        
        const wordCount = countWords(text);
        
        // Update database with text AND PDF path
        const { error: updateError } = await supabase
          .from("legislation_tracked_bills")
          .update({
            current_bill_text: text,
            current_bill_text_version: "Introduced",
            current_bill_text_url: pdfUrl,
            current_bill_text_hash: textHash,
            current_bill_text_extracted_at: new Date().toISOString(),
            current_bill_text_word_count: wordCount,
            current_bill_pdf_path: pdfPath,
            sync_error: null,  // Clear any previous error
          })
          .eq("id", bill.id);
        
        if (updateError) throw updateError;
        
        // Save to versions table
        await supabase
          .from("legislation_bill_text_versions")
          .upsert({
            bill_id: bill.id,
            version_name: "Introduced",
            version_order: 1,
            source_url: pdfUrl,
            media_type: "application/pdf",
            bill_text: text,
            text_hash: textHash,
            word_count: wordCount,
            extracted_at: new Date().toISOString(),
            extraction_method: "unpdf",
            is_current: true,
          }, { onConflict: "bill_id,source_url" });
        
        console.log(`✓ ${bill.bill_identifier}: ${wordCount} words, PDF: ${pdfPath ? 'stored' : 'failed'}`);
        results.extracted++;
        if (pdfPath) results.pdfs_stored++;
        
        await new Promise(r => setTimeout(r, 300));
        
      } catch (e: any) {
        console.error(`Error ${bill.bill_identifier}:`, e.message);
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