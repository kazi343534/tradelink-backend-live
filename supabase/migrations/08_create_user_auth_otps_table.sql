-- Migration: 08_create_user_auth_otps_table.sql
-- Description: One-time passwords for Shop Owner & Stockholder (Supplier)
--              phone-based LOGIN. Registration does NOT use OTP.
--              Separate from public.otps (delivery verification). Keyed by
--              phone_number + role.

CREATE TABLE IF NOT EXISTS public.user_auth_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'shop_owner',
    otp_code VARCHAR(6) NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    attempts INTEGER NOT NULL DEFAULT 0,            -- brute-force guard
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() + interval '5 minutes'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_auth_otps_phone_role
ON public.user_auth_otps(phone_number, role, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_auth_otps_expires_at
ON public.user_auth_otps(expires_at);

-- Enable RLS
ALTER TABLE public.user_auth_otps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select on user_auth_otps"
ON public.user_auth_otps FOR SELECT USING (true);

CREATE POLICY "Allow insert on user_auth_otps"
ON public.user_auth_otps FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update on user_auth_otps"
ON public.user_auth_otps FOR UPDATE USING (true);

CREATE POLICY "Allow delete on user_auth_otps"
ON public.user_auth_otps FOR DELETE USING (true);

-- Invalidate older unverified OTPs when a new one is issued
CREATE OR REPLACE FUNCTION invalidate_previous_otps(
    p_phone_number TEXT,
    p_role user_role
)
RETURNS void AS $$
BEGIN
    UPDATE public.user_auth_otps
    SET is_verified = true
    WHERE phone_number = p_phone_number
      AND role = p_role
      AND is_verified = false;
END;
$$ LANGUAGE plpgsql;

-- Purge stale expired rows (pg_cron or backend-triggered)
CREATE OR REPLACE FUNCTION purge_expired_auth_otps()
RETURNS void AS $$
BEGIN
    DELETE FROM public.user_auth_otps
    WHERE expires_at < now() - interval '1 day';
END;
$$ LANGUAGE plpgsql;
