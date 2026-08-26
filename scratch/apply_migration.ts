import { db } from '../backend/src/db/pool.js';
import * as fs from 'fs';
import * as path from 'path';

async function run() {
  const sql = fs.readFileSync(path.resolve('../supabase/migrations/13_add_supplier_match_count.sql'), 'utf-8');
  console.log('Running migration...');
  await db.query(sql);
  console.log('Migration applied successfully.');
  process.exit(0);
}

run().catch(console.error);
