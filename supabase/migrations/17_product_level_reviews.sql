-- Migration 007: Product-level reviews (inventory_id on ratings)
-- Reviews now attach to specific inventory items, not just the overall supplier.

-- 1. Add inventory_id to ratings table
ALTER TABLE public.ratings
ADD COLUMN IF NOT EXISTS inventory_id UUID REFERENCES public.stockholder_inventory(id) ON DELETE CASCADE;

-- 2. Add product-level rating columns to stockholder_inventory
ALTER TABLE public.stockholder_inventory
ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 5.0,
ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;

-- 3. Trigger function to recalculate per-product rating
CREATE OR REPLACE FUNCTION update_product_item_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.stockholder_inventory
    SET
        rating = COALESCE(
            (SELECT ROUND(AVG(r.rating)::numeric, 1)
             FROM public.ratings r
             WHERE r.inventory_id = NEW.inventory_id),
            5.0
        ),
        review_count = (
            SELECT COUNT(*)::int
            FROM public.ratings r
            WHERE r.inventory_id = NEW.inventory_id
        )
    WHERE id = NEW.inventory_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Attach trigger to ratings table
DROP TRIGGER IF EXISTS trigger_update_product_rating ON public.ratings;
CREATE TRIGGER trigger_update_product_rating
AFTER INSERT OR UPDATE ON public.ratings
FOR EACH ROW
WHEN (NEW.inventory_id IS NOT NULL)
EXECUTE FUNCTION update_product_item_rating();

-- 5. Backfill: try to match existing reviews to inventory items by product_name + supplier_id
UPDATE public.ratings r
SET inventory_id = si.id
FROM public.stockholder_inventory si
WHERE r.inventory_id IS NULL
  AND r.supplier_id = si.stockholder_id
  AND LOWER(si.custom_product_name) LIKE LOWER('%' || r.review || '%')
  AND false; -- Disabled: too risky for blind backfill. Run manually if needed.

-- 6. Backfill stockholder_inventory ratings from matched reviews
UPDATE public.stockholder_inventory si
SET
    rating = COALESCE(
        (SELECT ROUND(AVG(r.rating)::numeric, 1)
         FROM public.ratings r
         WHERE r.inventory_id = si.id),
        5.0
    ),
    review_count = (
        SELECT COUNT(*)::int
        FROM public.ratings r
        WHERE r.inventory_id = si.id
    )
WHERE EXISTS (
    SELECT 1 FROM public.ratings r WHERE r.inventory_id = si.id
);
