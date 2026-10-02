-- Sellers (brand storefronts) and the catalogue: products, variants (SKUs)
-- with stock, and an append-only stock movement ledger.

create type public.seller_status as enum ('pending', 'approved', 'suspended');
create type public.product_status as enum (
  'draft', 'pending_review', 'live', 'rejected', 'archived'
);
create type public.inventory_reason as enum (
  'seed', 'restock', 'adjustment', 'order_reserve', 'order_release'
);

-- ---------------------------------------------------------------------------
-- Sellers
-- ---------------------------------------------------------------------------

create table public.sellers (
  id uuid primary key default gen_random_uuid(),
  handle extensions.citext not null unique,
  name text not null,
  tagline text not null default '',
  story text not null default '',
  logo_url text,
  banner_url text,
  city text not null default '',
  status public.seller_status not null default 'pending',
  is_verified boolean not null default false,
  is_independent boolean not null default true,
  follower_count integer not null default 0 check (follower_count >= 0),
  rating numeric(2, 1) not null default 0 check (rating between 0 and 5),
  dispatch_days integer not null default 2 check (dispatch_days between 1 and 30),
  return_window_days integer not null default 7 check (return_window_days between 0 and 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger sellers_updated_at before update on public.sellers
  for each row execute function private.set_updated_at();

create table public.seller_members (
  seller_id uuid not null references public.sellers (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.seller_member_role not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (seller_id, user_id)
);

create or replace function private.is_seller_member(
  seller uuid,
  roles public.seller_member_role[] default null
)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.seller_members m
    where m.seller_id = seller
      and m.user_id = (select auth.uid())
      and (roles is null or m.role = any (roles))
  );
$$;
grant execute on function private.is_seller_member(uuid, public.seller_member_role[])
  to anon, authenticated;

alter table public.sellers enable row level security;
alter table public.seller_members enable row level security;

-- Sellers may edit their storefront, never their status or verified badge.
revoke update on public.sellers from authenticated;
grant update (name, tagline, story, logo_url, banner_url, city, dispatch_days, return_window_days)
  on public.sellers to authenticated;

create policy "sellers: approved are public" on public.sellers
  for select to anon, authenticated
  using (
    status = 'approved'
    or private.is_seller_member(id)
    or private.is_staff(array['ops', 'moderator']::public.app_role[])
  );

create policy "sellers: owners edit storefront" on public.sellers
  for update to authenticated
  using (private.is_seller_member(id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(id, array['owner', 'manager']::public.seller_member_role[]));

create policy "sellers: staff manage" on public.sellers
  for all to authenticated
  using (private.is_staff(array['ops', 'moderator']::public.app_role[]))
  with check (private.is_staff(array['ops', 'moderator']::public.app_role[]));

create policy "seller_members: see own team" on public.seller_members
  for select to authenticated
  using (private.is_seller_member(seller_id) or private.is_staff());

create policy "seller_members: staff manage" on public.seller_members
  for all to authenticated
  using (private.is_staff(array['ops']::public.app_role[]))
  with check (private.is_staff(array['ops']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- Categories and banners (CMS-light, Phase 3 adds an editor)
-- ---------------------------------------------------------------------------

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  handle text not null unique,
  title text not null,
  icon_name text,
  sort_order integer not null default 0
);

create table public.banners (
  id uuid primary key default gen_random_uuid(),
  headline text not null,
  subtitle text not null default '',
  cta_text text not null default 'Shop now',
  image_url text not null,
  deep_link text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz
);

alter table public.categories enable row level security;
alter table public.banners enable row level security;

create policy "categories: public" on public.categories
  for select to anon, authenticated using (true);
create policy "categories: staff manage" on public.categories
  for all to authenticated
  using (private.is_staff(array['growth', 'ops']::public.app_role[]))
  with check (private.is_staff(array['growth', 'ops']::public.app_role[]));

create policy "banners: live ones are public" on public.banners
  for select to anon, authenticated
  using (
    is_active
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  );
create policy "banners: staff manage" on public.banners
  for all to authenticated
  using (private.is_staff(array['growth', 'ops']::public.app_role[]))
  with check (private.is_staff(array['growth', 'ops']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- Products and variants
-- ---------------------------------------------------------------------------

create table public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.sellers (id),
  handle extensions.citext not null unique,
  title text not null,
  description text not null default '',
  -- Display category, e.g. 'Dresses'.
  category text not null default '',
  -- Every category chip the product shows under, e.g. {women,dresses}.
  category_handles text[] not null default '{}',
  tags text[] not null default '{}',
  images text[] not null default '{}',
  rating numeric(2, 1) not null default 0 check (rating between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  is_tryon_eligible boolean not null default false,
  is_featured boolean not null default false,
  is_new boolean not null default false,
  status public.product_status not null default 'draft',
  sort_rank integer not null default 0,
  -- Maintained from the variants (cheapest active price, paise).
  min_price integer not null default 0,
  min_compare_at_price integer,
  search_text text not null default '',
  search_vector tsvector,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_seller_status on public.products (seller_id, status);
create index products_live_rank on public.products (sort_rank) where status = 'live';
create index products_category_handles on public.products using gin (category_handles);
create index products_min_price on public.products (min_price);
create index products_review_count on public.products (review_count desc);

create trigger products_updated_at before update on public.products
  for each row execute function private.set_updated_at();

create table public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  -- Copied from the product so policies need no join.
  seller_id uuid not null references public.sellers (id),
  sku text not null unique,
  title text not null,
  size text not null,
  size_rank integer not null default 0,
  color_name text not null default '',
  color_hex text not null default '',
  price integer not null check (price > 0),
  compare_at_price integer check (compare_at_price is null or compare_at_price > price),
  stock integer not null default 0 check (stock >= 0),
  image_url text,
  position integer not null default 0,
  is_active boolean not null default true
);

create index product_variants_product on public.product_variants (product_id, position);

-- Variants always belong to their product's seller.
create or replace function private.variant_sync_seller()
returns trigger language plpgsql as $$
begin
  select p.seller_id into new.seller_id from public.products p where p.id = new.product_id;
  return new;
end $$;

create trigger product_variants_seller before insert or update of product_id
  on public.product_variants
  for each row execute function private.variant_sync_seller();

-- Keeps products.min_price / min_compare_at_price in step with the variants.
create or replace function private.sync_product_price()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  target uuid := coalesce(new.product_id, old.product_id);
begin
  update public.products p
  set min_price = coalesce(v.min_price, 0),
      min_compare_at_price = v.min_compare
  from (
    select min(price) as min_price, min(compare_at_price) as min_compare
    from public.product_variants
    where product_id = target and is_active
  ) v
  where p.id = target;
  return null;
end $$;

create trigger product_variants_price after insert or update or delete
  on public.product_variants
  for each row execute function private.sync_product_price();

-- Sellers can draft and submit; only moderators make a product live or
-- reject it (Blueprint fig. 33).
create or replace function private.products_guard_status()
returns trigger language plpgsql as $$
begin
  if new.status in ('live', 'rejected')
     and (tg_op = 'INSERT' or new.status is distinct from old.status)
     and coalesce((select auth.role()), 'service_role') <> 'service_role'
     and not private.is_staff(array['moderator']::public.app_role[]) then
    raise exception 'NOT_ALLOWED' using
      errcode = 'P0001',
      detail = 'Only Clothsy moderators can publish or reject products';
  end if;
  return new;
end $$;

create trigger products_status_guard before insert or update of status
  on public.products
  for each row execute function private.products_guard_status();

alter table public.products enable row level security;
alter table public.product_variants enable row level security;

create policy "products: live from approved sellers are public" on public.products
  for select to anon, authenticated
  using (
    (status = 'live' and exists (
      select 1 from public.sellers s where s.id = seller_id and s.status = 'approved'
    ))
    or private.is_seller_member(seller_id)
    or private.is_staff(array['moderator', 'ops']::public.app_role[])
  );

create policy "products: sellers manage their own" on public.products
  for all to authenticated
  using (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));

create policy "products: staff manage" on public.products
  for all to authenticated
  using (private.is_staff(array['moderator', 'ops']::public.app_role[]))
  with check (private.is_staff(array['moderator', 'ops']::public.app_role[]));

create policy "variants: visible with their product" on public.product_variants
  for select to anon, authenticated
  using (exists (select 1 from public.products p where p.id = product_id));

create policy "variants: sellers manage their own" on public.product_variants
  for all to authenticated
  using (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));

create policy "variants: staff manage" on public.product_variants
  for all to authenticated
  using (private.is_staff(array['ops']::public.app_role[]))
  with check (private.is_staff(array['ops']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- Stock movements (append-only)
-- ---------------------------------------------------------------------------

create table public.inventory_movements (
  id bigserial primary key,
  variant_id uuid not null references public.product_variants (id) on delete cascade,
  seller_id uuid not null,
  delta integer not null,
  reason public.inventory_reason not null,
  order_id uuid,
  actor_id uuid,
  created_at timestamptz not null default now()
);

create index inventory_movements_variant on public.inventory_movements (variant_id, created_at);

create trigger inventory_movements_append_only before update or delete
  on public.inventory_movements
  for each row execute function private.append_only();

-- Every stock change is logged. The reason and order come from transaction
-- settings that the order functions set (`clothsy.stock_reason`,
-- `clothsy.stock_order`); anything else is an adjustment.
create or replace function private.log_stock_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  reason text := nullif(current_setting('clothsy.stock_reason', true), '');
  order_ref text := nullif(current_setting('clothsy.stock_order', true), '');
begin
  if tg_op = 'INSERT' then
    if new.stock = 0 then
      return null;
    end if;
    insert into public.inventory_movements (variant_id, seller_id, delta, reason, actor_id)
    values (new.id, new.seller_id, new.stock,
            coalesce(reason, 'seed')::public.inventory_reason, (select auth.uid()));
  elsif new.stock is distinct from old.stock then
    insert into public.inventory_movements (variant_id, seller_id, delta, reason, order_id, actor_id)
    values (new.id, new.seller_id, new.stock - old.stock,
            coalesce(reason, 'adjustment')::public.inventory_reason,
            private.try_uuid(order_ref), (select auth.uid()));
  end if;
  return null;
end $$;

create trigger product_variants_stock_log after insert or update of stock
  on public.product_variants
  for each row execute function private.log_stock_change();

alter table public.inventory_movements enable row level security;

create policy "inventory: sellers see their own" on public.inventory_movements
  for select to authenticated
  using (private.is_seller_member(seller_id) or private.is_staff(array['ops']::public.app_role[]));
