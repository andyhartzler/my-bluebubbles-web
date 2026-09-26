-- Subscriber imports carry an occupation alongside employer. Keep it as its own
-- column so it reaches Mautic's position field via sync-to-mautic.
alter table public.subscribers add column if not exists occupation text;
