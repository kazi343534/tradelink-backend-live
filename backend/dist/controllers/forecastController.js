import { asyncHandler } from '../middleware/asyncHandler.js';
import { getDemandTrends, getSupplyTrends, generateForecastAnalysis, } from '../services/forecastService.js';
/**
 * POST /assistant/forecast
 *
 * Body: { product?: string, days?: number }
 *
 * Returns demand trends, supply trends, and an AI-generated analysis
 * of what products are in demand and where supply gaps exist.
 */
export const forecastHandler = asyncHandler(async (req, res) => {
    const { product, days } = req.body;
    const lookbackDays = typeof days === 'number' && days > 0 ? Math.min(days, 90) : 30;
    const [demandTrends, supplyTrends] = await Promise.all([
        getDemandTrends(lookbackDays),
        getSupplyTrends(),
    ]);
    const analysis = generateForecastAnalysis(demandTrends, supplyTrends, product ?? null);
    res.json({
        success: true,
        data: {
            demandTrends: demandTrends.map((d) => ({
                productName: d.product_name,
                category: d.category,
                totalDemand: d.total_demand,
                avgQuantity: d.avg_quantity,
                uniqueBuyers: d.unique_buyers,
                status: d.status,
            })),
            supplyTrends: supplyTrends.map((s) => ({
                productName: s.product_name,
                category: s.category,
                totalStock: s.total_stock,
                avgPrice: s.avg_price,
                supplierCount: s.supplier_count,
                totalQuantity: s.total_quantity,
            })),
            analysis,
        },
    });
});
//# sourceMappingURL=forecastController.js.map