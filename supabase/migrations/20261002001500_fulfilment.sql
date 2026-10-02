-- Seller order fulfilment (Blueprint section 40, fig. 34-35): accept a new
-- order, pack it (the tax invoice is numbered then), hand it to the courier
-- with its tracking number, and follow it to delivery. A seller who cannot
-- fulfil cancels with a reason before packing; the shopper is refunded
-- automatically and the cancellation counts against the seller's
-- performance score.

alter table public.seller_orders
  -- Dispatch promise: placed + the brand's dispatch days.
  add column dispatch_by timestamptz,
  add column accepted_at timestamptz,
  add column packed_at timestamptz,
  add column shipped_at timestamptz,
  add column delivered_at timestamptz,
  add column cancelled_by text check (cancelled_by in ('customer', 'seller', 'staff', 'system')),
  add column invoice_number text,
  add column invoice_date date,
  add constraint seller_orders_invoice_number unique (seller_id, invoice_number);

alter table public.shipments add column tracking_url text;

-- ---------------------------------------------------------------------------
-- Status machine
-- ---------------------------------------------------------------------------

create or replace function private.seller_order_rank(s public.seller_order_status)
returns integer language sql immutable as $$
  select case s
    when 'pending_payment' then 0
    when 'placed' then 1
    when 'confirmed' then 2
    when 'packed' then 3
    when 'shipped' then 4
    when 'out_for_delivery' then 5
    when 'delivered' then 6
    else -1
  end;
$$;

-- Each step only leads to the next ones: nothing skips packing or shipping
-- on the way to delivered.
create or replace function private.seller_orders_guard_transition()
returns trigger language plpgsql as $$
declare
  allowed boolean;
begin
  if new.status = old.status then
    return new;
  end if;
  allowed := case old.status
    when 'pending_payment' then new.status in ('placed', 'cancelled')
    when 'placed' then new.status in ('confirmed', 'packed', 'cancelled')
    when 'confirmed' then new.status in ('packed', 'cancelled')
    when 'packed' then new.status in ('shipped', 'cancelled')
    when 'shipped' then new.status in ('out_for_delivery', 'delivered')
    when 'out_for_delivery' then new.status = 'delivered'
    when 'delivered' then new.status = 'returned'
    else false
  end;
  if not allowed then
    if new.status = 'cancelled' then
      raise exception 'NOT_CANCELLABLE' using errcode = 'P0001',
        detail = jsonb_build_object('status', old.status)::text;
    end if;
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → %s', old.status, new.status);
  end if;
  return new;
end $$;

-- When each step happened, and the dispatch promise once an order is placed.
create or replace function private.seller_orders_timestamps()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'placed' and new.dispatch_by is null then
    new.dispatch_by := now() + make_interval(days => coalesce(
      (select s.dispatch_days from public.sellers s where s.id = new.seller_id), 2));
  end if;
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    case new.status
      when 'confirmed' then new.accepted_at := now();
      when 'packed' then new.packed_at := now();
      when 'shipped' then new.shipped_at := now();
      when 'delivered' then new.delivered_at := now();
      else null;
    end case;
  end if;
  return new;
end $$;

create trigger seller_orders_timestamps before insert or update of status on public.seller_orders
  for each row execute function private.seller_orders_timestamps();

-- The parcel follows the order's last-mile steps.
create or replace function private.seller_orders_sync_shipment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'out_for_delivery' then
    update public.shipments set status = 'out_for_delivery' where seller_order_id = new.id;
  elsif new.status = 'delivered' then
    update public.shipments set status = 'delivered', delivered_at = now()
    where seller_order_id = new.id;
  elsif new.status = 'returned' then
    update public.shipments set status = 'returned' where seller_order_id = new.id;
  end if;
  return null;
end $$;

create trigger seller_orders_sync_shipment after update of status on public.seller_orders
  for each row when (new.status is distinct from old.status)
  execute function private.seller_orders_sync_shipment();

-- ---------------------------------------------------------------------------
-- Cancelling: who cancelled is recorded; a confirmed order can still be
-- cancelled by the shopper (until it ships) or the seller (until packed).
-- ---------------------------------------------------------------------------

create or replace function private.cancel_part(
  p_order public.orders,
  p_seller_order public.seller_orders,
  p_reason text,
  p_actor text
)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  pay public.payments;
  refund integer := 0;
begin
  update public.seller_orders
  set status = 'cancelled', cancel_reason = p_reason, cancelled_at = now(),
      cancelled_by = p_actor
  where id = p_seller_order.id;
  perform private.release_stock(p_seller_order.id, p_order.id);

  if p_order.payment_status in ('paid', 'partially_refunded') and p_seller_order.total > 0 then
    select * into pay from public.payments
    where order_id = p_order.id and state = 'captured'
    order by created_at limit 1;
    insert into public.refunds (
      order_id, seller_order_id, payment_id, provider_payment_id, customer_id,
      amount, reason, requested_by)
    values (
      p_order.id, p_seller_order.id, pay.id, pay.provider_payment_id, p_order.customer_id,
      p_seller_order.total, p_reason, (select auth.uid()));
    refund := p_seller_order.total;
  end if;

  perform private.add_event(p_order.id, p_seller_order.id, 'cancelled',
    p_seller_order.status::text, 'cancelled', p_actor, p_reason);
  return refund;
end $$;

create or replace function public.cancel_seller_order(
  p_order_id uuid,
  p_seller_order_id uuid,
  p_reason text
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  so public.seller_orders;
  refund integer;
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found or not private.can_manage_order(o) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into so from public.seller_orders
  where id = p_seller_order_id and order_id = o.id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if o.payment_status = 'pending' then
    raise exception 'ORDER_AWAITING_PAYMENT' using errcode = 'P0001';
  end if;
  if so.status not in ('placed', 'confirmed', 'packed') then
    raise exception 'NOT_CANCELLABLE' using errcode = 'P0001',
      detail = jsonb_build_object('status', so.status)::text;
  end if;

  refund := private.cancel_part(o, so, coalesce(p_reason, 'cancelled'),
    case when o.customer_id = (select auth.uid()) then 'customer' else 'staff' end);
  return jsonb_build_object(
    'order_id', o.id,
    'payment_status', private.settle_order_after_cancel(o.id),
    'refund_amount', refund);
end $$;

create or replace function public.cancel_order(p_order_id uuid, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  so public.seller_orders;
  refund integer := 0;
  cancelled integer := 0;
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found or not private.can_manage_order(o) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if o.payment_status = 'pending' then
    perform private.fail_order(o.id, coalesce(p_reason, 'cancelled'), 'customer');
    return jsonb_build_object('order_id', o.id, 'payment_status', 'failed', 'refund_amount', 0);
  end if;
  for so in
    select * from public.seller_orders
    where order_id = o.id and status in ('placed', 'confirmed', 'packed')
    order by position
    for update
  loop
    refund := refund + private.cancel_part(o, so, coalesce(p_reason, 'cancelled'),
      case when o.customer_id = (select auth.uid()) then 'customer' else 'staff' end);
    cancelled := cancelled + 1;
  end loop;
  if cancelled = 0 then
    raise exception 'NOT_CANCELLABLE' using errcode = 'P0001';
  end if;
  return jsonb_build_object(
    'order_id', o.id,
    'payment_status', private.settle_order_after_cancel(o.id),
    'refund_amount', refund);
end $$;

-- ---------------------------------------------------------------------------
-- Seller fulfilment steps
-- ---------------------------------------------------------------------------

-- The seller order, locked, if the caller's team (or Clothsy ops) may act
-- on it.
create or replace function private.seller_order_for_team(p_seller_order_id uuid)
returns public.seller_orders
language plpgsql security definer set search_path = '' as $$
declare
  so public.seller_orders;
begin
  select * into so from public.seller_orders where id = p_seller_order_id for update;
  if not found or not (
    private.is_seller_member(so.seller_id)
    or private.is_staff(array['ops']::public.app_role[])
  ) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  return so;
end $$;

create or replace function private.actor_for(p_seller_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when private.is_seller_member(p_seller_id) then 'seller'
    when coalesce((select auth.role()), '') = 'service_role' then 'system'
    else 'staff'
  end;
$$;

create or replace function public.seller_accept_order(p_seller_order_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  so public.seller_orders := private.seller_order_for_team(p_seller_order_id);
begin
  if so.status <> 'placed' then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → confirmed', so.status);
  end if;
  update public.seller_orders set status = 'confirmed' where id = so.id;
  perform private.add_event(so.order_id, so.id, 'confirmed', 'placed', 'confirmed',
    private.actor_for(so.seller_id));
  return jsonb_build_object('seller_order_id', so.id, 'status', 'confirmed');
end $$;

-- Invoice numbers run per brand and Indian financial year (April-March),
-- e.g. NOOR/2627/00001 — consecutive, unique and at most 16 characters.
create table private.invoice_counters (
  seller_id uuid not null references public.sellers (id) on delete cascade,
  financial_year text not null,
  last_number integer not null default 0,
  primary key (seller_id, financial_year)
);
alter table private.invoice_counters enable row level security;
revoke all on private.invoice_counters from public, anon, authenticated;

create or replace function private.next_invoice_number(p_seller_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  today date := (now() at time zone 'Asia/Kolkata')::date;
  start_year integer := extract(year from today)::integer
    - case when extract(month from today) < 4 then 1 else 0 end;
  fy text := lpad((start_year % 100)::text, 2, '0') || lpad(((start_year + 1) % 100)::text, 2, '0');
  prefix text;
  n integer;
begin
  select upper(left(regexp_replace(s.handle::text, '[^a-zA-Z0-9]', '', 'g'), 4)) into prefix
  from public.sellers s where s.id = p_seller_id;
  insert into private.invoice_counters (seller_id, financial_year, last_number)
  values (p_seller_id, fy, 1)
  on conflict (seller_id, financial_year)
  do update set last_number = private.invoice_counters.last_number + 1
  returning last_number into n;
  return coalesce(nullif(prefix, ''), 'CLY') || '/' || fy || '/' || lpad(n::text, 5, '0');
end $$;

create or replace function public.seller_pack_order(p_seller_order_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  so public.seller_orders := private.seller_order_for_team(p_seller_order_id);
  number text;
begin
  if so.status not in ('placed', 'confirmed') then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → packed', so.status);
  end if;
  number := coalesce(so.invoice_number, private.next_invoice_number(so.seller_id));
  update public.seller_orders
  set status = 'packed', invoice_number = number,
      invoice_date = coalesce(invoice_date, (now() at time zone 'Asia/Kolkata')::date)
  where id = so.id;
  insert into public.shipments (seller_order_id, seller_id, customer_id)
  select so.id, so.seller_id, so.customer_id
  where not exists (select 1 from public.shipments where seller_order_id = so.id);
  perform private.add_event(so.order_id, so.id, 'packed', so.status::text, 'packed',
    private.actor_for(so.seller_id));
  return jsonb_build_object('seller_order_id', so.id, 'status', 'packed', 'invoice_number', number);
end $$;

-- Handed to the courier. Until a courier partner is connected the seller
-- enters the courier and tracking (AWB) number.
create or replace function public.seller_ship_order(
  p_seller_order_id uuid,
  p_carrier text,
  p_tracking_number text,
  p_tracking_url text default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  so public.seller_orders := private.seller_order_for_team(p_seller_order_id);
  v_carrier text := trim(coalesce(p_carrier, ''));
  v_awb text := upper(trim(coalesce(p_tracking_number, '')));
  v_url text := nullif(trim(coalesce(p_tracking_url, '')), '');
begin
  if so.status <> 'packed' then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → shipped', so.status);
  end if;
  if length(v_carrier) < 2 or v_awb !~ '^[A-Z0-9-]{6,30}$' then
    raise exception 'TRACKING_REQUIRED' using errcode = 'P0001';
  end if;
  if v_url is not null and v_url !~ '^https://' then
    raise exception 'INVALID_TRACKING_URL' using errcode = 'P0001';
  end if;
  update public.seller_orders set status = 'shipped' where id = so.id;
  update public.shipments
  set carrier = v_carrier, tracking_number = v_awb, tracking_url = v_url,
      status = 'in_transit', shipped_at = now()
  where seller_order_id = so.id;
  perform private.add_event(so.order_id, so.id, 'shipped', 'packed', 'shipped',
    private.actor_for(so.seller_id), format('%s · %s', v_carrier, v_awb));
  return jsonb_build_object('seller_order_id', so.id, 'status', 'shipped');
end $$;

-- The seller cannot fulfil: cancel with a reason before packing. The
-- shopper's money comes back through the refund outbox.
create or replace function public.seller_cancel_order(p_seller_order_id uuid, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  reason text := nullif(trim(coalesce(p_reason, '')), '');
  ref public.seller_orders;
  o public.orders;
  so public.seller_orders;
  refund integer;
begin
  select * into ref from public.seller_orders where id = p_seller_order_id;
  if not found or not (
    private.is_seller_member(ref.seller_id) or private.is_staff(array['ops']::public.app_role[])
  ) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if reason is null then
    raise exception 'REASON_REQUIRED' using errcode = 'P0001';
  end if;
  -- Same lock order as the shopper's cancel: the order, then the part.
  select * into o from public.orders where id = ref.order_id for update;
  select * into so from public.seller_orders where id = ref.id for update;
  if so.status not in ('placed', 'confirmed') then
    raise exception 'NOT_CANCELLABLE' using errcode = 'P0001',
      detail = jsonb_build_object('status', so.status)::text;
  end if;
  refund := private.cancel_part(o, so, reason, private.actor_for(so.seller_id));
  return jsonb_build_object(
    'seller_order_id', so.id,
    'payment_status', private.settle_order_after_cancel(o.id),
    'refund_amount', refund);
end $$;

-- Couriers (service role), Clothsy ops and — until a courier partner sends
-- updates — the seller move a shipped parcel along to delivery.
create or replace function public.advance_seller_order(
  p_seller_order_id uuid,
  p_to_status public.seller_order_status
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  so public.seller_orders;
  is_service boolean := coalesce((select auth.role()), '') = 'service_role';
  is_ops boolean := private.is_staff(array['ops']::public.app_role[]);
begin
  select * into so from public.seller_orders where id = p_seller_order_id for update;
  if not found or not (private.is_seller_member(so.seller_id) or is_ops or is_service) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if p_to_status in ('cancelled', 'returned', 'pending_payment')
     or (not is_service and not is_ops and p_to_status not in ('out_for_delivery', 'delivered')) then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001',
      detail = format('%s → %s', so.status, p_to_status);
  end if;
  update public.seller_orders set status = p_to_status where id = so.id;
  perform private.add_event(so.order_id, so.id, p_to_status::text, so.status::text,
    p_to_status::text, private.actor_for(so.seller_id));
  return jsonb_build_object('seller_order_id', so.id, 'status', p_to_status);
end $$;

grant execute on function public.seller_accept_order(uuid) to authenticated;
grant execute on function public.seller_pack_order(uuid) to authenticated;
grant execute on function public.seller_ship_order(uuid, text, text, text) to authenticated;
grant execute on function public.seller_cancel_order(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Tax invoice and shipping label data
-- ---------------------------------------------------------------------------

-- GST rates for apparel by selling price per piece, prices including GST.
-- Placeholder from the GST rate change of 22 Sep 2025 (5% up to ₹2,500,
-- 18% above) — confirm with a tax adviser before launch; change the rows,
-- not the code.
create table private.gst_slabs (
  -- Inclusive upper bound in paise; null is the top slab.
  max_unit_price integer unique,
  rate_bps integer not null check (rate_bps between 0 and 2800)
);
alter table private.gst_slabs enable row level security;
revoke all on private.gst_slabs from public, anon, authenticated;
insert into private.gst_slabs (max_unit_price, rate_bps) values (250000, 500), (null, 1800);

create or replace function private.gst_rate_bps(p_unit_price integer)
returns integer language sql stable security definer set search_path = '' as $$
  select rate_bps from private.gst_slabs
  where max_unit_price is null or p_unit_price <= max_unit_price
  order by max_unit_price nulls last
  limit 1;
$$;

-- Everything the panel needs to print the invoice and packing label for a
-- packed order. Prices include GST; tax is worked out per line in paise,
-- CGST + SGST within a state, IGST across states. Shipping is charged to the
-- shopper by Clothsy, so it is not on the brand's invoice.
create or replace function public.seller_order_invoice(p_seller_order_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  so public.seller_orders;
  o public.orders;
  s public.sellers;
  a public.seller_applications;
  buyer_state text;
  intra boolean;
  lines jsonb;
begin
  select * into so from public.seller_orders where id = p_seller_order_id;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into o from public.orders where id = so.order_id;
  if not (
    private.is_seller_member(so.seller_id)
    or o.customer_id = (select auth.uid())
    or private.is_staff(array['ops', 'support', 'finance']::public.app_role[])
  ) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if so.invoice_number is null then
    raise exception 'NOT_INVOICED' using errcode = 'P0001';
  end if;
  select * into s from public.sellers where id = so.seller_id;
  select * into a from public.seller_applications where seller_id = so.seller_id;
  buyer_state := coalesce(o.shipping_address ->> 'state', '');
  intra := lower(trim(buyer_state)) = lower(trim(coalesce(a.pickup_state, '')));

  select coalesce(jsonb_agg(line order by position), '[]'::jsonb) into lines
  from (
    select i.position, jsonb_build_object(
      'title', i.title,
      'variant', i.variant_title,
      'sku', v.sku,
      'hsn_code', p.hsn_code,
      'quantity', i.quantity,
      'unit_price', i.unit_price,
      'total', i.line_total,
      'gst_rate_bps', t.rate,
      'taxable_value', t.taxable,
      'cgst', case when intra then t.tax / 2 else 0 end,
      'sgst', case when intra then t.tax - t.tax / 2 else 0 end,
      'igst', case when intra then 0 else t.tax end) as line
    from public.order_items i
    join public.product_variants v on v.id = i.variant_id
    join public.products p on p.id = i.product_id
    cross join lateral (
      select r.rate,
             round(i.line_total * 10000.0 / (10000 + r.rate))::integer as taxable,
             i.line_total - round(i.line_total * 10000.0 / (10000 + r.rate))::integer as tax
      from (select private.gst_rate_bps(i.unit_price) as rate) r
    ) t
    where i.seller_order_id = so.id
  ) x;

  return jsonb_build_object(
    'invoice_number', so.invoice_number,
    'invoice_date', so.invoice_date,
    'order_number', o.order_number,
    'reference', so.reference,
    'order_date', o.created_at,
    'payment_method', o.payment_method,
    -- What the courier collects on delivery for cash-on-delivery parts.
    'cod_amount', case when o.payment_method = 'cod' then so.total else 0 end,
    'seller', jsonb_build_object(
      'name', s.name,
      'legal_name', coalesce(nullif(a.legal_name, ''), s.name),
      'gstin', a.gstin,
      'pan', a.pan,
      'line1', a.pickup_line1, 'line2', a.pickup_line2, 'city', a.pickup_city,
      'state', a.pickup_state, 'pin_code', a.pickup_pin_code,
      'support_email', s.support_email),
    'buyer', o.shipping_address,
    'place_of_supply', buyer_state,
    'intra_state', intra,
    'lines', lines,
    'totals', jsonb_build_object(
      'taxable_value', (select coalesce(sum((l ->> 'taxable_value')::integer), 0) from jsonb_array_elements(lines) l),
      'cgst', (select coalesce(sum((l ->> 'cgst')::integer), 0) from jsonb_array_elements(lines) l),
      'sgst', (select coalesce(sum((l ->> 'sgst')::integer), 0) from jsonb_array_elements(lines) l),
      'igst', (select coalesce(sum((l ->> 'igst')::integer), 0) from jsonb_array_elements(lines) l),
      'total', (select coalesce(sum((l ->> 'total')::integer), 0) from jsonb_array_elements(lines) l)),
    'shipment', (
      select jsonb_build_object('carrier', sh.carrier, 'tracking_number', sh.tracking_number,
                                'tracking_url', sh.tracking_url)
      from public.shipments sh where sh.seller_order_id = so.id limit 1)
  );
end $$;
grant execute on function public.seller_order_invoice(uuid) to authenticated;
