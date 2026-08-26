-- Migration 014: General buyer-seller direct messaging

-- 1. Conversation threads (unique per pair + optional product context)
CREATE TABLE IF NOT EXISTS public.chats (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_owner_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    stockholder_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    product_id     UUID REFERENCES public.stockholder_inventory(id) ON DELETE SET NULL,
    last_message   TEXT NOT NULL DEFAULT '',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One thread per pair per product (product-less threads use a sentinel
-- so NULL product rows also dedupe).
CREATE UNIQUE INDEX IF NOT EXISTS uq_chats_pair_product
ON public.chats (
    shop_owner_id, stockholder_id,
    COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

-- 2. Individual messages
CREATE TABLE IF NOT EXISTS public.messages (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id      UUID NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
    sender_type  TEXT NOT NULL CHECK (sender_type IN ('SHOP_OWNER', 'SUPPLIER')),
    sender_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    text_content TEXT NOT NULL CHECK (length(trim(text_content)) > 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_chat
ON public.messages(chat_id, created_at);

CREATE INDEX IF NOT EXISTS idx_chats_shop_owner ON public.chats(shop_owner_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chats_stockholder ON public.chats(stockholder_id, updated_at DESC);
