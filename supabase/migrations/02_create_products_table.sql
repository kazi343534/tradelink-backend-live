-- Migration: 02_create_products_table.sql
-- Description: Master catalog for standard market products across categories

CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Grocery',
    unit TEXT NOT NULL DEFAULT 'kg',
    default_price NUMERIC(10, 2),
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Allow read access to all users
CREATE POLICY "Allow public read on products"
ON public.products FOR SELECT
USING (true);

-- Allow authenticated users to insert/update products
CREATE POLICY "Allow authenticated insert on products"
ON public.products FOR INSERT
WITH CHECK (true);

-- Pre-populate common products
INSERT INTO public.products (name, category, unit, default_price) VALUES
('Basmati Rice', 'Grocery', 'kg', 145.00),
('Soybean Oil', 'Grocery', 'litre', 165.00),
('Sugar', 'Grocery', 'kg', 130.00),
('Lentils (Musur Dal)', 'Grocery', 'kg', 120.00),
('Wheat Flour (Atta)', 'Grocery', 'kg', 55.00),
('Napa Extra 500mg', 'Pharmacy', 'pcs', 2.50),
('Paracetamol Syrup', 'Pharmacy', 'pcs', 35.00),
('Steel Nails 2-inch', 'Hardware', 'kg', 110.00),
('PVC Pipe 1-inch', 'Hardware', 'pcs', 250.00)
ON CONFLICT DO NOTHING;
