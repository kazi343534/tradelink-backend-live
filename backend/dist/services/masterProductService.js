import { db } from '../db/pool.js';
import { mapStockRow } from './stockService.js';
export function mapMasterProductRow(row) {
    return {
        id: row.id,
        name: row.name,
        category: row.category,
        unit: row.unit,
        createdAt: row.created_at.toISOString(),
    };
}
/** List all master products, optionally filtered by category. */
export async function listMasterProducts(category) {
    if (category) {
        const { rows } = await db.query(`SELECT * FROM master_products WHERE category = $1 ORDER BY name`, [category]);
        return rows.map(mapMasterProductRow);
    }
    const { rows } = await db.query(`SELECT * FROM master_products ORDER BY category, name`);
    return rows.map(mapMasterProductRow);
}
/** Search stockholder inventory by product name (for AI chatbot sourcing). */
export async function searchInventory(query, category) {
    const pattern = `%${query}%`;
    if (category) {
        const { rows } = await db.query(`SELECT * FROM stockholder_inventory
       WHERE is_available = true
         AND custom_product_name ILIKE $1
         AND category = $2
       ORDER BY price_per_unit ASC
       LIMIT 20`, [pattern, category]);
        return rows.map(mapStockRow);
    }
    const { rows } = await db.query(`SELECT * FROM stockholder_inventory
     WHERE is_available = true
       AND custom_product_name ILIKE $1
     ORDER BY price_per_unit ASC
     LIMIT 20`, [pattern]);
    return rows.map(mapStockRow);
}
/** Get cheapest suppliers for a product (AI sourcing query). */
export async function getCheapestSuppliers(productName) {
    const { rows } = await db.query(`SELECT si.*, u.full_name
     FROM stockholder_inventory si
     JOIN users u ON u.id = si.stockholder_id
     WHERE si.is_available = true
       AND si.custom_product_name ILIKE '%' || $1 || '%'
     ORDER BY si.price_per_unit ASC
     LIMIT 10`, [productName]);
    return rows.map((row) => ({
        ...mapStockRow(row),
        stockholderName: row.full_name,
    }));
}
//# sourceMappingURL=masterProductService.js.map