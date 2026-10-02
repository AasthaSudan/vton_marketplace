-- Seller catalogue: drafts, submit, moderation, unpublish / republish,
-- stock adjustments, bulk stock import, low stock, collections.
-- Blueprint fig. 33.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.seller_owner('+919000000811', 'test-label') as owner \gset
select tests.seller_owner('+919000000812', 'noor-atelier') as rival \gset
select tests.create_staff('+919000000813', array['moderator']) as moderator \gset
select id as label_id from sellers where handle = 'test-label' \gset

-- A new listing
select tests.as_user(:'owner');
insert into products (seller_id, title, category, category_handles)
values (:'label_id', 'Linen Shirt', 'Tops', '{women,tops}')
returning id as product_id, handle::text as handle, status::text as status \gset
select ok(:'handle'::text like 'linen-shirt-%', 'a handle is made from the title');
select is(:'status'::text, 'draft', 'new listings are drafts');
select throws_ok(
  format($$insert into products (seller_id, title, status) values (%L, 'Sneaky', 'live')$$, :'label_id'),
  '42501', null, 'a listing cannot be created live');
select throws_ok(
  format($$insert into products (seller_id, title) values (%L, 'Not mine')$$,
         (select id from sellers where handle = 'noor-atelier')),
  '42501', null, 'sellers only list for their own brand');

insert into product_variants (product_id, sku, title, size, price, stock)
values (:'product_id', 'LS-M', 'Natural / M', 'M', 249900, 5);
select is((select seller_id from product_variants where sku = 'LS-M'), :'label_id'::uuid,
  'sizes belong to the listing''s brand');
select throws_ok(
  format($$insert into product_variants (product_id, sku, title, size, price) values (%L, 'LS-M', 'Again', 'M', 1000)$$,
         :'product_id'),
  '23505', null, 'a SKU is unique within the brand');

select tests.as_owner();
insert into product_variants (product_id, sku, title, size, price, stock)
select id, 'LS-M', 'Same SKU elsewhere', 'M', 100000, 1 from products where handle = 'lavender-blazer';
select pass('another brand may use the same SKU');

-- Submit for review
select tests.as_user(:'owner');
select is(
  tests.error_detail(format('select submit_product(%L)', :'product_id')) -> 'missing',
  '["description", "images"]'::jsonb,
  'submitting says exactly what the listing still needs');
update products
set description = 'Breathable linen shirt with a relaxed fit, mother-of-pearl buttons.',
    images = array['https://example.com/shirt.jpg'], tryon_requested = true, hsn_code = '6206'
where id = :'product_id';
select is(submit_product(:'product_id') ->> 'status', 'pending_review', 'submitted for review');
select throws_ok(format('select submit_product(%L)', :'product_id'),
  'P0001', 'NOT_SUBMITTABLE', 'a listing in review is not submitted twice');
select throws_ok(format('select moderate_product(%L, %L)', :'product_id', 'approve'),
  'P0001', 'NOT_ALLOWED', 'sellers cannot approve their own listings');
select tests.as_anon();
select is((select count(*)::integer from products where id = :'product_id'), 0,
  'listings in review are not public');

-- A brand still waiting for approval cannot submit.
select tests.create_user('+919000000814') as newbie \gset
select tests.as_user(:'newbie');
select register_seller('Fresh Label') ->> 'seller_id' as fresh_id \gset
insert into products (seller_id, title) values (:'fresh_id', 'First Piece') returning id as fresh_product \gset
select throws_ok(format('select submit_product(%L)', :'fresh_product'),
  'P0001', 'SELLER_NOT_APPROVED', 'brands are approved before their products are reviewed');

-- Moderation
select tests.as_user(:'moderator');
select throws_ok(format('select moderate_product(%L, %L)', :'product_id', 'reject'),
  'P0001', 'REASON_REQUIRED', 'a rejection always gives the reason');
select is(moderate_product(:'product_id', 'reject', 'Photos show a watermark') ->> 'status',
  'rejected', 'rejected with a reason');
select tests.as_user(:'owner');
select is((select rejection_reason from products where id = :'product_id'), 'Photos show a watermark',
  'the seller sees the specific reason');
update products set images = array['https://example.com/shirt-clean.jpg'] where id = :'product_id';
select is(submit_product(:'product_id') ->> 'status', 'pending_review', 'edited and resubmitted');
select tests.as_user(:'moderator');
select is(moderate_product(:'product_id', 'approve') ->> 'status', 'live', 'approved');
select tests.as_anon();
select is(
  (select is_tryon_eligible::text || ' ' || (approved_at is not null)::text
   from products where id = :'product_id'),
  'true true', 'live, and Try-On ready as the seller asked');

-- Unpublish and republish (no second review)
select tests.as_user(:'owner');
select is(set_product_listed(:'product_id', false) ->> 'status', 'archived', 'unpublished');
select tests.as_anon();
select is((select count(*)::integer from products where id = :'product_id'), 0,
  'unpublished listings are hidden');
select tests.as_user(:'owner');
select is(set_product_listed(:'product_id', true) ->> 'status', 'live', 'republished straight away');
select is_empty(format($$delete from products where id = %L returning id$$, :'product_id'),
  'a listing that was live is never deleted');
select isnt_empty($$delete from products where handle = 'test-draft' returning id$$,
  'a draft that never went live can be deleted');
select tests.as_user(:'rival');
select throws_ok(format('select set_product_listed(%L, false)', :'product_id'),
  'P0001', 'PRODUCT_NOT_FOUND', 'other brands cannot unpublish it');

-- Stock
select tests.as_user(:'owner');
select is(adjust_stock(tests.variant('tst_cheap'), -1, 'Damaged'), 2, 'stock goes down by the adjustment');
select throws_ok(format('select adjust_stock(%L, -10)', tests.variant('tst_cheap')),
  'P0001', 'INSUFFICIENT_STOCK', 'stock never goes below zero');
select tests.as_user(:'rival');
select throws_ok(format('select adjust_stock(%L, 5)', tests.variant('tst_cheap')),
  'P0001', 'VARIANT_NOT_FOUND', 'other brands cannot change it');

select tests.as_user(:'owner');
select is((select is_low_stock from product_variants where sku = 'tst_cheap'), true,
  '2 left with an alert at 3 is low stock');
select is(
  tests.error_detail(format($$select bulk_set_stock(%L, '[{"sku": "tst_cheap", "stock": 9}, {"sku": "NOPE", "stock": 1}, {"sku": "LS-M", "stock": "-2"}]')$$,
                            :'label_id')) -> 'errors',
  '[{"line": 2, "sku": "NOPE", "error": "UNKNOWN_SKU"}, {"line": 3, "sku": "LS-M", "error": "INVALID_STOCK"}]'::jsonb,
  'a bulk import lists every bad row');
select is((select stock from product_variants where sku = 'tst_cheap'), 2,
  'and changes nothing when any row is bad');
select is(
  bulk_set_stock(:'label_id', '[{"sku": "tst_cheap", "stock": 9}, {"sku": "LS-M", "stock": 5}]'),
  '{"updated": 1, "unchanged": 1}'::jsonb, 'a good import sets the units available');
select is((select is_low_stock from product_variants where sku = 'tst_cheap'), false,
  'the low-stock alert clears');
select tests.as_owner();
select is(
  (select reason::text || ' ' || note from inventory_movements m
   join product_variants v on v.id = m.variant_id
   where v.sku = 'tst_cheap' order by m.id desc limit 1),
  'bulk_import Bulk stock import', 'bulk imports are logged');

-- Collections
select tests.as_user(:'owner');
insert into seller_collections (seller_id, title, product_ids)
values (:'label_id', 'Summer Linen', array[:'product_id'::uuid]);
insert into seller_collections (seller_id, title, is_visible)
values (:'label_id', 'Coming soon', false);
select tests.as_anon();
select is((select array_agg(title) from seller_collections), array['Summer Linen'],
  'visitors see a brand''s visible collections');
select tests.as_user(:'rival');
select is_empty($$update seller_collections set title = 'Hijacked' returning id$$,
  'other brands cannot edit them');

select * from finish();
rollback;
