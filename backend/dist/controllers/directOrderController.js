import { asyncHandler } from '../middleware/asyncHandler.js';
import { createDirectOrder } from '../services/directOrderService.js';
/**
 * POST /orders/direct
 *
 * Create a direct order from a shop owner to a supplier's inventory item.
 * No demand is involved — the shop owner picks a product and orders it directly.
 *
 * Body: { stockId: string, quantity: number, deliveryAddress?: string }
 */
export const createDirectOrderHandler = asyncHandler(async (req, res) => {
    const shopOwnerId = req.userId;
    const { stockId, quantity, deliveryAddress } = req.body;
    if (!stockId || typeof stockId !== 'string') {
        res.status(400).json({ success: false, error: 'stockId is required' });
        return;
    }
    if (typeof quantity !== 'number' || quantity <= 0) {
        res.status(400).json({ success: false, error: 'quantity must be a positive number' });
        return;
    }
    const result = await createDirectOrder(shopOwnerId, {
        stockId,
        quantity,
        deliveryAddress,
    });
    res.status(201).json({ success: true, data: result });
});
//# sourceMappingURL=directOrderController.js.map