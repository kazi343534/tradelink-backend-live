-- Migration: 26_independent_riders.sql
-- Description: Pivot delivery men to independent gig economy model (Foodpanda style)

-- Add new order status for searching for a rider
DO $$ BEGIN
    ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'searching_for_rider';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add a new order status for when a rider is assigned and on their way
DO $$ BEGIN
    ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'out_for_delivery';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Delivery men are now independent. They no longer belong to a specific supplier.
-- We can drop the supplier_id column from users that was added in migration 25.
ALTER TABLE public.users
DROP COLUMN IF EXISTS supplier_id;

-- Delivery men will register themselves and set their own passwords.
-- We can drop the force_password_reset column.
ALTER TABLE public.users
DROP COLUMN IF EXISTS force_password_reset;
