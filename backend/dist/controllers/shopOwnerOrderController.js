import { asyncHandler } from '../middleware/asyncHandler.js';
import { getShopOwnerOrders } from '../services/shopOwnerOrderService.js';
/**
 * GET /orders/shop-owner
 * Returns all orders for the logged-in shop owner.
 */
export const getShopOwnerOrdersHandler = asyncHandler(async (req, res) => {
    const shopOwnerId = req.userId;
    const orders = await getShopOwnerOrders(shopOwnerId);
    res.json({ success: true, data: orders });
});
//# sourceMappingURL=shopOwnerOrderController.js.map