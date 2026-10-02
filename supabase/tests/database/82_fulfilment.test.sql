-- Seller fulfilment: accept, pack (invoice numbered), ship with tracking,
-- deliver; the seller cancels before packing and the shopper is refunded.
-- Blueprint fig. 34-35.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000821') as buyer \gset
select tests.create_user('+919000000822') as stranger \gset
select tests.seller_owner('+919000000823', 'test-label') as seller \gset
select tests.seller_owner('+919000000824', 'noor-atelier') as rival \gset
select tests.address(:'buyer', '110001') as addr \gset
select id as label_id from sellers where handle = 'test-label' \gset

-- The brand ships from Delhi, to a shopper in Delhi.
select tests.as_owner();
update addresses set city = 'New Delhi', state = 'Delhi' where id = :'addr';
update products set hsn_code = '6109' where handle = 'test-tee';
select set_config('clothsy.internal', 'on', true);
update seller_applications set legal_name = 'Test Label Pvt Ltd', gstin = '07ABCDE1234F1Z5',
  pickup_line1 = '2 Okhla', pickup_city = 'New Delhi', pickup_state = 'Delhi', pickup_pin_code = '110020'
where seller_id = :'label_id';
select set_config('clothsy.internal', '', true);

-- A cash-on-delivery order: tee ₹999 from Test Label.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap', 2)), :'addr', 'cod', 'COD', null,
  gen_random_uuid()) ->> 'order_id' as order_id \gset
select tests.as_owner();
select id as part from seller_orders where order_id = :'order_id' \gset
select ok((select dispatch_by > now() + interval '1 day' from seller_orders where id = :'part'),
  'a placed order carries the brand''s dispatch promise');

-- Accept
select tests.as_user(:'rival');
select throws_ok(format('select seller_accept_order(%L)', :'part'),
  'P0001', 'ORDER_NOT_FOUND', 'other brands cannot touch the order');
select tests.as_user(:'seller');
select throws_ok(format($$select seller_ship_order(%L, 'Delhivery', 'AWB123456')$$, :'part'),
  'P0001', 'INVALID_TRANSITION', 'nothing ships before it is packed');
select is(seller_accept_order(:'part') ->> 'status', 'confirmed', 'the seller accepts the order');
select throws_ok(format('select seller_accept_order(%L)', :'part'),
  'P0001', 'INVALID_TRANSITION', 'an order is accepted once');
select isnt((select accepted_at from seller_orders where id = :'part'), null, 'when it was accepted is kept');

-- Pack: the invoice is numbered.
select ok((seller_pack_order(:'part') ->> 'invoice_number') ~ '^TEST/[0-9]{4}/00001$',
  'packing numbers the invoice per brand and financial year');
select is((select status::text from shipments where seller_order_id = :'part'), 'pending',
  'a parcel is waiting for pickup');

-- Invoice (prices include GST; ₹999 a piece is in the 5% slab; Delhi to Delhi)
select seller_order_invoice(:'part') as inv \gset
select is((:'inv'::jsonb -> 'lines' -> 0 ->> 'gst_rate_bps')::integer, 500, '5% GST up to ₹2,500 a piece');
select is((:'inv'::jsonb -> 'lines' -> 0 ->> 'taxable_value')::integer, 190286,
  'taxable value is backed out of the GST-inclusive price');
select is(
  (:'inv'::jsonb -> 'totals' ->> 'cgst')::integer + (:'inv'::jsonb -> 'totals' ->> 'sgst')::integer,
  199800 - 190286, 'CGST + SGST within the same state');
select is((:'inv'::jsonb -> 'totals' ->> 'igst')::integer, 0, 'no IGST within the same state');
select is((:'inv'::jsonb ->> 'cod_amount')::integer, 199800 + 15000,
  'the courier collects the whole cash-on-delivery amount, shipping included');
select is((:'inv'::jsonb -> 'totals' ->> 'total')::integer, 199800,
  'the brand''s invoice covers the items (Clothsy bills the shipping)');
select is(:'inv'::jsonb -> 'seller' ->> 'gstin', '07ABCDE1234F1Z5', 'the brand''s GSTIN is on the invoice');
select is(:'inv'::jsonb -> 'lines' -> 0 ->> 'hsn_code', '6109', 'with the HSN code');
select tests.as_user(:'buyer');
select is(seller_order_invoice(:'part') ->> 'invoice_number', :'inv'::jsonb ->> 'invoice_number',
  'the shopper can get their invoice');
select tests.as_user(:'stranger');
select throws_ok(format('select seller_order_invoice(%L)', :'part'),
  'P0001', 'ORDER_NOT_FOUND', 'nobody else can');

-- Ship
select tests.as_user(:'seller');
select throws_ok(format($$select seller_cancel_order(%L, 'Out of stock')$$, :'part'),
  'P0001', 'NOT_CANCELLABLE', 'sellers cannot cancel once packed');
select throws_ok(format($$select seller_ship_order(%L, 'Delhivery', '12')$$, :'part'),
  'P0001', 'TRACKING_REQUIRED', 'a real tracking number is needed');
select throws_ok(format($$select advance_seller_order(%L, 'shipped')$$, :'part'),
  'P0001', 'INVALID_TRANSITION', 'shipping goes through the shipping step');
select is(seller_ship_order(:'part', 'Delhivery', 'awb-1234567', 'https://track.example/awb-1234567') ->> 'status',
  'shipped', 'handed to the courier');
select is((select carrier || ' ' || tracking_number || ' ' || status::text from shipments where seller_order_id = :'part'),
  'Delhivery AWB-1234567 in_transit', 'the parcel is in transit with its AWB');
select tests.as_user(:'buyer');
select is(
  (select note from order_events where seller_order_id = :'part' and to_status = 'shipped'),
  'Delhivery · AWB-1234567', 'the shopper sees the courier and AWB');

-- Delivered (until a courier partner sends updates, the seller can mark it)
select tests.as_user(:'seller');
select is(advance_seller_order(:'part', 'delivered') ->> 'status', 'delivered', 'delivered');
select is((select status::text from shipments where seller_order_id = :'part'), 'delivered',
  'the parcel is delivered too');

-- Nothing skips a step.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'cod', 'COD', null,
  gen_random_uuid()) ->> 'order_id' as order2 \gset
select tests.as_owner();
select id as part2 from seller_orders where order_id = :'order2' \gset
select tests.as_service();
select throws_ok(format($$select advance_seller_order(%L, 'delivered')$$, :'part2'),
  'P0001', 'INVALID_TRANSITION', 'an order is never delivered without shipping');

-- The shopper can still cancel an accepted order.
select tests.as_user(:'seller');
select seller_accept_order(:'part2');
select tests.as_user(:'buyer');
select is(cancel_seller_order(:'order2', :'part2', 'Ordered by mistake') ->> 'payment_status', 'cod',
  'shoppers cancel accepted orders too');
select tests.as_owner();
select is((select cancelled_by from seller_orders where id = :'part2'), 'customer', 'who cancelled is kept');

-- The seller cannot fulfil a paid order: cancel with a reason, refund queued.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'upi', 'UPI', null,
  gen_random_uuid()) ->> 'order_id' as order3 \gset
select tests.as_service();
select record_payment_intent(:'order3', 'mock', 'order_mock_823', 114900);
select confirm_payment(:'order3', 'order_mock_823', 'pay_mock_823', 114900, 'client_verify');
select tests.as_owner();
select id as part3 from seller_orders where order_id = :'order3' \gset
select tests.stock('tst_cheap') as before_cancel \gset
select tests.as_user(:'seller');
select throws_ok(format($$select seller_cancel_order(%L, ' ')$$, :'part3'),
  'P0001', 'REASON_REQUIRED', 'a seller cancellation needs a reason');
select is((seller_cancel_order(:'part3', 'Sold out in store') ->> 'refund_amount')::integer, 114900,
  'the shopper is refunded in full');
select tests.as_owner();
select is(tests.stock('tst_cheap'), :before_cancel + 1, 'stock comes back');
select is((select cancelled_by || ' / ' || cancel_reason from seller_orders where id = :'part3'),
  'seller / Sold out in store', 'the cancellation is on the seller''s record');
select is((select amount from refunds where seller_order_id = :'part3'), 114900, 'refund queued');

-- Invoices run on consecutively.
select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap')), :'addr', 'cod', 'COD', null,
  gen_random_uuid()) ->> 'order_id' as order4 \gset
select tests.as_owner();
select id as part4 from seller_orders where order_id = :'order4' \gset
select tests.as_user(:'seller');
select ok((seller_pack_order(:'part4') ->> 'invoice_number') ~ '/00002$', 'the next invoice is 00002');

select * from finish();
rollback;
