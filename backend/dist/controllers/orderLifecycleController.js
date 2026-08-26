import { asyncHandler } from '../middleware/asyncHandler.js';
import { acceptOrder, declineOrder, markOutOfDelivery, confirmDeliveryWithOtp, } from '../services/orderLifecycleService.js';
import { parseId } from '../middleware/validation.js';
/**
 * POST /orders/:id/accept
 * Supplier accepts a pending order.
 */
export const acceptOrderHandler = asyncHandler(async (req, res) => {
    const orderId = parseId(String(req.params.id), 'order id');
    const supplierId = req.userId;
    const result = await acceptOrder(orderId, supplierId);
    res.json({ success: true, data: result });
});
/**
 * POST /orders/:id/decline
 * Supplier declines a pending order.
 */
export const declineOrderHandler = asyncHandler(async (req, res) => {
    const orderId = parseId(String(req.params.id), 'order id');
    const supplierId = req.userId;
    const result = await declineOrder(orderId, supplierId);
    res.json({ success: true, data: result });
});
/**
 * POST /orders/:id/out-for-delivery
 * Supplier marks order as out for delivery and generates OTP.
 */
export const markOutOfDeliveryHandler = asyncHandler(async (req, res) => {
    const orderId = parseId(String(req.params.id), 'order id');
    const supplierId = req.userId;
    const result = await markOutOfDelivery(orderId, supplierId);
    res.json({ success: true, data: result });
});
/**
 * POST /orders/:id/verify-delivery
 * Supplier verifies OTP to confirm delivery.
 * Body: { otp: string }
 */
export const verifyDeliveryHandler = asyncHandler(async (req, res) => {
    const orderId = parseId(String(req.params.id), 'order id');
    const supplierId = req.userId;
    const { otp } = req.body;
    if (!otp || typeof otp !== 'string') {
        res.status(400).json({ success: false, error: 'OTP is required' });
        return;
    }
    const result = await confirmDeliveryWithOtp(orderId, supplierId, otp);
    res.json({ success: true, data: result });
});
//# sourceMappingURL=orderLifecycleController.js.map