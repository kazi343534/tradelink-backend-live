-- data_wipe.sql
-- Description: Wipes all data from TradeLink tables. Use with caution!
-- This will delete all rows from the specified tables and any rows in tables that reference them (CASCADE).

TRUNCATE TABLE 
    public.otps,
    public.user_auth_otps,
    public.ratings,
    public.orders,
    public.demands,
    public.stockholder_inventory,
    public.stocks,
    public.notifications,
    public.users,
    public.master_products,
    public.products
CASCADE;
