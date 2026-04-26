-- =====================================================================
-- 20260426_01_mailbox_kind.sql
--
-- §13 of Systems/CRM-Mail-Client.md — extend the mail client to support
-- self-owned mailboxes (Andrew, Dustin, Landon) alongside the existing
-- shared-alias model (15 execs sharing crm@moyoungdemocrats.org).
--
-- Two changes:
--   1. mail_aliases.mailbox_kind — discriminates 'shared_alias' (current
--      behavior, subject=crm@, q-clamp + post-filter required) from
--      'self_owned' (subject=their own mailbox, no clamp, no filter).
--   2. mail_pubsub_state goes from singleton(id=1) to per-mailbox keyed
--      on mailbox_email. Each row owns a Gmail users.watch + history
--      watermark for one mailbox. Existing crm@ row backfills as
--      mailbox_email='crm@moyoungdemocrats.org'.
-- =====================================================================

SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------
-- 1. mail_aliases.mailbox_kind
-- ---------------------------------------------------------------------
ALTER TABLE public.mail_aliases
  ADD COLUMN IF NOT EXISTS mailbox_kind text NOT NULL DEFAULT 'shared_alias'
  CHECK (mailbox_kind IN ('shared_alias','self_owned'));

-- Backfill existing rows explicitly so the value is intentional, not
-- inherited from the column default.
UPDATE public.mail_aliases
   SET mailbox_kind = 'shared_alias'
 WHERE mailbox_kind IS NULL;

CREATE INDEX IF NOT EXISTS idx_mail_aliases_kind
  ON public.mail_aliases (mailbox_kind);

-- ---------------------------------------------------------------------
-- 2. mail_pubsub_state — singleton → per-mailbox
-- ---------------------------------------------------------------------
-- New PK is mailbox_email (citext). The legacy `id` column / singleton
-- CHECK / default(1) all go away. Existing crm@ row gets backfilled to
-- mailbox_email='crm@moyoungdemocrats.org'. Code is updated to address
-- rows by mailbox_email instead of id=1.

ALTER TABLE public.mail_pubsub_state
  ADD COLUMN IF NOT EXISTS mailbox_email citext;

UPDATE public.mail_pubsub_state
   SET mailbox_email = 'crm@moyoungdemocrats.org'::citext
 WHERE mailbox_email IS NULL;

ALTER TABLE public.mail_pubsub_state
  ALTER COLUMN mailbox_email SET NOT NULL;

-- Drop legacy id-related artifacts:
--   * singleton CHECK (id = 1) — generated name, drop dynamically
--   * default of 1 on id
--   * id column itself (becomes redundant once mailbox_email is PK)
-- Then promote mailbox_email to PRIMARY KEY.
DO $$
DECLARE
  c_name text;
BEGIN
  -- Drop the singleton CHECK if present.
  FOR c_name IN
    SELECT c.conname
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
     WHERE t.relname = 'mail_pubsub_state'
       AND c.contype = 'c'
       AND pg_get_constraintdef(c.oid) ILIKE '%id = 1%'
  LOOP
    EXECUTE format('ALTER TABLE public.mail_pubsub_state DROP CONSTRAINT %I', c_name);
  END LOOP;

  -- Drop the existing PK on id (named mail_pubsub_state_pkey by default).
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.mail_pubsub_state'::regclass
      AND contype = 'p'
  ) THEN
    SELECT conname INTO c_name
      FROM pg_constraint
     WHERE conrelid = 'public.mail_pubsub_state'::regclass
       AND contype = 'p';
    EXECUTE format('ALTER TABLE public.mail_pubsub_state DROP CONSTRAINT %I', c_name);
  END IF;
END $$;

-- Drop the id column — no callers will reference it after this migration.
ALTER TABLE public.mail_pubsub_state
  DROP COLUMN IF EXISTS id;

-- mailbox_email becomes the primary key.
ALTER TABLE public.mail_pubsub_state
  ADD CONSTRAINT mail_pubsub_state_pkey PRIMARY KEY (mailbox_email);

-- =====================================================================
-- End migration.
-- =====================================================================
