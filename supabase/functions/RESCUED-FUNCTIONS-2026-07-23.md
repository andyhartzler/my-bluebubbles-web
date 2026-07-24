# Source-less deployed functions rescued 2026-07-23

Audit finding D2: 58 edge functions were DEPLOYED to Supabase project
faajpcarasilbfndzkmd but had no source in any repo — one accidental
`functions delete` or project migration would have lost them permanently.
Each directory here is the DEPLOYED source, pulled via
`supabase functions download <slug>` (58/58 succeeded). Source recovery
only — nothing was redeployed.

Some are web/member/forms-intake functions (process-chartering-submission,
process-member-signup, process-member-info-update, verify-member-for-vote,
generate-ag-email*) that logically belong to the master web repo; they were
placed here because this is the canonical backend repo for the shared
Supabase project. Relocate later if desired.

Known-dead among these (audit flagged for deletion AFTER this rescue):
fetch-member-photos (500, dead Google OAuth), send-campaign +
process-campaign-segment + track-email-open + track-link-click +
sync-to-listmonk + listmonk-subscribe (retired email stack, MOYD on Mautic),
zapier-webhook (Zapier retired), hs-chapters-supabase- (trailing-dash typo),
chapter-members-supabase (source-less duplicate). Delete decisions pending.
