import { db } from '../backend/src/db/pool.js';

async function run() {
  const sLat = 23.81007852554806;
  const sLng = 90.41935626983647;
  const maxRadius = 15;
  const userId = 'd4f4c41a-f9ae-451b-8c24-e1504c800973'; // The supplier id

  const query = `
      SELECT d.id, d.shop_owner_id, d.product_name, d.category, d.quantity,
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
               )))
             AS numeric), 1) AS distance_km,
             public.count_matching_suppliers(d.product_name) AS supplier_match_count
       FROM demands d
      LEFT JOIN users u ON u.id = d.shop_owner_id
      WHERE d.status IN ('open', 'pending')
        AND d.latitude IS NOT NULL AND d.longitude IS NOT NULL
        AND $1 IS NOT NULL AND $2 IS NOT NULL
        AND (
          6371 * ACOS(GREATEST(-1, LEAST(1,
            COS(RADIANS($1)) * COS(RADIANS(d.latitude))
            * COS(RADIANS(d.longitude) - RADIANS($2))
            + SIN(RADIANS($1)) * SIN(RADIANS(d.latitude))
          )))
        ) <= COALESCE($3::float8, 10)
      ORDER BY d.created_at DESC;
  `;

  try {
    const result = await db.query(query, [sLat, sLng, maxRadius]);
    console.log(`Found ${result.rows.length} nearby demands.`);
    console.log(result.rows);
  } catch (error) {
    console.error('Error:', error);
  }
  process.exit(0);
}

run();
