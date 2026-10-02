-- Cancelling: one seller's part or the whole order, refunds for prepaid
-- parts, stock back once, and nothing after shipping.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000501') as buyer \gset
select tests.create_user('+919000000502') as stranger \gset
select tests.create_user('+919000000503') as seller_user \gset
select tests.address(:'buyer', '110001') as addr \gset
insert into public.seller_members (seller_id, user_id, role)
select id, :'seller_user', 'owner' from public.sellers where handle = 'test-label';

-- A paid two-brand order: blazer ₹7,999 (Noor) + tee ₹999 + ₹150 (Test Label).
select tests.as_user(:'buyer');
select place_order(
  jsonb_build_array(tests.line('v_blazer_lavender'), tests.line('tst_cheap')),
  :'addr', 'upi', 'UPI', null, gen_random_uuid()) ->> 'order_id' as order_id \gset
select tests.as_service();
select record_payment_intent(:'order_id', 'mock', 'order_mock_501', 914800);
select confirm_payment(:'order_id', 'order_mock_501', 'pay_mock_501', 914800, 'client_verify');

select tests.as_owner();
select id as tee_part from seller_orders where order_id = :'order_id' and seller_name = 'Test Label' \gset
select id as blazer_part from seller_orders where order_id = :'order_id' and seller_name = 'Noor Atelier' \gset
select tests.stock('tst_cheap') as tee_stock \gset

-- Strangers cannot cancel it.
select tests.as_user(:'stranger');
select throws_ok(
  format($$select cancel_seller_order(%L, %L, 'mine now')$$, :'order_id', :'tee_part'),
  'P0001', 'ORDER_NOT_FOUND', 'strangers cannot cancel your order');

-- Cancel just the tee.
select tests.as_user(:'buyer');
select is(
  (cancel_seller_order(:'order_id', :'tee_part', 'Changed my mind') ->> 'refund_amount')::integer,
  114900, 'the cancelled part is refunded in full (with its shipping)');
select tests.as_owner();
select is((select status::text from seller_orders where id = :'tee_part'), 'cancelled', 'the tee part is cancelled');
select is((select status::text from seller_orders where id = :'blazer_part'), 'placed', 'the blazer part carries on');
select is((select payment_status::text from orders where id = :'order_id'), 'partially_refunded', 'the order is partly refunded');
select is(tests.stock('tst_cheap'), :tee_stock + 1, 'the tee goes back to stock');
select is((select amount from refunds where seller_order_id = :'tee_part'), 114900, 'one refund queued');
select is((select provider_payment_id from refunds where seller_order_id = :'tee_part'), 'pay_mock_501', 'against the captured payment');

select tests.as_user(:'buyer');
select throws_ok(
  format($$select cancel_seller_order(%L, %L, 'again')$$, :'order_id', :'tee_part'),
  'P0001', 'NOT_CANCELLABLE', 'a part cannot be cancelled twice');
select tests.as_owner();
select is(tests.stock('tst_cheap'), :tee_stock + 1, 'stock is released only once');

-- Once shipped, a part cannot be cancelled.
select tests.as_service();
select advance_seller_order(:'blazer_part', 'packed');
select advance_seller_order(:'blazer_part', 'shipped');
select tests.as_user(:'buyer');
select throws_ok(
  format($$select cancel_order(%L, 'too late')$$, :'order_id'),
  'P0001', 'NOT_CANCELLABLE', 'nothing left to cancel after shipping');

-- Statuses only move forward.
select tests.as_service();
select throws_ok(
  format($$select advance_seller_order(%L, 'packed')$$, :'blazer_part'),
  'P0001', 'INVALID_TRANSITION', 'a shipped order cannot go back to packed');

-- The seller can move their own part along; others cannot.
select tests.as_user(:'seller_user');
select throws_ok(
  format($$select advance_seller_order(%L, 'delivered')$$, :'blazer_part'),
  'P0001', 'ORDER_NOT_FOUND', 'sellers only move their own orders');

-- Cancelling a whole paid order refunds every part.
select tests.as_user(:'buyer');
select place_order(
  jsonb_build_array(tests.line('v_overshirt_sand'), tests.line('tst_cheap')),
  :'addr', 'card', 'Card', null, gen_random_uuid()) ->> 'order_id' as order2 \gset
select tests.as_service();
select record_payment_intent(:'order2', 'mock', 'order_mock_502',
  (select grand_total from orders where id = :'order2'));
select confirm_payment(:'order2', 'order_mock_502', 'pay_mock_502',
  (select grand_total from orders where id = :'order2'), 'webhook');
select tests.as_user(:'buyer');
select is(
  (cancel_order(:'order2', 'Ordered by mistake') ->> 'payment_status'),
  'refunded', 'cancelling everything refunds the order');
select tests.as_owner();
select is(
  (select sum(amount)::integer from refunds where order_id = :'order2'),
  (select grand_total from orders where id = :'order2'),
  'refunds add up to what was paid');

-- Cash on delivery: nothing to refund.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'cod',
  'Cash on delivery', null, gen_random_uuid()) ->> 'order_id' as cod_order \gset
select is(
  (cancel_order(:'cod_order', 'No longer needed') ->> 'refund_amount')::integer,
  0, 'cash-on-delivery orders have nothing to refund');
select tests.as_owner();
select is((select count(*)::integer from refunds where order_id = :'cod_order'), 0, 'no refund row');

-- Cancelling an unpaid order abandons it.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'upi',
  'UPI', null, gen_random_uuid()) ->> 'order_id' as unpaid \gset
select is(cancel_order(:'unpaid', 'Changed my mind') ->> 'payment_status', 'failed',
  'an unpaid order is simply dropped');

-- The refund outbox hands each refund out once.
select tests.as_service();
select id as refund_id from refunds where seller_order_id = :'tee_part' \gset
select isnt(claim_refund(:'refund_id'), null, 'a pending refund can be claimed');
select is(claim_refund(:'refund_id'), null, 'but only once');
select complete_refund(:'refund_id', 'rfnd_mock_1');
select tests.as_owner();
select is((select status::text from refunds where id = :'refund_id'), 'processed', 'refund processed');

select * from finish();
rollback;
