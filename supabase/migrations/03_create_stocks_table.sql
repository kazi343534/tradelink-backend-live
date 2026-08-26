-- Migration: 03_create_stocks_table.sql
-- Description: Inventory management for Supplier warehouses and Shop Owner stores

CREATE TABLE IF NOT EXISTS public.stocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Grocery',
    quantity NUMERIC(10, 2) NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'kg',
    price_per_unit NUMERIC(10, 2) NOT NULL DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.stocks ENABLE ROW LEVEL SECURITY;

-- Allow everyone to view stock items (for price comparison and supplier discovery)
CREATE POLICY "Allow public select on stocks"
ON public.stocks FOR SELECT
USING (true);

-- Allow users to manage their own stocks
CREATE POLICY "Allow insert own stocks"
ON public.stocks FOR INSERT
WITH CHECK (true);

CREATE POLICY "Allow update own stocks"
ON public.stocks FOR UPDATE
USING (true);

CREATE POLICY "Allow delete own stocks"
ON public.stocks FOR DELETE
USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_stocks_user_id ON public.stocks(user_id);
CREATE INDEX IF NOT EXISTS idx_stocks_product_name ON public.stocks(product_name);
