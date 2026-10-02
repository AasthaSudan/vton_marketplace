-- Who can see and change the catalogue.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000101') as seller_user \gset
select tests.create_user('+919000000102') as other_user \gset
insert into public.seller_members (seller_id, user_id, role)
select id, :'seller_user', 'owner' from public.sellers where handle = 'test-label';

-- Visitors
select tests.as_anon();
select is(
  (select count(*)::integer from public.products where handle = 'test-draft'),
  0, 'visitors never see drafts');
select is(
  (select count(*)::integer from public.products where handle = 'test-tee'),
  1, 'visitors see live products');
select is(
  (select count(*)::integer from public.product_variants where sku = 'tst_draft'),
  0, 'visitors never see draft variants');
select ok(
  (select count(*) from public.products) >= 9, 'the seeded catalogue is public');
select is(
  (select count(*)::integer from public.coupons), 0, 'coupons cannot be listed');

-- A suspended brand disappears with its products.
select tests.as_owner();
update public.sellers set status = 'suspended' where handle = 'test-label';
select tests.as_anon();
select is(
  (select count(*)::integer from public.products where handle = 'test-tee'),
  0, 'products of a suspended brand are hidden');
select tests.as_owner();
update public.sellers set status = 'approved' where handle = 'test-label';

-- The brand's own team
select tests.as_user(:'seller_user');
select is(
  (select count(*)::integer from public.products where handle = 'test-draft'),
  1, 'sellers see their own drafts');
select lives_ok(
  $$update public.products set title = 'Renamed Draft' where handle = 'test-draft'$$,
  'sellers edit their own products');
select throws_ok(
  $$update public.products set status = 'live' where handle = 'test-draft'$$,
  '42501', null, 'sellers cannot publish without moderation');
select throws_ok(
  $$update public.products set is_featured = true, rating = 5 where handle = 'test-draft'$$,
  '42501', null, 'sellers cannot feature or rate their own products');
select is_empty(
  $$update public.products set title = 'Hijacked'
    where handle = 'lavender-blazer' returning id$$,
  'sellers cannot change another brand''s products');
select throws_ok(
  $$update public.product_variants set stock = 7 where sku = 'tst_cheap'$$,
  '42501', null, 'stock is never overwritten directly');
select is(
  adjust_stock(tests.variant('tst_cheap'), 4, 'New delivery'), 7,
  'sellers adjust their own stock');
select tests.as_owner();
select is(
  (select reason::text || ' ' || note from public.inventory_movements m
   join public.product_variants v on v.id = m.variant_id
   where v.sku = 'tst_cheap' order by m.id desc limit 1),
  'restock New delivery', 'stock changes are logged with the reason and note');

-- Another shopper
select tests.as_user(:'other_user');
select is(
  (select count(*)::integer from public.products where handle = 'test-draft'),
  0, 'other shoppers never see drafts');

-- Banners outside their dates are hidden.
select tests.as_owner();
insert into public.banners (headline, image_url, starts_at)
values ('Future drop', 'https://example.com/b.jpg', now() + interval '1 day');
select tests.as_anon();
select is(
  (select count(*)::integer from public.banners where headline = 'Future drop'),
  0, 'scheduled banners stay hidden until they start');

select * from finish();
rollback;
