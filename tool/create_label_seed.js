// One-shot: ensure user-defined Gmail labels "Answered" and "Forwarded"
// exist on crm@moyoungdemocrats.org and print their IDs.
//
// Idempotent: if a label already exists, its existing ID is reused.
// Run from a directory where googleapis is installed, e.g.:
//   cd /tmp/mail-verify && node /Users/moyd/my-bluebubbles-web/tool/create_label_seed.js
//
// The IDs printed are then stored as Supabase secrets:
//   GMAIL_LABEL_ANSWERED_ID, GMAIL_LABEL_FORWARDED_ID
const { google } = require("googleapis");
const sa = require("/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json");

const SUBJECT = "crm@moyoungdemocrats.org";
const TARGET_NAMES = ["Answered", "Forwarded"];

const auth = new google.auth.JWT({
  email: sa.client_email,
  key: sa.private_key,
  scopes: ["https://www.googleapis.com/auth/gmail.labels"],
  subject: SUBJECT,
});
const gmail = google.gmail({ version: "v1", auth });

(async () => {
  const list = await gmail.users.labels.list({ userId: "me" });
  const existing = new Map(
    (list.data.labels || []).map((l) => [l.name, l.id]),
  );

  const ids = {};
  for (const name of TARGET_NAMES) {
    if (existing.has(name)) {
      ids[name] = existing.get(name);
      console.error(`[skip] ${name} already exists -> ${ids[name]}`);
      continue;
    }
    const created = await gmail.users.labels.create({
      userId: "me",
      requestBody: {
        name,
        labelListVisibility: "labelHide",
        messageListVisibility: "show",
      },
    });
    ids[name] = created.data.id;
    console.error(`[create] ${name} -> ${ids[name]}`);
  }

  // Print final IDs to stdout in shell-friendly form.
  console.log(`GMAIL_LABEL_ANSWERED_ID=${ids.Answered}`);
  console.log(`GMAIL_LABEL_FORWARDED_ID=${ids.Forwarded}`);
})().catch((err) => {
  console.error("FAILED:", err.errors || err.message || err);
  process.exit(1);
});
