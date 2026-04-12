# Plaid Integration + MEC Quarterly Report Generator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Finances page in the CRM that connects to UMB Bank via Plaid, syncs transactions, and auto-generates MEC quarterly campaign finance reports (CD1_A contributions CSV + CD3_B expenditures CSV).

**Architecture:** Supabase Edge Function handles all Plaid API communication (secrets stay server-side). Flutter CRM gets a new Finances page under the Donors section with: Plaid Link button, bank account overview, transaction list, and MEC report generator. Access tokens are permanent and stored in `plaid_connections` table.

**Tech Stack:** Plaid API (production), Supabase Edge Functions (Deno), Supabase Storage (CSV files), Flutter web CRM

---

## Plaid Configuration

**Plaid Dashboard Settings:**
- Client ID: `69b6acecb236c9000d2afc21`
- Environment: Production
- Redirect URI: `https://moyd.app/plaid/callback`

**Supabase Edge Function Secrets:**
- `PLAID_CLIENT_ID` = `69b6acecb236c9000d2afc21`
- `PLAID_SECRET` = `0a32a69d8d71c0e390b886ebca4e98`
- `PLAID_ENV` = `production`

---

## Database Schema (ALREADY CREATED)

### `plaid_connections`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| institution_id | text | Plaid institution ID |
| institution_name | text | "UMB Bank" |
| item_id | text UNIQUE | Plaid item identifier |
| access_token | text | Permanent, never expires |
| account_ids | text[] | Array of linked account IDs |
| account_names | text[] | Human-readable names |
| status | text | active / needs_update / revoked |
| cursor | text | For transaction sync pagination |
| last_synced_at | timestamptz | Last successful sync |

### `bank_transactions`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| plaid_transaction_id | text UNIQUE | Plaid's transaction ID |
| plaid_connection_id | uuid FK | Links to plaid_connections |
| amount | numeric(12,2) | Positive=expense, negative=income |
| date | date | Transaction date |
| name | text | Merchant/payee |
| merchant_name | text | Clean merchant name |
| category | text[] | Plaid category hierarchy |
| mec_purpose | text | User-editable for MEC report |
| mec_included | boolean | Whether to include in MEC report |
| mec_payment_type | text | M/C/R for MEC |

### `mec_reports`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| quarter | text | "2026-Q1" |
| period_start/end | date | Quarter boundaries |
| filing_deadline | date | 15th of following month |
| status | text | draft / ready / filed |
| total_contributions | numeric | Sum from donations |
| total_expenditures | numeric | Sum from bank_transactions |
| cd1a_csv_url | text | Download link for contributions CSV |
| cd3b_csv_url | text | Download link for expenditures CSV |

---

## Edge Function (ALREADY CREATED)

`supabase/functions/plaid/index.ts` handles 5 actions:
1. `create_link_token` — starts Plaid Link
2. `exchange_token` — stores permanent access token
3. `sync_transactions` — pulls all new transactions from UMB
4. `generate_mec_report` — builds CD1_A + CD3_B CSVs
5. `status` — returns connection + report status

---

## Tasks

### Task 1: Deploy Edge Function + Set Secrets

- [ ] **Step 1: Set Plaid secrets in Supabase Dashboard**

Go to Supabase Dashboard → Edge Functions → Secrets and add:
```
PLAID_CLIENT_ID=69b6acecb236c9000d2afc21
PLAID_SECRET=0a32a69d8d71c0e390b886ebca4e98
PLAID_ENV=production
```

- [ ] **Step 2: Deploy the edge function**

```bash
cd /Users/moyd/my-bluebubbles-web
npx supabase functions deploy plaid --project-ref faajpcarasilbfndzkmd
```

- [ ] **Step 3: Test status endpoint**

```bash
curl -X POST https://faajpcarasilbfndzkmd.supabase.co/functions/v1/plaid \
  -H "Authorization: Bearer <anon_key>" \
  -H "Content-Type: application/json" \
  -d '{"action":"status"}'
```

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/plaid/
git commit -m "feat: Plaid Edge Function — link, exchange, sync, MEC report"
```

---

### Task 2: Build Flutter Finances Page

**Files:**
- Create: `lib/screens/crm/finances_page.dart`
- Modify: `lib/main.dart` (add to nav)

- [ ] **Step 1: Create FinancesPage widget**

The page has 3 sections:
1. **Bank Connection** — shows Plaid connection status, "Connect Bank" button
2. **Recent Transactions** — list of bank transactions from `bank_transactions` table
3. **MEC Reports** — list of generated reports with download buttons + "Generate Report" action

```dart
class FinancesPage extends StatefulWidget { ... }

class _FinancesPageState extends State<FinancesPage> {
  // Calls Edge Function for status, sync, and report generation
  // Uses Supabase client for direct table reads (transactions, reports)
}
```

Key features:
- "Connect UMB Bank" button opens Plaid Link (via plaid_flutter package or webview)
- "Sync Transactions" button calls edge function
- Transaction list with date, merchant, amount, category
- Each transaction has editable "MEC Purpose" field and "Include in Report" toggle
- "Generate Q1 2026 Report" button calls edge function, shows download links
- Report cards show: quarter, contribution count/total, expenditure count/total, CSV download buttons

- [ ] **Step 2: Add plaid_flutter to pubspec.yaml**

```yaml
dependencies:
  plaid_flutter: ^3.1.0
```

For web: Plaid Link opens via JavaScript — plaid_flutter handles this automatically.

- [ ] **Step 3: Add Finances to Donors page navigation**

In the Donors section, add a tab or button that links to the Finances page. Or add it as a new `_HomeSection.finances` entry.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat: Finances page — Plaid Link + transactions + MEC reports"
```

---

### Task 3: Plaid Link Flow (Connect Bank)

- [ ] **Step 1: Implement Plaid Link initialization**

1. Call edge function with `action: "create_link_token"` and `redirect_uri: "https://moyd.app/plaid/callback"`
2. Open Plaid Link with the returned `link_token`
3. On success, call edge function with `action: "exchange_token"` and the `public_token`
4. Show success message, refresh connection status

- [ ] **Step 2: Handle Plaid Link callback**

For web: Plaid Link redirects back to `https://moyd.app/plaid/callback` with OAuth state. The app needs to detect this URL and resume the Link flow.

- [ ] **Step 3: Auto-sync after connection**

After successful connection, immediately call `sync_transactions` to pull initial transaction history.

- [ ] **Step 4: Commit**

---

### Task 4: Transaction Management UI

- [ ] **Step 1: Transaction list view**

Show bank_transactions in a scrollable list:
- Date | Merchant | Amount | Category
- Color code: red for expenses, green for income
- Toggle: "Include in MEC Report" checkbox
- Editable: "MEC Purpose" dropdown or text field

- [ ] **Step 2: Bulk categorization**

Allow selecting multiple transactions and setting MEC purpose in bulk (e.g., "Office Supplies", "Travel", "Printing").

- [ ] **Step 3: Commit**

---

### Task 5: MEC Report Generator UI

- [ ] **Step 1: Quarter selector**

Dropdown to pick quarter (auto-detects current quarter). Shows:
- Period: Jan 1 - Mar 31, 2026
- Filing deadline: April 15, 2026
- Status: Draft / Ready / Filed

- [ ] **Step 2: Preview before generating**

Show counts: "X contributions from Y donors ($Z total)" and "X expenditures ($Z total)"

- [ ] **Step 3: Generate button**

Calls edge function `generate_mec_report` with selected quarter. Shows progress, then download links for CSV files.

- [ ] **Step 4: Download buttons**

Two buttons: "Download CD1_A (Contributions)" and "Download CD3_B (Expenditures)". Opens the CSV URLs from Supabase storage.

- [ ] **Step 5: Mark as Filed**

After uploading to MEC, user clicks "Mark as Filed" to update status.

- [ ] **Step 6: Commit**

---

### Task 6: Auto-Sync Scheduling

- [ ] **Step 1: pg_cron job for daily transaction sync**

```sql
SELECT cron.schedule('plaid-daily-sync', '0 6 * * *',
  $$SELECT net.http_post(
    'https://faajpcarasilbfndzkmd.supabase.co/functions/v1/plaid',
    '{"action":"sync_transactions"}',
    '{"Content-Type":"application/json","Authorization":"Bearer <service_role_key>"}'
  )$$
);
```

- [ ] **Step 2: Commit**

---

## MEC Report Field Mapping

### CD1_A (Contributions) — from `donations` + `donors` tables

| MEC Field | Source |
|---|---|
| First Name | donors.name (split) |
| Last Name | donors.name (split) |
| Address 1 | donors.address |
| City | donors.city |
| State | donors.state |
| Zip | donors.zip_code |
| Employer | donors.employer |
| Occupation | donors.occupation |
| Date | donations.donation_date |
| Amount | donations.amount |
| Type | "M" (all monetary from ActBlue) |
| Election Type | "G" (general) |

### CD3_B (Expenditures) — from `bank_transactions` table

| MEC Field | Source |
|---|---|
| Company Name | bank_transactions.merchant_name |
| Date | bank_transactions.date |
| Purpose | bank_transactions.mec_purpose (user-edited) |
| Amount | bank_transactions.amount |
| Type | bank_transactions.mec_expenditure_type ("P") |
| Payment Type | bank_transactions.mec_payment_type ("C" for debit) |

---

## Execution Notes

- Plaid access tokens are PERMANENT — store once, use forever
- The Edge Function handles ALL Plaid API calls (secrets never client-side)
- Transaction sync uses Plaid's cursor-based sync API (efficient, incremental)
- MEC reports are CSV files stored in Supabase storage (public download links)
- The `mec_included` flag on bank_transactions lets users exclude non-campaign expenses
- The `mec_purpose` field lets users categorize expenses for MEC reporting
- Only expenditures over $100 need to be itemized (per MEC rules)
