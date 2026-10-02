-- Seller dashboard and insights: today's work, sales, products, money,
-- performance score, daily sales, top products, Try-On conversion.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000841') as buyer \gset
select tests.create_user('+919000000842') as browser \gset
select tests.seller_owner('+919000000843', 'test-label') as seller \gset
select tests.seller_owner('+919000000844', 'noor-atelier') as rival \gset
select tests.address(:'buyer', '110001') as addr \gset
select id as label_id from sellers where handle = 'test-label' \gset
select id as tee_id from products where handle = 'test-tee' \gset

-- Two shoppers try the tee on; one of them buys two.
select tests.as_owner();
insert into tryon_jobs (user_id, preset_id, product_id, variant_id, status, created_at)
select x.u, (select id from tryon_presets order by id offset x.n limit 1), :'tee_id',
       tests.variant('tst_cheap'), 'succeeded', now() - interval '1 hour'
from (values (:'buyer'::uuid, 0), (:'browser'::uuid, 0), (:'browser'::uuid, 1)) x(u, n);

select tests.as_user(:'buyer');
select place_order(jsonb_build_array(tests.line('tst_cheap', 2)), :'addr', 'cod', 'COD', null,
  gen_random_uuid()) ->> 'order_id' as order_id \gset

select tests.as_user(:'seller');
select seller_dashboard(:'label_id') as dash \gset
select is(:'dash'::jsonb -> 'orders' ->> 'new', '1', 'one new order waits for the seller');
select is(:'dash'::jsonb -> 'orders' ->> 'today', '1', 'it came in today');
select is(:'dash'::jsonb -> 'sales_30d',
  '{"orders": 1, "units": 2, "gmv": 199800, "aov": 199800}'::jsonb, 'sales for the last 30 days');
select is(:'dash'::jsonb -> 'products' ->> 'live', '1', 'one live product');
select is(:'dash'::jsonb ->> 'low_stock', '1', 'the tee is running low (1 left)');
select is(:'dash'::jsonb -> 'performance' ->> 'score', '100', 'a clean record scores 100');

select is((select count(*)::integer from seller_sales_daily(:'label_id', 7)), 7,
  'daily sales cover every day, sales or not');
select is(
  (select gmv from seller_sales_daily(:'label_id', 7)
   where day = (now() at time zone 'Asia/Kolkata')::date),
  199800, 'today''s sales');
select is((select units from seller_top_products(:'label_id') where product_id = :'tee_id'), 2,
  'the tee is the top product');
select is(
  (select jsonb_build_object('tryons', tryons, 'shoppers', shoppers, 'buyers', buyers)
   from seller_tryon_insights(:'label_id') where product_id = :'tee_id'),
  '{"tryons": 3, "shoppers": 2, "buyers": 1}'::jsonb,
  'Try-On insights: 3 previews by 2 shoppers, 1 of whom bought it');

-- Cancelling as the seller lowers the score.
select tests.as_owner();
select id as part from seller_orders where order_id = :'order_id' \gset
select tests.as_user(:'seller');
select seller_cancel_order(:'part', 'Could not source fabric');
select is(seller_dashboard(:'label_id') -> 'performance' ->> 'score', '50',
  'cancelling the only order halves the score');

-- Only the brand (and Clothsy ops / finance) see it.
select tests.as_user(:'rival');
select throws_ok(format('select seller_dashboard(%L)', :'label_id'),
  'P0001', 'SELLER_NOT_FOUND', 'other brands cannot see the dashboard');
select throws_ok(format('select * from seller_tryon_insights(%L)', :'label_id'),
  'P0001', 'SELLER_NOT_FOUND', 'or its Try-On insights');

select * from finish();
rollback;
