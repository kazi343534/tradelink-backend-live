import { app } from './app.js';
import { env } from './config/env.js';
import { db } from './db/pool.js';

async function start() {
  if (!env.demoMode) {
    try {
      await db.query('SELECT 1');
      console.log('[api] database connection OK');
    } catch (err) {
      console.warn('[api] database unreachable — starting anyway:', (err as Error).message);
    }
  }

  app.listen(env.port, () => {
    console.log(`[api] TradeLink API listening on http://localhost:${env.port}`);
    console.log(`[api] demo mode: ${env.demoMode}`);
  });
}

start();