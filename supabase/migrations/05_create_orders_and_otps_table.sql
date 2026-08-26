-- Migration: 05_create_orders_and_otps_table.sql
-- Description: Orders created between Shop Owners and Suppliers with OTP verification

DO $$ BEGIN
    CREATE TYPE order_status AS ENUM ('pending', 'accepted', 'in_transit', 'delivered', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    demand_id UUID REFERENCES public.demands(id) ON DELETE SET NULL,
    shop_owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    product_name TEXT NOT NULL,
    quantity NUMERIC(10, 2) NOT NULL,
    unit TEXT NOT NULL DEFAULT 'kg',
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    status order_status NOT NULL DEFAULT 'pending',
    delivery_address TEXT,
    delivery_lat DOUBLE PRECISION,
    delivery_lng DOUBLE PRECISION,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- OTP Table for secure delivery verification
CREATE TABLE IF NOT EXISTS public.otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES public.orders(id) ON DELETE CASCADE,
    otp_code VARCHAR(6) NOT NULL,
    is_verified BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '24 hours'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public select on orders"
ON public.orders FOR SELECT USING (true);

CREATE POLICY "Allow insert on orders"
ON public.orders FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update on orders"
ON public.orders FOR UPDATE USING (true);

CREATE POLICY "Allow select on otps"
ON public.otps FOR SELECT USING (true);

CREATE POLICY "Allow insert on otps"
ON public.otps FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update on otps"
ON public.otps FOR UPDATE USING (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_shop_owner ON public.orders(shop_owner_id);
CREATE INDEX IF NOT EXISTS idx_orders_supplier ON public.orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
