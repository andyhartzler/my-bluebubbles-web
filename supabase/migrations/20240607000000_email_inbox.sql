-- Enable required extensions
create extension if not exists "pgcrypto";

-- Email inbox table stores inbound and outbound email metadata and content.
create table if not exists public.email_inbox (
    id uuid primary key default gen_random_uuid(),
    member_id uuid not null,
    message_id text not null,
    thread_id text,
    subject text,
    from_email text,
    to_emails text[],
    cc_emails text[],
    bcc_emails text[],
    snippet text,
    body_text text,
    body_html text,
    direction text not null default 'inbound' check (direction in ('inbound', 'outbound')),
    message_state text not null default 'received',
    received_at timestamptz not null default timezone('utc', now()),
    sent_at timestamptz,
    references_header text,
    in_reply_to_header text,
    reply_to_email text,
    headers jsonb default '{}'::jsonb,
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now()),
    unique (member_id, message_id)
);

-- Maintain referential integrity with members.
do $$
begin
    alter table public.email_inbox
        add constraint email_inbox_member_id_fkey
            foreign key (member_id)
            references public.members (id)
            on delete cascade;
exception
    when duplicate_object then null;
end
$$;

-- Indexes for efficient lookups.
create index if not exists email_inbox_member_id_received_at_idx
    on public.email_inbox (member_id, received_at desc);

create index if not exists email_inbox_message_id_idx
    on public.email_inbox (message_id);

create index if not exists email_inbox_thread_id_idx
    on public.email_inbox (thread_id);

-- Use trigger to maintain the updated_at column.
create or replace function public.set_email_inbox_updated_at()
returns trigger as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$ language plpgsql;

drop trigger if exists set_email_inbox_updated_at on public.email_inbox;

create trigger set_email_inbox_updated_at
    before update on public.email_inbox
    for each row
    execute function public.set_email_inbox_updated_at();

-- Surface a convenient view joining member context with email history.
drop view if exists public.member_email_history;

create view public.member_email_history as
select
    m.id as member_id,
    m.name as member_name,
    m.email as member_email,
    e.id as email_id,
    e.message_id,
    e.thread_id,
    e.subject,
    e.direction,
    e.message_state,
    e.from_email,
    e.to_emails,
    e.cc_emails,
    e.bcc_emails,
    e.reply_to_email,
    e.received_at,
    e.sent_at,
    e.snippet,
    e.body_text,
    e.body_html,
    e.references_header,
    e.in_reply_to_header,
    e.headers,
    e.metadata,
    e.created_at,
    e.updated_at
from public.email_inbox e
join public.members m on m.id = e.member_id;

-- Verification queries executed in Supabase SQL editor:
-- 1. \d+ public.email_inbox;
-- 2. select * from public.email_inbox limit 5;
-- 3. select * from public.member_email_history order by received_at desc limit 5;
-- 4. explain analyze select * from public.email_inbox where member_id = '<member uuid>' order by received_at desc limit 20;
