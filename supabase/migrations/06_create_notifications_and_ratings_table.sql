-- Migration: 06_create_notifications_and_ratings_table.sql
-- Description: In-app notifications and Supplier ratings & reviews

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    type TEXT DEFAULT 'info',
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    shop_owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    review TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select on notifications"
ON public.notifications FOR SELECT USING (true);

CREATE POLICY "Allow insert on notifications"
ON public.notifications FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow update on notifications"
ON public.notifications FOR UPDATE USING (true);

CREATE POLICY "Allow select on ratings"
ON public.ratings FOR SELECT USING (true);

CREATE POLICY "Allow insert on ratings"
ON public.ratings FOR INSERT WITH CHECK (true);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_ratings_supplier_id ON public.ratings(supplier_id);
