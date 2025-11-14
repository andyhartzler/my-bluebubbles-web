-- Ensure Gmail-specific metadata columns exist for the email_inbox table.
alter table if exists public.email_inbox
    add column if not exists gmail_message_id text;

alter table if exists public.email_inbox
    add column if not exists gmail_thread_id text;

alter table if exists public.email_inbox
    add column if not exists history_id text;

alter table if exists public.email_inbox
    add column if not exists from_address text;

alter table if exists public.email_inbox
    add column if not exists to_address text[];

alter table if exists public.email_inbox
    add column if not exists cc_address text[];

alter table if exists public.email_inbox
    add column if not exists bcc_address text[];

alter table if exists public.email_inbox
    add column if not exists label_ids text[];

alter table if exists public.email_inbox
    add column if not exists in_reply_to text;

alter table if exists public.email_inbox
    add column if not exists date timestamptz;

alter table if exists public.email_inbox
    add column if not exists synced_at timestamptz default timezone('utc', now());

-- Backfill new columns using existing data where possible.
update public.email_inbox
set
    gmail_message_id = coalesce(gmail_message_id, message_id),
    gmail_thread_id = coalesce(gmail_thread_id, thread_id),
    from_address = coalesce(from_address, from_email),
    to_address = coalesce(to_address, to_emails),
    cc_address = coalesce(cc_address, cc_emails),
    bcc_address = coalesce(bcc_address, bcc_emails),
    in_reply_to = coalesce(in_reply_to, in_reply_to_header),
    date = coalesce(date, received_at, sent_at),
    synced_at = coalesce(synced_at, updated_at)
where
    gmail_message_id is null
    or gmail_thread_id is null
    or from_address is null
    or to_address is null
    or cc_address is null
    or bcc_address is null
    or in_reply_to is null
    or date is null
    or synced_at is null;

-- Ensure Gmail identifiers are indexed for fast lookups and upserts.
create unique index if not exists email_inbox_member_gmail_message_key
    on public.email_inbox (member_id, gmail_message_id);

create index if not exists email_inbox_gmail_thread_id_idx
    on public.email_inbox (gmail_thread_id);
