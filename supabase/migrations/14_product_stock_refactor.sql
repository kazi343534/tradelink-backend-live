-- =============================================================================
-- TradeLink — Product & Stock Architecture Refactoring (v2)
--
-- Tier 1: master_products  — Global product catalog (metadata only, no price)
-- Tier 2: stockholder_inventory — Per-supplier dynamic live listings
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tier 1: Global Master Product Catalog
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.master_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    category VARCHAR(100) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed Standard Master Catalog
INSERT INTO public.master_products (name, category, unit) VALUES
('Basmati Rice', 'Grocery', 'kg'),
('Soybean Oil', 'Grocery', 'litre'),
('Sugar', 'Grocery', 'kg'),
('Lentils (Musur Dal)', 'Grocery', 'kg'),
('Wheat Flour (Atta)', 'Grocery', 'kg'),
('Napa Extra 500mg', 'Pharmacy', 'pcs'),
('Paracetamol Syrup', 'Pharmacy', 'pcs'),
('Steel Nails 2-inch', 'Hardware', 'kg'),
('PVC Pipe 1-inch', 'Hardware', 'pcs')
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Tier 2: Dynamic Stockholder Inventory (Real-Time Live Listings)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stockholder_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stockholder_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    master_product_id UUID REFERENCES public.master_products(id),
    custom_product_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    price_per_unit DECIMAL(10,2) NOT NULL,
    quantity_available DECIMAL(10,2) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    is_available BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Migrate existing stocks data into stockholder_inventory
-- ---------------------------------------------------------------------------
INSERT INTO public.stockholder_inventory (
    stockholder_id, master_product_id, custom_product_name,
    category, price_per_unit, quantity_available, unit, is_available
)
SELECT
    s.user_id,
    s.product_id,
    s.product_name,
    s.category,
    s.price_per_unit,
    s.quantity,
    s.unit,
    s.is_available
FROM public.stocks s
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- Indexes for lightning-fast AI Sourcing Queries
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_inventory_product_search
ON public.stockholder_inventory (custom_product_name, is_available, price_per_unit);

CREATE INDEX IF NOT EXISTS idx_inventory_stockholder
ON public.stockholder_inventory (stockholder_id);

CREATE INDEX IF NOT EXISTS idx_inventory_category
ON public.stockholder_inventory (category, is_available);

CREATE INDEX IF NOT EXISTS idx_master_products_name
ON public.master_products (name);

CREATE INDEX IF NOT EXISTS idx_master_products_category
ON public.master_products (category);

-- ---------------------------------------------------------------------------
-- RLS Policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.master_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stockholder_inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on master_products"
ON public.master_products FOR SELECT USING (true);

CREATE POLICY "Allow public select on stockholder_inventory"
ON public.stockholder_inventory FOR SELECT USING (true);

CREATE POLICY "Allow insert own inventory"
ON public.stockholder_inventory FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update own inventory"
ON public.stockholder_inventory FOR UPDATE USING (true);

CREATE POLICY "Allow delete own inventory"
ON public.stockholder_inventory FOR DELETE USING (true);

-- ---------------------------------------------------------------------------
-- Trigger: keep updated_at fresh
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN
    CREATE TRIGGER trg_stockholder_inventory_updated_at
        BEFORE UPDATE ON public.stockholder_inventory
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
EXCEPTION WHEN duplicate_object THEN null;
END $$;