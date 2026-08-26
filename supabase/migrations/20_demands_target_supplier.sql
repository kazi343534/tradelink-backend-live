-- Migration 010: Route chatbot-originated demands to a specific supplier
ALTER TABLE public.demands
ADD COLUMN IF NOT EXISTS target_supplier_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_demands_target_supplier
ON public.demands(target_supplier_id)
WHERE target_supplier_id IS NOT NULL;
