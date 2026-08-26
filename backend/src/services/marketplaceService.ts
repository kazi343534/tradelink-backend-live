import { db } from '../db/pool.js';
import type { MarketplaceProduct, MarketplaceSearchParams } from '../types/index.js';

export interface MarketplaceProductRow {
  stock_id: string;
  stockholder_id: string;
  supplier_name: string;
  warehouse_address: string | null;
  supplier_lat: number | null;
  supplier_lng: number | null;
  supplier_phone?: string | null;
  product_name: string;
  category: string;
  price_per_unit: number;
  quantity_available: number;
  unit: string;
  image_url: string | null;
  delivery_radius_km: number;
  distance_km: number;
  avg_rating: number | string | null;
  rating_count: number | string;
}

export function mapMarketplaceProductRow(row: MarketplaceProductRow): MarketplaceProduct {
  return {
    stockId: row.stock_id,
    stockholderId: row.stockholder_id,
    supplierName: row.supplier_name,
    warehouseAddress: row.warehouse_address,
    supplierLat: row.supplier_lat,
    supplierLng: row.supplier_lng,
    supplierPhone: row.supplier_phone ?? null,
    productName: row.product_name,
    category: row.category,
    pricePerUnit: row.price_per_unit,
    quantityAvailable: row.quantity_available,
    unit: row.unit,
    imageUrl: row.image_url,
    deliveryRadiusKm: row.delivery_radius_km,
    distanceKm: row.distance_km,
    rating: row.avg_rating != null ? Number(row.avg_rating) : 0,
    ratingCount: Number(row.rating_count) || 0,
  };
}

/**
 * Search/browse products in the marketplace with spatial filtering.
 * Uses Haversine formula (pure SQL, no PostGIS required).
 */
export async function searchMarketplace(
  params: MarketplaceSearchParams,
): Promise<MarketplaceProduct[]> {
  const {
    query,
    shopLat,
    shopLng,
    category,
    maxDistance = 50,
    sortBy = 'distance',
    limit = 50,
    offset = 0,
  } = params;

  const safeLat = shopLat ?? 23.777176;
  const safeLng = shopLng ?? 90.399451;

  const hasQuery = query != null && query.trim().length > 0;
  const searchPattern = hasQuery ? `%${query.trim()}%` : null;

  // Haversine distance in km — pure SQL, no extensions needed
  // Clamps ACOS input to [-1, 1] to prevent numeric domain errors
  const haversineExpr = `
    CASE
      WHEN u.latitude IS NOT NULL AND u.longitude IS NOT NULL THEN
        ROUND(CAST(
          6371 * ACOS(
            GREATEST(-1, LEAST(1,
              COS(RADIANS($1)) * COS(RADIANS(u.latitude))
              * COS(RADIANS(u.longitude) - RADIANS($2))
              + SIN(RADIANS($1)) * SIN(RADIANS(u.latitude))
            ))
          ) AS numeric
        ), 1)
      ELSE 999
    END
  `;

  let sql = `
    SELECT
      si.id AS stock_id,
      si.stockholder_id,
      COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
      COALESCE(u.address, '') AS warehouse_address,
      u.latitude AS supplier_lat,
      u.longitude AS supplier_lng,
      si.custom_product_name AS product_name,
      si.category,
      si.price_per_unit,
      si.quantity_available,
      si.unit,
      si.image_url,
      COALESCE(si.delivery_radius_km, 50) AS delivery_radius_km,
      ${haversineExpr} AS distance_km,
      COALESCE(si.rating, 5.0) AS avg_rating,
      COALESCE(si.review_count, 0) AS rating_count
    FROM public.stockholder_inventory si
    JOIN public.users u ON si.stockholder_id = u.id
    WHERE si.is_available = true
      AND si.quantity_available > 0
  `;

  const queryParams: (string | number)[] = [safeLat, safeLng];
  let paramIdx = 3;

  if (hasQuery && searchPattern) {
    sql += ` AND (
      LOWER(si.custom_product_name) LIKE LOWER($${paramIdx})
      OR LOWER(si.category) LIKE LOWER($${paramIdx})
    )`;
    queryParams.push(searchPattern);
    paramIdx++;
  }

  if (category && category !== 'All') {
    sql += ` AND LOWER(si.category) = LOWER($${paramIdx})`;
    queryParams.push(category);
    paramIdx++;
  }

  // Distance filter
  sql += ` AND ${haversineExpr.replace(/\$1/g, `$1`).replace(/\$2/g, `$2`)} <= $${paramIdx}`;
  queryParams.push(maxDistance);
  paramIdx++;

  switch (sortBy) {
    case 'price':
    case 'price_asc':
      sql += ` ORDER BY si.price_per_unit ASC`;
      break;
    case 'price_desc':
      sql += ` ORDER BY si.price_per_unit DESC`;
      break;
    case 'rating':
    case 'top_rated':
    case 'Top Rated':
      // Rated items first (unrated defaults must not bury reviewed
      // products), then best average rating, then most-reviewed.
      sql += ` ORDER BY (COALESCE(si.review_count, 0) > 0) DESC, avg_rating DESC, COALESCE(si.review_count, 0) DESC, distance_km ASC`;
      break;
    case 'rating_asc':
    case 'low_rated':
      // Lowest-rated first, but still among items that actually have reviews.
      sql += ` ORDER BY (COALESCE(si.review_count, 0) > 0) DESC, avg_rating ASC, COALESCE(si.review_count, 0) DESC, distance_km ASC`;
      break;
    case 'distance':
    default:
      sql += ` ORDER BY distance_km ASC, si.price_per_unit ASC`;
      break;
  }

  sql += ` LIMIT $${paramIdx} OFFSET $${paramIdx + 1}`;
  queryParams.push(limit, offset);

  const { rows } = await db.query<MarketplaceProductRow>(sql, queryParams);
  return rows.map(mapMarketplaceProductRow);
}

/**
 * Get a single product detail with supplier info.
 */
export async function getProductDetail(
  stockId: string,
  shopLat: number | null,
  shopLng: number | null,
): Promise<MarketplaceProduct | null> {
  const safeLat = shopLat ?? 23.777176;
  const safeLng = shopLng ?? 90.399451;

  const haversineExpr = `
    CASE
      WHEN u.latitude IS NOT NULL AND u.longitude IS NOT NULL THEN
        ROUND(CAST(
          6371 * ACOS(
            GREATEST(-1, LEAST(1,
              COS(RADIANS($1)) * COS(RADIANS(u.latitude))
              * COS(RADIANS(u.longitude) - RADIANS($2))
              + SIN(RADIANS($1)) * SIN(RADIANS(u.latitude))
            ))
          ) AS numeric
        ), 1)
      ELSE 0
    END
  `;

  const sql = `
    SELECT
      si.id AS stock_id,
      si.stockholder_id,
      COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
      COALESCE(u.address, '') AS warehouse_address,
      u.latitude AS supplier_lat,
      u.longitude AS supplier_lng,
      COALESCE(u.phone_number, '') AS supplier_phone,
      si.custom_product_name AS product_name,
      si.category,
      si.price_per_unit,
      si.quantity_available,
      si.unit,
      si.image_url,
      COALESCE(si.delivery_radius_km, 50) AS delivery_radius_km,
      ${haversineExpr} AS distance_km,
      COALESCE(si.rating, 5.0) AS avg_rating,
      COALESCE(si.review_count, 0) AS rating_count
    FROM public.stockholder_inventory si
    JOIN public.users u ON si.stockholder_id = u.id
    WHERE si.id = $3
      AND si.is_available = true
  `;

  const { rows } = await db.query<MarketplaceProductRow>(sql, [safeLat, safeLng, stockId]);
  if (rows.length === 0) return null;
  return mapMarketplaceProductRow(rows[0]);
}

/**
 * Get products by category with spatial filtering.
 */
export async function getProductsByCategory(
  category: string,
  shopLat: number | null,
  shopLng: number | null,
  limit = 50,
  offset = 0,
): Promise<MarketplaceProduct[]> {
  const safeLat = shopLat ?? 23.777176;
  const safeLng = shopLng ?? 90.399451;

  const haversineExpr = `
    CASE
      WHEN u.latitude IS NOT NULL AND u.longitude IS NOT NULL THEN
        ROUND(CAST(
          6371 * ACOS(
            GREATEST(-1, LEAST(1,
              COS(RADIANS($1)) * COS(RADIANS(u.latitude))
              * COS(RADIANS(u.longitude) - RADIANS($2))
              + SIN(RADIANS($1)) * SIN(RADIANS(u.latitude))
            ))
          ) AS numeric
        ), 1)
      ELSE 999
    END
  `;

  const sql = `
    SELECT
      si.id AS stock_id,
      si.stockholder_id,
      COALESCE(u.full_name, 'Unknown Supplier') AS supplier_name,
      COALESCE(u.address, '') AS warehouse_address,
      u.latitude AS supplier_lat,
      u.longitude AS supplier_lng,
      si.custom_product_name AS product_name,
      si.category,
      si.price_per_unit,
      si.quantity_available,
      si.unit,
      si.image_url,
      COALESCE(si.delivery_radius_km, 50) AS delivery_radius_km,
      ${haversineExpr} AS distance_km,
      COALESCE(si.rating, 5.0) AS avg_rating,
      COALESCE(si.review_count, 0) AS rating_count
    FROM public.stockholder_inventory si
    JOIN public.users u ON si.stockholder_id = u.id
    WHERE LOWER(si.category) = LOWER($3)
      AND si.is_available = true
      AND si.quantity_available > 0
    ORDER BY distance_km ASC, si.price_per_unit ASC
    LIMIT $4 OFFSET $5
  `;

  const { rows } = await db.query<MarketplaceProductRow>(sql, [
    safeLat,
    safeLng,
    category,
    limit,
    offset,
  ]);
  return rows.map(mapMarketplaceProductRow);
}
