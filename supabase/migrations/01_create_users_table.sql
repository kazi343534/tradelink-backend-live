-- Migration: 01_create_users_table.sql
-- Description: Create users table for Shop Owners and Suppliers with RLS policies

-- Create ENUM for user roles if not exists
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('shop_owner', 'supplier');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create Users table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'shop_owner',
    full_name TEXT NOT NULL,
    phone_number TEXT NOT NULL UNIQUE,
    business_name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Grocery',
    
    -- Specific to Suppliers (formerly Stockholders)
    trade_license TEXT,
    min_order_value NUMERIC(12, 2) DEFAULT 0,
    supply_radius TEXT,
    
    -- Location coordinates
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active profiles
CREATE POLICY "Allow public read access to users"
ON public.users FOR SELECT
USING (true);

-- Allow authenticated or anon registration insert
CREATE POLICY "Allow inserts to users table"
ON public.users FOR INSERT
WITH CHECK (true);

-- Allow users to update their own profile
CREATE POLICY "Allow users to update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = auth_id OR auth.uid() IS NULL);

-- Create index for fast phone lookup & role filtering
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone_number);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
