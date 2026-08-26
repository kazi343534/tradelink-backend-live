-- Migration 009: Custom demand posting with target price + 'Open' status
-- 1. Add 'open' to demand_status enum (must run outside transaction)
ALTER TYPE demand_status ADD VALUE IF NOT EXISTS 'open' BEFORE 'pending';

-- 2. Budget / target price offered by the shop owner
ALTER TABLE public.demands
ADD COLUMN IF NOT EXISTS target_price NUMERIC(12,2);

-- 3. Backfill: existing open demands become 'open'
UPDATE public.demands SET status = 'open' WHERE status = 'pending';
