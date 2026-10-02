-- Sign-ins for the web panels on the LOCAL stack only (seeds never run on a
-- hosted project). Password for both: clothsy-local
--
--   seller@clothsy.test  owner of Noor Atelier (approved, payouts set up)
--   ops@clothsy.test     Clothsy staff: ops, moderator, finance, support
--
-- New brands sign up in the Seller Panel themselves.

create function pg_temp.local_user(p_email text, p_name text)
returns uuid language plpgsql as $$
declare
  uid uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change)
  values (
    '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', p_email,
    extensions.crypt('clothsy-local', extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', p_name),
    now(), now(), '', '', '', '');
  insert into auth.identities (user_id, provider_id, provider, identity_data, last_sign_in_at,
                               created_at, updated_at)
  values (uid, uid::text, 'email',
          jsonb_build_object('sub', uid::text, 'email', p_email, 'email_verified', true),
          now(), now(), now());
  return uid;
end $$;

do $$
declare
  seller_user uuid := pg_temp.local_user('seller@clothsy.test', 'Noor Kapoor');
  ops_user uuid := pg_temp.local_user('ops@clothsy.test', 'Clothsy Ops');
  noor uuid := (select id from public.sellers where handle = 'noor-atelier');
begin
  insert into public.seller_members (seller_id, user_id, role) values (noor, seller_user, 'owner');
  perform set_config('clothsy.internal', 'on', true);

  update public.seller_applications
  set owner_name = 'Noor Kapoor', contact_email = 'seller@clothsy.test',
      contact_phone = '+919999900011', business_type = 'proprietorship',
      legal_name = 'Noor Atelier', pan = 'ABCPK1234F', gstin = '07ABCPK1234F1Z5',
      pickup_line1 = '14 Shahpur Jat', pickup_city = 'New Delhi', pickup_state = 'Delhi',
      pickup_pin_code = '110049'
  where seller_id = noor;
  insert into private.seller_bank_accounts (seller_id, account_holder, account_number, ifsc,
                                            status, verified_at)
  values (noor, 'Noor Atelier', '50100012345678', 'HDFC0000123', 'verified', now());

  perform set_config('clothsy.internal', '', true);

  insert into public.staff_roles (user_id, role)
  select ops_user, r::public.app_role from unnest(array['ops', 'moderator', 'finance', 'support']) r;
end $$;
