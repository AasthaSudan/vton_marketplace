-- Search (with typos and brand names), PIN checks, coupon validation and
-- addresses.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.as_anon();

select ok(
  exists (select 1 from search_products('blazer') where handle = 'lavender-blazer'),
  'finds by title');
select ok(
  exists (select 1 from search_products('blazr') where handle = 'lavender-blazer'),
  'forgives typos');
select ok(
  exists (select 1 from search_products('silk dress')),
  'matches several words in any order');
select ok(
  (select bool_and(seller_id = (select id from sellers where handle = 'noor-atelier'))
   from search_products('noor atelier')),
  'finds a brand''s pieces by brand name');
select is(
  (select count(*)::integer from search_products('secret draft')),
  0, 'drafts never appear in search');
select is((select count(*)::integer from search_products('   ')), 0, 'empty searches return nothing');

select is(check_pin_serviceability('110001') ->> 'serviceable', 'true', 'launch PINs are served');
select is(check_pin_serviceability('700001') ->> 'cod_available', 'false', 'some PINs are prepaid only');
select is(check_pin_serviceability('999999') ->> 'serviceable', 'false', 'unknown PINs are not served yet');

select is(validate_coupon('clothsy10', 100000) -> 'rule' ->> 'percent_bps', '1000', 'coupons are case-insensitive');
select is(validate_coupon('NOPE', 100000) ->> 'reason', 'COUPON_INVALID', 'unknown coupons explain why');

-- Addresses: the first is the default, a new default replaces the old.
select tests.as_owner();
select tests.create_user('+919000000701') as shopper \gset
select tests.as_user(:'shopper');
insert into addresses (name, phone, line1, city, state, pin_code)
values ('Riya', '+919999900001', 'Home', 'Delhi', 'Delhi', '110001');
select is((select is_default from addresses), true, 'the first address is the default');
insert into addresses (name, phone, line1, city, state, pin_code, is_default)
values ('Riya', '+919999900001', 'Office', 'Gurugram', 'Haryana', '122001', true);
select is((select line1 from addresses where is_default), 'Office', 'a new default replaces the old');
select is((select count(*)::integer from addresses where is_default), 1, 'exactly one default');
delete from addresses where line1 = 'Office';
select is((select line1 from addresses where is_default), 'Home', 'deleting the default promotes another');
select throws_ok(
  $$insert into addresses (name, phone, line1, city, state, pin_code)
    values ('X', '1', 'Y', 'Z', 'W', '12345')$$,
  '23514', null, 'PIN codes have six digits');

select * from finish();
rollback;
