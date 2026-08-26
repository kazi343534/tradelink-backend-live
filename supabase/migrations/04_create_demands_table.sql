-- Migration: 04_create_demands_table.sql
-- Description: Demands posted by Shop Owners to request products from nearby Suppliers

DO $$ BEGIN
    CREATE TYPE demand_status AS ENUM ('pending', 'accepted', 'delivered', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.demands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Grocery',
    quantity NUMERIC(10, 2) NOT NULL,
    unit TEXT NOT NULL DEFAULT 'kg',
    notes TEXT,
    status demand_status NOT NULL DEFAULT 'pending',
    
    -- When a supplier accepts the demand
    accepted_supplier_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.demands ENABLE ROW LEVEL SECURITY;

-- Allow reading demands (Shop Owners can view their demands, Suppliers can view all active demands)
CREATE POLICY "Allow public select on demands"
ON public.demands FOR SELECT
USING (true);

-- Allow Shop Owners to insert demands
CREATE POLICY "Allow insert demands"
ON public.demands FOR INSERT
WITH CHECK (true);

-- Allow updating demands (status changes)
CREATE POLICY "Allow update demands"
ON public.demands FOR UPDATE
USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_demands_shop_owner ON public.demands(shop_owner_id);
CREATE INDEX IF NOT EXISTS idx_demands_status ON public.demands(status);
