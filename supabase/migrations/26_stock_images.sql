-- Persistent product image storage (replaces ephemeral local /uploads disk,
-- which Render wipes on every restart/redeploy).
CREATE TABLE IF NOT EXISTS public.stock_images (
  stock_id  UUID PRIMARY KEY REFERENCES public.stockholder_inventory(id) ON DELETE CASCADE,
  mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
  data      BYTEA NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
