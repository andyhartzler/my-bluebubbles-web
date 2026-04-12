-- =====================================================
-- MOYD Receipt Management System
-- Stores email receipts with AI-extracted metadata,
-- matches to bank transactions for MEC reporting.
-- =====================================================

-- 1. Receipts table
CREATE TABLE IF NOT EXISTS public.receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Email source
  email_message_id TEXT UNIQUE,
  email_from TEXT,
  email_to TEXT,
  email_subject TEXT,
  email_date TIMESTAMPTZ,
  email_account TEXT,  -- 'andrew' or 'info'

  -- AI-extracted fields
  vendor_name TEXT,
  amount NUMERIC,
  category TEXT,
  description TEXT,

  -- PDF storage
  storage_path TEXT,  -- path in Supabase storage bucket
  storage_url TEXT,   -- signed URL
  pdf_source TEXT DEFAULT 'email',  -- 'email' (converted) or 'attachment'
  original_filename TEXT,

  -- Transaction matching
  transaction_id TEXT,  -- FK to bank_transactions.id when matched
  match_status TEXT DEFAULT 'unmatched',  -- 'unmatched', 'matched', 'inkind', 'ignored'
  match_confidence NUMERIC,

  -- MEC report fields
  mec_included BOOLEAN DEFAULT TRUE,
  mec_purpose TEXT,

  -- Metadata
  processed_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_receipts_email_date ON public.receipts(email_date DESC);
CREATE INDEX IF NOT EXISTS idx_receipts_vendor ON public.receipts(vendor_name);
CREATE INDEX IF NOT EXISTS idx_receipts_amount ON public.receipts(amount);
CREATE INDEX IF NOT EXISTS idx_receipts_match_status ON public.receipts(match_status);
CREATE INDEX IF NOT EXISTS idx_receipts_transaction ON public.receipts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_category ON public.receipts(category);
CREATE INDEX IF NOT EXISTS idx_receipts_email_msg_id ON public.receipts(email_message_id);

-- 3. Storage bucket (run separately or via Supabase dashboard)
-- INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', false) ON CONFLICT DO NOTHING;

-- 4. Notify PostgREST
NOTIFY pgrst, 'reload schema';
