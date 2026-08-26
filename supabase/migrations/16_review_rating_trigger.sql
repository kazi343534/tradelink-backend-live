-- 1. Add rating and review_count columns to users table (suppliers are users with role='supplier')
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) DEFAULT 5.0,
ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;

-- 2. Function to automatically recalculate Supplier Average Rating on new review insertion
CREATE OR REPLACE FUNCTION update_supplier_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.users
    SET
        rating = COALESCE(
            (SELECT ROUND(AVG(r.rating)::numeric, 1)
             FROM public.ratings r
             WHERE r.supplier_id = NEW.supplier_id),
            5.0
        ),
        review_count = (
            SELECT COUNT(*)
            FROM public.ratings r
            WHERE r.supplier_id = NEW.supplier_id
        )
    WHERE id = NEW.supplier_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Attach Trigger (fires after INSERT or UPDATE on ratings)
DROP TRIGGER IF EXISTS trigger_update_supplier_rating ON public.ratings;
CREATE TRIGGER trigger_update_supplier_rating
AFTER INSERT OR UPDATE ON public.ratings
FOR EACH ROW
EXECUTE FUNCTION update_supplier_rating();

-- 4. Backfill existing ratings for all suppliers
UPDATE public.users u
SET
    rating = COALESCE(
        (SELECT ROUND(AVG(r.rating)::numeric, 1)
         FROM public.ratings r
         WHERE r.supplier_id = u.id),
        5.0
    ),
    review_count = (
        SELECT COUNT(*)
        FROM public.ratings r
        WHERE r.supplier_id = u.id
    )
WHERE u.role = 'supplier';
