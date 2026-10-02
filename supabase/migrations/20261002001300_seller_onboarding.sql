-- Seller onboarding (Blueprint section 38, fig. 32). A brand registers,
-- fills in owner, business, tax, pickup and bank details, uploads its
-- documents and submits. Clothsy's verification team approves, asks for more
-- information (the seller sees exactly what is missing and resubmits without
-- starting over) or rejects with a clear reason. Shoppers only ever see
-- approved sellers.

create type public.seller_application_status as enum (
  'draft', 'submitted', 'needs_info', 'approved', 'rejected'
);
create type public.business_type as enum (
  'individual', 'proprietorship', 'partnership', 'llp', 'private_limited', 'public_limited'
);
create type public.seller_document_kind as enum (
  'pan_card', 'gst_certificate', 'cancelled_cheque', 'address_proof',
  'brand_authorisation', 'other'
);
create type public.bank_account_status as enum ('unverified', 'verified', 'failed');

-- ---------------------------------------------------------------------------
-- Storefront extras (Store: brand story, policies, social links)
-- ---------------------------------------------------------------------------

alter table public.sellers
  add column instagram_url text,
  add column website_url text,
  add column support_email text,
  add column return_policy text not null default '',
  add column shipping_policy text not null default '';

grant update (instagram_url, website_url, support_email, return_policy, shipping_policy)
  on public.sellers to authenticated;

-- ---------------------------------------------------------------------------
-- Applications
-- ---------------------------------------------------------------------------

create table public.seller_applications (
  seller_id uuid primary key references public.sellers (id) on delete cascade,
  status public.seller_application_status not null default 'draft',
  owner_name text not null default '',
  contact_email text not null default '',
  -- E.164, e.g. +919876543210.
  contact_phone text not null default '',
  business_type public.business_type,
  legal_name text not null default '',
  pan text check (pan is null or pan ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'),
  gstin text check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  -- Where couriers collect parcels; also the seller's place of supply.
  pickup_line1 text not null default '',
  pickup_line2 text not null default '',
  pickup_city text not null default '',
  pickup_state text not null default '',
  pickup_pin_code text check (pickup_pin_code is null or pickup_pin_code ~ '^[1-9][0-9]{5}$'),
  review_note text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger seller_applications_updated_at before update on public.seller_applications
  for each row execute function private.set_updated_at();

-- PAN / GSTIN are stored upper-case; empty strings mean "not given".
create or replace function private.seller_applications_normalise()
returns trigger language plpgsql as $$
begin
  new.pan := nullif(upper(regexp_replace(coalesce(new.pan, ''), '\s', '', 'g')), '');
  new.gstin := nullif(upper(regexp_replace(coalesce(new.gstin, ''), '\s', '', 'g')), '');
  new.pickup_pin_code := nullif(trim(coalesce(new.pickup_pin_code, '')), '');
  new.owner_name := trim(new.owner_name);
  new.legal_name := trim(new.legal_name);
  new.contact_email := lower(trim(new.contact_email));
  new.contact_phone := regexp_replace(new.contact_phone, '[\s-]', '', 'g');
  return new;
end $$;

create trigger seller_applications_normalise before insert or update
  on public.seller_applications
  for each row execute function private.seller_applications_normalise();

-- Details can only change while the seller is filling the form in (draft) or
-- answering a request for more information; under review or after a
-- decision they are locked.
create or replace function private.seller_applications_guard()
returns trigger language plpgsql as $$
begin
  -- Clothsy's own corrections (support tooling, local seed data).
  if coalesce(current_setting('clothsy.internal', true), '') = 'on' then
    return new;
  end if;
  if old.status not in ('draft', 'needs_info')
     and (new.owner_name, new.contact_email, new.contact_phone, new.business_type,
          new.legal_name, new.pan, new.gstin, new.pickup_line1, new.pickup_line2,
          new.pickup_city, new.pickup_state, new.pickup_pin_code)
         is distinct from
         (old.owner_name, old.contact_email, old.contact_phone, old.business_type,
          old.legal_name, old.pan, old.gstin, old.pickup_line1, old.pickup_line2,
          old.pickup_city, old.pickup_state, old.pickup_pin_code) then
    raise exception 'APPLICATION_LOCKED' using errcode = 'P0001',
      detail = jsonb_build_object('status', old.status)::text;
  end if;
  return new;
end $$;

create trigger seller_applications_guard before update on public.seller_applications
  for each row execute function private.seller_applications_guard();

-- Every seller has an application; sellers created already approved (the
-- launch brands) start approved.
create or replace function private.sellers_create_application()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.seller_applications (seller_id, status, reviewed_at)
  values (
    new.id,
    case when new.status = 'approved' then 'approved' else 'draft' end::public.seller_application_status,
    case when new.status = 'approved' then now() end)
  on conflict (seller_id) do nothing;
  return null;
end $$;

create trigger sellers_application after insert on public.sellers
  for each row execute function private.sellers_create_application();

-- The verification history a seller and Clothsy both see (append-only).
create table public.seller_application_events (
  id bigserial primary key,
  seller_id uuid not null references public.sellers (id) on delete cascade,
  from_status public.seller_application_status,
  to_status public.seller_application_status not null,
  actor_role text not null check (actor_role in ('seller', 'staff', 'system')),
  actor_id uuid,
  note text,
  created_at timestamptz not null default now()
);

create index seller_application_events_seller on public.seller_application_events (seller_id, created_at);

create trigger seller_application_events_append_only before update or delete
  on public.seller_application_events
  for each row execute function private.append_only();

create or replace function private.add_application_event(
  p_seller_id uuid,
  p_from public.seller_application_status,
  p_to public.seller_application_status,
  p_actor text,
  p_note text default null
)
returns void language sql security definer set search_path = '' as $$
  insert into public.seller_application_events (seller_id, from_status, to_status, actor_role, actor_id, note)
  values (p_seller_id, p_from, p_to, p_actor, (select auth.uid()), p_note);
$$;

-- ---------------------------------------------------------------------------
-- Bank account (for payouts). Kept out of the API schema: only these
-- functions and the payout service read it, and sellers only ever see the
-- last four digits.
-- ---------------------------------------------------------------------------

create table private.seller_bank_accounts (
  seller_id uuid primary key references public.sellers (id) on delete cascade,
  account_holder text not null check (length(trim(account_holder)) >= 2),
  account_number text not null check (account_number ~ '^[0-9]{9,18}$'),
  ifsc text not null check (ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
  status public.bank_account_status not null default 'unverified',
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table private.seller_bank_accounts enable row level security;
revoke all on private.seller_bank_accounts from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- KYC documents: files in the private seller-documents bucket under
-- <seller id>/..., one row each.
-- ---------------------------------------------------------------------------

create table public.seller_documents (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.sellers (id) on delete cascade,
  kind public.seller_document_kind not null,
  storage_path text not null unique,
  file_name text not null default '',
  uploaded_by uuid default auth.uid() references auth.users (id),
  created_at timestamptz not null default now(),
  check (storage_path like seller_id::text || '/%')
);

create index seller_documents_seller on public.seller_documents (seller_id, kind);

-- True while the seller may change their application (and its documents).
create or replace function private.application_editable(p_seller_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.seller_applications a
    where a.seller_id = p_seller_id and a.status in ('draft', 'needs_info')
  );
$$;
grant execute on function private.application_editable(uuid) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('seller-documents', 'seller-documents', false, 10485760,
        array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "seller-documents: team reads, staff review"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'seller-documents'
    and (private.is_seller_member(private.try_uuid((storage.foldername(name))[1]),
           array['owner', 'manager']::public.seller_member_role[])
         or private.is_staff(array['ops', 'moderator']::public.app_role[]))
  );

create policy "seller-documents: team uploads while editable"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'seller-documents'
    and private.is_seller_member(private.try_uuid((storage.foldername(name))[1]),
          array['owner', 'manager']::public.seller_member_role[])
    and private.application_editable(private.try_uuid((storage.foldername(name))[1]))
  );

create policy "seller-documents: team removes while editable"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'seller-documents'
    and private.is_seller_member(private.try_uuid((storage.foldername(name))[1]),
          array['owner', 'manager']::public.seller_member_role[])
    and private.application_editable(private.try_uuid((storage.foldername(name))[1]))
  );

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.seller_applications enable row level security;
alter table public.seller_application_events enable row level security;
alter table public.seller_documents enable row level security;

-- Sellers edit the form fields; status and review fields change only through
-- submit / review functions.
revoke insert, update, delete on public.seller_applications from anon, authenticated;
grant update (owner_name, contact_email, contact_phone, business_type, legal_name, pan,
              gstin, pickup_line1, pickup_line2, pickup_city, pickup_state, pickup_pin_code)
  on public.seller_applications to authenticated;

create policy "applications: team and reviewers read" on public.seller_applications
  for select to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    or private.is_staff(array['ops', 'moderator', 'finance']::public.app_role[])
  );

create policy "applications: team edits" on public.seller_applications
  for update to authenticated
  using (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]))
  with check (private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[]));

revoke insert, update, delete on public.seller_application_events from anon, authenticated;
create policy "application events: team and reviewers read" on public.seller_application_events
  for select to authenticated
  using (
    private.is_seller_member(seller_id)
    or private.is_staff(array['ops', 'moderator']::public.app_role[])
  );

revoke update on public.seller_documents from anon, authenticated;
create policy "documents: team and reviewers read" on public.seller_documents
  for select to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    or private.is_staff(array['ops', 'moderator']::public.app_role[])
  );
create policy "documents: team adds while editable" on public.seller_documents
  for insert to authenticated
  with check (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    and private.application_editable(seller_id)
  );
create policy "documents: team removes while editable" on public.seller_documents
  for delete to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    and private.application_editable(seller_id)
  );

-- ---------------------------------------------------------------------------
-- What is still missing before an application can be submitted
-- ---------------------------------------------------------------------------

create or replace function private.application_missing(p_seller_id uuid)
returns text[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_remove(array[
    case when a.owner_name = '' then 'owner_name' end,
    case when a.contact_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then 'contact_email' end,
    case when a.contact_phone !~ '^\+91[6-9][0-9]{9}$' then 'contact_phone' end,
    case when a.business_type is null then 'business_type' end,
    case when a.legal_name = '' then 'legal_name' end,
    case when a.pan is null then 'pan' end,
    -- A GSTIN embeds the business PAN (characters 3-12).
    case when a.gstin is not null and a.pan is not null
           and substr(a.gstin, 3, 10) <> a.pan then 'gstin_pan_mismatch' end,
    case when a.pickup_line1 = '' or a.pickup_city = '' or a.pickup_state = ''
           or a.pickup_pin_code is null then 'pickup_address' end,
    case when not exists (
      select 1 from private.seller_bank_accounts b where b.seller_id = a.seller_id)
      then 'bank_account' end,
    case when not exists (
      select 1 from public.seller_documents d
      where d.seller_id = a.seller_id and d.kind = 'pan_card') then 'document_pan_card' end,
    case when not exists (
      select 1 from public.seller_documents d
      where d.seller_id = a.seller_id and d.kind = 'cancelled_cheque')
      then 'document_cancelled_cheque' end,
    case when a.gstin is not null and not exists (
      select 1 from public.seller_documents d
      where d.seller_id = a.seller_id and d.kind = 'gst_certificate')
      then 'document_gst_certificate' end
  ], null), '{}')
  from public.seller_applications a
  where a.seller_id = p_seller_id;
$$;

-- ---------------------------------------------------------------------------
-- Seller-facing functions
-- ---------------------------------------------------------------------------

-- The stores the signed-in user works for, with what the panel needs to
-- decide where to send them.
create or replace function public.my_sellers()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'seller_id', s.id,
      'handle', s.handle,
      'name', s.name,
      'status', s.status,
      'role', m.role,
      'application_status', a.status,
      'review_note', a.review_note,
      -- What still blocks submitting (only while the form can be edited).
      'missing', case when a.status in ('draft', 'needs_info')
                      then to_jsonb(coalesce(private.application_missing(s.id), '{}'))
                      else '[]'::jsonb end
    ) order by m.created_at), '[]'::jsonb)
  from public.seller_members m
  join public.sellers s on s.id = m.seller_id
  left join public.seller_applications a on a.seller_id = s.id
  where m.user_id = (select auth.uid());
$$;
grant execute on function public.my_sellers() to authenticated;

-- Starts a brand: a pending store, its owner and a draft application.
create or replace function public.register_seller(p_brand_name text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  brand text := trim(coalesce(p_brand_name, ''));
  base text;
  candidate text;
  n integer := 1;
  new_id uuid;
  u auth.users;
begin
  if uid is null then
    raise exception 'NOT_SIGNED_IN' using errcode = 'P0001';
  end if;
  if length(brand) < 2 or length(brand) > 60 then
    raise exception 'INVALID_NAME' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.seller_members where user_id = uid and role = 'owner') then
    raise exception 'ALREADY_REGISTERED' using errcode = 'P0001';
  end if;

  base := trim(both '-' from regexp_replace(lower(brand), '[^a-z0-9]+', '-', 'g'));
  if base = '' then
    base := 'brand';
  end if;
  candidate := base;
  while exists (select 1 from public.sellers where lower(handle::text) = candidate) loop
    n := n + 1;
    candidate := base || '-' || n;
  end loop;

  insert into public.sellers (handle, name, status)
  values (candidate, brand, 'pending')
  returning id into new_id;
  insert into public.seller_members (seller_id, user_id, role) values (new_id, uid, 'owner');

  select * into u from auth.users where id = uid;
  update public.seller_applications
  set contact_email = coalesce(u.email, ''),
      contact_phone = case
        when coalesce(u.phone, '') = '' then ''
        when u.phone like '+%' then u.phone
        else '+' || u.phone end,
      owner_name = coalesce(u.raw_user_meta_data ->> 'full_name', '')
  where seller_id = new_id;
  perform private.add_application_event(new_id, null, 'draft', 'seller');

  return jsonb_build_object('seller_id', new_id, 'handle', candidate);
end $$;
grant execute on function public.register_seller(text) to authenticated;

-- Adds or replaces the payout account. While the application is open it is
-- checked during review; changing it later pauses payouts until Clothsy
-- verifies the new account.
create or replace function public.set_seller_bank_account(
  p_seller_id uuid,
  p_account_holder text,
  p_account_number text,
  p_ifsc text
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_number text := regexp_replace(coalesce(p_account_number, ''), '[\s-]', '', 'g');
  v_ifsc text := upper(trim(coalesce(p_ifsc, '')));
  v_holder text := trim(coalesce(p_account_holder, ''));
  app_status public.seller_application_status;
begin
  if not private.is_seller_member(p_seller_id, array['owner']::public.seller_member_role[]) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  select status into app_status from public.seller_applications where seller_id = p_seller_id;
  if app_status in ('submitted', 'rejected') then
    raise exception 'APPLICATION_LOCKED' using errcode = 'P0001',
      detail = jsonb_build_object('status', app_status)::text;
  end if;
  if length(v_holder) < 2 or v_number !~ '^[0-9]{9,18}$' or v_ifsc !~ '^[A-Z]{4}0[A-Z0-9]{6}$' then
    raise exception 'INVALID_BANK_DETAILS' using errcode = 'P0001';
  end if;

  insert into private.seller_bank_accounts (seller_id, account_holder, account_number, ifsc)
  values (p_seller_id, v_holder, v_number, v_ifsc)
  on conflict (seller_id) do update
  set account_holder = excluded.account_holder,
      account_number = excluded.account_number,
      ifsc = excluded.ifsc,
      status = 'unverified',
      verified_at = null,
      updated_at = now();

  return public.get_seller_bank_account(p_seller_id);
end $$;

-- The payout account as the panel may show it: never the full number.
create or replace function public.get_seller_bank_account(p_seller_id uuid)
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'account_holder', b.account_holder,
    'last4', right(b.account_number, 4),
    'ifsc', b.ifsc,
    'status', b.status,
    'verified_at', b.verified_at)
  from private.seller_bank_accounts b
  where b.seller_id = p_seller_id
    and (private.is_seller_member(p_seller_id, array['owner', 'manager']::public.seller_member_role[])
         or private.is_staff(array['ops', 'finance']::public.app_role[]));
$$;
grant execute on function public.set_seller_bank_account(uuid, text, text, text) to authenticated;
grant execute on function public.get_seller_bank_account(uuid) to authenticated;

-- Sends the application for review, or says exactly what is missing.
create or replace function public.submit_seller_application(p_seller_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a public.seller_applications;
  missing text[];
begin
  if not private.is_seller_member(p_seller_id, array['owner', 'manager']::public.seller_member_role[]) then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into a from public.seller_applications where seller_id = p_seller_id for update;
  if a.status not in ('draft', 'needs_info') then
    raise exception 'APPLICATION_LOCKED' using errcode = 'P0001',
      detail = jsonb_build_object('status', a.status)::text;
  end if;
  missing := private.application_missing(p_seller_id);
  if cardinality(missing) > 0 then
    raise exception 'APPLICATION_INCOMPLETE' using errcode = 'P0001',
      detail = jsonb_build_object('missing', missing)::text;
  end if;

  update public.seller_applications
  set status = 'submitted', submitted_at = now()
  where seller_id = p_seller_id;
  perform private.add_application_event(p_seller_id, a.status, 'submitted', 'seller');
  return jsonb_build_object('seller_id', p_seller_id, 'status', 'submitted');
end $$;
grant execute on function public.submit_seller_application(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Clothsy's verification team (the Admin Panel's review screen is Phase 3)
-- ---------------------------------------------------------------------------

-- approve | needs_info | reject. A request for more information and a
-- rejection always carry a note the seller sees.
create or replace function public.review_seller_application(
  p_seller_id uuid,
  p_decision text,
  p_note text default null
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a public.seller_applications;
  note text := nullif(trim(coalesce(p_note, '')), '');
  next_status public.seller_application_status;
begin
  if not private.is_staff(array['ops', 'moderator']::public.app_role[]) then
    raise exception 'NOT_ALLOWED' using errcode = 'P0001';
  end if;
  select * into a from public.seller_applications where seller_id = p_seller_id for update;
  if not found then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  if a.status <> 'submitted' then
    raise exception 'NOT_IN_REVIEW' using errcode = 'P0001',
      detail = jsonb_build_object('status', a.status)::text;
  end if;
  next_status := case p_decision
    when 'approve' then 'approved'
    when 'needs_info' then 'needs_info'
    when 'reject' then 'rejected'
  end;
  if next_status is null then
    raise exception 'INVALID_DECISION' using errcode = 'P0001';
  end if;
  if next_status <> 'approved' and note is null then
    raise exception 'NOTE_REQUIRED' using errcode = 'P0001';
  end if;

  update public.seller_applications
  set status = next_status, review_note = note, reviewed_at = now(),
      reviewed_by = (select auth.uid())
  where seller_id = p_seller_id;

  if next_status = 'approved' then
    update public.sellers set status = 'approved', is_verified = true where id = p_seller_id;
    -- The cancelled cheque was checked with the documents.
    update private.seller_bank_accounts
    set status = 'verified', verified_at = now()
    where seller_id = p_seller_id;
  end if;
  perform private.add_application_event(p_seller_id, a.status, next_status, 'staff', note);
  return jsonb_build_object('seller_id', p_seller_id, 'status', next_status);
end $$;
grant execute on function public.review_seller_application(uuid, text, text) to authenticated;

-- Marks a changed payout account as checked (or not), e.g. after a penny
-- drop. Payouts only go to verified accounts.
create or replace function public.verify_seller_bank_account(p_seller_id uuid, p_ok boolean)
returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_staff(array['ops', 'finance']::public.app_role[]) then
    raise exception 'NOT_ALLOWED' using errcode = 'P0001';
  end if;
  update private.seller_bank_accounts
  set status = case when p_ok then 'verified' else 'failed' end::public.bank_account_status,
      verified_at = case when p_ok then now() end
  where seller_id = p_seller_id;
  if not found then
    raise exception 'SELLER_NOT_FOUND' using errcode = 'P0001';
  end if;
  return public.get_seller_bank_account(p_seller_id);
end $$;
grant execute on function public.verify_seller_bank_account(uuid, boolean) to authenticated;
