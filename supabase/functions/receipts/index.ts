// Receipt Processing Edge Function
// Replaces Zapier "Receipts Logger" workflow
//
// Actions:
//   process_gmail  — Scan Gmail for receipt emails, extract data via AI, store PDFs
//   list           — List all receipts with optional filters
//   match          — Match a receipt to a bank transaction
//   update         — Update receipt metadata (category, mec_purpose, etc.)
//
// Environment variables (set via Supabase Dashboard → Edge Functions → Secrets):
//   GMAIL_SERVICE_ACCOUNT_JSON — Google service account JSON for Gmail API
//   AI_API_KEY — API key for ai.hartzler.app (gemma4)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const AI_ENDPOINT = "https://ai.hartzler.app/v1";
const AI_API_KEY = Deno.env.get("AI_API_KEY") ?? "7231d4a948bdd737e1a9861060a72a3fb3c647e773e132b74b0883c789bb0eae";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://moyd.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── AI Receipt Analysis ──

async function analyzeReceipt(subject: string, from: string, bodyText: string): Promise<{
  vendor_name: string;
  amount: number | null;
  category: string;
  description: string;
}> {
  const prompt = `Analyze this email receipt and extract the following information as JSON:
- vendor_name: The company/vendor name
- amount: The total amount as a number (no $ sign), or null if not found
- category: One of: Advertising, Office Supplies, Travel, Printing, Postage, Events, Consulting, Utilities, Software, Internet Services, Groceries, Restaurants, Transportation, Donations, Fees, General Merchandise
- description: A brief 1-line description of the purchase

Email Subject: ${subject}
From: ${from}
Body (first 2000 chars): ${bodyText.slice(0, 2000)}

Respond ONLY with valid JSON, no other text.`;

  try {
    const resp = await fetch(`${AI_ENDPOINT}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${AI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gemma4",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.1,
        max_tokens: 200,
      }),
    });

    if (!resp.ok) {
      console.error("AI API error:", resp.status, await resp.text());
      return { vendor_name: from, amount: null, category: "General Merchandise", description: subject };
    }

    const data = await resp.json();
    const content = data.choices?.[0]?.message?.content ?? "";

    // Extract JSON from response (handle markdown code blocks)
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return {
        vendor_name: parsed.vendor_name || from,
        amount: typeof parsed.amount === "number" ? parsed.amount : null,
        category: parsed.category || "General Merchandise",
        description: parsed.description || subject,
      };
    }
  } catch (e) {
    console.error("AI analysis failed:", e);
  }

  // Fallback: extract amount from subject/body
  const amountMatch = (subject + " " + bodyText).match(/\$\s*(\d+(?:,\d{3})*(?:\.\d{2})?)/);
  return {
    vendor_name: from.replace(/<.*>/, "").trim() || "Unknown",
    amount: amountMatch ? parseFloat(amountMatch[1].replace(/,/g, "")) : null,
    category: "General Merchandise",
    description: subject,
  };
}

// ── HTML to clean text ──

function htmlToText(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<script[\s\S]*?<\/script>/gi, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#\d+;/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

// ── Convert HTML email to a styled HTML document for PDF-like display ──

function wrapEmailHtml(subject: string, from: string, date: string, html: string): string {
  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { font-family: -apple-system, Arial, sans-serif; margin: 40px; color: #333; }
  .header { border-bottom: 2px solid #273351; padding-bottom: 16px; margin-bottom: 24px; }
  .header h1 { font-size: 18px; color: #273351; margin: 0 0 8px 0; }
  .header .meta { font-size: 13px; color: #666; }
  .content { line-height: 1.6; }
  .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #ddd; font-size: 11px; color: #999; }
</style>
</head>
<body>
<div class="header">
  <h1>${subject}</h1>
  <div class="meta">From: ${from}<br>Date: ${date}</div>
</div>
<div class="content">${html}</div>
<div class="footer">Archived by MOYD CRM Receipt System</div>
</body>
</html>`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, ...params } = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    switch (action) {
      // ── Process a single receipt from email data ──
      case "process_receipt": {
        const {
          message_id, from, to, subject, date,
          body_html, body_text, attachments, account,
        } = params;

        // Check if already processed
        const { data: existing } = await supabase
          .from("receipts")
          .select("id")
          .eq("email_message_id", message_id)
          .maybeSingle();

        if (existing) {
          return new Response(
            JSON.stringify({ skipped: true, id: existing.id }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        // AI analysis
        const text = body_text || htmlToText(body_html || "");
        const analysis = await analyzeReceipt(subject || "", from || "", text);

        // Store the receipt document (PDF/HTML)
        let storagePath = "";
        let storageUrl = "";
        let pdfSource = "email";
        let originalFilename = "";

        const dateStr = date ? new Date(date).toISOString().split("T")[0] : new Date().toISOString().split("T")[0];
        const safeVendor = (analysis.vendor_name || "receipt").replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 50);

        if (attachments?.length) {
          // Use the first PDF/image attachment
          const attach = attachments[0];
          pdfSource = "attachment";
          originalFilename = attach.filename || "receipt.pdf";
          storagePath = `${dateStr}/${safeVendor}_${originalFilename}`;

          // Decode base64 attachment and upload
          const fileData = Uint8Array.from(atob(attach.data), (c) => c.charCodeAt(0));
          const { error: uploadErr } = await supabase.storage
            .from("receipts")
            .upload(storagePath, fileData, {
              contentType: attach.content_type || "application/pdf",
              upsert: true,
            });
          if (uploadErr) console.error("Upload error:", uploadErr);
        } else if (body_html) {
          // Store the styled HTML as the receipt document
          const styledHtml = wrapEmailHtml(
            subject || "Receipt",
            from || "",
            date || new Date().toISOString(),
            body_html
          );
          storagePath = `${dateStr}/${safeVendor}_email_receipt.html`;
          const htmlBytes = new TextEncoder().encode(styledHtml);
          const { error: uploadErr } = await supabase.storage
            .from("receipts")
            .upload(storagePath, htmlBytes, {
              contentType: "text/html",
              upsert: true,
            });
          if (uploadErr) console.error("Upload error:", uploadErr);
        }

        // Get permanent public URL (bucket is public)
        if (storagePath) {
          const { data: urlData } = supabase.storage
            .from("receipts")
            .getPublicUrl(storagePath);
          storageUrl = urlData?.publicUrl || "";
        }

        // Insert receipt record
        const { data: receipt, error: insertErr } = await supabase
          .from("receipts")
          .insert({
            email_message_id: message_id,
            email_from: from,
            email_to: to,
            email_subject: subject,
            email_date: date,
            email_account: account || "unknown",
            vendor_name: analysis.vendor_name,
            amount: analysis.amount,
            category: analysis.category,
            description: analysis.description,
            storage_path: storagePath,
            storage_url: storageUrl,
            pdf_source: pdfSource,
            original_filename: originalFilename || storagePath.split("/").pop(),
          })
          .select()
          .single();

        if (insertErr) throw insertErr;

        return new Response(
          JSON.stringify({ success: true, receipt }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ── List receipts with filters ──
      case "list": {
        let query = supabase
          .from("receipts")
          .select("*")
          .order("email_date", { ascending: false });

        if (params.match_status) query = query.eq("match_status", params.match_status);
        if (params.category) query = query.eq("category", params.category);
        if (params.limit) query = query.limit(params.limit);

        const { data, error } = await query;
        if (error) throw error;

        return new Response(
          JSON.stringify({ receipts: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ── Delete receipt (DB record + storage file) ──
      case "delete": {
        const { receipt_id } = params;
        const { data: receipt } = await supabase
          .from("receipts")
          .select("storage_path")
          .eq("id", receipt_id)
          .maybeSingle();

        // Delete from storage first
        if (receipt?.storage_path) {
          await supabase.storage
            .from("receipts")
            .remove([receipt.storage_path]);
        }

        // Delete DB record
        const { error } = await supabase
          .from("receipts")
          .delete()
          .eq("id", receipt_id);

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ── Match receipt to transaction ──
      case "match": {
        const { receipt_id, transaction_id, match_status } = params;

        const { data, error } = await supabase
          .from("receipts")
          .update({
            transaction_id,
            match_status: match_status || "matched",
            updated_at: new Date().toISOString(),
          })
          .eq("id", receipt_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, receipt: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ── Update receipt metadata ──
      case "update": {
        const { receipt_id, ...updates } = params;
        const allowed = [
          "vendor_name", "amount", "category", "description",
          "match_status", "mec_included", "mec_purpose",
        ];
        const safeUpdates: Record<string, unknown> = { updated_at: new Date().toISOString() };
        for (const key of allowed) {
          if (key in updates) safeUpdates[key] = updates[key];
        }

        const { data, error } = await supabase
          .from("receipts")
          .update(safeUpdates)
          .eq("id", receipt_id)
          .select()
          .single();

        if (error) throw error;

        return new Response(
          JSON.stringify({ success: true, receipt: data }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ── Get public URL for a receipt ──
      case "refresh_url": {
        const { receipt_id } = params;
        const { data: receipt } = await supabase
          .from("receipts")
          .select("storage_path")
          .eq("id", receipt_id)
          .single();

        if (!receipt?.storage_path) {
          return new Response(
            JSON.stringify({ error: "No file stored for this receipt" }),
            { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const { data: urlData } = supabase.storage
          .from("receipts")
          .getPublicUrl(receipt.storage_path);

        // Update stored URL
        await supabase
          .from("receipts")
          .update({ storage_url: urlData?.publicUrl, updated_at: new Date().toISOString() })
          .eq("id", receipt_id);

        return new Response(
          JSON.stringify({ url: urlData?.publicUrl }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      default:
        return new Response(
          JSON.stringify({ error: `Unknown action: ${action}` }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
  } catch (e) {
    console.error("Receipt function error:", e);
    return new Response(
      JSON.stringify({ error: e.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
