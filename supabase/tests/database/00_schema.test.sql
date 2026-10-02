-- Safety nets for the whole schema: row level security everywhere, only the
-- intended functions callable by the app, and history that cannot be edited.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select is(
  (select array_agg(c.relname::text order by c.relname)
   from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  null,
  'every public table has row level security'
);

-- Functions the app may call, and who may call them.
select is(
  (select array_agg(p.proname::text order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and has_function_privilege('anon', p.oid, 'execute')),
  array['check_pin_serviceability', 'search_products', 'validate_coupon'],
  'anonymous visitors can only search, check PINs and coupons'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and has_function_privilege('authenticated', p.oid, 'execute')),
  array[
    'advance_seller_order', 'cancel_order', 'cancel_seller_order',
    'check_pin_serviceability', 'delete_my_tryon_data', 'delete_tryon_photo',
    'fail_payment', 'get_seller_bank_account', 'get_tryon_status', 'my_sellers',
    'place_order', 'register_seller', 'review_seller_application', 'search_products',
    'set_default_address', 'set_seller_bank_account', 'set_tryon_consent',
    'submit_seller_application', 'validate_coupon', 'verify_seller_bank_account'],
  'signed-in users can only call the shopper, brand and staff functions (each checks the caller)'
);

select ok(
  not has_function_privilege('authenticated',
    'public.confirm_payment(uuid, text, text, integer, text)', 'execute'),
  'only the payment service can confirm payments'
);
select ok(
  has_function_privilege('service_role',
    'public.confirm_payment(uuid, text, text, integer, text)', 'execute'),
  'the payment service can confirm payments'
);
select ok(
  not has_function_privilege('authenticated',
    'public.start_tryon_job(uuid, uuid, uuid, uuid, uuid, boolean)', 'execute'),
  'only the try-on service can start jobs and spend credits'
);
select ok(
  not has_table_privilege('authenticated', 'private.seller_bank_accounts', 'select'),
  'bank account numbers are not readable through the API'
);

-- Append-only history.
select tests.make_fixtures();
update public.product_variants set stock = stock + 1 where sku = 'tst_cheap';
select throws_ok(
  $$update public.inventory_movements set delta = 99$$,
  'P0001', 'APPEND_ONLY', 'stock history cannot be edited'
);
select throws_ok(
  $$delete from public.inventory_movements$$,
  'P0001', 'APPEND_ONLY', 'stock history cannot be deleted'
);

select tests.create_user('+919000000001');
select throws_ok(
  $$update public.tryon_credit_ledger set delta = 100$$,
  'P0001', 'APPEND_ONLY', 'the credit ledger cannot be edited'
);

select is(
  (select balance from public.tryon_credit_balances b
   join auth.users u on u.id = b.user_id where u.phone = '+919000000001'),
  15,
  'new shoppers start with 15 AI previews'
);
select is(
  (select count(*)::integer from public.profiles p
   join auth.users u on u.id = p.id where u.phone = '+919000000001'),
  1,
  'new shoppers get a profile'
);

select * from finish();
rollback;
