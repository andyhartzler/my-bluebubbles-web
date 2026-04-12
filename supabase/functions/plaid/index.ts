// Plaid Integration Edge Function
// Handles: link token creation, token exchange, transaction sync
//
// Environment variables are set via Supabase Dashboard → Edge Functions → Secrets:
//   PLAID_CLIENT_ID, PLAID_SECRET, PLAID_ENV

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const PLAID_CLIENT_ID = Deno.env.get("PLAID_CLIENT_ID") ?? "";
const PLAID_SECRET = Deno.env.get("PLAID_SECRET") ?? "";
const PLAID_ENV = Deno.env.get("PLAID_ENV") ?? "production";
const PLAID_BASE_URL =
  PLAID_ENV === "production"
    ? "https://production.plaid.com"
    : PLAID_ENV === "development"
    ? "https://development.plaid.com"
    : "https://sandbox.plaid.com";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://moyd.app",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function plaidRequest(endpoint: string, body: Record<string, unknown>) {
  const resp = await fetch(`${PLAID_BASE_URL}${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: PLAID_CLIENT_ID,
      secret: PLAID_SECRET,
      ...body,
    }),
  });
  const data = await resp.json();
  if (!resp.ok) {
    throw new Error(`Plaid API error: ${data.error_message ?? data.error_code ?? resp.statusText}`);
  }
  return data;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, ...params } = await req.json();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    switch (action) {
      // ── Create Link Token (for Plaid Link UI) ──
      case "create_link_token": {
        const data = await plaidRequest("/link/token/create", {
          user: { client_user_id: "moyd-crm" },
          client_name: "MOYD CRM",
          products: ["transactions"],
          country_codes: ["US"],
          language: "en",
          redirect_uri: params.redirect_uri,
        });
        return new Response(JSON.stringify(data), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // ── Exchange Public Token for Access Token ──
      case "exchange_token": {
        const data = await plaidRequest("/item/public_token/exchange", {
          public_token: params.public_token,
        });

        if (data.access_token) {
          // Get account info
          const accounts = await plaidRequest("/accounts/get", {
            access_token: data.access_token,
          });

          // Store permanently in Supabase
          await supabase.from("plaid_connections").upsert(
            {
              item_id: data.item_id,
              institution_id: params.institution_id ?? "unknown",
              institution_name: params.institution_name ?? "UMB Bank",
              access_token: data.access_token,
              account_ids: accounts.accounts?.map(
                (a: { account_id: string }) => a.account_id
              ),
              account_names: accounts.accounts?.map(
                (a: { name: string }) => a.name
              ),
              account_types: accounts.accounts?.map(
                (a: { type: string }) => a.type
              ),
              status: "active",
              updated_at: new Date().toISOString(),
            },
            { onConflict: "item_id" }
          );
        }

        return new Response(
          JSON.stringify({ success: true, item_id: data.item_id }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // ── Sync Transactions ──
      case "sync_transactions": {
        // Get all active Plaid connections
        const { data: connections } = await supabase
          .from("plaid_connections")
          .select("*")
          .eq("status", "active");

        if (!connections?.length) {
          return new Response(
            JSON.stringify({ error: "No active Plaid connections" }),
            {
              status: 400,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }

        let totalAdded = 0;
        let totalModified = 0;
        let totalRemoved = 0;

        for (const conn of connections) {
          let hasMore = true;
          let cursor = conn.cursor ?? "";

          while (hasMore) {
            const data = await plaidRequest("/transactions/sync", {
              access_token: conn.access_token,
              cursor: cursor || undefined,
              count: 500,
            });

            // Insert new transactions
            if (data.added?.length) {
              const rows = data.added.map(
                (t: {
                  transaction_id: string;
                  account_id: string;
                  amount: number;
                  date: string;
                  name: string;
                  merchant_name: string;
                  category: string[];
                  category_id: string;
                  payment_channel: string;
                  pending: boolean;
                }) => ({
                  plaid_transaction_id: t.transaction_id,
                  plaid_connection_id: conn.id,
                  account_id: t.account_id,
                  amount: t.amount,
                  date: t.date,
                  name: t.name,
                  merchant_name: t.merchant_name,
                  category: t.category,
                  category_id: t.category_id,
                  payment_channel: t.payment_channel,
                  pending: t.pending,
                  // Auto-map payment type for MEC
                  mec_payment_type:
                    t.payment_channel === "online"
                      ? "R"
                      : t.payment_channel === "in store"
                      ? "C"
                      : "C",
                })
              );
              await supabase
                .from("bank_transactions")
                .upsert(rows, { onConflict: "plaid_transaction_id" });
              totalAdded += data.added.length;
            }

            // Update modified transactions
            if (data.modified?.length) {
              for (const t of data.modified) {
                await supabase
                  .from("bank_transactions")
                  .update({
                    amount: t.amount,
                    date: t.date,
                    name: t.name,
                    merchant_name: t.merchant_name,
                    pending: t.pending,
                  })
                  .eq("plaid_transaction_id", t.transaction_id);
              }
              totalModified += data.modified.length;
            }

            // Remove deleted transactions
            if (data.removed?.length) {
              const ids = data.removed.map(
                (t: { transaction_id: string }) => t.transaction_id
              );
              await supabase
                .from("bank_transactions")
                .delete()
                .in("plaid_transaction_id", ids);
              totalRemoved += data.removed.length;
            }

            hasMore = data.has_more;
            cursor = data.next_cursor;
          }

          // Save cursor for next sync
          await supabase
            .from("plaid_connections")
            .update({
              cursor: cursor,
              last_synced_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq("id", conn.id);
        }

        return new Response(
          JSON.stringify({
            success: true,
            added: totalAdded,
            modified: totalModified,
            removed: totalRemoved,
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // ── Generate MEC Quarterly Report ──
      case "generate_mec_report": {
        const { quarter } = params; // e.g. "2026-Q1"
        if (!quarter || !/^\d{4}-Q[1-4]$/.test(quarter)) {
          return new Response(
            JSON.stringify({ error: 'Invalid quarter format. Use "YYYY-Q1" through "YYYY-Q4".' }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
        const [year, q] = quarter.split("-");
        const qNum = parseInt(q.replace("Q", ""));
        const periodStart = `${year}-${String((qNum - 1) * 3 + 1).padStart(2, "0")}-01`;
        const periodEnd =
          qNum === 1
            ? `${year}-03-31`
            : qNum === 2
            ? `${year}-06-30`
            : qNum === 3
            ? `${year}-09-30`
            : `${year}-12-31`;
        const filingDeadline =
          qNum === 4
            ? `${parseInt(year) + 1}-01-15`
            : `${year}-${String(qNum * 3 + 1).padStart(2, "0")}-15`;

        // ── CD1_A: Contributions Received ──
        const { data: donations } = await supabase
          .from("donations")
          .select("*, donors(*)")
          .gte("donation_date", periodStart + "T00:00:00Z")
          .lte("donation_date", periodEnd + "T23:59:59Z")
          .eq("status", "completed")
          .order("donation_date");

        const cd1aRows: string[] = [];
        let totalContributions = 0;
        let monetaryTotal = 0;

        for (const d of donations ?? []) {
          const donor = d.donors;
          if (!donor) continue;
          const nameParts = (donor.name ?? "").split(" ");
          const firstName = nameParts[0] ?? "";
          const lastName = nameParts.slice(1).join(" ") ?? "";
          const amount = d.amount ?? 0;
          totalContributions += amount;
          monetaryTotal += amount;

          // CD1_A: Committee Name, Business, First, Last, Addr1, Addr2, City, State, Zip, Employer, Occupation, Date, Amount, Aggregate, Type, Election
          cd1aRows.push(
            [
              "", // Committee Name
              "", // Business Name
              `"${firstName}"`,
              `"${lastName}"`,
              `"${donor.address ?? ""}"`,
              "", // Address 2
              `"${donor.city ?? ""}"`,
              `"${donor.state ?? ""}"`,
              `"${donor.zip_code ?? ""}"`,
              `"${donor.employer ?? ""}"`,
              `"${donor.occupation ?? ""}"`,
              d.donation_date
                ? new Date(d.donation_date).toLocaleDateString("en-US")
                : "",
              amount.toFixed(2),
              amount.toFixed(2), // Aggregate (same for single donation)
              d.payment_method === "actblue" ? "M" : "M", // All monetary
              "G", // General election
            ].join(",")
          );
        }

        // ── CD3_B: Expenditures ──
        const { data: expenditures } = await supabase
          .from("bank_transactions")
          .select("*")
          .gte("date", periodStart)
          .lte("date", periodEnd + "T23:59:59Z")
          .eq("mec_included", true)
          .gt("amount", 0) // Positive = debits/expenses in Plaid
          .order("date");

        const cd3bRows: string[] = [];
        let totalExpenditures = 0;

        // Sum ALL expenditures for the total, but only ITEMIZE those over $100 in the CSV
        for (const t of expenditures ?? []) {
          const amount = Math.abs(t.amount);
          totalExpenditures += amount;
          if (amount < 100) continue; // MEC only requires itemization over $100

          cd3bRows.push(
            [
              `"${t.merchant_name ?? t.name ?? ""}"`, // Company Name
              "", // First Name
              "", // Last Name
              `"${t.mec_payee_address ?? ""}"`,
              "", // Address 2
              `"${t.mec_payee_city ?? ""}"`,
              `"${t.mec_payee_state ?? ""}"`,
              `"${t.mec_payee_zip ?? ""}"`,
              new Date(t.date).toLocaleDateString("en-US"),
              `"${t.mec_purpose ?? (t.category?.[0] ?? "Operating Expenses")}"`,
              "", // Aggregate (only for Campaign Worker)
              amount.toFixed(2),
              t.mec_expenditure_type ?? "P",
              t.mec_payment_type ?? "C",
            ].join(",")
          );
        }

        // Build CSV strings
        const cd1aHeader =
          "Committee Name,Business/Org Name,First Name,Last Name,Address 1,Address 2,City,State,Zip,Employer,Occupation,Date,Contribution Amount,Contribution Aggregate Amount,Contr Type,Election Type";
        const cd1aCsv = cd1aHeader + "\n" + cd1aRows.join("\n");

        const cd3bHeader =
          "Company Name,First Name,Last Name,Address 1,Address 2,City,State,Zip,Expnd Date,Expnd Purpose,Expenditure Aggregate Amount,Expenditure Amount,Expenditure Type,Payment Type";
        const cd3bCsv = cd3bHeader + "\n" + cd3bRows.join("\n");

        // Upload CSVs to Supabase storage
        const cd1aFile = `mec-reports/${quarter}-CD1A-contributions.csv`;
        const cd3bFile = `mec-reports/${quarter}-CD3B-expenditures.csv`;

        await supabase.storage
          .from("governing-documents")
          .upload(cd1aFile, new TextEncoder().encode(cd1aCsv), {
            contentType: "text/csv",
            upsert: true,
          });
        await supabase.storage
          .from("governing-documents")
          .upload(cd3bFile, new TextEncoder().encode(cd3bCsv), {
            contentType: "text/csv",
            upsert: true,
          });

        const cd1aUrl = supabase.storage
          .from("governing-documents")
          .getPublicUrl(cd1aFile).data.publicUrl;
        const cd3bUrl = supabase.storage
          .from("governing-documents")
          .getPublicUrl(cd3bFile).data.publicUrl;

        // Save report record
        await supabase.from("mec_reports").upsert(
          {
            quarter,
            period_start: periodStart,
            period_end: periodEnd,
            filing_deadline: filingDeadline,
            status: "ready",
            total_contributions: totalContributions,
            contribution_count: cd1aRows.length,
            monetary_contributions: monetaryTotal,
            inkind_contributions: 0,
            total_expenditures: totalExpenditures,
            expenditure_count: cd3bRows.length,
            cd1a_csv_url: cd1aUrl,
            cd3b_csv_url: cd3bUrl,
            generated_at: new Date().toISOString(),
            generated_by: "edge-function",
            updated_at: new Date().toISOString(),
          },
          { onConflict: "quarter" }
        );

        return new Response(
          JSON.stringify({
            success: true,
            quarter,
            contributions: {
              count: cd1aRows.length,
              total: totalContributions,
              csv_url: cd1aUrl,
            },
            expenditures: {
              count: cd3bRows.length,
              total: totalExpenditures,
              csv_url: cd3bUrl,
            },
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // ── Get Connection Status ──
      case "status": {
        const { data: connections } = await supabase
          .from("plaid_connections")
          .select("id, institution_name, account_names, status, last_synced_at")
          .eq("status", "active");

        const { data: reports } = await supabase
          .from("mec_reports")
          .select("*")
          .order("period_start", { ascending: false })
          .limit(4);

        return new Response(
          JSON.stringify({ connections, reports }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      default:
        return new Response(
          JSON.stringify({ error: `Unknown action: ${action}` }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
    }
  } catch (error: unknown) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
