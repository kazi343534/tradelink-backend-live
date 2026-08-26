-- Migration 012: Real-time negotiation chat
-- 1. Chat history per negotiation thread
CREATE TABLE IF NOT EXISTS public.negotiation_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    negotiation_id  UUID NOT NULL REFERENCES public.negotiations(id) ON DELETE CASCADE,
    sender_type     TEXT NOT NULL CHECK (sender_type IN ('SHOP_OWNER', 'SUPPLIER')),
    sender_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL CHECK (length(trim(message)) > 0),
    offered_price   NUMERIC(12,2) CHECK (offered_price IS NULL OR offered_price > 0),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_negotiation_messages_thread
ON public.negotiation_messages(negotiation_id, created_at);

-- 2. Spec-aligned name for the live offer on the negotiation row
ALTER TABLE public.negotiations
RENAME COLUMN proposed_price TO current_proposed_price;

ALTER TABLE public.negotiations
ADD COLUMN IF NOT EXISTS accepted_by UUID REFERENCES public.users(id);
