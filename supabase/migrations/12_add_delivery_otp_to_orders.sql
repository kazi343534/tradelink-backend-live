-- Migration: Add delivery_otp to orders table and update status lifecycle
-- New lifecycle: pending -> accepted -> out_for_delivery -> delivered

-- Add delivery_otp column directly to orders (simpler than separate otps table)
ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS delivery_otp VARCHAR(6);

-- Update the order_status enum to support 'out_for_delivery'
-- PostgreSQL doesn't allow removing enum values, so we add the new one
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'out_for_delivery' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN
    ALTER TYPE public.order_status ADD VALUE IF NOT EXISTS 'out_for_delivery' AFTER 'accepted';
  END IF;
END $$;
