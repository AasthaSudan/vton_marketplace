-- Seller catalogue tools (Blueprint section 39, fig. 33, and the Products,
-- Inventory and Store areas of fig. 30): drafts, submit for review,
-- moderation with a reason, unpublish / republish, stock adjustments and
-- bulk stock import, low-stock alerts, collections.

-- ---------------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------------

alter table public.products
  add column rejection_reason text,
  add column submitted_at timestamptz,
  add column reviewed_at timestamptz,
  -- Set the first time a product goes live; a product that was approved
  -- once can be unpublished and republished without another review.
  add column approved_at timestamptz,
  -- The seller asks for Try-On; moderators decide (is_tryon_eligible).
  add column tryon_requested boolean not null default false,
  -- For tax invoices (e.g. 6204 for women's dresses).
  add column hsn_code text check (hsn_code is null or hsn_code ~ '^[0-9]{4,8}$');

-- SKUs only need to be unique within a brand.
alter table public.product_variants drop constraint product_variants_sku_key;
alter table public.product_variants
  add constraint product_variants_seller_sku unique (seller_id, sku),
  add column low_stock_threshold integer not null default 3 check (low_stock_threshold >= 0),
  add column is_low_stock boolean generated always as (is_active and stock <= low_stock_threshold) stored;

create index product_variants_low_stock on public.product_variants (seller_id) where is_low_stock;

-- Handles are generated from the title when the seller does not give one.
create or replace function private.products_default_handle()
returns trigger language plpgsql as $$
begin
  if new.handle is null or trim(new.handle::text) = '' then
    new.handle := trim(both '-' from regexp_replace(lower(coalesce(new.title, 'product')),
                                                    '[^a-z0-9]+', '-', 'g'))
                  || '-' || substr(md5(gen_random_uuid()::text), 1, 6);
  end if;
  return new;
end $$;

create trigger products_default_handle before insert on public.products
  for each row execute function private.products_default_handle();

-- Status changes: only moderators (or Clothsy's own functions, which set
-- clothsy.internal) publish or reject.
create or replace function private.products_guard_status()
returns trigger language plpgsql as $$
begin
  if new.status in ('live', 'rejected')
     and (tg_op = 'INSERT' or new.status is distinct from old.status)
     and coalesce(current_setting('clothsy.internal', true), '') <> 'on'
     and coalesce((select auth.role()), 'service_role') <> 'service_role'
     and not private.is_staff(array['moderator']::public.app_role[]) then
    raise exception 'NOT_ALLOWED' using
      errcode = 'P0001',
      detail = 'Only Clothsy moderators can publish or reject products';
  end if;
  if new.status = 'live' and new.approved_at is null then
    new.approved_at := now();
  end if;
  return new;
end $$;

-- Sellers write the listing itself; status, ranking, ratings and Try-On
-- eligibility change only through Clothsy's functions.
revoke insert, update on public.products from anon, authenticated;
grant insert (seller_id, handle, title, description, category, category_handles, tags, images,
              tryon_requested, hsn_code)
  on public.products to authenticated;
grant update (title, description, category, category_handles, tags, images, tryon_requested, hsn_code)
  on public.products to authenticated;

drop policy "products: sellers manage their own" on public.products;

create policy "products: sellers add their own" on public.products
  for insert to authenticated
  with check (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    and status = 'draft'
  );

create policy "products: sellers edit their own" on public.products
  for update to authenticated
  using (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));

-- Only listings that never went live can be deleted; others are unpublished.
create policy "products: sellers delete unpublished drafts" on public.products
  for delete to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    and status in ('draft', 'rejected')
    and approved_at is null
  );

-- ---------------------------------------------------------------------------
-- Variants
-- ---------------------------------------------------------------------------

-- Stock changes go through adjust_stock / bulk_set_stock (logged with a
-- reason, safe against orders reserving at the same time).
revoke insert, update on public.product_variants from anon, authenticated;
grant insert (product_id, sku, title, size, size_rank, color_name, color_hex, price,
              compare_at_price, stock, image_url, position, is_active, low_stock_threshold)
  on public.product_variants to authenticated;
grant update (sku, title, size, size_rank, color_name, color_hex, price, compare_at_price,
              image_url, position, is_active, low_stock_threshold)
  on public.product_variants to authenticated;

drop policy "variants: sellers manage their own" on public.product_variants;

create policy "variants: sellers add their own" on public.product_variants
  for insert to authenticated
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));

create policy "variants: sellers edit their own" on public.product_variants
  for update to authenticated
  using (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));

-- Sizes of a listing that never went live can be removed; later they are
-- switched off instead (orders point at them).
create policy "variants: sellers delete unpublished" on public.product_variants
  for delete to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.approved_at is null and p.status in ('draft', 'rejected')
    )
  );

-- ---------------------------------------------------------------------------
-- Stock: notes on movements, and who did it
-- ---------------------------------------------------------------------------

alter type public.inventory_reason add value if not exists 'bulk_import';
alter table public.inventory_movements add column note text;

-- Like before, plus an optional note (clothsy.stock_note). New sizes added
-- by a seller count as a restock rather than seed data.
create or replace function private.log_stock_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  reason text := nullif(current_setting('clothsy.stock_reason', true), '');
  order_ref text := nullif(current_setting('clothsy.stock_order', true), '');
  note text := nullif(current_setting('clothsy.stock_note', true), '');
begin
  if tg_op = 'INSERT' then
    if new.stock = 0 then
      return null;
    end if;
    insert into public.inventory_movements (variant_id, seller_id, delta, reason, actor_id, note)
    values (new.id, new.seller_id, new.stock,
            coalesce(reason, case when (select auth.uid()) is null then 'seed' else 'restock' end)
              ::public.inventory_reason,
            (select auth.uid()), note);
  elsif new.stock is distinct from old.stock then
    insert into public.inventory_movements (variant_id, seller_id, delta, reason, order_id, actor_id, note)
    values (new.id, new.seller_id, new.stock - old.stock,
            coalesce(reason, 'adjustment')::public.inventory_reason,
            private.try_uuid(order_ref), (select auth.uid()), note);
  end if;
  return null;
end $$;

-- Adds (or with a negative delta removes) stock of one size; returns the
-- new stock. Any member of the brand's team may do it.
create or replace function public.adjust_stock(
  p_variant_id uuid,
  p_delta integer,
  p_note text default null
)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v public.product_variants;
begin
  select * into v from public.product_variants where id = p_variant_id for update;
  if not found or not (
    private.is_seller_member(v.seller_id)
    or private.is_staff(array['ops']::public.app_role[])
  ) then
    raise exception 'VARIANT_NOT_FOUND' using errcode = 'P0001';
  end if;
  if coalesce(p_delta, 0) = 0 then
    return v.stock;
  end if;
  if v.stock + p_delta < 0 then
    raise exception 'INSUFFICIENT_STOCK' using errcode = 'P0001',
      detail = jsonb_build_object('stock', v.stock)::text;
  end if;
  perform set_config('clothsy.stock_reason',
    case when p_delta > 0 then 'restock' else 'adjustment' end, true);
  perform set_config('clothsy.stock_note', coalesce(left(trim(p_note), 200), ''), true);
  update public.product_variants set stock = stock + p_delta where id = v.id
  returning stock into v.stock;
  perform set_config('clothsy.stock_reason', '', true);
  perform set_config('clothsy.stock_note', '', true);
  return v.stock;
end $$;
grant execute on function public.adjust_stock(uuid, integer, text) to authenticated;

-- Bulk stock import: [{"sku": "...", "stock": n}, ...] sets the units
-- available to sell (units in open orders are already taken off). All rows
-- are checked first; nothing changes unless every row is valid.
create or replace function public.bulk_set_stock(p_seller_id uuid, p_rows jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v public.product_variants;
  errors jsonb := '[]'::jsonb;
  changed integer := 0;
  unchanged integer := 0;
begin
  if not (private.is_seller_member(p_seller_id) or private.is_staff(array['ops']::public.app_role[])) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0
     or jsonb_array_length(p_rows) > 5000 then
    raise exception 'INVALID_IMPORT' using errcode = 'P0001';
  end if;

  for r in
    select x.ordinality as line, x.value ->> 'sku' as sku, x.value ->> 'stock' as stock
    from jsonb_array_elements(p_rows) with ordinality as x
  loop
    if r.stock is null or r.stock !~ '^[0-9]{1,6}$' then
      errors := errors || jsonb_build_object('line', r.line, 'sku', r.sku, 'error', 'INVALID_STOCK');
    elsif not exists (
      select 1 from public.product_variants pv
      where pv.seller_id = p_seller_id and pv.sku = trim(r.sku)
    ) then
      errors := errors || jsonb_build_object('line', r.line, 'sku', r.sku, 'error', 'UNKNOWN_SKU');
    end if;
  end loop;
  if (select count(distinct trim(x ->> 'sku')) from jsonb_array_elements(p_rows) x)
     <> jsonb_array_length(p_rows) then
    errors := errors || jsonb_build_object('error', 'DUPLICATE_SKU');
  end if;
  if jsonb_array_length(errors) > 0 then
    raise exception 'INVALID_IMPORT' using errcode = 'P0001',
      detail = jsonb_build_object('errors', errors)::text;
  end if;

  perform set_config('clothsy.stock_reason', 'bulk_import', true);
  perform set_config('clothsy.stock_note', 'Bulk stock import', true);
  for r in
    select trim(x ->> 'sku') as sku, (x ->> 'stock')::integer as stock
    from jsonb_array_elements(p_rows) x
    order by 1
  loop
    select * into v from public.product_variants
    where seller_id = p_seller_id and sku = r.sku
    for update;
    if v.stock = r.stock then
      unchanged := unchanged + 1;
    else
      update public.product_variants set stock = r.stock where id = v.id;
      changed := changed + 1;
    end if;
  end loop;
  perform set_config('clothsy.stock_reason', '', true);
  perform set_config('clothsy.stock_note', '', true);
  return jsonb_build_object('updated', changed, 'unchanged', unchanged);
end $$;
grant execute on function public.bulk_set_stock(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Listing lifecycle
-- ---------------------------------------------------------------------------

-- What a listing still needs before Clothsy can review it.
create or replace function private.product_missing(p_product_id uuid)
returns text[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_remove(array[
    case when length(trim(p.title)) < 3 then 'title' end,
    case when length(trim(p.description)) < 20 then 'description' end,
    case when trim(p.category) = '' or cardinality(p.category_handles) = 0 then 'category' end,
    case when cardinality(p.images) = 0 then 'images' end,
    case when not exists (
      select 1 from public.product_variants v where v.product_id = p.id and v.is_active)
      then 'variants' end
  ], null), '{}')
  from public.products p
  where p.id = p_product_id;
$$;

create or replace function public.submit_product(p_product_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  p public.products;
  missing text[];
begin
  select * into p from public.products where id = p_product_id for update;
  if not found or not private.is_seller_member(p.seller_id,
       array['owner', 'manager']::public.seller_member_role[]) then
    raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.sellers s where s.id = p.seller_id and s.status = 'approved') then
    raise exception 'SELLER_NOT_APPROVED' using errcode = 'P0001';
  end if;
  if p.status not in ('draft', 'rejected') then
    raise exception 'NOT_SUBMITTABLE' using errcode = 'P0001',
      detail = jsonb_build_object('status', p.status)::text;
  end if;
  missing := private.product_missing(p.id);
  if cardinality(missing) > 0 then
    raise exception 'PRODUCT_INCOMPLETE' using errcode = 'P0001',
      detail = jsonb_build_object('missing', missing)::text;
  end if;
  update public.products
  set status = 'pending_review', submitted_at = now(), rejection_reason = null
  where id = p.id;
  return jsonb_build_object('product_id', p.id, 'status', 'pending_review');
end $$;
grant execute on function public.submit_product(uuid) to authenticated;

-- Unpublish (live → archived) or republish (archived → live when it was
-- approved before, otherwise back to draft).
create or replace function public.set_product_listed(p_product_id uuid, p_listed boolean)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  p public.products;
  next_status public.product_status;
begin
  select * into p from public.products where id = p_product_id for update;
  if not found or not private.is_seller_member(p.seller_id,
       array['owner', 'manager']::public.seller_member_role[]) then
    raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0001';
  end if;
  if p_listed then
    if p.status <> 'archived' then
      raise exception 'NOT_UNPUBLISHED' using errcode = 'P0001';
    end if;
    next_status := case when p.approved_at is not null then 'live' else 'draft' end;
  else
    if p.status <> 'live' then
      raise exception 'NOT_LIVE' using errcode = 'P0001';
    end if;
    next_status := 'archived';
  end if;
  perform set_config('clothsy.internal', 'on', true);
  update public.products set status = next_status where id = p.id;
  perform set_config('clothsy.internal', '', true);
  return jsonb_build_object('product_id', p.id, 'status', next_status);
end $$;
grant execute on function public.set_product_listed(uuid, boolean) to authenticated;

-- Clothsy moderation (Admin Panel in Phase 3): approve or reject with the
-- specific reason the seller will see.
create or replace function public.moderate_product(
  p_product_id uuid,
  p_decision text,
  p_reason text default null,
  p_tryon_eligible boolean default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  p public.products;
  reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if not private.is_staff(array['moderator']::public.app_role[]) then
    raise exception 'NOT_ALLOWED' using errcode = 'P0001';
  end if;
  select * into p from public.products where id = p_product_id for update;
  if not found then
    raise exception 'PRODUCT_NOT_FOUND' using errcode = 'P0001';
  end if;
  if p.status <> 'pending_review' then
    raise exception 'NOT_IN_REVIEW' using errcode = 'P0001';
  end if;
  if p_decision = 'approve' then
    update public.products
    set status = 'live', reviewed_at = now(), rejection_reason = null,
        is_tryon_eligible = coalesce(p_tryon_eligible, p.tryon_requested),
        is_new = true
    where id = p.id;
    return jsonb_build_object('product_id', p.id, 'status', 'live');
  elsif p_decision = 'reject' then
    if reason is null then
      raise exception 'REASON_REQUIRED' using errcode = 'P0001';
    end if;
    update public.products
    set status = 'rejected', reviewed_at = now(), rejection_reason = reason
    where id = p.id;
    return jsonb_build_object('product_id', p.id, 'status', 'rejected');
  end if;
  raise exception 'INVALID_DECISION' using errcode = 'P0001';
end $$;
grant execute on function public.moderate_product(uuid, text, text, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Collections (Store → Collections)
-- ---------------------------------------------------------------------------

create table public.seller_collections (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.sellers (id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 60),
  description text not null default '',
  product_ids uuid[] not null default '{}',
  position integer not null default 0,
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index seller_collections_seller on public.seller_collections (seller_id, position);

create trigger seller_collections_updated_at before update on public.seller_collections
  for each row execute function private.set_updated_at();

alter table public.seller_collections enable row level security;

create policy "collections: visible ones of approved brands are public" on public.seller_collections
  for select to anon, authenticated
  using (
    (is_visible and exists (
      select 1 from public.sellers s where s.id = seller_id and s.status = 'approved'))
    or private.is_seller_member(seller_id)
  );

create policy "collections: team manages" on public.seller_collections
  for all to authenticated
  using (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));
