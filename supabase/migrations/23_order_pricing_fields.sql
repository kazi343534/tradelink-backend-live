-- Migration 013: Standard-order fields so negotiation-created orders
-- carry full pricing metadata and integrate cleanly with the lifecycle.

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS unit_price NUMERIC(12,2),
ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'unpaid';

-- Backfill unit_price where derivable
UPDATE public.orders
SET unit_price = ROUND((total_amount / NULLIF(quantity, 0))::numeric, 2)
WHERE unit_price IS NULL;
