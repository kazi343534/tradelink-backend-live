import { db } from '../backend/src/db/pool.js';

async function run() {
  const demands = await db.query('SELECT * FROM demands ORDER BY created_at DESC LIMIT 5');
  console.log('Recent demands:', demands.rows);
  
  const users = await db.query('SELECT id, role, latitude, longitude, supply_radius FROM users');
  console.log('Users:', users.rows);
  
  process.exit(0);
}

run().catch(console.error);
