-- Migration: 13_add_supplier_match_count.sql
-- Description: Reusable SQL function that counts how many suppliers currently
--              have an in-stock product matching a demand's product name.
--              Used by the Supplier home feed to badge each demand with
--              "N suppliers match".

CREATE OR REPLACE FUNCTION public.count_matching_suppliers(p_product_name TEXT)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
    SELECT COUNT(DISTINCT si.stockholder_id)::INTEGER
    FROM public.stockholder_inventory si
    WHERE si.is_available = true
      AND si.quantity_available > 0
      AND p_product_name IS NOT NULL
      AND p_product_name <> ''
      AND si.custom_product_name ILIKE '%' || p_product_name || '%'
$$;

COMMENT ON FUNCTION public.count_matching_suppliers(TEXT) IS
'Counts distinct suppliers whose available inventory matches the given product name (case-insensitive substring match).';
