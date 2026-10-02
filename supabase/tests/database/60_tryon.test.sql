-- Try-On: consent before own photos, credits, the cache, credit refunds on
-- failure, one-tap deletion and the retention purge.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.make_fixtures();
select tests.create_user('+919000000601') as shopper \gset
select tests.create_user('+919000000602') as other \gset
select id as preset from tryon_presets order by sort_order limit 1 \gset
select id as blazer from products where handle = 'lavender-blazer' \gset
select tests.variant('v_blazer_lavender') as blazer_v \gset
select id as tote from products where category = 'Bags' and not is_tryon_eligible limit 1 \gset
select v.id as tote_v from product_variants v where v.product_id = :'tote' limit 1 \gset

-- Own photos need consent.
select tests.as_user(:'shopper');
select is(get_tryon_status() ->> 'consented', 'false', 'no consent at first');
select is((get_tryon_status() ->> 'credits')::integer, 15, '15 previews to start');
select throws_ok(
  format($$insert into tryon_photos (storage_path) values (%L)$$, :'shopper' || '/me.jpg'),
  '42501', null, 'no photo without consent');

select set_tryon_consent(true);
select lives_ok(
  format($$insert into tryon_photos (storage_path) values (%L)$$, :'shopper' || '/me.jpg'),
  'consented shoppers can add a photo');
select throws_ok(
  format($$insert into tryon_photos (storage_path) values (%L)$$, :'other' || '/not-mine.jpg'),
  '42501', null, 'only into their own folder');
select id as photo from tryon_photos where storage_path = :'shopper' || '/me.jpg' \gset

-- Jobs (run by the try-on service)
select tests.as_service();
select start_tryon_job(:'shopper', null, :'preset', :'blazer', :'blazer_v') ->> 'job_id' as job1 \gset
select finish_tryon_job(:'job1', 'succeeded', 'mock', null, null, 'https://example.com/r.jpg');
select is(
  (start_tryon_job(:'shopper', null, :'preset', :'blazer', :'blazer_v') ->> 'cached')::boolean,
  true, 'the same photo and piece come from the cache');
select tests.as_user(:'shopper');
select is((get_tryon_status() ->> 'credits')::integer, 14, 'the cache costs nothing');

select tests.as_service();
select start_tryon_job(:'shopper', :'photo', null, :'blazer', :'blazer_v') ->> 'job_id' as job2 \gset
select finish_tryon_job(:'job2', 'failed', 'mock', null, null, null, 'PROVIDER_ERROR');
select tests.as_user(:'shopper');
select is((get_tryon_status() ->> 'credits')::integer, 14, 'a failed preview gives the credit back');

select tests.as_service();
select throws_ok(
  format($$select start_tryon_job(%L, null, %L, %L, %L)$$, :'shopper', :'preset', :'tote', :'tote_v'),
  'P0001', 'NOT_ELIGIBLE', 'pieces without Try-On are refused');
select throws_ok(
  format($$select start_tryon_job(%L, %L, null, %L, %L)$$, :'other', :'photo', :'blazer', :'blazer_v'),
  'P0001', 'NO_CONSENT', 'nobody can use another shopper''s photo');

select tests.as_owner();
update tryon_credit_balances set balance = 0 where user_id = :'shopper';
select tests.as_service();
select throws_ok(
  format($$select start_tryon_job(%L, null, %L, %L, %L, true)$$, :'shopper', :'preset', :'blazer', :'blazer_v'),
  'P0001', 'NO_CREDITS', 'no credits, no new preview');

-- Only the shopper sees their photos and previews.
select tests.as_user(:'other');
select is((select count(*)::integer from tryon_photos), 0, 'other shoppers see no photos');
select is((select count(*)::integer from tryon_jobs), 0, 'or previews');
select tests.as_user(:'shopper');
select ok((select count(*) from tryon_jobs) >= 1, 'shoppers see their own previews');
select throws_ok(
  $$update tryon_credit_balances set balance = 999$$,
  '42501', null, 'shoppers cannot give themselves credits');

-- Withdrawing consent deletes photos and their previews.
select set_tryon_consent(false) -> 'deleted_paths' as deleted \gset
select ok(
  :'deleted'::jsonb ? ('tryon-photos/' || :'shopper' || '/me.jpg'),
  'withdrawing consent returns the files to remove');
select is((select count(*)::integer from tryon_photos), 0, 'photos are gone');
select tests.as_owner();
select ok(
  (select count(*) from tryon_purge_candidates() where kind = 'photo') >= 1,
  'and queued for the storage purge');
select ok(
  (select deleted_at is not null from tryon_jobs where id = :'job2'),
  'their previews are deleted too');
select is(
  (select granted from tryon_consents where user_id = :'shopper' order by id desc limit 1),
  false, 'the decision is on record');

select * from finish();
rollback;
