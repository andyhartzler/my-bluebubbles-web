/**
 * MOYD Receipt Poller — Google Apps Script
 *
 * Polls Gmail for receipt emails and sends them to the Supabase Edge Function
 * for AI analysis, PDF storage, and database logging.
 *
 * SETUP:
 * 1. Open https://script.google.com and create a new project
 * 2. Paste this entire file
 * 3. Run setup() once to initialize
 * 4. The script will automatically poll every 15 minutes
 *
 * The script searches for receipt-like emails in the last 24 hours,
 * skips any already processed (tracked via Script Properties),
 * and sends each new receipt to the Supabase receipts Edge Function.
 */

const SUPABASE_URL = 'https://faajpcarasilbfndzkmd.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyMTcxOTksImV4cCI6MjA3NTc5MzE5OX0.your-anon-key-here';
// Use service role key for Edge Function calls (bypasses JWT verification)
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhYWpwY2FyYXNpbGJmbmR6a21kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDIxNzE5OSwiZXhwIjoyMDc1NzkzMTk5fQ.aNG79mrHw8P1TjJ6uYqP0ceSK65DOjaVUMt-MazXnWU';

// Gmail search query — same as the Zapier Receipts Logger
const GMAIL_SEARCH = [
  'subject:(receipt OR invoice OR "payment confirmation" OR "order confirmation"',
  'OR "billing statement" OR "payment received" OR "transaction" OR subscription)',
  'OR from:(paypal OR stripe OR square OR venmo OR "apple.com" OR "google.com"',
  'OR actblue OR "meta.com" OR facebook OR mailchimp OR zapier OR canva',
  'OR zoom OR linktree OR weglot OR uber OR lyft)',
  'newer_than:1d',
  '-label:receipts-processed'
].join(' ');

/**
 * Main polling function — called by time-based trigger every 15 minutes
 */
function pollForReceipts() {
  const threads = GmailApp.search(GMAIL_SEARCH, 0, 20);
  const props = PropertiesService.getScriptProperties();
  let processed = 0;
  let skipped = 0;

  for (const thread of threads) {
    const messages = thread.getMessages();

    for (const message of messages) {
      const messageId = message.getId();

      // Skip if already processed
      if (props.getProperty('processed_' + messageId)) {
        skipped++;
        continue;
      }

      try {
        const result = processMessage(message);
        if (result.success || result.skipped) {
          // Mark as processed
          props.setProperty('processed_' + messageId, new Date().toISOString());
          processed++;

          // Add label so we don't re-search
          let label = GmailApp.getUserLabelByName('receipts-processed');
          if (!label) label = GmailApp.createLabel('receipts-processed');
          thread.addLabel(label);
        }
      } catch (e) {
        console.error('Error processing message ' + messageId + ': ' + e.message);
      }
    }
  }

  if (processed > 0) {
    console.log('Processed ' + processed + ' new receipts, skipped ' + skipped);
  }
}

/**
 * Process a single Gmail message — extract data and send to Edge Function
 */
function processMessage(message) {
  const messageId = message.getId();
  const from = message.getFrom();
  const to = message.getTo();
  const subject = message.getSubject();
  const date = message.getDate().toISOString();
  const bodyHtml = message.getBody();
  const bodyText = message.getPlainBody();

  // Determine account
  const account = to.includes('andrew@') ? 'andrew' :
                   to.includes('info@') ? 'info' : 'other';

  // Get attachments (PDFs and images)
  const attachments = [];
  for (const att of message.getAttachments()) {
    const contentType = att.getContentType();
    if (contentType.includes('pdf') || contentType.includes('image')) {
      attachments.push({
        filename: att.getName(),
        content_type: contentType,
        data: Utilities.base64Encode(att.getBytes()),
      });
    }
  }

  // Send to Supabase Edge Function
  const payload = {
    action: 'process_receipt',
    message_id: messageId,
    from: from,
    to: to,
    subject: subject,
    date: date,
    body_html: bodyHtml ? bodyHtml.substring(0, 50000) : '',  // Limit size
    body_text: bodyText ? bodyText.substring(0, 10000) : '',
    attachments: attachments.slice(0, 1),  // First attachment only
    account: account,
  };

  const response = UrlFetchApp.fetch(
    SUPABASE_URL + '/functions/v1/receipts',
    {
      method: 'POST',
      contentType: 'application/json',
      headers: {
        'Authorization': 'Bearer ' + SUPABASE_SERVICE_KEY,
      },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true,
    }
  );

  const status = response.getResponseCode();
  const body = JSON.parse(response.getContentText());

  if (status >= 200 && status < 300) {
    return body;
  } else {
    throw new Error('Edge Function returned ' + status + ': ' + JSON.stringify(body));
  }
}

/**
 * One-time setup — creates the time-based trigger
 * Run this function manually once after pasting the script.
 */
function setup() {
  // Remove any existing triggers
  const triggers = ScriptApp.getProjectTriggers();
  for (const t of triggers) {
    if (t.getHandlerFunction() === 'pollForReceipts') {
      ScriptApp.deleteTrigger(t);
    }
  }

  // Create 15-minute trigger
  ScriptApp.newTrigger('pollForReceipts')
    .timeBased()
    .everyMinutes(15)
    .create();

  // Create the Gmail label
  let label = GmailApp.getUserLabelByName('receipts-processed');
  if (!label) {
    GmailApp.createLabel('receipts-processed');
  }

  console.log('Setup complete! The script will poll for receipts every 15 minutes.');
  console.log('Running initial poll now...');
  pollForReceipts();
}

/**
 * Cleanup — removes old processed markers (older than 30 days)
 * Run monthly or as needed.
 */
function cleanupOldMarkers() {
  const props = PropertiesService.getScriptProperties();
  const all = props.getProperties();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 30);

  let removed = 0;
  for (const [key, value] of Object.entries(all)) {
    if (key.startsWith('processed_')) {
      const processedDate = new Date(value);
      if (processedDate < cutoff) {
        props.deleteProperty(key);
        removed++;
      }
    }
  }
  console.log('Removed ' + removed + ' old markers');
}
