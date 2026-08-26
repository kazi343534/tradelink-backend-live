-- Migration: 10_add_preferred_language.sql
-- Description: Add preferred_language field to users table for localization

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'English';
