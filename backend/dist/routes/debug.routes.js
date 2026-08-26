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
export default router;
//# sourceMappingURL=debug.routes.js.map