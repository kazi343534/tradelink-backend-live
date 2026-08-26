-- Migration 008: Track which inventory item each order fulfils,
-- so delivered quantity can be deducted from stock at OTP verification.

-- 1. Add inventory_id to orders
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS inventory_id UUID REFERENCES public.stockholder_inventory(id) ON DELETE SET NULL;

-- 2. Backfill existing orders by matching product_name + supplier
UPDATE public.orders o
SET inventory_id = matched.id
FROM (
    SELECT DISTINCT ON (o2.id) o2.id AS order_id, si.id
    FROM public.orders o2
    JOIN public.stockholder_inventory si
      ON si.stockholder_id = o2.supplier_id
     AND LOWER(si.custom_product_name) = LOWER(o2.product_name)
    WHERE o2.inventory_id IS NULL
    ORDER BY o2.id, si.created_at DESC
) matched
WHERE o.id = matched.order_id;
