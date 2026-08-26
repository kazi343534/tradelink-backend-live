import { db } from '../db/pool.js';
// ── Query demand trends (resilient to missing table) ───────────────
export async function getDemandTrends(days = 30) {
    try {
        const { rows } = await db.query(`
      SELECT
        product_name,
        category,
        COUNT(*)::int AS total_demand,
        ROUND(AVG(quantity), 1)::float AS avg_quantity,
        COUNT(DISTINCT shop_owner_id)::int AS unique_buyers,
        status
      FROM public.demands
      WHERE created_at >= NOW() - INTERVAL '1 day' * $1
      GROUP BY product_name, category, status
      ORDER BY total_demand DESC
      LIMIT 20
      `, [days]);
        return rows;
    }
    catch (err) {
        // If the demands table doesn't exist or has no data, return empty
        if (err?.code === '42P01' || err?.code === '42703') {
            console.warn('[forecast] demands table not available, returning empty');
            return [];
        }
        throw err;
    }
}
// ── Query supply trends from inventory ─────────────────────────────
export async function getSupplyTrends() {
    try {
        const { rows } = await db.query(`
      SELECT
        si.custom_product_name AS product_name,
        si.category,
        COUNT(*)::int AS total_stock,
        ROUND(AVG(si.price_per_unit), 2)::float AS avg_price,
        COUNT(DISTINCT si.stockholder_id)::int AS supplier_count,
        SUM(si.quantity_available)::float AS total_quantity
      FROM public.stockholder_inventory si
      WHERE si.is_available = true
        AND si.quantity_available > 0
      GROUP BY si.custom_product_name, si.category
      ORDER BY total_stock DESC
      LIMIT 20
      `);
        return rows;
    }
    catch (err) {
        if (err?.code === '42P01' || err?.code === '42703') {
            console.warn('[forecast] stockholder_inventory table not available, returning empty');
            return [];
        }
        throw err;
    }
}
// ── Generate analysis text ─────────────────────────────────────────
export function generateForecastAnalysis(demandTrends, supplyTrends, productHint) {
    const parts = [];
    if (demandTrends.length === 0 && supplyTrends.length === 0) {
        return 'Not enough data yet to generate a forecast. As more orders and stock listings are added, I\'ll be able to provide demand predictions.';
    }
    // Demand summary
    if (demandTrends.length > 0) {
        const topDemand = demandTrends.slice(0, 5);
        parts.push(`📈 Top demanded products (last 30 days): ${topDemand.map((d) => `${d.product_name} (${d.total_demand} orders)`).join(', ')}.`);
        const pendingCount = demandTrends
            .filter((d) => d.status === 'pending')
            .reduce((sum, d) => sum + d.total_demand, 0);
        if (pendingCount > 0) {
            parts.push(`⏳ ${pendingCount} pending demands still unfulfilled — opportunity for new stock.`);
        }
    }
    // Supply summary
    if (supplyTrends.length > 0) {
        const topSupply = supplyTrends.slice(0, 5);
        parts.push(`📦 Most stocked products: ${topSupply.map((s) => `${s.product_name} (${s.supplier_count} suppliers, avg ৳${s.avg_price})`).join(', ')}.`);
        // Identify supply gaps
        const demandProducts = new Set(demandTrends.map((d) => d.product_name.toLowerCase()));
        const supplyProducts = new Set(supplyTrends.map((s) => s.product_name.toLowerCase()));
        const gaps = [...demandProducts].filter((d) => !supplyProducts.has(d));
        if (gaps.length > 0) {
            parts.push(`⚠️ Supply gap detected for: ${gaps.slice(0, 3).join(', ')}. High demand but low/no supply.`);
        }
    }
    // Product-specific hint
    if (productHint) {
        const relatedDemand = demandTrends.filter((d) => d.product_name.toLowerCase().includes(productHint.toLowerCase()));
        const relatedSupply = supplyTrends.filter((s) => s.product_name.toLowerCase().includes(productHint.toLowerCase()));
        if (relatedDemand.length > 0 || relatedSupply.length > 0) {
            parts.push(`🔍 For "${productHint}": ${relatedDemand.length} demand entries, ${relatedSupply.length} supply listings.`);
        }
    }
    return parts.join('\n');
}
//# sourceMappingURL=forecastService.js.map