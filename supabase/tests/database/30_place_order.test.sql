-- place_order: server pricing, the seller split, stock holds, idempotency
-- and every refusal reason. Also who can read whose orders.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000301') as buyer \gset
select tests.create_user('+919000000302') as other \gset
select tests.create_user('+919000000303') as seller_user \gset
select tests.address(:'buyer', '110001') as addr \gset
select tests.address(:'buyer', '700001') as prepaid_only_addr \gset
select tests.address(:'buyer', '999999') as far_addr \gset
insert into public.seller_members (seller_id, user_id, role)
select id, :'seller_user', 'owner' from public.sellers where handle = 'noor-atelier';

-- Two brands: Noor Atelier ₹7,999 (free shipping) + Test Label ₹999 (₹150),
-- with LUXURY20 (20% of ₹8,998 = ₹1,799.60 → 179960 paise).
select tests.as_user(:'buyer');
select place_order(
  jsonb_build_array(tests.line('v_blazer_lavender'), tests.line('tst_cheap')),
  :'addr', 'cod', 'Cash on delivery', 'luxury20', '11111111-1111-1111-1111-111111111111'
) as result \gset

select tests.as_owner();
select (:'result'::jsonb ->> 'order_id')::uuid as order_id \gset

select is((select subtotal from orders where id = :'order_id'), 899800, 'goods total from catalogue prices');
select is((select shipping_total from orders where id = :'order_id'), 15000, 'only the small shipment pays shipping');
select is((select discount_total from orders where id = :'order_id'), 179960, 'coupon applied on the server');
select is((select grand_total from orders where id = :'order_id'), 899800 + 15000 - 179960, 'grand total');
select is((select payment_status::text from orders where id = :'order_id'), 'cod', 'cash on delivery is placed at once');

select is(
  (select array_agg(seller_name order by position) from seller_orders where order_id = :'order_id'),
  array['Noor Atelier', 'Test Label'], 'one seller order per brand, in bag order');
select is(
  (select array_agg(right(reference, 2) order by position) from seller_orders where order_id = :'order_id'),
  array['-A', '-B'], 'references end in A and B');
-- splitProportionally(179960, [799900, 99900]) → [159980, 19980] (exact)
select is(
  (select array_agg(discount_share order by position) from seller_orders where order_id = :'order_id'),
  array[159980, 19980], 'coupon split by seller subtotal, to the paisa');
select is(
  (select sum(total)::integer from seller_orders where order_id = :'order_id'),
  (select grand_total from orders where id = :'order_id'), 'parts add up to the order');
select is(tests.stock('v_blazer_lavender'), 9, 'stock held for the blazer');
select is(tests.stock('tst_cheap'), 2, 'stock held for the tee');
select is(
  (select count(*)::integer from inventory_movements m
   where m.order_id = :'order_id' and m.reason = 'order_reserve'),
  2, 'holds are logged against the order');

-- Retrying the same checkout returns the same order and holds nothing more.
select tests.as_user(:'buyer');
select ok(
  (place_order(
    jsonb_build_array(tests.line('v_blazer_lavender'), tests.line('tst_cheap')),
    :'addr', 'cod', 'Cash on delivery', 'LUXURY20', '11111111-1111-1111-1111-111111111111'
  ) ->> 'replayed')::boolean,
  'a retried checkout is answered from the first one');
select is(tests.stock('tst_cheap'), 2, 'a retry holds no extra stock');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap', 2)), %L,
    'cod', 'COD', null, '11111111-1111-1111-1111-111111111111')$$, :'addr'),
  'P0001', 'IDEMPOTENCY_CONFLICT', 'a different bag cannot reuse the key');

-- Refusals
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap', 3)), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'OUT_OF_STOCK', 'more than is in stock');
select is(tests.stock('tst_cheap'), 2, 'a refused order holds nothing');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap')), %L,
    'cod', 'COD', null, gen_random_uuid(), 1)$$, :'addr'),
  'P0001', 'PRICE_CHANGED', 'the total the shopper saw must match');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap')), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'far_addr'),
  'P0001', 'PIN_NOT_SERVICEABLE', 'unknown PIN codes are refused');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap')), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'prepaid_only_addr'),
  'P0001', 'COD_UNAVAILABLE', 'COD only where the PIN allows it');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('v5_black', 2)), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'COD_UNAVAILABLE', 'COD only up to the cap');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap')), %L,
    'cod', 'COD', 'NOPE', gen_random_uuid())$$, :'addr'),
  'P0001', 'COUPON_INVALID', 'unknown coupons are refused');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_draft')), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'VARIANT_UNAVAILABLE', 'drafts cannot be ordered');
select throws_ok(
  format($$select place_order('[{"variant_id": "v_blazer_lavender", "quantity": 1}]'::jsonb, %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'VARIANT_UNAVAILABLE', 'a stale mock bag is refused');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap', 11)), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'INVALID_QUANTITY', 'at most 10 of a piece');
select throws_ok(
  format($$select place_order(jsonb_build_array(jsonb_build_object('variant_id', tests.variant('tst_cheap'), 'quantity', 'two')), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'INVALID_QUANTITY', 'quantities must be whole numbers');

-- Prepaid orders wait for payment with stock held for 15 minutes.
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'upi',
  'UPI', null, gen_random_uuid()) ->> 'order_id' as prepaid_id \gset
select tests.as_owner();
select is((select payment_status::text from orders where id = :'prepaid_id'), 'pending', 'prepaid orders wait for payment');
select is((select status::text from seller_orders where order_id = :'prepaid_id'), 'pending_payment', 'nothing is placed before payment');
select ok((select reserved_until between now() + interval '14 minutes' and now() + interval '16 minutes'
           from orders where id = :'prepaid_id'), 'stock is held for 15 minutes');

-- Someone else's address cannot be used.
select tests.as_user(:'other');
select throws_ok(
  format($$select place_order(jsonb_build_array(tests.line('tst_cheap')), %L,
    'cod', 'COD', null, gen_random_uuid())$$, :'addr'),
  'P0001', 'ADDRESS_NOT_FOUND', 'only your own addresses');

-- Who can read what
select is((select count(*)::integer from orders), 0, 'other shoppers see none of these orders');
select is((select count(*)::integer from seller_orders), 0, '...nor their seller orders');
select is((select count(*)::integer from order_items), 0, '...nor their items');
select throws_ok(
  format($$update orders set grand_total = 1 where id = %L$$, :'order_id'),
  '42501', null, 'shoppers cannot write orders directly');

select tests.as_user(:'buyer');
select is((select count(*)::integer from orders), 2, 'the buyer sees their orders');
select is((select count(*)::integer from order_events where order_id = :'order_id'), 1, 'and their tracking events');

select tests.as_user(:'seller_user');
select is((select count(*)::integer from orders), 0, 'sellers never see the parent order or payment');
select is(
  (select array_agg(seller_name) from seller_orders), array['Noor Atelier'],
  'sellers see only their own part');
select is((select count(*)::integer from order_items), 1, 'and only their own items');

select tests.as_anon();
select is((select count(*)::integer from orders), 0, 'visitors see no orders');

select * from finish();
rollback;
