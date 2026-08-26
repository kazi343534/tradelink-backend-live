import type { Response } from 'express';
import type { AuthRequest } from '../middleware/auth.js';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { getHomeStats } from '../services/homeStatsService.js';

export const getHomeStatsHandler = asyncHandler(
  async (req: AuthRequest, res: Response) => {
    const stockholderId = req.userId!;
    const stats = await getHomeStats(stockholderId);
    res.json({ success: true, data: stats });
  },
);