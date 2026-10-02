-- Pricing primitives (identical to the Dart domain, checked by the generated
-- parity tests) and server-side coupons.

-- Per-seller shipment charge: free at or above ₹1,999, else ₹150; nothing
-- for an empty shipment. Mirrors SellerBagGroup.shippingFee.
create or replace function private.shipping_fee(subtotal bigint)
returns integer language sql immutable as $$
  select case
    when subtotal <= 0 then 0
    when subtotal >= 199900 then 0
    else 15000
  end;
$$;

-- Splits [amount] paise across [weights] without losing or inventing a
-- paisa: floor every share, then give the leftover paise to the largest
-- remainders (ties to the earlier share). Line-for-line port of
-- splitProportionally in packages/clothsy_core/lib/core/utils/money_split.dart.
create or replace function private.split_proportionally(amount bigint, weights bigint[])
returns integer[] language plpgsql immutable as $$
declare
  n integer := coalesce(array_length(weights, 1), 0);
  total bigint := 0;
  shares bigint[] := '{}';
  remainders bigint[] := '{}';
  leftover bigint;
  i integer;
  pick integer;
begin
  if n = 0 then
    return '{}';
  end if;
  if amount < 0 then
    return (select array_agg(-s order by o)
            from unnest(private.split_proportionally(-amount, weights)) with ordinality as t(s, o));
  end if;
  for i in 1..n loop
    total := total + weights[i];
  end loop;
  if total <= 0 or amount = 0 then
    return array_fill(0, array[n]);
  end if;
  for i in 1..n loop
    shares := shares || ((amount * weights[i]) / total);
    remainders := remainders || ((amount * weights[i]) % total);
  end loop;
  leftover := amount;
  for i in 1..n loop
    leftover := leftover - shares[i];
  end loop;
  while leftover > 0 loop
    -- Largest remainder first; ties go to the earliest share.
    select o into pick
    from unnest(remainders) with ordinality as r(rem, o)
    order by rem desc, o asc
    limit 1;
    shares[pick] := shares[pick] + 1;
    remainders[pick] := -1;
    leftover := leftover - 1;
  end loop;
  return shares::integer[];
end $$;

-- Seller-order letter: A..Z, then 27, 28... Mirrors OrderSplitter.suffix.
create or replace function private.seller_suffix(i integer)
returns text language sql immutable as $$
  select case when i < 26 then chr(65 + i) else (i + 1)::text end;
$$;

-- ---------------------------------------------------------------------------
-- Coupons
-- ---------------------------------------------------------------------------

create type public.discount_kind as enum ('percent', 'flat');

create table public.coupons (
  id uuid primary key default gen_random_uuid(),
  code extensions.citext not null unique,
  kind public.discount_kind not null,
  percent_bps integer check (percent_bps between 1 and 10000),
  flat_amount integer check (flat_amount > 0),
  max_discount integer check (max_discount > 0),
  min_subtotal integer not null default 0 check (min_subtotal >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  usage_limit integer check (usage_limit > 0),
  per_customer_limit integer check (per_customer_limit > 0),
  first_order_only boolean not null default false,
  is_active boolean not null default true,
  funded_by text not null default 'platform' check (funded_by in ('platform', 'seller')),
  created_at timestamptz not null default now(),
  check (
    (kind = 'percent' and percent_bps is not null and flat_amount is null)
    or (kind = 'flat' and flat_amount is not null and percent_bps is null)
  )
);

create table public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons (id),
  order_id uuid not null unique,
  customer_id uuid not null,
  amount integer not null check (amount >= 0),
  voided_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.coupons enable row level security;
alter table public.coupon_redemptions enable row level security;

-- Coupons are not listable by shoppers (no guessing codes); validate_coupon
-- checks one code at a time.
create policy "coupons: staff manage" on public.coupons
  for all to authenticated
  using (private.is_staff(array['growth', 'finance']::public.app_role[]))
  with check (private.is_staff(array['growth', 'finance']::public.app_role[]));

create policy "redemptions: own" on public.coupon_redemptions
  for select to authenticated
  using (customer_id = (select auth.uid()) or private.is_staff(array['finance', 'growth']::public.app_role[]));

-- Discount for [goods] paise: integer maths rounded half up, capped, never
-- more than the goods. Same formula as CouponRule.discountFor in Dart.
create or replace function private.coupon_discount(c public.coupons, goods bigint)
returns integer language sql immutable as $$
  select case
    when goods <= 0 or goods < c.min_subtotal then 0
    else least(
      goods,
      coalesce(c.max_discount, 2147483647),
      case c.kind
        when 'percent' then (goods * c.percent_bps + 5000) / 10000
        else c.flat_amount
      end
    )::integer
  end;
$$;

-- The usable coupon for [code], or an error code: COUPON_INVALID,
-- COUPON_EXPIRED, COUPON_MIN_NOT_MET or COUPON_LIMIT_REACHED.
create or replace function private.resolve_coupon(p_code text, p_goods bigint, p_customer uuid)
returns public.coupons
language plpgsql stable security definer set search_path = '' as $$
declare
  c public.coupons;
  used integer;
begin
  -- lower() on both sides: with an empty search_path citext's own `=` is not
  -- visible, and a plain text comparison would be case-sensitive.
  select * into c from public.coupons x
  where lower(x.code::text) = lower(trim(p_code)) and x.is_active;
  if not found then
    raise exception 'COUPON_INVALID' using errcode = 'P0001';
  end if;
  if (c.starts_at is not null and c.starts_at > now())
     or (c.ends_at is not null and c.ends_at <= now()) then
    raise exception 'COUPON_EXPIRED' using errcode = 'P0001';
  end if;
  if p_goods < c.min_subtotal then
    raise exception 'COUPON_MIN_NOT_MET' using
      errcode = 'P0001', detail = jsonb_build_object('min_subtotal', c.min_subtotal)::text;
  end if;
  if c.usage_limit is not null then
    select count(*) into used from public.coupon_redemptions r
    where r.coupon_id = c.id and r.voided_at is null;
    if used >= c.usage_limit then
      raise exception 'COUPON_LIMIT_REACHED' using errcode = 'P0001';
    end if;
  end if;
  if p_customer is not null and c.per_customer_limit is not null then
    select count(*) into used from public.coupon_redemptions r
    where r.coupon_id = c.id and r.customer_id = p_customer and r.voided_at is null;
    if used >= c.per_customer_limit then
      raise exception 'COUPON_LIMIT_REACHED' using errcode = 'P0001';
    end if;
  end if;
  if p_customer is not null and c.first_order_only and exists (
    select 1 from public.orders o
    where o.customer_id = p_customer and o.payment_status in ('paid', 'cod', 'partially_refunded', 'refunded')
  ) then
    raise exception 'COUPON_LIMIT_REACHED' using
      errcode = 'P0001', detail = 'first_order_only';
  end if;
  return c;
end $$;

-- {valid, reason, rule} for showing a coupon in the bag. The rule lets the
-- app recompute the discount as quantities change; place_order re-checks.
create or replace function public.validate_coupon(p_code text, p_goods_subtotal integer)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  c public.coupons;
begin
  c := private.resolve_coupon(p_code, p_goods_subtotal, (select auth.uid()));
  return jsonb_build_object(
    'valid', true,
    'rule', jsonb_build_object(
      'code', c.code::text,
      'percent_bps', c.percent_bps,
      'flat_amount', c.flat_amount,
      'max_discount', c.max_discount,
      'min_subtotal', c.min_subtotal));
exception when sqlstate 'P0001' then
  return jsonb_build_object('valid', false, 'reason', sqlerrm);
end $$;

grant execute on function public.validate_coupon(text, integer) to anon, authenticated;
