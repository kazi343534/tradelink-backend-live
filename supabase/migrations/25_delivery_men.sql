-- Migration: 25_delivery_men.sql
-- Description: Add delivery man role, supplier link, and force password reset

DO $$ BEGIN
    ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'delivery_man';
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS force_password_reset BOOLEAN DEFAULT false;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS delivery_man_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
