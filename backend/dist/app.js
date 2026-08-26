import cors from 'cors';
import express from 'express';
import path from 'path';
import { requireAuth } from './middleware/auth.js';
import stockholderRoutes from './routes/stockholder.routes.js';
import stockImageRoutes from './routes/image.routes.js';
export const app = express();
app.set('trust proxy', 1);
app.use(cors({ origin: true }));
app.use(express.json());
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));
// Public image endpoint — must stay outside requireAuth (Image.network
// sends no auth headers). Backed by Postgres, survives restarts.
app.use('/stock-images', stockImageRoutes);
const API_VERSION = '2026-08-26.1';
app.get('/health', (_req, res) => {
    res.json({ success: true, message: 'TradeLink API is running', version: API_VERSION, ts: Date.now() });
});
app.use('/api/v1', requireAuth, stockholderRoutes);
// 404 handler
app.use((_req, res) => {
    res.status(404).json({ success: false, error: 'Route not found' });
});
// Central error handler
app.use((err, _req, res, _next) => {
    const error = err;
    if (error instanceof SyntaxError) {
        res.status(400).json({ success: false, error: 'Invalid JSON body' });
        return;
    }
    const zodError = error;
    if (zodError.name === 'ZodError') {
        res.status(400).json({ success: false, error: 'Validation failed', details: zodError.issues });
        return;
    }
    const status = error.status ?? 500;
    if (status >= 500) {
        console.error('[api] unexpected error:', error);
    }
    res.status(status).json({ success: false, error: error.message ?? 'Internal server error' });
});
//# sourceMappingURL=app.js.map