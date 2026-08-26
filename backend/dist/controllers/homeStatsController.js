import { asyncHandler } from '../middleware/asyncHandler.js';
import { getHomeStats } from '../services/homeStatsService.js';
export const getHomeStatsHandler = asyncHandler(async (req, res) => {
    const stockholderId = req.userId;
    const stats = await getHomeStats(stockholderId);
    res.json({ success: true, data: stats });
});
//# sourceMappingURL=homeStatsController.js.map