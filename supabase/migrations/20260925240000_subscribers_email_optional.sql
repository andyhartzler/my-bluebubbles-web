-- Phone- and mail-only contacts are subscribers too (donor imports often have
-- no email). Email stays unique when present; every row must still carry at
-- least one way to reach the person. sync-to-mautic already skips rows with no
-- email, so these never create empty Mautic contacts.
alter table public.subscribers alter column email drop not null;
alter table public.subscribers add constraint subscribers_has_contact
  check (email is not null or phone is not null or address is not null);
