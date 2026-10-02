-- Foundation: extensions, the private helper schema, locked-down function
-- privileges, shopper profiles and staff roles.
--
-- Conventions for every Clothsy migration:
--   * money is integer paise (₹1 = 100) — never numeric/float;
--   * every table has row level security;
--   * functions are not executable by clients unless granted explicitly;
--   * SECURITY DEFINER functions set search_path = '' and check ownership.

create extension if not exists pg_trgm with schema extensions;
create extension if not exists citext with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- Helpers that clients never call directly.
create schema if not exists private;
grant usage on schema private to anon, authenticated, service_role;

-- Postgres lets everyone (PUBLIC) execute new functions, and Supabase also
-- grants EXECUTE to anon/authenticated in `public`. Clothsy grants it per
-- function instead. (PUBLIC's default is global, so it is revoked globally.)
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated;
alter default privileges in schema private revoke execute on functions from anon, authenticated;
alter default privileges in schema public grant execute on functions to service_role;
alter default privileges in schema private grant execute on functions to service_role;

create type public.app_role as enum (
  'super_admin', 'ops', 'moderator', 'finance', 'support', 'growth'
);
create type public.seller_member_role as enum ('owner', 'manager', 'staff');

-- ---------------------------------------------------------------------------
-- Generic triggers and helpers
-- ---------------------------------------------------------------------------

create or replace function private.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Append-only history (orders, payments, Coins, stock): rows can be added,
-- never changed. Deletes are only allowed when cascading from a parent.
create or replace function private.append_only()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 then
    return old;
  end if;
  raise exception 'APPEND_ONLY' using
    errcode = 'P0001',
    detail = format('%s rows cannot be changed', tg_table_name);
end $$;

create or replace function private.try_uuid(value text)
returns uuid language plpgsql immutable as $$
begin
  return value::uuid;
exception when others then
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  phone text,
  email text,
  avatar_url text,
  member_tier text not null default 'Clothsy Member',
  -- StylePreferences.toJson(): categories, looks, brand_ids, budget, completed_at.
  style_prefs jsonb,
  deletion_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

alter table public.profiles enable row level security;

-- Shoppers may edit their own name, email, photo, preferences and deletion
-- request — never their tier.
revoke update on public.profiles from authenticated;
grant update (full_name, email, avatar_url, style_prefs, deletion_requested_at)
  on public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- Staff roles (Admin Panel, Phase 3)
-- ---------------------------------------------------------------------------

create table public.staff_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

alter table public.staff_roles enable row level security;

-- True when the signed-in user holds one of [roles] (any staff role when
-- [roles] is null). super_admin always counts.
create or replace function private.is_staff(roles public.app_role[] default null)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.staff_roles r
    where r.user_id = (select auth.uid())
      and (roles is null or r.role = any (roles) or r.role = 'super_admin')
  );
$$;
grant execute on function private.is_staff(public.app_role[]) to anon, authenticated;

create policy "profiles: read own" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or private.is_staff(array['support', 'ops']::public.app_role[]));

create policy "profiles: update own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "staff_roles: read own" on public.staff_roles
  for select to authenticated
  using (user_id = (select auth.uid()) or private.is_staff(array['super_admin']::public.app_role[]));

create policy "staff_roles: super admin manages" on public.staff_roles
  for all to authenticated
  using (private.is_staff(array['super_admin']::public.app_role[]))
  with check (private.is_staff(array['super_admin']::public.app_role[]));
