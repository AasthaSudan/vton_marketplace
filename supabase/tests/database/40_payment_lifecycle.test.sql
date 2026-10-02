-- Payments: confirmation is idempotent, failures release stock, late or
-- duplicate payments are refunded and never revive an order.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000401') as buyer \gset
select tests.address(:'buyer', '110001') as addr \gset

-- Place a prepaid order and record its gateway order.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'upi',
  'UPI (Google Pay)', null, gen_random_uuid()) ->> 'order_id' as order_id \gset
select tests.as_service();
select record_payment_intent(:'order_id', 'mock', 'order_mock_401', 114900);
select ok(
  (record_payment_intent(:'order_id', 'mock', 'order_mock_401_retry', 114900) ->> 'replayed')::boolean,
  'one payment intent per order');
select throws_ok(
  format($$select record_payment_intent(%L, 'mock', 'order_x', 1)$$, :'order_id'),
  'P0001', 'AMOUNT_MISMATCH', 'the intent must be for the order total');

-- Wrong amount is refused and recorded.
select is(
  confirm_payment(:'order_id', 'order_mock_401', 'pay_1', 100, 'webhook') ->> 'error',
  'AMOUNT_MISMATCH', 'a payment for the wrong amount does not count');
select tests.as_owner();
select is((select count(*)::integer from payment_events
           where order_id = :'order_id' and event_type = 'amount_mismatch'), 1,
  'and the attempt is on record');
select is((select payment_status::text from orders where id = :'order_id'), 'pending',
  'the order still waits for payment');
select tests.as_service();

-- Confirm
select is(
  confirm_payment(:'order_id', 'order_mock_401', 'pay_mock_401', 114900, 'client_verify') ->> 'payment_status',
  'paid', 'a verified payment marks the order paid');
select tests.as_owner();
select is((select status::text from seller_orders where order_id = :'order_id'), 'placed', 'seller orders are placed');
select is((select reserved_until from orders where id = :'order_id'), null, 'the hold ends');
select is((select state::text from payments where order_id = :'order_id'), 'captured', 'payment captured');

-- Confirming again (webhook after the app) changes nothing.
select tests.as_service();
select ok(
  (confirm_payment(:'order_id', 'order_mock_401', 'pay_mock_401', 114900, 'webhook') ->> 'replayed')::boolean,
  'confirming twice is a no-op');
select tests.as_owner();
select is((select count(*)::integer from payment_events
           where order_id = :'order_id' and event_type = 'captured'), 1, 'captured once');

-- A second, different payment for the same order is refunded.
select tests.as_service();
select ok(
  (confirm_payment(:'order_id', 'order_mock_401', 'pay_mock_dup', 114900, 'webhook') ->> 'refund_queued')::boolean,
  'a duplicate payment is refunded');
select tests.as_owner();
select is((select reason from refunds where provider_payment_id = 'pay_mock_dup'), 'duplicate_payment',
  'refund recorded for the duplicate');
select is((select payment_status::text from orders where id = :'order_id'), 'paid', 'the order stays paid');

-- A failure report after payment never undoes it.
select tests.as_user(:'buyer');
select is(fail_payment(:'order_id', 'late failure') ->> 'payment_status', 'paid',
  'a late failure report is ignored');

-- Failed payment: order cancelled, stock released, coupon freed.
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'card',
  'Card', 'CLOTHSY10', gen_random_uuid()) ->> 'order_id' as failed_id \gset
select tests.as_owner();
select tests.stock('tst_cheap') as stock_held \gset
select tests.as_user(:'buyer');
select is(fail_payment(:'failed_id', 'Bank declined') ->> 'payment_status', 'failed',
  'the shopper reports a failed payment');
select tests.as_owner();
select is(tests.stock('tst_cheap'), :stock_held + 1, 'its stock is released');
select is((select status::text from seller_orders where order_id = :'failed_id'), 'cancelled', 'its seller order is cancelled');
select isnt((select voided_at from coupon_redemptions where order_id = :'failed_id'), null, 'its coupon use is voided');

-- Paid after it failed: refunded, order not revived.
select tests.as_owner();
insert into payments (order_id, customer_id, provider, provider_order_id, amount, state)
select :'failed_id', :'buyer', 'mock', 'order_mock_late', grand_total, 'failed'
from orders where id = :'failed_id';
select tests.as_service();
select ok(
  (confirm_payment(:'failed_id', 'order_mock_late', 'pay_mock_late',
    (select grand_total from orders where id = :'failed_id'), 'webhook') ->> 'refund_queued')::boolean,
  'a payment for a cancelled order is refunded');
select tests.as_owner();
select is((select payment_status::text from orders where id = :'failed_id'), 'failed', 'and the order stays cancelled');
select is((select reason from refunds where provider_payment_id = 'pay_mock_late'), 'late_payment', 'refund reason');

-- Unpaid orders expire after their hold.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'upi',
  'UPI', null, gen_random_uuid()) ->> 'order_id' as stale_id \gset
select tests.as_owner();
update orders set reserved_until = now() - interval '1 minute' where id = :'stale_id';
select tests.stock('tst_cheap') as stock_before_expiry \gset
select tests.as_service();
select ok(release_expired_reservations() >= 1, 'expired holds are released');
select tests.as_owner();
select is((select payment_status::text from orders where id = :'stale_id'), 'failed', 'the unpaid order is cancelled');
select is(tests.stock('tst_cheap'), :stock_before_expiry + 1, 'and its stock is back');

-- Shoppers cannot confirm their own payments.
select tests.as_user(:'buyer');
select throws_ok(
  format($$select confirm_payment(%L, 'order_mock_401', 'pay_x', 114900, 'client_verify')$$, :'order_id'),
  '42501', null, 'only the payment service confirms payments');

select * from finish();
rollback;
