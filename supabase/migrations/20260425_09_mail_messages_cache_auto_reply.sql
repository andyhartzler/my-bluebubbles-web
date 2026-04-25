-- =====================================================================
-- 20260425_09_mail_messages_cache_auto_reply.sql
-- Phase 6 follow-up: track when the mail-pubsub-receiver fired a
-- vacation auto-reply for a given inbound message. Used as the primary
-- idempotency guard so that history.list replays (after watermark
-- reset, retries, etc.) don't double-send.
-- =====================================================================

SET search_path = public, pg_temp;

ALTER TABLE public.mail_messages_cache
  ADD COLUMN IF NOT EXISTS auto_replied_at timestamptz;

-- Supports the "have we auto-replied to this (alias, sender) pair in
-- the last 24h?" rate-limit query in the receiver.
CREATE INDEX IF NOT EXISTS idx_mmc_alias_from_auto_replied
  ON public.mail_messages_cache (alias_email, from_addr, auto_replied_at DESC)
  WHERE auto_replied_at IS NOT NULL;
