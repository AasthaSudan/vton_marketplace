-- Clothsy AI Try-On (Blueprint section 35): model photos, the shopper's own
-- photos (only with consent, private, deleted after the retention period),
-- preview jobs and per-shopper credits.

create type public.tryon_job_status as enum ('queued', 'processing', 'succeeded', 'failed');

create or replace function private.tryon_retention()
returns interval language sql immutable as $$ select interval '30 days' $$;

-- AI previews a new shopper starts with (same as the app's mock).
create or replace function private.tryon_starting_credits()
returns integer language sql immutable as $$ select 15 $$;

create table public.tryon_presets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  image_url text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

-- Every consent decision, kept as history (append-only).
create table public.tryon_consents (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  granted boolean not null,
  policy_version text not null default '2026-10',
  created_at timestamptz not null default now()
);

create trigger tryon_consents_append_only before update or delete on public.tryon_consents
  for each row execute function private.append_only();

create or replace function private.has_tryon_consent(p_user uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select c.granted from public.tryon_consents c
    where c.user_id = p_user
    order by c.created_at desc, c.id desc
    limit 1
  ), false);
$$;
grant execute on function private.has_tryon_consent(uuid) to authenticated;

create table public.tryon_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Object path in the private `tryon-photos` bucket: <user id>/<file>.
  storage_path text not null unique,
  label text not null default 'My photo',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  deleted_at timestamptz
);

create table public.tryon_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  photo_id uuid references public.tryon_photos (id) on delete cascade,
  preset_id uuid references public.tryon_presets (id),
  product_id uuid not null references public.products (id),
  variant_id uuid not null references public.product_variants (id),
  status public.tryon_job_status not null default 'queued',
  provider text,
  provider_job_id text,
  garment_image_url text,
  -- Object path in the private `tryon-results` bucket, or a provider URL.
  result_path text,
  result_url text,
  error_code text,
  rating integer check (rating between 1 and 5),
  feedback_note text,
  credit_consumed boolean not null default false,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz not null default now() + interval '30 days',
  deleted_at timestamptz,
  check ((photo_id is null) <> (preset_id is null))
);

-- The same photo + variant is answered from the cache, without a credit.
create unique index tryon_jobs_cache on public.tryon_jobs
  (user_id, coalesce(photo_id, preset_id), variant_id)
  where status = 'succeeded' and deleted_at is null;
create index tryon_jobs_user on public.tryon_jobs (user_id, created_at desc);

create table public.tryon_credit_balances (
  user_id uuid primary key references auth.users (id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.tryon_credit_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  delta integer not null,
  reason text not null,
  job_id uuid,
  created_at timestamptz not null default now()
);

create trigger tryon_credit_ledger_append_only before update or delete on public.tryon_credit_ledger
  for each row execute function private.append_only();

alter table public.tryon_presets enable row level security;
alter table public.tryon_consents enable row level security;
alter table public.tryon_photos enable row level security;
alter table public.tryon_jobs enable row level security;
alter table public.tryon_credit_balances enable row level security;
alter table public.tryon_credit_ledger enable row level security;

revoke insert, update, delete on public.tryon_jobs, public.tryon_credit_balances,
  public.tryon_credit_ledger from anon, authenticated;
revoke update on public.tryon_photos from authenticated;
grant update (label, deleted_at) on public.tryon_photos to authenticated;
grant update (rating, feedback_note, deleted_at) on public.tryon_jobs to authenticated;

create policy "presets: public" on public.tryon_presets
  for select to anon, authenticated using (is_active);

create policy "consents: own" on public.tryon_consents
  for select to authenticated using (user_id = (select auth.uid()));
create policy "consents: add own" on public.tryon_consents
  for insert to authenticated with check (user_id = (select auth.uid()));

create policy "photos: own, not deleted" on public.tryon_photos
  for select to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null);
create policy "photos: add own with consent" on public.tryon_photos
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and storage_path like (select auth.uid())::text || '/%'
    and private.has_tryon_consent((select auth.uid()))
  );
create policy "photos: rename or delete own" on public.tryon_photos
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "jobs: own, not deleted" on public.tryon_jobs
  for select to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null);
create policy "jobs: rate or delete own" on public.tryon_jobs
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "credits: own" on public.tryon_credit_balances
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['support']::public.app_role[]));
create policy "credit ledger: own" on public.tryon_credit_ledger
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['support']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- New shoppers: a profile and their starting AI previews
-- ---------------------------------------------------------------------------

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, phone, email, full_name)
  values (new.id, new.phone, new.email,
          coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do nothing;
  insert into public.tryon_credit_balances (user_id, balance)
  values (new.id, private.tryon_starting_credits())
  on conflict (user_id) do nothing;
  insert into public.tryon_credit_ledger (user_id, delta, reason)
  values (new.id, private.tryon_starting_credits(), 'signup_grant');
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Shopper-facing helpers (row level security applies)
-- ---------------------------------------------------------------------------

-- {consented, credits, retention_days} for the Try-On screen.
create or replace function public.get_tryon_status()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'consented', private.has_tryon_consent((select auth.uid())),
    'credits', coalesce((
      select b.balance from public.tryon_credit_balances b
      where b.user_id = (select auth.uid())), 0),
    'retention_days', extract(day from private.tryon_retention())::integer);
$$;
grant execute on function public.get_tryon_status() to authenticated;

-- Soft-deletes every photo and preview of the caller; returns the storage
-- paths so the app (and the hourly cleanup) can remove the files.
create or replace function public.delete_my_tryon_data()
returns text[]
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  paths text[];
begin
  if uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;
  with photos as (
    update public.tryon_photos set deleted_at = now()
    where user_id = uid and deleted_at is null
    returning storage_path
  ), jobs as (
    update public.tryon_jobs set deleted_at = now()
    where user_id = uid and deleted_at is null and photo_id is not null
    returning result_path
  )
  select coalesce(array_agg(p), '{}') into paths
  from (
    select 'tryon-photos/' || storage_path as p from photos
    union all
    select 'tryon-results/' || result_path from jobs where result_path is not null
  ) x;
  return paths;
end $$;
grant execute on function public.delete_my_tryon_data() to authenticated;

-- Records consent; withdrawing it deletes the shopper's photos and previews.
create or replace function public.set_tryon_consent(p_granted boolean)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  paths text[] := '{}';
begin
  if uid is null then
    raise exception 'AUTH_REQUIRED' using errcode = 'P0001';
  end if;
  insert into public.tryon_consents (user_id, granted) values (uid, p_granted);
  if not p_granted then
    paths := public.delete_my_tryon_data();
  end if;
  return jsonb_build_object('consented', p_granted, 'deleted_paths', paths);
end $$;
grant execute on function public.set_tryon_consent(boolean) to authenticated;

create or replace function public.delete_tryon_photo(p_photo_id uuid)
returns text[]
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := (select auth.uid());
  paths text[];
begin
  with photo as (
    update public.tryon_photos set deleted_at = now()
    where id = p_photo_id and user_id = uid and deleted_at is null
    returning storage_path
  ), jobs as (
    update public.tryon_jobs set deleted_at = now()
    where photo_id = p_photo_id and user_id = uid and deleted_at is null
    returning result_path
  )
  select coalesce(array_agg(p), '{}') into paths
  from (
    select 'tryon-photos/' || storage_path as p from photo
    union all
    select 'tryon-results/' || result_path from jobs where result_path is not null
  ) x;
  return paths;
end $$;
grant execute on function public.delete_tryon_photo(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Jobs (called by the tryon-run Edge Function with the service role)
-- ---------------------------------------------------------------------------

-- Starts a preview for [p_user]: checks consent, ownership and eligibility,
-- answers from the cache when it can, otherwise spends one credit.
-- Returns {job_id, cached, status, result_path, result_url, credits}.
create or replace function public.start_tryon_job(
  p_user uuid,
  p_photo_id uuid,
  p_preset_id uuid,
  p_product_id uuid,
  p_variant_id uuid,
  p_force boolean default false
)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  job public.tryon_jobs;
  garment text;
  credits integer;
begin
  if (p_photo_id is null) = (p_preset_id is null) then
    raise exception 'INVALID_REQUEST' using errcode = 'P0001';
  end if;
  if p_photo_id is not null then
    if not private.has_tryon_consent(p_user) then
      raise exception 'NO_CONSENT' using errcode = 'P0001';
    end if;
    if not exists (
      select 1 from public.tryon_photos ph
      where ph.id = p_photo_id and ph.user_id = p_user and ph.deleted_at is null
    ) then
      raise exception 'PHOTO_NOT_FOUND' using errcode = 'P0001';
    end if;
  elsif not exists (select 1 from public.tryon_presets pr where pr.id = p_preset_id and pr.is_active) then
    raise exception 'PHOTO_NOT_FOUND' using errcode = 'P0001';
  end if;

  select coalesce(v.image_url, p.images[1]) into garment
  from public.product_variants v
  join public.products p on p.id = v.product_id
  where v.id = p_variant_id and p.id = p_product_id
    and p.status = 'live' and p.is_tryon_eligible;
  if not found then
    raise exception 'NOT_ELIGIBLE' using errcode = 'P0001';
  end if;

  if not p_force then
    select * into job from public.tryon_jobs j
    where j.user_id = p_user
      and coalesce(j.photo_id, j.preset_id) = coalesce(p_photo_id, p_preset_id)
      and j.variant_id = p_variant_id
      and j.status = 'succeeded' and j.deleted_at is null;
    if found then
      select balance into credits from public.tryon_credit_balances where user_id = p_user;
      return jsonb_build_object('job_id', job.id, 'cached', true, 'status', job.status,
        'result_path', job.result_path, 'result_url', job.result_url,
        'garment_image_url', job.garment_image_url, 'credits', coalesce(credits, 0));
    end if;
  else
    -- A fresh preview replaces the cached one.
    update public.tryon_jobs set deleted_at = now()
    where user_id = p_user
      and coalesce(photo_id, preset_id) = coalesce(p_photo_id, p_preset_id)
      and variant_id = p_variant_id and status = 'succeeded' and deleted_at is null;
  end if;

  update public.tryon_credit_balances set balance = balance - 1, updated_at = now()
  where user_id = p_user and balance > 0
  returning balance into credits;
  if not found then
    raise exception 'NO_CREDITS' using errcode = 'P0001';
  end if;

  insert into public.tryon_jobs (user_id, photo_id, preset_id, product_id, variant_id,
    status, garment_image_url, credit_consumed)
  values (p_user, p_photo_id, p_preset_id, p_product_id, p_variant_id,
    'processing', garment, true)
  returning * into job;
  insert into public.tryon_credit_ledger (user_id, delta, reason, job_id)
  values (p_user, -1, 'tryon', job.id);

  return jsonb_build_object('job_id', job.id, 'cached', false, 'status', job.status,
    'garment_image_url', garment, 'credits', credits);
end $$;

-- Records the outcome; a failed preview gives the credit back.
create or replace function public.finish_tryon_job(
  p_job_id uuid,
  p_status public.tryon_job_status,
  p_provider text default null,
  p_provider_job_id text default null,
  p_result_path text default null,
  p_result_url text default null,
  p_error_code text default null
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  job public.tryon_jobs;
begin
  update public.tryon_jobs
  set status = p_status,
      provider = coalesce(p_provider, provider),
      provider_job_id = coalesce(p_provider_job_id, provider_job_id),
      result_path = coalesce(p_result_path, result_path),
      result_url = coalesce(p_result_url, result_url),
      error_code = p_error_code,
      completed_at = case when p_status in ('succeeded', 'failed') then now() end
  where id = p_job_id and status in ('queued', 'processing')
  returning * into job;
  if not found then
    return;
  end if;
  if p_status = 'failed' and job.credit_consumed then
    update public.tryon_credit_balances set balance = balance + 1, updated_at = now()
    where user_id = job.user_id;
    insert into public.tryon_credit_ledger (user_id, delta, reason, job_id)
    values (job.user_id, 1, 'refund_failed_tryon', job.id);
    update public.tryon_jobs set credit_consumed = false where id = job.id;
  end if;
end $$;

-- Rows whose files must be removed: expired or deleted by the shopper.
create or replace function public.tryon_purge_candidates(p_limit integer default 200)
returns table (kind text, id uuid, path text)
language sql stable security definer set search_path = '' as $$
  (select 'photo', ph.id, 'tryon-photos/' || ph.storage_path
   from public.tryon_photos ph
   where ph.deleted_at is not null or ph.expires_at < now()
   limit p_limit)
  union all
  (select 'job', j.id, 'tryon-results/' || j.result_path
   from public.tryon_jobs j
   where j.result_path is not null
     and (j.deleted_at is not null or j.expires_at < now()
          -- previews of a photo that is going away go with it
          or exists (
            select 1 from public.tryon_photos ph
            where ph.id = j.photo_id and (ph.deleted_at is not null or ph.expires_at < now())))
   limit p_limit);
$$;

create or replace function public.tryon_purge_rows(p_photo_ids uuid[], p_job_ids uuid[])
returns void
language sql security definer set search_path = '' as $$
  delete from public.tryon_jobs where id = any (p_job_ids);
  delete from public.tryon_photos where id = any (p_photo_ids);
$$;
