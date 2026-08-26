import { asyncHandler } from '../middleware/asyncHandler.js';
import { db } from '../db/pool.js';
function mapOrderRow(row) {
    return {
        id: row.id,
        demandId: row.demand_id,
        shopOwnerId: row.shop_owner_id,
        supplierId: row.supplier_id,
        productName: row.product_name,
        quantity: row.quantity,
        unit: row.unit,
        totalAmount: row.total_amount,
        status: row.status,
        deliveryAddress: row.delivery_address,
        createdAt: row.created_at.toISOString(),
    };
}
export const listOrdersHandler = asyncHandler(async (req, res) => {
    const userId = req.userId;
    const { rows } = await db.query(`SELECT id, demand_id, shop_owner_id, supplier_id, product_name,
              quantity, unit, total_amount, status, delivery_address, created_at
       FROM orders
       WHERE supplier_id = $1
       ORDER BY created_at DESC
       LIMIT 50`, [userId]);
    res.json({ success: true, data: rows.map(mapOrderRow) });
});
//# sourceMappingURL=orderController.js.map