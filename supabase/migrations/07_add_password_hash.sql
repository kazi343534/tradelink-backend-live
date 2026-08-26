-- Migration: 07_add_password_hash.sql
-- Description: Add password_hash column to users table for manual authentication.

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS password_hash TEXT;
