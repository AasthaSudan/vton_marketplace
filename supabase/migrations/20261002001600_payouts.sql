-- Seller payouts (Blueprint section 41, fig. 36-37). Money moves once an
-- order is final: when a seller order is delivered a settlement works out
-- what the brand earns (item value less commission, shipping, collection fee
-- and GST on those fees); after the brand's return window it becomes
-- eligible, and eligible settlements are batched into payouts to the
-- verified bank account. Returns after a payout come back as adjustments.
--
-- Every rate here is a placeholder until the commission policy and seller
-- agreement are decided (docs/ROADMAP.md 🔑) — change rows, not code.

create type public.settlement_status as enum ('pending', 'eligible', 'in_payout', 'paid', 'reversed');
create type public.payout_status as enum ('pending', 'processing', 'paid', 'failed');

-- ---------------------------------------------------------------------------
-- Fee policy
-- ---------------------------------------------------------------------------

create table private.payout_policy (
  key text primary key,
  value integer not null check (value >= 0),
  note text not null default ''
);
alter table private.payout_policy enable row level security;
revoke all on private.payout_policy from public, anon, authenticated;

insert into private.payout_policy (key, value, note) values
  ('commission_bps', 1500, 'Platform commission on item value (15%) — placeholder'),
  ('shipping_fee', 6000, 'Charged per shipment, paise (₹60) — placeholder'),
  ('collection_fee_bps', 200, 'Payment & collection fee on item value (2%) — placeholder'),
  ('gst_on_fees_bps', 1800, 'GST on Clothsy''s fees (18%)'),
  ('min_payout', 10000, 'Smallest payout, paise (₹100); smaller balances wait');

create or replace function private.policy(p_key text)
returns integer language sql stable security definer set search_path = '' as $$
  select value from private.payout_policy where key = p_key;
$$;

-- Category or seller-agreement commission overrides; the most specific
-- match wins, otherwise commission_bps.
create table private.commission_rates (
  id serial primary key,
  seller_id uuid references public.sellers (id) on delete cascade,
  category text,
  rate_bps integer not null check (rate_bps between 0 and 10000),
  unique nulls not distinct (seller_id, category)
);
alter table private.commission_rates enable row level security;
revoke all on private.commission_rates from public, anon, authenticated;

create or replace function private.commission_bps(p_seller_id uuid, p_category text)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select r.rate_bps from private.commission_rates r
     where (r.seller_id = p_seller_id or r.seller_id is null)
       and (r.category = p_category or r.category is null)
       and not (r.seller_id is null and r.category is null)
     order by (r.seller_id is not null) desc, (r.category is not null) desc
     limit 1),
    private.policy('commission_bps'));
$$;

-- ---------------------------------------------------------------------------
-- Settlements, adjustments, payouts
-- ---------------------------------------------------------------------------

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.sellers (id),
  amount integer not null check (amount > 0),
  settlement_count integer not null default 0,
  period_start timestamptz,
  period_end timestamptz,
  -- Where it went (masked).
  account_last4 text not null,
  ifsc text not null,
  status public.payout_status not null default 'pending',
  provider text,
  provider_payout_id text unique,
  -- Bank reference the seller can match on their statement.
  utr text,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index payouts_seller on public.payouts (seller_id, created_at desc);

create table public.seller_settlements (
  id uuid primary key default gen_random_uuid(),
  seller_order_id uuid not null unique references public.seller_orders (id),
  seller_id uuid not null references public.sellers (id),
  order_id uuid not null references public.orders (id),
  reference text not null,
  -- Item value at the selling price; Clothsy funds its own coupons and
  -- keeps the shipping it charges shoppers.
  gross integer not null check (gross >= 0),
  commission integer not null,
  shipping_fee integer not null,
  collection_fee integer not null,
  gst_on_fees integer not null,
  net integer not null,
  status public.settlement_status not null default 'pending',
  delivered_at timestamptz not null,
  eligible_at timestamptz not null,
  payout_id uuid references public.payouts (id),
  created_at timestamptz not null default now()
);

create index seller_settlements_seller on public.seller_settlements (seller_id, status, eligible_at);

-- Amounts added to or taken from the next payout (e.g. a return after the
-- order was already paid out).
create table public.seller_adjustments (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.sellers (id),
  seller_order_id uuid references public.seller_orders (id),
  amount integer not null check (amount <> 0),
  reason text not null,
  payout_id uuid references public.payouts (id),
  created_by uuid,
  created_at timestamptz not null default now()
);

create index seller_adjustments_open on public.seller_adjustments (seller_id) where payout_id is null;

alter table public.payouts enable row level security;
alter table public.seller_settlements enable row level security;
alter table public.seller_adjustments enable row level security;

revoke insert, update, delete on public.payouts, public.seller_settlements, public.seller_adjustments
  from anon, authenticated;

create policy "payouts: brand owners and finance read" on public.payouts
  for select to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    or private.is_staff(array['finance']::public.app_role[])
  );
create policy "settlements: brand owners and finance read" on public.seller_settlements
  for select to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    or private.is_staff(array['finance']::public.app_role[])
  );
create policy "adjustments: brand owners and finance read" on public.seller_adjustments
  for select to authenticated
  using (
    private.is_seller_member(seller_id, array['owner', 'manager']::public.seller_member_role[])
    or private.is_staff(array['finance']::public.app_role[])
  );

-- What a delivered seller order earns the brand (fig. 37).
create or replace function private.settlement_amounts(p_seller_order_id uuid)
returns table (gross integer, commission integer, shipping_fee integer, collection_fee integer,
               gst_on_fees integer, net integer)
language plpgsql stable security definer set search_path = '' as $$
declare
  so public.seller_orders;
begin
  select * into so from public.seller_orders where id = p_seller_order_id;
  select coalesce(sum(i.line_total), 0)::integer,
         coalesce(sum(round(i.line_total * private.commission_bps(so.seller_id, p.category) / 10000.0)), 0)::integer
    into gross, commission
  from public.order_items i
  join public.products p on p.id = i.product_id
  where i.seller_order_id = so.id;
  shipping_fee := private.policy('shipping_fee');
  collection_fee := round(gross * private.policy('collection_fee_bps') / 10000.0)::integer;
  gst_on_fees := round((commission + shipping_fee + collection_fee)
                       * private.policy('gst_on_fees_bps') / 10000.0)::integer;
  net := gross - commission - shipping_fee - collection_fee - gst_on_fees;
  return next;
end $$;

-- Delivered → a settlement; returned → reversed, or taken back from the
-- next payout when it was already paid out.
create or replace function private.seller_orders_settle()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  amounts record;
  st public.seller_settlements;
begin
  if new.status = 'delivered' then
    select * into amounts from private.settlement_amounts(new.id);
    insert into public.seller_settlements (
      seller_order_id, seller_id, order_id, reference, gross, commission, shipping_fee,
      collection_fee, gst_on_fees, net, delivered_at, eligible_at)
    values (
      new.id, new.seller_id, new.order_id, new.reference, amounts.gross, amounts.commission,
      amounts.shipping_fee, amounts.collection_fee, amounts.gst_on_fees, amounts.net,
      coalesce(new.delivered_at, now()),
      coalesce(new.delivered_at, now()) + make_interval(days => coalesce(
        (select s.return_window_days from public.sellers s where s.id = new.seller_id), 7)))
    on conflict (seller_order_id) do nothing;
  elsif new.status = 'returned' then
    select * into st from public.seller_settlements where seller_order_id = new.id for update;
    if found then
      if st.status in ('pending', 'eligible') then
        update public.seller_settlements set status = 'reversed' where id = st.id;
      elsif st.status in ('in_payout', 'paid') then
        insert into public.seller_adjustments (seller_id, seller_order_id, amount, reason)
        values (st.seller_id, st.seller_order_id, -st.net, 'Returned after payout: ' || st.reference);
      end if;
    end if;
  end if;
  return null;
end $$;

create trigger seller_orders_settle after update of status on public.seller_orders
  for each row when (new.status is distinct from old.status and new.status in ('delivered', 'returned'))
  execute function private.seller_orders_settle();

-- ---------------------------------------------------------------------------
-- Payout run (daily, pg_cron) and the payout service (Edge Function)
-- ---------------------------------------------------------------------------

-- Settlements past their return window become eligible; each brand with a
-- verified bank account and at least the minimum gets one payout.
create or replace function public.create_payouts()
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  b private.seller_bank_accounts;
  new_id uuid;
  created integer := 0;
  total integer := 0;
begin
  if not (coalesce((select auth.role()), 'service_role') = 'service_role'
          or private.is_staff(array['finance']::public.app_role[])) then
    raise exception 'NOT_ALLOWED' using errcode = 'P0001';
  end if;

  update public.seller_settlements set status = 'eligible'
  where status = 'pending' and eligible_at <= now();

  for r in
    select s.id as seller_id,
           coalesce((select sum(net) from public.seller_settlements st
                     where st.seller_id = s.id and st.status = 'eligible'), 0)
           + coalesce((select sum(amount) from public.seller_adjustments ad
                       where ad.seller_id = s.id and ad.payout_id is null), 0) as amount
    from public.sellers s
    where exists (select 1 from public.seller_settlements st
                  where st.seller_id = s.id and st.status = 'eligible')
       or exists (select 1 from public.seller_adjustments ad
                  where ad.seller_id = s.id and ad.payout_id is null)
    order by s.id
  loop
    select * into b from private.seller_bank_accounts where seller_id = r.seller_id;
    if not found or b.status <> 'verified' or r.amount < private.policy('min_payout') then
      continue;
    end if;
    insert into public.payouts (seller_id, amount, account_last4, ifsc)
    values (r.seller_id, r.amount, right(b.account_number, 4), b.ifsc)
    returning id into new_id;
    update public.seller_settlements
    set status = 'in_payout', payout_id = new_id
    where seller_id = r.seller_id and status = 'eligible';
    update public.seller_adjustments set payout_id = new_id
    where seller_id = r.seller_id and payout_id is null;
    update public.payouts p
    set settlement_count = x.n, period_start = x.first_delivery, period_end = x.last_delivery
    from (select count(*)::integer as n, min(delivered_at) as first_delivery,
                 max(delivered_at) as last_delivery
          from public.seller_settlements where payout_id = new_id) x
    where p.id = new_id;
    created := created + 1;
    total := total + r.amount;
  end loop;
  return jsonb_build_object('payouts', created, 'amount', total);
end $$;
grant execute on function public.create_payouts() to authenticated;

create or replace function public.pending_payouts(p_limit integer default 20)
returns setof uuid
language sql stable security definer set search_path = '' as $$
  select id from public.payouts
  where status in ('pending', 'failed') and attempts < 5
  order by created_at
  limit least(greatest(p_limit, 1), 100);
$$;

-- Takes a payout for sending (never twice) and returns what the provider
-- needs, including the full account number — service role only.
create or replace function public.claim_payout(p_payout_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  p public.payouts;
  b private.seller_bank_accounts;
begin
  update public.payouts
  set status = 'processing', attempts = attempts + 1
  where id = p_payout_id and status in ('pending', 'failed') and attempts < 5
  returning * into p;
  if not found then
    return null;
  end if;
  select * into b from private.seller_bank_accounts where seller_id = p.seller_id;
  if not found or b.status <> 'verified' or right(b.account_number, 4) <> p.account_last4
     or b.ifsc <> p.ifsc then
    update public.payouts set status = 'failed', last_error = 'bank account changed'
    where id = p.id;
    return null;
  end if;
  return jsonb_build_object(
    'payout_id', p.id,
    'seller_id', p.seller_id,
    'amount', p.amount,
    'account_holder', b.account_holder,
    'account_number', b.account_number,
    'ifsc', b.ifsc,
    'attempt', p.attempts);
end $$;

create or replace function public.complete_payout(
  p_payout_id uuid,
  p_provider text,
  p_provider_payout_id text,
  p_utr text default null
)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.payouts
  set status = 'paid', provider = p_provider, provider_payout_id = p_provider_payout_id,
      utr = p_utr, processed_at = now(), last_error = null
  where id = p_payout_id and status = 'processing';
  if found then
    update public.seller_settlements set status = 'paid' where payout_id = p_payout_id;
  end if;
end $$;

create or replace function public.fail_payout(p_payout_id uuid, p_error text)
returns void
language sql security definer set search_path = '' as $$
  update public.payouts set status = 'failed', last_error = left(p_error, 500)
  where id = p_payout_id and status = 'processing';
$$;

-- Daily payout run at 02:00 IST; queued payouts are sent every 15 minutes.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('create-payouts', '30 20 * * *', 'select public.create_payouts()');
    perform cron.schedule('payout-sweep', '*/15 * * * *',
      $job$select private.invoke_edge_function('payout', '{"sweep": true}'::jsonb)$job$);
  end if;
end $$;
