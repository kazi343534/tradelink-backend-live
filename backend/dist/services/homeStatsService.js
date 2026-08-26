import { db } from '../db/pool.js';
import { countActiveStock } from './stockService.js';
export function mapDemandRow(row) {
    return {
        id: row.id,
        shopOwnerId: row.shop_owner_id,
        productName: row.product_name,
        category: row.category,
        quantity: Number(row.quantity),
        unit: row.unit,
        notes: row.notes,
        targetPrice: row.target_price != null ? Number(row.target_price) : null,
        status: row.status,
        createdAt: row.created_at.toISOString(),
        deliveryAddress: row.delivery_address || null,
        latitude: row.latitude != null ? Number(row.latitude) : null,
        longitude: row.longitude != null ? Number(row.longitude) : null,
        distanceKm: row.distance_km != null ? Number(row.distance_km) : null,
        supplierMatchCount: row.supplier_match_count != null ? Number(row.supplier_match_count) : 0,
        shopOwnerName: row.shop_owner_name,
        shopOwnerPhone: row.shop_owner_phone,
    };
}
/**
 * Aggregates the Supplier (stockholder) home dashboard.
 * Nearby demands are filtered by geographic proximity: open demands
 * (including chatbot-created ones) within the supplier's service radius.
 */
export async function getHomeStats(userId) {
    // 1. Supplier location + service radius
    const { rows: supplierRows } = await db.query(`SELECT latitude, longitude, supply_radius
     FROM users
     WHERE id = $1`, [userId]);
    const supplier = supplierRows[0];
    const sLat = supplier?.latitude ?? null;
    const sLng = supplier?.longitude ?? null;
    // Defensive: supply_radius may contain junk ('null', '', text)
    const radiusNum = parseFloat(String(supplier?.supply_radius ?? ''));
    const maxRadius = Number.isFinite(radiusNum) && radiusNum > 0 ? radiusNum : 10;
    // 2. Open demands for this supplier:
    //    - Chatbot-targeted demands are visible ONLY to the targeted supplier.
    //    - Broadcast demands (no target) are filtered by geographic radius
    //      (default 10 km). Haversine distance, clamped ACOS to avoid float
    //      domain errors.
    const demandRowsResult = await db.query(`SELECT d.id, d.shop_owner_id, d.product_name, d.category, d.quantity,
            d.unit, d.notes, d.target_price, d.status, d.created_at,
            COALESCE(d.delivery_address, u.address, '') AS delivery_address,
            d.latitude, d.longitude,
            COALESCE(u.business_name, u.full_name, 'Shop Owner') AS shop_owner_name,
            COALESCE(u.phone_number, '') AS shop_owner_phone,
            ROUND(CAST(
              6371 * ACOS(GREATEST(-1, LEAST(1,
                COS(RADIANS($1)) * COS(RADIANS(d.latitude))
                * COS(RADIANS(d.longitude) - RADIANS($2))
                + SIN(RADIANS($1)) * SIN(RADIANS(d.latitude))
              ))
            ) AS numeric), 1) AS distance_km,
            public.count_matching_suppliers(d.product_name) AS supplier_match_count
      FROM demands d
     LEFT JOIN users u ON u.id = d.shop_owner_id
     WHERE d.status IN ('open', 'pending')
       AND (
         d.target_supplier_id = $4::uuid
         OR (
           d.target_supplier_id IS NULL
           AND d.latitude IS NOT NULL AND d.longitude IS NOT NULL
           AND $1 IS NOT NULL AND $2 IS NOT NULL
           AND (
             6371 * ACOS(GREATEST(-1, LEAST(1,
               COS(RADIANS($1)) * COS(RADIANS(d.latitude))
               * COS(RADIANS(d.longitude) - RADIANS($2))
               + SIN(RADIANS($1)) * SIN(RADIANS(d.latitude))
             )))
           ) <= COALESCE($3::float8, 10)
         )
       )
     ORDER BY d.created_at DESC
     LIMIT 50`, [sLat, sLng, maxRadius, userId]);
    const demandRows = demandRowsResult.rows;
    const { rows: pendingRows } = await db.query(`SELECT count(*)::text AS count
     FROM orders
     WHERE supplier_id = $1
       AND status IN ('pending', 'accepted', 'searching_for_rider', 'out_for_delivery', 'in_transit')`, [userId]);
    const stockItemsCount = await countActiveStock(userId);
    return {
        newDemandsCount: demandRows.length,
        pendingOrdersCount: Number(pendingRows[0]?.count ?? 0),
        stockItemsCount,
        nearbyDemands: demandRows.map(mapDemandRow),
    };
}
//# sourceMappingURL=homeStatsService.js.map