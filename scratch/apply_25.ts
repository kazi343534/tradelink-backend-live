import { db } from '../backend/src/db/pool.js';
import * as fs from 'fs';
import * as path from 'path';

async function run() {
  const filePath = path.resolve('../supabase/migrations/25_delivery_men.sql');
  const sql = fs.readFileSync(filePath, 'utf-8');
  console.log('Applying 25_delivery_men.sql...');
  try {
    await db.query(sql);
    console.log('✅ Success');
  } catch (err: any) {
    console.error('❌ Error:', err);
  }
  process.exit(0);
}

run();
