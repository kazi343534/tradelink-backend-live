-- Migration 011: Price negotiation / bargaining system
-- Bargain conversations live here until both sides finalize; only an
-- accepted counter-offer is converted into a real order.

CREATE TABLE IF NOT EXISTS public.negotiations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_owner_id   UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    stockholder_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    stock_id        UUID NOT NULL REFERENCES public.stockholder_inventory(id) ON DELETE CASCADE,
    product_name    TEXT   NOT NULL,
    quantity        NUMERIC(12,2) NOT NULL CHECK (quantity > 0),
    original_price  NUMERIC(12,2) NOT NULL,
    proposed_price  NUMERIC(12,2) NOT NULL CHECK (proposed_price > 0),
    last_offered_by TEXT NOT NULL DEFAULT 'shop_owner'
                    CHECK (last_offered_by IN ('shop_owner', 'supplier')),
    status          TEXT NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'COUNTERED', 'ACCEPTED', 'REJECTED', 'ORDER_CREATED')),
    message         TEXT,
    counter_message TEXT,
    order_id        UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_negotiations_shop_owner
ON public.negotiations(shop_owner_id, status);

CREATE INDEX IF NOT EXISTS idx_negotiations_supplier
ON public.negotiations(stockholder_id, status);
