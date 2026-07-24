import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

/**
 * mautic-report-discovery
 * 
 * Discovers available report sources and their columns in Mautic.
 * Use this to find the correct column names for creating reports.
 * 
 * Usage:
 *   POST {}                           - List all report sources
 *   POST { "source": "page.hits" }    - Get columns for specific source
 */

function cleanEnvVar(value: string | undefined): string {
  if (!value) return "";
  return value.replace(/^["']|["']$/g, "").trim();
}

const mauticUrl = cleanEnvVar(Deno.env.get("MAUTIC_URL"));
const mauticUsername = cleanEnvVar(Deno.env.get("MAUTIC_USERNAME"));
const mauticPassword = cleanEnvVar(Deno.env.get("MAUTIC_PASSWORD"));

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function getMauticAuth(): string {
  return `Basic ${btoa(`${mauticUsername}:${mauticPassword}`)}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }
  
  try {
    const body = await req.json().catch(() => ({}));
    const { source } = body;
    
    if (!mauticUrl || !mauticUsername || !mauticPassword) {
      throw new Error("Missing Mautic configuration");
    }
    
    const authHeader = getMauticAuth();
    
    // Get report builder options (sources, columns, etc.)
    // This endpoint returns available data sources and their columns
    const optionsRes = await fetch(`${mauticUrl}/api/reports`, {
      headers: { Authorization: authHeader },
    });
    
    if (!optionsRes.ok) {
      throw new Error(`Failed to get reports: ${optionsRes.status} - ${await optionsRes.text()}`);
    }
    
    const reportsData = await optionsRes.json();
    
    // Try to get report configuration options
    // Mautic should have an endpoint for this
    const newReportRes = await fetch(`${mauticUrl}/api/reports/new`, {
      method: "GET",  // GET on /new returns the form/options
      headers: { Authorization: authHeader },
    });
    
    let reportOptions = null;
    if (newReportRes.ok) {
      reportOptions = await newReportRes.json();
    }
    
    // If a specific source is requested, try to get its columns
    let sourceColumns = null;
    if (source) {
      // Try fetching columns for the source
      // Some Mautic versions have this endpoint
      const columnsRes = await fetch(`${mauticUrl}/api/reports/columns/${source}`, {
        headers: { Authorization: authHeader },
      });
      
      if (columnsRes.ok) {
        sourceColumns = await columnsRes.json();
      }
    }
    
    // Also list existing reports to see their structure
    const existingReports = Object.values(reportsData.reports || {}).map((r: any) => ({
      id: r.id,
      name: r.name,
      source: r.source,
      columns: r.columns,
    }));
    
    return new Response(
      JSON.stringify({
        success: true,
        existingReports,
        reportOptions,
        sourceColumns,
        requestedSource: source,
        hint: "Look at existingReports to see what columns work for each source type",
      }, null, 2),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
    
  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});