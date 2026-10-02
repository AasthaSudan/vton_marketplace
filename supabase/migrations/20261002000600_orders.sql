-- Orders (Blueprint fig. 17, 20, 21): one parent order and payment per
-- checkout, split into one seller order per brand, each with its own items,
-- status, shipment and refundable total. Status history is append-only.

create type public.payment_method as enum ('upi', 'card', 'net_banking', 'cod');
create type public.order_payment_status as enum (
  'pending', 'paid', 'cod', 'failed', 'partially_refunded', 'refunded'
);
create type public.seller_order_status as enum (
  'pending_payment', 'placed', 'packed', 'shipped', 'out_for_delivery',
  'delivered', 'cancelled', 'returned'
);
create type public.shipment_status as enum (
  'pending', 'in_transit', 'out_for_delivery', 'delivered', 'returned'
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid references auth.users (id) on delete set null,
  idempotency_key uuid not null,
  request_hash text not null,
  payment_method public.payment_method not null,
  payment_label text not null,
  payment_status public.order_payment_status not null,
  subtotal integer not null check (subtotal >= 0),
  shipping_total integer not null check (shipping_total >= 0),
  discount_total integer not null check (discount_total >= 0),
  grand_total integer not null check (grand_total >= 0),
  coupon_id uuid references public.coupons (id),
  coupon_code text,
  -- Address as it was when the order was placed.
  shipping_address jsonb not null,
  -- Stock is held until then while an online payment is pending.
  reserved_until timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (customer_id, idempotency_key)
);

create index orders_customer on public.orders (customer_id, created_at desc);
create index orders_pending_reservation on public.orders (reserved_until)
  where payment_status = 'pending';

create trigger orders_updated_at before update on public.orders
  for each row execute function private.set_updated_at();

create table public.seller_orders (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  seller_id uuid not null references public.sellers (id),
  -- Copied from the order so policies need no join.
  customer_id uuid,
  -- e.g. CLY-48211903-A
  reference text not null unique,
  position integer not null,
  seller_name text not null,
  status public.seller_order_status not null,
  subtotal integer not null check (subtotal >= 0),
  shipping_fee integer not null check (shipping_fee >= 0),
  discount_share integer not null default 0 check (discount_share >= 0),
  total integer generated always as (greatest(subtotal + shipping_fee - discount_share, 0)) stored,
  cancel_reason text,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id, seller_id)
);

create index seller_orders_seller on public.seller_orders (seller_id, created_at desc);
create index seller_orders_customer on public.seller_orders (customer_id);

create trigger seller_orders_updated_at before update on public.seller_orders
  for each row execute function private.set_updated_at();

-- Seller orders only move forward along placed → packed → shipped →
-- out for delivery → delivered; they can be cancelled before shipping and
-- returned after delivery (Blueprint fig. 20 and 34).
create or replace function private.seller_order_rank(s public.seller_order_status)
returns integer language sql immutable as $$
  select case s
    when 'pending_payment' then 0
    when 'placed' then 1
    when 'packed' then 2
    when 'shipped' then 3
    when 'out_for_delivery' then 4
    when 'delivered' then 5
    else -1
  end;
$$;

create or replace function private.seller_orders_guard_transition()
returns trigger language plpgsql as $$
begin
  if new.status = old.status then
    return new;
  end if;
  if old.status in ('cancelled', 'returned') then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → %s', old.status, new.status);
  end if;
  if new.status = 'cancelled' then
    if old.status not in ('pending_payment', 'placed', 'packed') then
      raise exception 'NOT_CANCELLABLE' using errcode = 'P0001';
    end if;
  elsif new.status = 'returned' then
    if old.status <> 'delivered' then
      raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
        detail = format('%s → %s', old.status, new.status);
    end if;
  elsif private.seller_order_rank(new.status) <= private.seller_order_rank(old.status) then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → %s', old.status, new.status);
  end if;
  return new;
end $$;

create trigger seller_orders_transition before update of status on public.seller_orders
  for each row execute function private.seller_orders_guard_transition();

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  seller_order_id uuid not null references public.seller_orders (id) on delete cascade,
  customer_id uuid,
  seller_id uuid not null,
  product_id uuid not null references public.products (id),
  variant_id uuid not null references public.product_variants (id),
  -- Snapshot of what was bought, so later catalogue edits never change it.
  title text not null,
  variant_title text not null,
  size text not null,
  color_name text not null,
  color_hex text not null,
  image_url text,
  unit_price integer not null check (unit_price > 0),
  compare_at_price integer,
  quantity integer not null check (quantity between 1 and 10),
  line_total integer generated always as (unit_price * quantity) stored,
  position integer not null default 0
);

create index order_items_seller_order on public.order_items (seller_order_id);

create table public.shipments (
  id uuid primary key default gen_random_uuid(),
  seller_order_id uuid not null references public.seller_orders (id) on delete cascade,
  seller_id uuid not null,
  customer_id uuid,
  carrier text,
  tracking_number text,
  status public.shipment_status not null default 'pending',
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.order_events (
  id bigserial primary key,
  order_id uuid not null references public.orders (id) on delete cascade,
  seller_order_id uuid references public.seller_orders (id) on delete cascade,
  customer_id uuid,
  event_type text not null,
  from_status text,
  to_status text,
  actor_id uuid,
  actor_role text not null default 'system'
    check (actor_role in ('customer', 'seller', 'staff', 'system')),
  -- Shown on the shopper's tracking timeline.
  customer_visible boolean not null default true,
  note text,
  payload jsonb,
  created_at timestamptz not null default now()
);

create index order_events_order on public.order_events (order_id, created_at);

create trigger order_events_append_only before update or delete on public.order_events
  for each row execute function private.append_only();

-- ---------------------------------------------------------------------------
-- Row level security: shoppers read their own orders (changes only through
-- the order functions); sellers see only their own part, never other
-- sellers' parts or payment details.
-- ---------------------------------------------------------------------------

alter table public.orders enable row level security;
alter table public.seller_orders enable row level security;
alter table public.order_items enable row level security;
alter table public.shipments enable row level security;
alter table public.order_events enable row level security;

revoke insert, update, delete on public.orders, public.seller_orders,
  public.order_items, public.order_events from anon, authenticated;
revoke insert, update, delete on public.shipments from anon;

create policy "orders: own" on public.orders
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or private.is_staff(array['ops', 'support', 'finance']::public.app_role[])
  );

create policy "seller_orders: customer or seller" on public.seller_orders
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or private.is_seller_member(seller_id)
    or private.is_staff(array['ops', 'support', 'finance']::public.app_role[])
  );

create policy "order_items: customer or seller" on public.order_items
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or private.is_seller_member(seller_id)
    or private.is_staff(array['ops', 'support', 'finance']::public.app_role[])
  );

create policy "shipments: customer or seller" on public.shipments
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or private.is_seller_member(seller_id)
    or private.is_staff(array['ops', 'support']::public.app_role[])
  );

create policy "shipments: seller or ops write" on public.shipments
  for all to authenticated
  using (private.is_seller_member(seller_id) or private.is_staff(array['ops']::public.app_role[]))
  with check (private.is_seller_member(seller_id) or private.is_staff(array['ops']::public.app_role[]));

create policy "order_events: visible ones" on public.order_events
  for select to authenticated
  using (
    (customer_id = (select auth.uid()) and customer_visible)
    or (seller_order_id is not null and exists (
      select 1 from public.seller_orders so
      where so.id = seller_order_id and private.is_seller_member(so.seller_id)
    ))
    or private.is_staff()
  );
