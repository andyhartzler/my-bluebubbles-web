# Manual Test Plan

This document outlines manual QA coverage for the CRM-enabled BlueBubbles web experience. The focus areas were requested to ensure cache reliability, Gmail synchronization, reply handling, unread state accuracy, robust error handling, and confirmation that data persists in Supabase after the UI operations.

## Test Environment
- Latest development branch build of the web client.
- Supabase project configured with CRM tables and edge functions.
- Gmail integration enabled with valid OAuth credentials.
- Test member accounts with deterministic phone numbers (E.164 format) and email addresses.
- Clear browser cache between scenarios unless specified otherwise.

## 1. Cache Load Validation
1. Seed Supabase with at least one member and associated cached metadata.
2. Launch the web client, authenticate, and open the CRM members list.
3. Trigger a hard refresh (Ctrl/Cmd+Shift+R) to bypass the HTTP cache.
4. Observe that member data appears immediately from the local cache while network requests complete.
5. Confirm that stale data is replaced by fresh data without flashes or layout shifts.
6. Inspect DevTools Application → IndexedDB (or local storage) to ensure cached entries are updated with the latest timestamps.

### Expected Results
- Cached data renders before the network response, preventing blank states.
- Supabase response merges cleanly with cached entries.
- IndexedDB/local storage timestamps reflect the latest fetch.

## 2. Gmail Sync Flow
1. From the CRM dashboard, open the Gmail sync panel.
2. Trigger a manual sync; monitor network tab for Gmail API calls.
3. Verify that new emails matching member addresses populate the conversation timeline.
4. Confirm that thread metadata (labels, sync cursor) updates in the UI and persisted storage.
5. Disconnect and reconnect Gmail to confirm OAuth token refresh works.

### Expected Results
- Sync completes without errors, with a progress indicator visible.
- New Gmail messages appear in chronological order and show sender information.
- Reconnection maintains the previous sync cursor and avoids duplicate imports.

## 3. Reply Flow
1. Select a conversation linked to a CRM member.
2. Compose a reply using standard messaging controls.
3. Send the message; ensure delivery status transitions from sending → sent.
4. Reload the page and confirm the sent message persists and remains associated with the correct member.
5. Initiate a follow-up reply from the Gmail sync view to confirm cross-surface consistency.

### Expected Results
- Replies send successfully and respect rate-limiting settings.
- Reloading the UI shows the same conversation state without loss.
- Gmail-side replies mirror in the CRM thread with accurate timestamps.

## 4. Unread State Management
1. Mark an existing conversation as unread in the CRM panel.
2. Navigate away (e.g., to the bulk messaging screen) and return.
3. Confirm the unread badge persists until the conversation is opened.
4. Open the conversation to clear the unread badge.
5. Log out and log back in to verify the unread state is synchronized server-side.

### Expected Results
- Unread badges remain consistent across navigation.
- Opening a conversation clears the badge across all panels.
- Re-authentication preserves read/unread state.

## 5. Error Handling Scenarios
### 5.1 Network Loss During Cache Fetch
1. Disable the network in DevTools immediately after initiating the CRM members load.
2. Confirm the UI surfaces an inline warning and offers a retry action.
3. Re-enable the network and retry, ensuring the cache refresh completes.

### 5.2 Gmail Sync Failure
1. Revoke Gmail OAuth consent to force an authentication error.
2. Initiate a sync and verify the UI displays a descriptive error with a re-authenticate button.
3. Re-authorize Gmail and rerun the sync to confirm recovery.

### 5.3 Supabase Write Failure
1. Temporarily adjust Supabase Row Level Security to reject updates from the test user.
2. Attempt to update member notes in the CRM member panel.
3. Verify the UI reports the error, rolls back optimistic updates, and logs details to the console.
4. Restore RLS permissions and confirm the same operation succeeds.

## 6. Backend Verification & Persistence Checks
Perform these backend validations after each primary flow to ensure Supabase reflects UI changes:

1. **Supabase SQL Editor**
   - Run `select * from members where phone_e164 = '+15555550123';` (replace with test handle) to confirm profile updates (notes, unread flags, last_contacted) persist.
   - Query the `member_messages` table for new rows tied to the conversation GUID to ensure replies are recorded.

2. **Edge Function Logs**
   - Use `supabase functions logs --name crm-sync --since 10m` to confirm edge function invocations for Gmail sync and error handling paths.
   - Review log payloads for `status: success` entries and absence of retry storms.

3. **Storage Buckets** (if attachments are involved)
   - Check Supabase Storage for new attachments uploaded during replies.

4. **Audit Trail**
   - Verify that Supabase audit tables (or triggers) captured the state transitions for unread/read toggles and note edits.

Document the query outputs and log excerpts in the QA evidence repository for traceability.

## 7. UI Regression Evidence
- Current contribution guidelines do **not** mandate screenshot capture. If this policy changes, capture before/after images of the CRM members list, Gmail sync panel, and conversation view after each major regression test and store them under `screenshots/manual-tests/` with descriptive filenames.

## Reporting
Record each scenario, result, and backend verification artifact in the shared QA runbook or test management tool. Include:
- Tester name and date/time
- Scenario ID
- Pass/Fail with defect references
- Links to Supabase query results, logs, and (if applicable) screenshots

