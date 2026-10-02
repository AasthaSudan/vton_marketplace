-- The order lifecycle. Clients never write order or payment tables; they
-- call these functions, which re-price everything on the server, hold stock,
-- and keep every change idempotent and on record.
--
-- Errors are raised as `P0001` with a machine-readable message
-- (OUT_OF_STOCK, PRICE_CHANGED, ...) and JSON details; the app turns them
-- into friendly copy.

-- Largest order (paise) payable by cash on delivery. PLACEHOLDER ₹10,000
-- until the COD policy is decided (same value as AppConstants in the app).
create or replace function private.cod_max_order_value()
returns integer language sql immutable as $$ select 1000000 $$;

-- Gives a seller order's units back to stock.
create or replace function private.release_stock(p_seller_order_id uuid, p_order_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('clothsy.stock_reason', 'order_release', true);
  perform set_config('clothsy.stock_order', p_order_id::text, true);
  update public.product_variants v
  set stock = v.stock + i.quantity
  from (
    select variant_id, sum(quantity)::integer as quantity
    from public.order_items
    where seller_order_id = p_seller_order_id
    group by variant_id
  ) i
  where v.id = i.variant_id;
end $$;

create or replace function private.add_event(
  p_order_id uuid,
  p_seller_order_id uuid,
  p_type text,
  p_from text,
  p_to text,
  p_actor_role text,
  p_note text default null,
  p_visible boolean default true
)
returns void language sql security definer set search_path = '' as $$
  insert into public.order_events (
    order_id, seller_order_id, customer_id, event_type, from_status, to_status,
    actor_id, actor_role, customer_visible, note)
  select p_order_id, p_seller_order_id, o.customer_id, p_type, p_from, p_to,
         (select auth.uid()), p_actor_role, p_visible, p_note
  from public.orders o where o.id = p_order_id;
$$;

-- ---------------------------------------------------------------------------
-- place_order
-- ---------------------------------------------------------------------------

create or replace function public.place_order(
  p_items jsonb,
  p_address_id uuid,
  p_payment_method public.payment_method,
  p_payment_label text,
  p_coupon_code text,
  p_idempotency_key uuid,
  p_expected_total integer default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  v_hash text;
  v_existing public.orders;
  v_lines jsonb;
  v_line jsonb;
  v_missing jsonb;
  v_seller_ids uuid[];
  v_seller_names text[];
  v_subtotals bigint[];
  v_goods bigint;
  v_coupon public.coupons;
  v_discount integer := 0;
  v_shares integer[];
  v_shipping integer;
  v_shipping_total integer := 0;
  v_grand integer := 0;
  v_addr public.addresses;
  v_pin public.serviceable_pincodes;
  v_order_id uuid := gen_random_uuid();
  v_number text;
  v_so_ids uuid[] := '{}';
  v_so_id uuid;
  v_prepaid boolean := p_payment_method <> 'cod';
  v_count integer;
  i integer;
begin
  if uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;
  if p_idempotency_key is null then
    raise exception 'INVALID_REQUEST' using errcode = 'P0001', detail = 'idempotency key missing';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array'
     or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > 50 then
    raise exception 'INVALID_ITEMS' using errcode = 'P0001';
  end if;

  -- Retries of the same checkout queue up here and get the same order.
  perform pg_advisory_xact_lock(hashtextextended(uid::text || p_idempotency_key::text, 0));

  v_hash := md5(jsonb_build_object(
    'items', (select jsonb_agg(jsonb_build_object(
                 'variant_id', e->>'variant_id', 'quantity', e->'quantity')
               order by e->>'variant_id', e->>'quantity')
              from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e),
    'address', p_address_id,
    'method', p_payment_method,
    'coupon', upper(coalesce(trim(p_coupon_code), ''))
  )::text);

  select * into v_existing from public.orders o
  where o.customer_id = uid and o.idempotency_key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_hash then
      raise exception 'IDEMPOTENCY_CONFLICT' using errcode = 'P0001';
    end if;
    return jsonb_build_object(
      'order_id', v_existing.id,
      'order_number', v_existing.order_number,
      'grand_total', v_existing.grand_total,
      'payment_status', v_existing.payment_status,
      'replayed', true);
  end if;

  -- Validate and merge the bag lines (same variant twice → one line).
  if exists (
    select 1 from jsonb_array_elements(p_items) e
    where private.try_uuid(e->>'variant_id') is null
  ) then
    raise exception 'VARIANT_UNAVAILABLE' using errcode = 'P0001',
      detail = jsonb_build_object('reason', 'unknown variant')::text;
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) e
    -- CASE keeps the checks in order (a non-number is never cast).
    where case
      when jsonb_typeof(e->'quantity') is distinct from 'number' then true
      when (e->>'quantity')::numeric <> floor((e->>'quantity')::numeric) then true
      else (e->>'quantity')::numeric not between 1 and 10
    end
  ) then
    raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
  end if;

  with raw as (
    select (e->>'variant_id')::uuid as variant_id,
           (e->>'quantity')::integer as quantity,
           ord
    from jsonb_array_elements(p_items) with ordinality as t(e, ord)
  ), merged as (
    select variant_id, sum(quantity)::integer as quantity, min(ord) as pos
    from raw group by variant_id
  )
  select
    jsonb_agg(jsonb_build_object(
      'variant_id', v.id,
      'product_id', p.id,
      'seller_id', s.id,
      'seller_name', s.name,
      'quantity', m.quantity,
      'pos', m.pos,
      'unit_price', v.price,
      'compare_at', v.compare_at_price,
      'title', p.title,
      'variant_title', v.title,
      'size', v.size,
      'color_name', v.color_name,
      'color_hex', v.color_hex,
      'image_url', coalesce(v.image_url, p.images[1])
    ) order by m.pos),
    (select jsonb_agg(m2.variant_id) from merged m2
     where not exists (
       select 1 from public.product_variants v2
       join public.products p2 on p2.id = v2.product_id
       join public.sellers s2 on s2.id = p2.seller_id
       where v2.id = m2.variant_id and v2.is_active
         and p2.status = 'live' and s2.status = 'approved'))
  into v_lines, v_missing
  from merged m
  join public.product_variants v on v.id = m.variant_id
  join public.products p on p.id = v.product_id
  join public.sellers s on s.id = p.seller_id
  where v.is_active and p.status = 'live' and s.status = 'approved';

  if v_missing is not null then
    raise exception 'VARIANT_UNAVAILABLE' using errcode = 'P0001',
      detail = jsonb_build_object('variant_ids', v_missing)::text;
  end if;
  if exists (select 1 from jsonb_array_elements(v_lines) l where (l->>'quantity')::integer > 10) then
    raise exception 'INVALID_QUANTITY' using errcode = 'P0001';
  end if;

  -- One group per seller, in the order sellers first appear in the bag
  -- (CartSummary.sellerGroups).
  select array_agg(g.seller_id order by g.first_pos),
         array_agg(g.seller_name order by g.first_pos),
         array_agg(g.subtotal order by g.first_pos)
  into v_seller_ids, v_seller_names, v_subtotals
  from (
    select (l->>'seller_id')::uuid as seller_id,
           min(l->>'seller_name') as seller_name,
           min((l->>'pos')::integer) as first_pos,
           sum((l->>'unit_price')::bigint * (l->>'quantity')::bigint) as subtotal
    from jsonb_array_elements(v_lines) l
    group by 1
  ) g;

  select sum(x) into v_goods from unnest(v_subtotals) x;

  if nullif(trim(coalesce(p_coupon_code, '')), '') is not null then
    v_coupon := private.resolve_coupon(trim(p_coupon_code), v_goods, uid);
    v_discount := private.coupon_discount(v_coupon, v_goods);
  end if;
  v_shares := private.split_proportionally(v_discount, v_subtotals);

  for i in 1..array_length(v_seller_ids, 1) loop
    v_shipping := private.shipping_fee(v_subtotals[i]);
    v_shipping_total := v_shipping_total + v_shipping;
    v_grand := v_grand + greatest(v_subtotals[i] + v_shipping - v_shares[i], 0);
  end loop;

  -- The shopper agreed to a total; never charge a different one.
  if p_expected_total is not null and p_expected_total <> v_grand then
    raise exception 'PRICE_CHANGED' using errcode = 'P0001',
      detail = jsonb_build_object('grand_total', v_grand)::text;
  end if;

  select * into v_addr from public.addresses a
  where a.id = p_address_id and a.user_id = uid;
  if not found then
    raise exception 'ADDRESS_NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into v_pin from public.serviceable_pincodes sp where sp.pin_code = v_addr.pin_code;
  if not found or not v_pin.is_serviceable then
    raise exception 'PIN_NOT_SERVICEABLE' using errcode = 'P0001',
      detail = jsonb_build_object('pin_code', v_addr.pin_code)::text;
  end if;
  if not v_prepaid and (not v_pin.cod_available or v_grand > private.cod_max_order_value()) then
    raise exception 'COD_UNAVAILABLE' using errcode = 'P0001',
      detail = jsonb_build_object('max', private.cod_max_order_value())::text;
  end if;

  -- Hold stock, variant by variant in a fixed order (no deadlocks). Any
  -- shortage rolls the whole order back.
  perform set_config('clothsy.stock_reason', 'order_reserve', true);
  perform set_config('clothsy.stock_order', v_order_id::text, true);
  for v_line in
    select l from jsonb_array_elements(v_lines) l order by l->>'variant_id'
  loop
    update public.product_variants
    set stock = stock - (v_line->>'quantity')::integer
    where id = (v_line->>'variant_id')::uuid
      and stock >= (v_line->>'quantity')::integer;
    get diagnostics v_count = row_count;
    if v_count = 0 then
      raise exception 'OUT_OF_STOCK' using errcode = 'P0001',
        detail = jsonb_build_object(
          'variant_id', v_line->>'variant_id',
          'title', v_line->>'title',
          'size', v_line->>'size')::text;
    end if;
  end loop;

  loop
    v_number := 'CLY-' || lpad((floor(random() * 100000000))::bigint::text, 8, '0');
    exit when not exists (select 1 from public.orders o where o.order_number = v_number);
  end loop;

  insert into public.orders (
    id, order_number, customer_id, idempotency_key, request_hash,
    payment_method, payment_label, payment_status,
    subtotal, shipping_total, discount_total, grand_total,
    coupon_id, coupon_code, shipping_address, reserved_until)
  values (
    v_order_id, v_number, uid, p_idempotency_key, v_hash,
    p_payment_method, coalesce(nullif(trim(p_payment_label), ''), p_payment_method::text),
    case when v_prepaid then 'pending' else 'cod' end::public.order_payment_status,
    v_goods, v_shipping_total, v_discount, v_grand,
    v_coupon.id, v_coupon.code::text,
    jsonb_build_object(
      'label', v_addr.label, 'name', v_addr.name, 'phone', v_addr.phone,
      'line1', v_addr.line1, 'line2', v_addr.line2, 'city', v_addr.city,
      'state', v_addr.state, 'pin_code', v_addr.pin_code),
    case when v_prepaid then now() + interval '15 minutes' end);

  for i in 1..array_length(v_seller_ids, 1) loop
    insert into public.seller_orders (
      order_id, seller_id, customer_id, reference, position, seller_name,
      status, subtotal, shipping_fee, discount_share)
    values (
      v_order_id, v_seller_ids[i], uid,
      v_number || '-' || private.seller_suffix(i - 1), i - 1, v_seller_names[i],
      case when v_prepaid then 'pending_payment' else 'placed' end::public.seller_order_status,
      v_subtotals[i], private.shipping_fee(v_subtotals[i]), v_shares[i])
    returning id into v_so_id;
    v_so_ids := v_so_ids || v_so_id;
  end loop;

  insert into public.order_items (
    order_id, seller_order_id, customer_id, seller_id, product_id, variant_id,
    title, variant_title, size, color_name, color_hex, image_url,
    unit_price, compare_at_price, quantity, position)
  select v_order_id,
         v_so_ids[array_position(v_seller_ids, (l->>'seller_id')::uuid)],
         uid, (l->>'seller_id')::uuid, (l->>'product_id')::uuid, (l->>'variant_id')::uuid,
         l->>'title', l->>'variant_title', l->>'size', l->>'color_name', l->>'color_hex',
         l->>'image_url', (l->>'unit_price')::integer, (l->>'compare_at')::integer,
         (l->>'quantity')::integer, (l->>'pos')::integer
  from jsonb_array_elements(v_lines) l;

  if v_coupon.id is not null and v_discount > 0 then
    insert into public.coupon_redemptions (coupon_id, order_id, customer_id, amount)
    values (v_coupon.id, v_order_id, uid, v_discount);
  end if;

  perform private.add_event(
    v_order_id, null,
    case when v_prepaid then 'awaiting_payment' else 'placed' end,
    null,
    case when v_prepaid then 'pending_payment' else 'placed' end,
    'customer');

  return jsonb_build_object(
    'order_id', v_order_id,
    'order_number', v_number,
    'grand_total', v_grand,
    'payment_status', case when v_prepaid then 'pending' else 'cod' end,
    'replayed', false);
end $$;

grant execute on function public.place_order(
  jsonb, uuid, public.payment_method, text, text, uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Payment intent (called by the create-order Edge Function)
-- ---------------------------------------------------------------------------

create or replace function public.record_payment_intent(
  p_order_id uuid,
  p_provider public.payment_provider,
  p_provider_order_id text,
  p_amount integer
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  pay public.payments;
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if o.payment_status <> 'pending' then
    raise exception 'NOT_PENDING' using errcode = 'P0001';
  end if;
  if p_amount <> o.grand_total then
    raise exception 'AMOUNT_MISMATCH' using errcode = 'P0001';
  end if;

  select * into pay from public.payments
  where order_id = o.id and state in ('created', 'captured');
  if found then
    return jsonb_build_object('provider_order_id', pay.provider_order_id, 'replayed', true);
  end if;

  insert into public.payments (order_id, customer_id, provider, provider_order_id, amount)
  values (o.id, o.customer_id, p_provider, p_provider_order_id, p_amount)
  returning * into pay;
  insert into public.payment_events (payment_id, order_id, event_type, amount, source)
  values (pay.id, o.id, 'created', p_amount, 'create_order');
  return jsonb_build_object('provider_order_id', pay.provider_order_id, 'replayed', false);
end $$;

-- ---------------------------------------------------------------------------
-- Failing and expiring unpaid orders
-- ---------------------------------------------------------------------------

create or replace function private.fail_order(p_order_id uuid, p_reason text, p_actor text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  so record;
begin
  update public.orders
  set payment_status = 'failed', reserved_until = null
  where id = p_order_id and payment_status = 'pending';
  if not found then
    return;
  end if;
  for so in
    select id, status from public.seller_orders
    where order_id = p_order_id and status = 'pending_payment'
  loop
    update public.seller_orders
    set status = 'cancelled', cancel_reason = p_reason, cancelled_at = now()
    where id = so.id;
    perform private.release_stock(so.id, p_order_id);
  end loop;
  update public.coupon_redemptions set voided_at = now()
  where order_id = p_order_id and voided_at is null;
  update public.payments set state = 'failed'
  where order_id = p_order_id and state = 'created';
  perform private.add_event(p_order_id, null, 'payment_failed', 'pending_payment',
    'cancelled', p_actor, p_reason, false);
end $$;

-- The shopper (or the payment service) reports that a payment failed or was
-- abandoned: the order is cancelled and its stock released. A no-op once the
-- order is paid — a late "failed" never undoes a confirmed payment.
create or replace function public.fail_payment(p_order_id uuid, p_reason text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  is_service boolean := coalesce((select auth.role()), '') = 'service_role';
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found or (not is_service and o.customer_id is distinct from (select auth.uid())) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  perform private.fail_order(o.id, coalesce(p_reason, 'payment_failed'),
    case when is_service then 'system' else 'customer' end);
  return jsonb_build_object('order_id', o.id,
    'payment_status', (select payment_status from public.orders where id = o.id));
end $$;
grant execute on function public.fail_payment(uuid, text) to authenticated;

-- pg_cron: unpaid orders older than their hold are cancelled.
create or replace function public.release_expired_reservations()
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  o record;
  n integer := 0;
begin
  for o in
    select id from public.orders
    where payment_status = 'pending' and reserved_until < now()
    order by reserved_until
    limit 200
    for update skip locked
  loop
    perform private.fail_order(o.id, 'reservation_expired', 'system');
    n := n + 1;
  end loop;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- Confirming payments
-- ---------------------------------------------------------------------------

-- Called only by the payment functions after the gateway's signature or
-- webhook was verified. Idempotent: confirming twice changes nothing. A
-- payment that arrives for a cancelled order, or a second payment for a paid
-- one, is refunded automatically and never revives the order.
create or replace function public.confirm_payment(
  p_order_id uuid,
  p_provider_order_id text,
  p_provider_payment_id text,
  p_amount integer,
  p_source text
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  pay public.payments;
begin
  select * into o from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into pay from public.payments
  where order_id = o.id and provider_order_id = p_provider_order_id
  for update;
  if not found then
    raise exception 'PAYMENT_NOT_FOUND' using errcode = 'P0001';
  end if;
  if p_amount <> pay.amount then
    -- Recorded (not raised) so the attempt stays on file for finance.
    insert into public.payment_events (payment_id, order_id, event_type, provider_payment_id, amount, source)
    values (pay.id, o.id, 'amount_mismatch', p_provider_payment_id, p_amount, p_source);
    return jsonb_build_object('order_id', o.id, 'payment_status', o.payment_status,
      'error', 'AMOUNT_MISMATCH');
  end if;

  if o.payment_status = 'pending' then
    update public.orders
    set payment_status = 'paid', confirmed_at = now(), reserved_until = null
    where id = o.id;
    update public.seller_orders set status = 'placed'
    where order_id = o.id and status = 'pending_payment';
    update public.payments
    set state = 'captured', provider_payment_id = p_provider_payment_id,
        captured_at = now(),
        signature_verified_at = case when p_source = 'client_verify' then now() end
    where id = pay.id;
    insert into public.payment_events (payment_id, order_id, event_type, provider_payment_id, amount, source)
    values (pay.id, o.id, 'captured', p_provider_payment_id, p_amount, p_source);
    perform private.add_event(o.id, null, 'payment_confirmed', 'pending_payment', 'placed', 'system');
    return jsonb_build_object('order_id', o.id, 'payment_status', 'paid', 'replayed', false);
  end if;

  if pay.provider_payment_id = p_provider_payment_id then
    return jsonb_build_object('order_id', o.id, 'payment_status', o.payment_status, 'replayed', true);
  end if;

  if o.payment_status = 'cod' then
    raise exception 'NOT_PREPAID' using errcode = 'P0001';
  end if;

  -- Paid again, or paid after the order was cancelled: refund it.
  insert into public.refunds (order_id, payment_id, provider_payment_id, customer_id, amount, reason)
  values (o.id, pay.id, p_provider_payment_id, o.customer_id, p_amount,
          case when o.payment_status = 'failed' then 'late_payment' else 'duplicate_payment' end)
  on conflict do nothing;
  if o.payment_status = 'failed' and pay.provider_payment_id is null then
    update public.payments
    set state = 'captured', provider_payment_id = p_provider_payment_id, captured_at = now()
    where id = pay.id;
  end if;
  insert into public.payment_events (payment_id, order_id, event_type, provider_payment_id, amount, source)
  values (pay.id, o.id,
          case when o.payment_status = 'failed' then 'late_payment' else 'duplicate_payment' end,
          p_provider_payment_id, p_amount, p_source);
  return jsonb_build_object('order_id', o.id, 'payment_status', o.payment_status,
    'refund_queued', true);
end $$;

-- ---------------------------------------------------------------------------
-- Cancellations
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
  set status = 'cancelled', cancel_reason = p_reason, cancelled_at = now()
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

-- After cancelling parts: a prepaid order is partially or fully refunded.
create or replace function private.settle_order_after_cancel(p_order_id uuid)
returns public.order_payment_status
language plpgsql security definer set search_path = '' as $$
declare
  o public.orders;
  open_parts integer;
begin
  select * into o from public.orders where id = p_order_id;
  if o.payment_status not in ('paid', 'partially_refunded') then
    return o.payment_status;
  end if;
  select count(*) into open_parts from public.seller_orders
  where order_id = p_order_id and status not in ('cancelled', 'returned');
  update public.orders
  set payment_status = case when open_parts = 0 then 'refunded' else 'partially_refunded' end::public.order_payment_status
  where id = p_order_id
  returning payment_status into o.payment_status;
  return o.payment_status;
end $$;

create or replace function private.can_manage_order(p_order public.orders)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_order.customer_id = (select auth.uid())
      or private.is_staff(array['ops', 'support']::public.app_role[]);
$$;

-- Cancels one seller's part before it ships (Blueprint fig. 21); prepaid
-- parts are refunded through the refund outbox.
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
  if so.status not in ('placed', 'packed') then
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
grant execute on function public.cancel_seller_order(uuid, uuid, text) to authenticated;

-- Cancels every part that has not shipped. An unpaid order is simply
-- abandoned (stock released, nothing to refund).
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
    where order_id = o.id and status in ('placed', 'packed')
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
grant execute on function public.cancel_order(uuid, text) to authenticated;

-- Moves a seller order forward (packed, shipped, ...). Used by the Seller
-- Panel in Phase 2; lets tracking be exercised before that exists.
create or replace function public.advance_seller_order(
  p_seller_order_id uuid,
  p_to_status public.seller_order_status
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  so public.seller_orders;
begin
  select * into so from public.seller_orders where id = p_seller_order_id for update;
  if not found or not (
    private.is_seller_member(so.seller_id)
    or private.is_staff(array['ops']::public.app_role[])
    or coalesce((select auth.role()), '') = 'service_role'
  ) then
    raise exception 'ORDER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if p_to_status in ('cancelled', 'returned', 'pending_payment') then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001';
  end if;
  update public.seller_orders set status = p_to_status where id = so.id;
  perform private.add_event(so.order_id, so.id, p_to_status::text, so.status::text,
    p_to_status::text,
    case when coalesce((select auth.role()), '') = 'service_role' then 'system' else 'seller' end);
  return jsonb_build_object('seller_order_id', so.id, 'status', p_to_status);
end $$;
grant execute on function public.advance_seller_order(uuid, public.seller_order_status)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Refund outbox (processed by the `refund` Edge Function)
-- ---------------------------------------------------------------------------

-- Refunds waiting to be sent (or retried after a failure).
create or replace function public.pending_refunds(p_limit integer default 20)
returns setof uuid
language sql stable security definer set search_path = '' as $$
  select id from public.refunds
  where status in ('pending', 'failed') and attempts < 5
  order by created_at
  limit least(greatest(p_limit, 1), 100);
$$;

-- Marks a refund as being processed; returns what the provider needs, or
-- null when someone else already took it (so it is never sent twice).
create or replace function public.claim_refund(p_refund_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r public.refunds;
  provider public.payment_provider;
  already integer;
  paid integer;
begin
  update public.refunds
  set status = 'processing', attempts = attempts + 1
  where id = p_refund_id and status in ('pending', 'failed') and attempts < 5
  returning * into r;
  if not found then
    return null;
  end if;
  select p.provider, p.amount into provider, paid from public.payments p where p.id = r.payment_id;
  -- Never refund more than was paid on this payment.
  select coalesce(sum(amount), 0) into already from public.refunds
  where provider_payment_id = r.provider_payment_id and status = 'processed';
  if r.reason not in ('late_payment', 'duplicate_payment') and already + r.amount > paid then
    update public.refunds set status = 'failed', last_error = 'exceeds payment' where id = r.id;
    return null;
  end if;
  return jsonb_build_object(
    'refund_id', r.id,
    'order_id', r.order_id,
    'provider', provider,
    'provider_payment_id', r.provider_payment_id,
    'amount', r.amount);
end $$;

create or replace function public.complete_refund(p_refund_id uuid, p_provider_refund_id text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  r public.refunds;
begin
  update public.refunds
  set status = 'processed', provider_refund_id = p_provider_refund_id, processed_at = now(),
      last_error = null
  where id = p_refund_id and status = 'processing'
  returning * into r;
  if not found then
    return;
  end if;
  insert into public.payment_events (payment_id, order_id, event_type, provider_payment_id, amount, source)
  values (r.payment_id, r.order_id, 'refunded', r.provider_payment_id, r.amount, 'refund');
  perform private.add_event(r.order_id, r.seller_order_id, 'refund_processed', null, null,
    'system', format('Refund of %s paise processed', r.amount));
end $$;

create or replace function public.fail_refund(p_refund_id uuid, p_error text)
returns void
language sql security definer set search_path = '' as $$
  update public.refunds set status = 'failed', last_error = left(p_error, 500)
  where id = p_refund_id and status = 'processing';
$$;
