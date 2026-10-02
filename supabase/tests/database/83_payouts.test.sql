-- Settlements and payouts: delivered → settlement (fig. 37 maths), eligible
-- after the return window, batched into a payout to a verified account,
-- returns after payout netted from the next one. Blueprint section 41.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000831') as buyer \gset
select tests.seller_owner('+919000000832', 'test-label') as seller \gset
select tests.seller_owner('+919000000833', 'noor-atelier') as rival \gset
select tests.create_staff('+919000000834', array['finance']) as finance \gset
select tests.address(:'buyer', '110001') as addr \gset
select id as label_id from sellers where handle = 'test-label' \gset

-- A delivered ₹999 order.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'cod', 'COD', null,
  gen_random_uuid()) ->> 'order_id' as order_id \gset
select tests.as_owner();
select id as part from seller_orders where order_id = :'order_id' \gset
select tests.as_service();
select advance_seller_order(:'part', 'packed');
select advance_seller_order(:'part', 'shipped');
select advance_seller_order(:'part', 'delivered');

-- The settlement (15% commission, ₹60 shipping, 2% collection, 18% GST on fees)
select tests.as_user(:'seller');
select is(
  (select jsonb_build_object('gross', gross, 'commission', commission, 'shipping_fee', shipping_fee,
     'collection_fee', collection_fee, 'gst_on_fees', gst_on_fees, 'net', net)
   from seller_settlements where seller_order_id = :'part'),
  '{"gross": 99900, "commission": 14985, "shipping_fee": 6000, "collection_fee": 1998, "gst_on_fees": 4137, "net": 72780}'::jsonb,
  'the brand sees how every rupee is worked out');
select is(
  (select status::text || ' ' || (eligible_at = delivered_at + interval '7 days')::text
   from seller_settlements where seller_order_id = :'part'),
  'pending true', 'it waits out the 7-day return window');
select tests.as_user(:'rival');
select is((select count(*)::integer from seller_settlements), 0, 'other brands see none of it');
select tests.as_user(:'buyer');
select is((select count(*)::integer from seller_settlements), 0, 'shoppers see none of it');
select throws_ok('select create_payouts()', 'P0001', 'NOT_ALLOWED', 'shoppers cannot run payouts');

select tests.as_service();
select is(create_payouts(), '{"payouts": 0, "amount": 0}'::jsonb, 'nothing is paid inside the return window');

-- After the return window, but no verified bank account yet
select tests.as_owner();
update seller_settlements set eligible_at = now() - interval '1 minute' where seller_order_id = :'part';
select tests.as_service();
select is(create_payouts() ->> 'payouts', '0', 'no payout without a payout account');
select is((select status::text from seller_settlements where seller_order_id = :'part'), 'eligible',
  'the settlement is ready');
select tests.as_user(:'seller');
select set_seller_bank_account(:'label_id', 'Test Label Pvt Ltd', '000123456789', 'UTIB0000001');
select tests.as_service();
select is(create_payouts() ->> 'payouts', '0', 'nor to an account nobody has verified');

-- Verified → paid out
select tests.as_user(:'finance');
select verify_seller_bank_account(:'label_id', true);
select is(create_payouts(), '{"payouts": 1, "amount": 72780}'::jsonb, 'finance runs the payout');
select tests.as_user(:'seller');
select id as payout_id from payouts where seller_id = :'label_id' \gset
select is(
  (select status::text || ' ' || account_last4 || ' ' || settlement_count from payouts where id = :'payout_id'),
  'pending 6789 1', 'the brand sees the payout coming to its account');

select tests.as_service();
select is(claim_payout(:'payout_id') ->> 'account_number', '000123456789',
  'the payout service gets the full account number');
select is(claim_payout(:'payout_id'), null::jsonb, 'a payout is never sent twice');
select fail_payout(:'payout_id', 'bank timeout');
select ok(:'payout_id'::uuid = any (array(select pending_payouts())), 'a failed payout is retried');
select ok(claim_payout(:'payout_id') is not null, 'and claimed again');
select complete_payout(:'payout_id', 'mock', 'pout_mock_1', 'UTR0001');
select tests.as_user(:'seller');
select is((select status::text || ' ' || utr from payouts where id = :'payout_id'), 'paid UTR0001',
  'paid, with the bank reference');
select is((select status::text from seller_settlements where seller_order_id = :'part'), 'paid',
  'the settlement is paid');

-- Returned after the payout (the returns flow is Phase 3): taken from the
-- next one.
select tests.as_owner();
update seller_orders set status = 'returned' where id = :'part';
select tests.as_user(:'seller');
select is((select amount from seller_adjustments where seller_order_id = :'part'), -72780,
  'a return after payout becomes a deduction');
select tests.as_service();
select is(create_payouts() ->> 'payouts', '0', 'a balance below zero is not paid out');

-- A commission agreed with the brand (10%) applies to its next orders.
select tests.as_owner();
insert into private.commission_rates (seller_id, rate_bps) values (:'label_id', 1000);
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'cod', 'COD', null,
  gen_random_uuid()) ->> 'order_id' as order2 \gset
select tests.as_owner();
select id as part2 from seller_orders where order_id = :'order2' \gset
select tests.as_service();
select advance_seller_order(:'part2', 'packed');
select advance_seller_order(:'part2', 'shipped');
select advance_seller_order(:'part2', 'delivered');
select is((select commission from seller_settlements where seller_order_id = :'part2'), 9990,
  'the brand''s own commission rate is used');

select * from finish();
rollback;
