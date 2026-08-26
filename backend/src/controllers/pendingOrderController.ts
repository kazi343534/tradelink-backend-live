import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { getPendingOrders, getCompletedOrders } from '../services/pendingOrderService.js';

export const getPendingOrdersHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const stockholderId = req.userId!;
    const orders = await getPendingOrders(stockholderId);
    res.json({ success: true, data: orders });
  },
);

export const getCompletedOrdersHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const stockholderId = req.userId!;
    const orders = await getCompletedOrders(stockholderId);
    res.json({ success: true, data: orders });
  },
);
