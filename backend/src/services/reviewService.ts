import { db } from '../db/pool.js';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface SubmitReviewInput {
  orderId?: string | null;
  supplierId?: string | null;
  inventoryId?: string | null;
  rating: number;
  comment?: string | null;
}

export interface ReviewItem {
  id: string;
  orderId: string | null;
  shopOwnerId: string;
  supplierId: string;
  inventoryId: string | null;
  rating: number;
  comment: string | null;
  createdAt: string;
}

function isValidUuid(v: string | null | undefined): boolean {
  return !!v && UUID_RE.test(v);
}

/**
 * Submit a review for a completed order.
 * - inventoryId attaches the review to a specific product (inventory item).
 * - If inventoryId is missing, tries to look it up from the order's product_name + supplier_id.
 * - Uses ON CONFLICT so a second submission updates the existing review.
 */
export async function submitReview(
  shopOwnerId: string,
  input: SubmitReviewInput,
): Promise<ReviewItem> {
  const { rating, comment } = input;
  let orderId = input.orderId && isValidUuid(input.orderId) ? input.orderId : null;
  let supplierId = input.supplierId && isValidUuid(input.supplierId) ? input.supplierId : null;
  let inventoryId = input.inventoryId && isValidUuid(input.inventoryId) ? input.inventoryId : null;

  const client = await db.connect();
  try {
    await client.query('BEGIN');

    // If supplierId is missing, try to look it up from the order
    if (!supplierId && orderId) {
      const { rows } = await client.query(
        'SELECT supplier_id, product_name FROM public.orders WHERE id = $1',
        [orderId],
      );
      if (rows.length > 0) {
        if (rows[0].supplier_id) supplierId = rows[0].supplier_id;
      }
    }

    // If inventoryId is missing, try to resolve from order's product_name + supplier
    if (!inventoryId && orderId && supplierId) {
      const { rows: orderRows } = await client.query(
        'SELECT product_name FROM public.orders WHERE id = $1',
        [orderId],
      );
      if (orderRows.length > 0 && orderRows[0].product_name) {
        const invResult = await client.query(
          `SELECT id FROM public.stockholder_inventory
           WHERE stockholder_id = $1
             AND LOWER(custom_product_name) = LOWER($2)
           LIMIT 1`,
          [supplierId, orderRows[0].product_name],
        );
        if (invResult.rows.length > 0) {
          inventoryId = invResult.rows[0].id;
        }
      }
    }

    if (!supplierId) {
      throw Object.assign(new Error('Could not determine supplier. Please try again.'), { status: 400 });
    }

    // Validate shopOwnerId exists
    const ownerCheck = await client.query('SELECT id FROM public.users WHERE id = $1', [shopOwnerId]);
    if (ownerCheck.rows.length === 0) {
      throw Object.assign(new Error('Shop owner not found'), { status: 400 });
    }

    // Validate supplierId exists
    const supplierCheck = await client.query('SELECT id FROM public.users WHERE id = $1', [supplierId]);
    if (supplierCheck.rows.length === 0) {
      throw Object.assign(new Error('Supplier not found'), { status: 400 });
    }

    // Validate inventoryId exists if provided
    if (inventoryId) {
      const invCheck = await client.query('SELECT id FROM public.stockholder_inventory WHERE id = $1', [inventoryId]);
      if (invCheck.rows.length === 0) {
        inventoryId = null; // Invalid, insert without it
      }
    }

    let result;
    if (orderId) {
      // Validate order exists
      const orderCheck = await client.query('SELECT id FROM public.orders WHERE id = $1', [orderId]);
      if (orderCheck.rows.length === 0) {
        orderId = null;
      }
    }

    if (orderId) {
      result = await client.query(
        `INSERT INTO public.ratings (order_id, shop_owner_id, supplier_id, inventory_id, rating, review)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (order_id) DO UPDATE
           SET rating = EXCLUDED.rating,
               review = EXCLUDED.review,
               supplier_id = EXCLUDED.supplier_id,
               inventory_id = COALESCE(EXCLUDED.inventory_id, public.ratings.inventory_id)
         RETURNING id, order_id, shop_owner_id, supplier_id, inventory_id, rating, review, created_at`,
        [orderId, shopOwnerId, supplierId, inventoryId, rating, comment ?? null],
      );
    } else {
      result = await client.query(
        `INSERT INTO public.ratings (order_id, shop_owner_id, supplier_id, inventory_id, rating, review)
         VALUES (NULL, $1, $2, $3, $4, $5)
         RETURNING id, order_id, shop_owner_id, supplier_id, inventory_id, rating, review, created_at`,
        [shopOwnerId, supplierId, inventoryId, rating, comment ?? null],
      );
    }

    await client.query('COMMIT');

    const row = result.rows[0];
    return {
      id: row.id,
      orderId: row.order_id,
      shopOwnerId: row.shop_owner_id,
      supplierId: row.supplier_id,
      inventoryId: row.inventory_id,
      rating: Number(row.rating),
      comment: row.review,
      createdAt: row.created_at.toISOString(),
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Resolve order + supplier + inventory from product name for a shop owner.
 * Used when notification metadata is missing (old notifications).
 */
export async function resolveOrderForReview(
  shopOwnerId: string,
  productName: string,
): Promise<{ orderId: string; supplierId: string; inventoryId: string | null } | null> {
  const { rows } = await db.query(
    `SELECT o.id AS order_id, o.supplier_id,
            (SELECT si.id FROM public.stockholder_inventory si
             WHERE si.stockholder_id = o.supplier_id
               AND LOWER(si.custom_product_name) = LOWER(o.product_name)
             LIMIT 1) AS inventory_id
     FROM public.orders o
     WHERE o.shop_owner_id = $1
       AND LOWER(o.product_name) LIKE LOWER($2)
       AND o.status = 'delivered'
     ORDER BY o.created_at DESC
     LIMIT 1`,
    [shopOwnerId, `%${productName}%`],
  );
  if (rows.length === 0) return null;
  return {
    orderId: rows[0].order_id,
    supplierId: rows[0].supplier_id,
    inventoryId: rows[0].inventory_id,
  };
}

/**
 * Get average rating and review count for a supplier (overall).
 */
export async function getSupplierRating(
  supplierId: string,
): Promise<{ rating: number; reviewCount: number }> {
  const { rows } = await db.query(
    `SELECT
       COALESCE(ROUND(AVG(rating)::numeric, 1), 5.0) AS avg_rating,
       COUNT(*)::int AS review_count
     FROM public.ratings
     WHERE supplier_id = $1`,
    [supplierId],
  );
  return {
    rating: Number(rows[0]?.avg_rating ?? 5.0),
    reviewCount: rows[0]?.review_count ?? 0,
  };
}

/**
 * Get average rating and review count for a specific inventory item (product).
 */
export async function getInventoryRating(
  inventoryId: string,
): Promise<{ rating: number; reviewCount: number }> {
  const { rows } = await db.query(
    `SELECT COALESCE(rating, 5.0) AS rating, COALESCE(review_count, 0) AS review_count
     FROM public.stockholder_inventory
     WHERE id = $1`,
    [inventoryId],
  );
  return {
    rating: Number(rows[0]?.rating ?? 5.0),
    reviewCount: rows[0]?.review_count ?? 0,
  };
}

/**
 * List individual reviews attached to a specific inventory item (product),
 * joined with the reviewer's shop name.
 */
export interface ProductReview {
  id: string;
  rating: number;
  comment: string | null;
  reviewerName: string;
  createdAt: string;
}

export async function listInventoryReviews(
  inventoryId: string,
  limit = 20,
): Promise<ProductReview[]> {
  const { rows } = await db.query(
    `SELECT r.id, r.rating, r.review, r.created_at,
            COALESCE(u.business_name, u.full_name, 'Shop Owner') AS reviewer_name
     FROM public.ratings r
     LEFT JOIN public.users u ON r.shop_owner_id = u.id
     WHERE r.inventory_id = $1
     ORDER BY r.created_at DESC
     LIMIT $2`,
    [inventoryId, limit],
  );
  return rows.map((row) => ({
    id: row.id,
    rating: Number(row.rating),
    comment: row.review,
    reviewerName: row.reviewer_name,
    createdAt: row.created_at.toISOString(),
  }));
}
