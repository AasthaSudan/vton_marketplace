-- The seller accepts a new order before processing it (Blueprint fig. 34:
-- New → Confirmed → Packed → Shipped → Delivered). A new enum value must be
-- committed before anything uses it, hence its own migration.

alter type public.seller_order_status add value if not exists 'confirmed' after 'placed';
