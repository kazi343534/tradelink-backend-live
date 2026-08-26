import pg from 'pg';
import { env } from '../config/env.js';
export const pool = new pg.Pool({
    connectionString: env.databaseUrl,
    max: 10,
    idleTimeoutMillis: 30_000,
});
pool.on('error', (err) => {
    console.error('[pg] idle client error:', err.message);
});
export { pool as db };
//# sourceMappingURL=pool.js.map