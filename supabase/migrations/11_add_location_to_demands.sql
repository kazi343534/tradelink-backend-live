-- Migration: 11_add_location_to_demands.sql
-- Description: Add delivery address and coordinates directly to demands for clarity

ALTER TABLE public.demands
ADD COLUMN IF NOT EXISTS delivery_address TEXT,
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
