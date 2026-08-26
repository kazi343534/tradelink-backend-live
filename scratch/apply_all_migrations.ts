import { db } from '../backend/src/db/pool.js';
import * as fs from 'fs';
import * as path from 'path';

async function run() {
  const migrationsDir = path.resolve('../supabase/migrations');
  const files = fs.readdirSync(migrationsDir)
                  .filter(f => f.endsWith('.sql') && parseInt(f.split('_')[0], 10) >= 14)
                  .sort((a, b) => parseInt(a.split('_')[0], 10) - parseInt(b.split('_')[0], 10));

  for (const file of files) {
    const filePath = path.join(migrationsDir, file);
    const sql = fs.readFileSync(filePath, 'utf-8');
    console.log(`Running migration: ${file}...`);
    try {
      await db.query(sql);
      console.log(`✅ Success: ${file}`);
    } catch (err: any) {
      console.warn(`⚠️ Warning on ${file}: ${err.message}`);
    }
  }

  process.exit(0);
}

run().catch(console.error);
