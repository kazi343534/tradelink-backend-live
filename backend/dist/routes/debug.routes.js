import { Router } from 'express';
import { asyncHandler } from '../middleware/asyncHandler.js';
import { env } from '../config/env.js';
import { db } from '../db/pool.js';
const router = Router();
// GET /debug/db — TEMP diagnostics (remove after debugging)
router.get('/db', asyncHandler(async (_req, res) => {
    let masked = 'unset';
    try {
        const u = new URL(env.databaseUrl);
        masked = `${u.protocol}//${u.username}@${u.host}${u.pathname}`;
    }
    catch (e) {
        masked = 'UNPARSEABLE: ' + (e.message ?? '');
    }
    let dbOk = false;
    let dbErr = '';
    try {
        await db.query('SELECT 1');
        dbOk = true;
    }
    catch (e) {
        dbErr = `${e.code ?? ''} ${e.message ?? ''}`.slice(0, 160);
    }
    res.json({
        success: true,
        data: {
            nodeEnv: process.env.NODE_ENV ?? null,
            demoModeRaw: process.env.DEMO_MODE ?? null,
            dbUrlMasked: masked,
            urlLength: env.databaseUrl.length,
            dbConnected: dbOk,
            dbError: dbErr,
        },
    });
}));
// GET /debug/stock-images — check stock_images table existence and row counts
router.get('/stock-images', asyncHandler(async (_req, res) => {
    const results = {};
    // 1. Does stock_images table exist?
    try {
        const { rows } = await db.query(`SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'stock_images') AS exists`);
        results.tableExists = rows[0]?.exists ?? false;
    }
    catch (e) {
        results.tableError = e.message;
    }
    // 2. How many rows in stock_images?
    try {
        const { rows } = await db.query(`SELECT count(*)::int AS count FROM stock_images`);
        results.imageCount = rows[0]?.count ?? 0;
    }
    catch (e) {
        results.countError = e.message;
    }
    // 3. How many stock items have image_url set?
    try {
        const { rows } = await db.query(`SELECT count(*)::int AS count FROM stockholder_inventory WHERE image_url IS NOT NULL AND image_url != ''`);
        results.stocksWithUrl = rows[0]?.count ?? 0;
    }
    catch (e) {
        results.stockUrlError = e.message;
    }
    // 4. Sample stock_images rows (just stock_id + byte length, no actual data)
    try {
        const { rows } = await db.query(`SELECT stock_id, length(data) AS byte_length, mime_type FROM stock_images LIMIT 5`);
        results.sampleImages = rows;
    }
    catch (e) {
        results.sampleError = e.message;
    }
    // 5. Check stockholder_inventory image_url patterns
    try {
        const { rows } = await db.query(`SELECT image_url FROM stockholder_inventory WHERE image_url IS NOT NULL AND image_url != '' LIMIT 5`);
        results.sampleUrls = rows.map((r) => r.image_url);
    }
    catch (e) {
        results.urlSampleError = e.message;
    }
    res.json({ success: true, data: results });
}));
export default router;
//# sourceMappingURL=debug.routes.js.map