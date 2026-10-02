-- Seller onboarding: register, fill in, submit, be asked for more, resubmit,
-- get approved (or rejected with a reason). Blueprint fig. 32.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
\ir _helpers.psql
select no_plan();

select tests.create_user('+919000000801') as founder \gset
select tests.create_user('+919000000802') as stranger \gset
select tests.create_staff('+919000000803', array['moderator']) as reviewer \gset

-- Register
select tests.as_user(:'founder');
select register_seller('Kiet Threads') ->> 'seller_id' as seller_id \gset
select is((select handle::text from sellers where id = :'seller_id'), 'kiet-threads',
  'the store handle comes from the brand name');
select throws_ok($$select register_seller('Second Brand')$$,
  'P0001', 'ALREADY_REGISTERED', 'one store per owner');
select is(my_sellers() -> 0 ->> 'application_status', 'draft',
  'a new store starts with a draft application');
select is(my_sellers() -> 0 ->> 'role', 'owner', 'the founder owns it');
select is((select contact_phone from seller_applications where seller_id = :'seller_id'),
  '+919000000801', 'the sign-in phone is filled in');
select ok((my_sellers() -> 0 -> 'missing') ?& array['owner_name', 'business_type', 'legal_name',
    'pan', 'pickup_address', 'bank_account', 'document_pan_card', 'document_cancelled_cheque'],
  'the panel lists everything that is missing');
select is(
  tests.error_detail(format('select submit_seller_application(%L)', :'seller_id')) -> 'missing',
  my_sellers() -> 0 -> 'missing',
  'submitting an incomplete application says exactly what is missing');

-- Others see nothing of a pending store.
select tests.as_user(:'stranger');
select is((select count(*)::integer from sellers where id = :'seller_id'), 0,
  'a pending store is not public');
select is((select count(*)::integer from seller_applications where seller_id = :'seller_id'), 0,
  'others cannot read the application');
select throws_ok(
  format($$select set_seller_bank_account(%L, 'Mine', '123456789', 'HDFC0000123')$$, :'seller_id'),
  'P0001', 'SELLER_NOT_FOUND', 'others cannot set the payout account');
select tests.as_anon();
select is((select count(*)::integer from seller_applications), 0, 'visitors see no applications');

-- Fill it in
select tests.as_user(:'founder');
update seller_applications
set owner_name = 'Kiet Founder', contact_email = 'Founder@Kiet.Example',
    business_type = 'proprietorship', legal_name = 'Kiet Threads', pan = 'abcpk1234f',
    gstin = '09ZZZZZ9999Z1Z5', pickup_line1 = '1 Knowledge Park', pickup_city = 'Ghaziabad',
    pickup_state = 'Uttar Pradesh', pickup_pin_code = '201206'
where seller_id = :'seller_id';
select is((select pan || ' ' || contact_email from seller_applications where seller_id = :'seller_id'),
  'ABCPK1234F founder@kiet.example', 'PAN and email are normalised');
select ok((my_sellers() -> 0 -> 'missing') ? 'gstin_pan_mismatch',
  'a GSTIN must carry the business PAN');
update seller_applications set gstin = '09abcpk1234f1z5' where seller_id = :'seller_id';
select ok(not ((my_sellers() -> 0 -> 'missing') ? 'gstin_pan_mismatch'),
  'a matching GSTIN is accepted');
select throws_ok($$update seller_applications set status = 'approved'$$,
  '42501', null, 'sellers cannot approve themselves');

-- Payout account
select throws_ok(
  format($$select set_seller_bank_account(%L, 'Kiet Threads', '12ab', 'HDFC0000123')$$, :'seller_id'),
  'P0001', 'INVALID_BANK_DETAILS', 'bank details are checked');
select is(
  set_seller_bank_account(:'seller_id', 'Kiet Threads', '5010 0099 8877 66', 'hdfc0000123') - 'verified_at',
  '{"account_holder": "Kiet Threads", "last4": "7766", "ifsc": "HDFC0000123", "status": "unverified"}'::jsonb,
  'only the last four digits ever come back');
select throws_ok($$select * from private.seller_bank_accounts$$,
  '42501', null, 'the full account number is never readable');

-- Documents
insert into seller_documents (seller_id, kind, storage_path, file_name) values
  (:'seller_id', 'pan_card', :'seller_id' || '/pan.pdf', 'pan.pdf'),
  (:'seller_id', 'cancelled_cheque', :'seller_id' || '/cheque.jpg', 'cheque.jpg');
select is(my_sellers() -> 0 -> 'missing', '["document_gst_certificate"]'::jsonb,
  'with a GSTIN, only the GST certificate is still missing');
insert into seller_documents (seller_id, kind, storage_path, file_name)
values (:'seller_id', 'gst_certificate', :'seller_id' || '/gst.pdf', 'gst.pdf');
select is(my_sellers() -> 0 -> 'missing', '[]'::jsonb, 'nothing is missing');
select throws_ok(
  format($$insert into seller_documents (seller_id, kind, storage_path) values (%L, 'other', 'elsewhere/x.pdf')$$,
         :'seller_id'),
  '23514', null, 'documents live in the store''s own folder');

-- Submit; details lock while in review.
select is(submit_seller_application(:'seller_id') ->> 'status', 'submitted',
  'a complete application is submitted');
select throws_ok(
  format($$update seller_applications set legal_name = 'Changed' where seller_id = %L$$, :'seller_id'),
  'P0001', 'APPLICATION_LOCKED', 'details are locked while in review');
select throws_ok(
  format($$insert into seller_documents (seller_id, kind, storage_path) values (%L, 'other', %L)$$,
         :'seller_id', :'seller_id' || '/late.pdf'),
  '42501', null, 'documents are locked while in review');
select throws_ok(format($$select review_seller_application(%L, 'approve')$$, :'seller_id'),
  'P0001', 'NOT_ALLOWED', 'sellers cannot review their own application');

-- More information needed
select tests.as_user(:'reviewer');
select throws_ok(format($$select review_seller_application(%L, 'needs_info')$$, :'seller_id'),
  'P0001', 'NOTE_REQUIRED', 'asking for more always says what');
select is(review_seller_application(:'seller_id', 'needs_info', 'The cheque photo is blurred') ->> 'status',
  'needs_info', 'the reviewer asks for a clearer cheque');

select tests.as_user(:'founder');
select is(my_sellers() -> 0 ->> 'review_note', 'The cheque photo is blurred',
  'the seller sees exactly what is needed');
delete from seller_documents where seller_id = :'seller_id' and kind = 'cancelled_cheque';
insert into seller_documents (seller_id, kind, storage_path, file_name)
values (:'seller_id', 'cancelled_cheque', :'seller_id' || '/cheque-2.jpg', 'cheque-2.jpg');
select is(submit_seller_application(:'seller_id') ->> 'status', 'submitted',
  'and resubmits without starting over');

-- Approved
select tests.as_user(:'reviewer');
select is(review_seller_application(:'seller_id', 'approve') ->> 'status', 'approved',
  'the reviewer approves');
select throws_ok(format($$select review_seller_application(%L, 'reject', 'late')$$, :'seller_id'),
  'P0001', 'NOT_IN_REVIEW', 'a decided application is not reviewed again');
select tests.as_anon();
select is((select is_verified from sellers where id = :'seller_id'), true,
  'the approved store is public and verified');
select tests.as_user(:'founder');
select is(get_seller_bank_account(:'seller_id') ->> 'status', 'verified',
  'the payout account was verified with the documents');
select is(
  (select array_agg(to_status::text order by id) from seller_application_events
   where seller_id = :'seller_id'),
  array['draft', 'submitted', 'needs_info', 'submitted', 'approved'],
  'the verification history is kept');
select throws_ok($$update seller_application_events set note = 'edited'$$,
  '42501', null, 'the history cannot be edited');

-- Changing the payout account later pauses payouts until it is checked.
select is(set_seller_bank_account(:'seller_id', 'Kiet Threads', '123456789012', 'ICIC0001234') ->> 'status',
  'unverified', 'a new payout account needs verifying again');
select tests.as_user(:'reviewer');
select throws_ok(format($$select verify_seller_bank_account(%L, true)$$, :'seller_id'),
  'P0001', 'NOT_ALLOWED', 'moderators do not verify bank accounts');

-- A rejection keeps its reason and closes the application.
select tests.create_user('+919000000804') as second \gset
select tests.as_user(:'second');
select register_seller('Copy Cat Co') ->> 'seller_id' as copy_id \gset
select tests.as_owner();
update seller_applications
set owner_name = 'C', contact_email = 'c@example.com', contact_phone = '+919000000804',
    business_type = 'individual', legal_name = 'Copy Cat', pan = 'ZZZPC9999Z',
    pickup_line1 = '1 Road', pickup_city = 'Delhi', pickup_state = 'Delhi', pickup_pin_code = '110001'
where seller_id = :'copy_id';
insert into private.seller_bank_accounts (seller_id, account_holder, account_number, ifsc)
values (:'copy_id', 'Copy Cat', '123456789', 'SBIN0001234');
insert into seller_documents (seller_id, kind, storage_path) values
  (:'copy_id', 'pan_card', :'copy_id' || '/pan.pdf'),
  (:'copy_id', 'cancelled_cheque', :'copy_id' || '/cheque.pdf');
select tests.as_user(:'second');
select submit_seller_application(:'copy_id');
select tests.as_user(:'reviewer');
select is(review_seller_application(:'copy_id', 'reject', 'Brand logo belongs to another company')
  ->> 'status', 'rejected', 'the reviewer rejects with a reason');
select tests.as_user(:'second');
select is(my_sellers() -> 0 ->> 'review_note', 'Brand logo belongs to another company',
  'the seller sees why');
select throws_ok(format($$select submit_seller_application(%L)$$, :'copy_id'),
  'P0001', 'APPLICATION_LOCKED', 'a rejected application cannot simply be resubmitted');
select tests.as_anon();
select is((select count(*)::integer from sellers where id = :'copy_id'), 0,
  'a rejected store never becomes public');

-- The local demo account (seed/20_local_accounts.sql)
select tests.as_owner();
select (select id from auth.users where email = 'seller@clothsy.test') as seed_seller \gset
select tests.as_user(:'seed_seller');
select is(my_sellers() -> 0 ->> 'handle', 'noor-atelier', 'the local demo seller runs Noor Atelier');
select is(my_sellers() -> 0 ->> 'application_status', 'approved', 'already approved');

select * from finish();
rollback;
