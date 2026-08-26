-- =============================================================================
-- TradeLink — Marketplace Search Model (v5)
--
-- Adds image_url and delivery_radius_km to stockholder_inventory
-- Enables spatial filtering for nearby supplier discovery
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add image and delivery radius columns to stockholder_inventory
-- ---------------------------------------------------------------------------
ALTER TABLE public.stockholder_inventory 
ADD COLUMN IF NOT EXISTS image_url TEXT,
ADD COLUMN IF NOT EXISTS delivery_radius_km INT DEFAULT 10;

-- ---------------------------------------------------------------------------
-- 2. Add earth_distance extension for distance calculations (if not exists)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;

-- ---------------------------------------------------------------------------
-- 3. Consolidated Spatial Search Query (Filters by Supplier Delivery Radius)
-- This is the core marketplace query that:
--   - Searches products by name or category
--   - Filters by availability and stock
--   - Calculates real distance using Haversine formula
--   - Only shows suppliers whose delivery radius covers the shop location
--   - Orders by distance (nearest first), then price (cheapest first)
-- ---------------------------------------------------------------------------

-- Example usage of the spatial query:
-- SELECT 
--     si.id AS stock_id,
--     s.stockholder_id,
--     s.business_name AS supplier_name,
--     s.warehouse_address,
--     s.rating,
--     si.custom_product_name AS product_name,
--     si.category,
--     si.price_per_unit,
--     si.quantity_available,
--     si.unit,
--     si.image_url,
--     si.delivery_radius_km,
--     ROUND(CAST(ST_DistanceSphere(s.location_point, ST_MakePoint(:shop_lng, :shop_lat)) / 1000.0 AS numeric), 1) AS distance_km
-- FROM public.stockholder_inventory si
-- JOIN public.stockholders s ON si.stockholder_id = s.stockholder_id
-- WHERE (LOWER(si.custom_product_name) LIKE LOWER(:query) OR LOWER(si.category) LIKE LOWER(:query))
--   AND si.is_available = true
--   AND si.quantity_available > 0
--   AND (ST_DistanceSphere(s.location_point, ST_MakePoint(:shop_lng, :shop_lat)) / 1000.0) <= si.delivery_radius_km
-- ORDER BY distance_km ASC, si.price_per_unit ASC;

-- ---------------------------------------------------------------------------
-- 4. Index for spatial queries on stockholder_inventory
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_inventory_image_url 
ON public.stockholder_inventory (image_url) WHERE image_url IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_inventory_delivery_radius 
ON public.stockholder_inventory (delivery_radius_km);

-- ---------------------------------------------------------------------------
-- 5. Add location_point geometry column to stockholders if not exists
-- (This enables PostGIS spatial queries)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
    ALTER TABLE public.stockholders 
    ADD COLUMN IF NOT EXISTS location_point GEOGRAPHY(POINT, 4326);
EXCEPTION WHEN duplicate_column THEN null;
END $$;

-- Update location_point from latitude/longitude if they exist
UPDATE public.stockholders 
SET location_point = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE location_point IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL;

-- Create a trigger to automatically update location_point when lat/lng change
CREATE OR REPLACE FUNCTION update_location_point()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.location_point = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to users table (stockholders inherit from users)
DO $$ BEGIN
    CREATE TRIGGER trg_update_location_point
        BEFORE INSERT OR UPDATE OF latitude, longitude
        ON public.users
        FOR EACH ROW
        EXECUTE FUNCTION update_location_point();
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- ---------------------------------------------------------------------------
-- 6. Create a view for marketplace search results
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.marketplace_search_view AS
SELECT 
    si.id AS stock_id,
    si.stockholder_id,
    u.full_name AS supplier_name,
    u.address AS warehouse_address,
    u.latitude AS supplier_lat,
    u.longitude AS supplier_lng,
    si.custom_product_name AS product_name,
    si.category,
    si.price_per_unit,
    si.quantity_available,
    si.unit,
    si.image_url,
    si.delivery_radius_km,
    si.created_at,
    si.updated_at
FROM public.stockholder_inventory si
JOIN public.users u ON si.stockholder_id = u.id
WHERE si.is_available = true 
  AND si.quantity_available > 0;