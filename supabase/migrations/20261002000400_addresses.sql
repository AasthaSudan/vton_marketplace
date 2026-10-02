-- Saved delivery addresses and PIN code serviceability (a stub table until a
-- courier aggregator's API replaces it in Phase 2).

create table public.addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  label text not null default 'Home',
  name text not null,
  phone text not null,
  line1 text not null,
  line2 text not null default '',
  city text not null,
  state text not null,
  pin_code text not null check (pin_code ~ '^[1-9][0-9]{5}$'),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index addresses_one_default on public.addresses (user_id) where is_default;

create trigger addresses_updated_at before update on public.addresses
  for each row execute function private.set_updated_at();

-- The first address is the default; choosing a new default clears the old.
create or replace function private.addresses_default()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' and not exists (
    select 1 from public.addresses a where a.user_id = new.user_id and a.id <> new.id
  ) then
    new.is_default := true;
  end if;
  if new.is_default then
    update public.addresses set is_default = false
    where user_id = new.user_id and id <> new.id and is_default;
  end if;
  return new;
end $$;

create trigger addresses_default before insert or update of is_default
  on public.addresses
  for each row execute function private.addresses_default();

-- Deleting the default promotes the newest remaining address.
create or replace function private.addresses_promote_default()
returns trigger language plpgsql as $$
begin
  if old.is_default then
    update public.addresses set is_default = true
    where id = (
      select id from public.addresses
      where user_id = old.user_id
      order by created_at desc
      limit 1
    );
  end if;
  return null;
end $$;

create trigger addresses_promote_default after delete on public.addresses
  for each row execute function private.addresses_promote_default();

alter table public.addresses enable row level security;

create policy "addresses: own" on public.addresses
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "addresses: support reads" on public.addresses
  for select to authenticated
  using (private.is_staff(array['support', 'ops']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- PIN serviceability
-- ---------------------------------------------------------------------------

create table public.serviceable_pincodes (
  pin_code text primary key check (pin_code ~ '^[1-9][0-9]{5}$'),
  city text not null,
  state text not null,
  is_serviceable boolean not null default true,
  cod_available boolean not null default true,
  -- Courier transit time in working days after the seller dispatches.
  eta_days integer not null default 3 check (eta_days between 1 and 15)
);

alter table public.serviceable_pincodes enable row level security;

create policy "pincodes: public" on public.serviceable_pincodes
  for select to anon, authenticated using (true);
create policy "pincodes: ops manage" on public.serviceable_pincodes
  for all to authenticated
  using (private.is_staff(array['ops']::public.app_role[]))
  with check (private.is_staff(array['ops']::public.app_role[]));

-- {serviceable, cod_available, eta_days, city, state} for a PIN. Unknown PINs
-- are not serviceable yet.
create or replace function public.check_pin_serviceability(p_pin text)
returns jsonb
language sql stable set search_path = public as $$
  select coalesce(
    (select jsonb_build_object(
       'pin_code', s.pin_code,
       'serviceable', s.is_serviceable,
       'cod_available', s.is_serviceable and s.cod_available,
       'eta_days', s.eta_days,
       'city', s.city,
       'state', s.state)
     from public.serviceable_pincodes s where s.pin_code = p_pin),
    jsonb_build_object(
      'pin_code', p_pin, 'serviceable', false, 'cod_available', false, 'eta_days', 0)
  );
$$;
grant execute on function public.check_pin_serviceability(text) to anon, authenticated;

create or replace function public.set_default_address(p_id uuid)
returns void
language sql set search_path = public as $$
  update public.addresses set is_default = true
  where id = p_id and user_id = (select auth.uid());
$$;
grant execute on function public.set_default_address(uuid) to authenticated;
